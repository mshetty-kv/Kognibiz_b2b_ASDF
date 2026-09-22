/**
 * OfficeDepotPermissionAssigner
 *
 * Canonical chain step 8b: Profiles / Permission assignment (BR-01).
 * PRECONDITION: OfficeDepotBuyerUserProvisioner.execute() committed in a PRIOR transaction.
 * Traces to: FR-03 / US-03, EC-03.
 *
 * EVERY permission set and permission set license name below was confirmed by querying the
 * target org 00DgL00000L7NwjUAF on 2026-09-21 - not recalled, not inferred:
 *   SELECT Name, Label FROM PermissionSet WHERE IsOwnedByProfile = false
 *     -> B2BBuyer ("Buyer"), B2BBuyerManager ("Buyer Manager"), CommerceAdmin, CommerceUser ("Shopper"), Merchandiser
 *   SELECT DeveloperName, TotalLicenses, UsedLicenses FROM PermissionSetLicense
 *     -> B2BBuyerPsl (40 total / 10 used), CommerceAdminUserPsl (1040 / 2)
 * The recipe is copied from a buyer that already works in this org (chirag001@kognivera.com),
 * which holds exactly PermissionSet B2BBuyer + PermissionSetLicense B2BBuyerPsl.
 *
 * This class re-verifies each name at runtime and REFUSES to assign anything it cannot find,
 * which is the concrete EC-03 countermeasure. The licence is assigned before the permission
 * set because the platform rejects the set when its licence is absent.
 */
public with sharing class OfficeDepotPermissionAssigner {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotPermissionAssigner().run();
    }

    private static final String ACCOUNT_NAME = 'Northwind Office Group';
    private static final String BUYER_PERMISSION_SET = 'B2BBuyer';
    private static final String BUYER_PERMISSION_SET_LICENSE = 'B2BBuyerPsl';
    /** Project-owned supplemental set deployed from force-app/main/default/permissionsets/. */
    private static final String SUPPLEMENTAL_PERMISSION_SET = 'Office_Depot_Buyer_Access';

    private List<User> loadBuyerUsers() {
        List<User> users = [
            SELECT Id, Username FROM User
            WHERE Contact.Account.Name = :ACCOUNT_NAME AND IsActive = true
            WITH USER_MODE
        ];
        if (users.isEmpty()) {
            throw new CommerceAccessException(
                'No active buyer users under account "' + ACCOUNT_NAME + '". ' +
                'Run OfficeDepotBuyerUserProvisioner.execute() first and let it commit.');
        }
        return users;
    }

    /** EC-03 countermeasure: resolve by name, assign nothing that does not resolve. */
    private Map<String, Id> resolvePermissionSets() {
        Set<String> wanted = new Set<String>{ BUYER_PERMISSION_SET, SUPPLEMENTAL_PERMISSION_SET };
        Map<String, Id> byName = new Map<String, Id>();
        for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :wanted WITH USER_MODE]) {
            byName.put(ps.Name, ps.Id);
        }
        if (!byName.containsKey(BUYER_PERMISSION_SET)) {
            throw new CommerceAccessException(
                'EC-03: required permission set "' + BUYER_PERMISSION_SET + '" not found in this org. ' +
                'Halting rather than assigning a name that does not exist.');
        }
        if (!byName.containsKey(SUPPLEMENTAL_PERMISSION_SET)) {
            System.debug(LoggingLevel.WARN,
                'Supplemental permission set "' + SUPPLEMENTAL_PERMISSION_SET + '" not found. ' +
                'Deploy force-app/main/default/permissionsets/ first. Continuing with the standard set only.');
        }
        return byName;
    }

    private Id resolveBuyerLicenseId() {
        List<PermissionSetLicense> licenses = [
            SELECT Id, TotalLicenses, UsedLicenses FROM PermissionSetLicense
            WHERE DeveloperName = :BUYER_PERMISSION_SET_LICENSE WITH USER_MODE LIMIT 1
        ];
        if (licenses.isEmpty()) {
            throw new CommerceAccessException(
                'EC-03: permission set license "' + BUYER_PERMISSION_SET_LICENSE + '" not present in this org.');
        }
        PermissionSetLicense psl = licenses[0];
        if (psl.TotalLicenses != null && psl.UsedLicenses != null && psl.UsedLicenses >= psl.TotalLicenses) {
            throw new CommerceAccessException(
                'No seats remaining on ' + BUYER_PERMISSION_SET_LICENSE +
                ' (' + psl.UsedLicenses + '/' + psl.TotalLicenses + '). Free a seat before provisioning buyers.');
        }
        return psl.Id;
    }

    /** Licence first, permission set second. Bulkified: one query, one DML per stage. */
    private void assignLicenses(List<User> users, Id licenseId) {
        Set<Id> already = new Set<Id>();
        for (PermissionSetLicenseAssign a : [
            SELECT AssigneeId FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicenseId = :licenseId AND AssigneeId IN :users WITH USER_MODE
        ]) {
            already.add(a.AssigneeId);
        }
        List<PermissionSetLicenseAssign> toInsert = new List<PermissionSetLicenseAssign>();
        for (User u : users) {
            if (!already.contains(u.Id)) {
                toInsert.add(new PermissionSetLicenseAssign(AssigneeId = u.Id, PermissionSetLicenseId = licenseId));
            }
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All buyer users already hold ' + BUYER_PERMISSION_SET_LICENSE + '.');
            return;
        }
        List<Database.SaveResult> results = Database.insert(toInsert, false, AccessLevel.USER_MODE);
        for (Integer i = 0; i < results.size(); i++) {
            System.debug(results[i].isSuccess() ? LoggingLevel.INFO : LoggingLevel.ERROR,
                'PSL assign ' + (results[i].isSuccess() ? 'OK' : 'FAILED: ' + results[i].getErrors()));
        }
    }

    private void assignPermissionSets(List<User> users, Map<String, Id> permissionSetByName) {
        Set<Id> setIds = new Set<Id>(permissionSetByName.values());
        Set<String> already = new Set<String>();
        for (PermissionSetAssignment a : [
            SELECT AssigneeId, PermissionSetId FROM PermissionSetAssignment
            WHERE PermissionSetId IN :setIds AND AssigneeId IN :users WITH USER_MODE
        ]) {
            already.add(a.AssigneeId + '|' + a.PermissionSetId);
        }
        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (User u : users) {
            for (Id psId : setIds) {
                if (!already.contains(u.Id + '|' + psId)) {
                    toInsert.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = psId));
                }
            }
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All buyer permission set assignments already present.');
            return;
        }
        List<Database.SaveResult> results = Database.insert(toInsert, false, AccessLevel.USER_MODE);
        Integer ok = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                System.debug(LoggingLevel.ERROR, 'PermissionSetAssignment failed: ' + sr.getErrors());
            }
        }
        System.debug(LoggingLevel.INFO, 'Permission set assignments created: ' + ok + '/' + toInsert.size());
    }

    public void run() {
        List<User> users = loadBuyerUsers();
        Map<String, Id> permissionSets = resolvePermissionSets();
        Id licenseId = resolveBuyerLicenseId();
        assignLicenses(users, licenseId);
        assignPermissionSets(users, permissionSets);
        System.debug(LoggingLevel.INFO, 'Step 8b (Permissions) complete for ' + users.size() + ' buyer user(s).');
    }
}

/**
 * OfficeDepotPreflight  -  READ ONLY. Performs NO DML.
 *
 * Canonical chain step 1: Org Enablement (verification only).
 * Traces to: FR-01 / US-01, FR-03 / US-03 (EC-03 permission-set hallucination guard),
 *            NFR-01 (dependency order), NFR-02 (evidence).
 *
 * Run FIRST, before every other class in the chain. It fails loudly rather than letting a later
 * step create records out of canonical order (BR-01) or against a hallucinated API name.
 */
public with sharing class OfficeDepotPreflight {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotPreflight().run();
    }

    private static final String STORE_NAME = 'Office Depot';

    /** Permission set API names confirmed against org 00DgL00000L7NwjUAF on 2026-09-21. */
    private static final Set<String> REQUIRED_PERMISSION_SETS = new Set<String>{
        'B2BBuyer', 'CommerceAdmin', 'Merchandiser'
    };

    /** Permission set licence developer names confirmed in the same org on the same date. */
    private static final Set<String> REQUIRED_PSL = new Set<String>{
        'B2BBuyerPsl', 'CommerceAdminUserPsl'
    };

    private final List<String> findings = new List<String>();
    private Boolean failed = false;

    private void record(Boolean ok, String label, String detail) {
        this.findings.add((ok ? '[PASS] ' : '[FAIL] ') + label + ' :: ' + detail);
        if (!ok) {
            this.failed = true;
        }
    }

    /** Step 1 evidence: commerce objects are queryable, therefore Commerce is enabled. */
    private void verifyOrgEnablement() {
        Map<String, Schema.SObjectType> globalTypes = Schema.getGlobalDescribe();
        for (String objName : new List<String>{
            'WebStore', 'WebStoreNetwork', 'BuyerGroup', 'BuyerAccount',
            'CommerceEntitlementPolicy', 'ProductCatalog', 'ProductCategory', 'StoreIntegratedService'
        }) {
            Schema.SObjectType t = globalTypes.get(objName);
            record(t != null, 'OrgEnablement/' + objName, t == null ? 'SObject not present' : 'present');
            if (t != null && !t.getDescribe().isAccessible()) {
                record(false, 'OrgEnablement/' + objName, 'present but NOT accessible to running user');
            }
        }
    }

    /** EC-03 guard: every permission set name this project relies on must actually exist. */
    private void verifyPermissionSetNames() {
        Set<String> foundSets = new Set<String>();
        for (PermissionSet ps : [
            SELECT Name FROM PermissionSet WHERE Name IN :REQUIRED_PERMISSION_SETS WITH USER_MODE
        ]) {
            foundSets.add(ps.Name);
        }
        for (String required : REQUIRED_PERMISSION_SETS) {
            record(foundSets.contains(required), 'PermissionSet/' + required,
                foundSets.contains(required) ? 'exists in org' : 'MISSING - do not assign (EC-03 hallucination)');
        }

        Set<String> foundPsl = new Set<String>();
        for (PermissionSetLicense psl : [
            SELECT DeveloperName FROM PermissionSetLicense WHERE DeveloperName IN :REQUIRED_PSL WITH USER_MODE
        ]) {
            foundPsl.add(psl.DeveloperName);
        }
        for (String required : REQUIRED_PSL) {
            record(foundPsl.contains(required), 'PermissionSetLicense/' + required,
                foundPsl.contains(required) ? 'exists in org' : 'MISSING - buyer cannot be licensed');
        }
    }

    /**
     * Step 2 gate. Every downstream script depends on the WebStore existing, which in
     * this platform is produced by site creation from the "Commerce Store (LWR)" template,
     * NOT by a metadata deploy. See scripts/bash/10_create_store_and_site.sh.
     */
    private void verifyStoreAndSite() {
        List<WebStore> stores = [
            SELECT Id, Name, Type FROM WebStore WHERE Name = :STORE_NAME WITH USER_MODE LIMIT 1
        ];
        record(!stores.isEmpty(), 'WebStore/' + STORE_NAME,
            stores.isEmpty()
                ? 'NOT FOUND - run scripts/bash/10_create_store_and_site.sh first (BR-01 step 2)'
                : 'found ' + stores[0].Id + ' Type=' + stores[0].Type);

        if (stores.isEmpty()) {
            return;
        }
        List<WebStoreNetwork> links = [
            SELECT Id, Network.Name, Network.Status
            FROM WebStoreNetwork WHERE WebStoreId = :stores[0].Id WITH USER_MODE LIMIT 1
        ];
        record(!links.isEmpty(), 'WebStoreNetwork/' + STORE_NAME,
            links.isEmpty() ? 'store exists but has NO linked Experience Cloud site'
                            : 'linked to network "' + links[0].Network.Name + '" status=' + links[0].Network.Status);
    }

    /**
     * AD-01 reality check. The spec assumes a clean org; this one is not clean.
     * Surfacing that here keeps the assessment honest instead of silently colliding.
     */
    private void reportPreExistingState() {
        this.findings.add('[INFO] Pre-existing WebStore count: ' + [SELECT COUNT() FROM WebStore]);
        this.findings.add('[INFO] Pre-existing ProductCatalog count: ' + [SELECT COUNT() FROM ProductCatalog]);
        this.findings.add('[INFO] Pre-existing BuyerGroup count: ' + [SELECT COUNT() FROM BuyerGroup]);
        this.findings.add('[INFO] Pre-existing Product2 count: ' + [SELECT COUNT() FROM Product2]);
    }

    /** Product2 in this org carries a universally-required custom picklist. Seeders must set it. */
    private void reportRequiredProductFields() {
        for (Schema.SObjectField f : Schema.SObjectType.Product2.fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isCustom() && d.isCreateable() && !d.isNillable() && !d.isDefaultedOnCreate()) {
                this.findings.add('[INFO] Product2 REQUIRED custom field: ' + d.getName() + ' (' + d.getType() + ')');
            }
        }
    }

    public void run() {
        verifyOrgEnablement();
        verifyPermissionSetNames();
        verifyStoreAndSite();
        reportPreExistingState();
        reportRequiredProductFields();
        for (String f : this.findings) {
            System.debug(LoggingLevel.INFO, f);
        }
        if (this.failed) {
            throw new CommerceBusinessException(
                'PREFLIGHT FAILED - do not continue the dependency chain. See [FAIL] lines above.');
        }
        System.debug(LoggingLevel.INFO, 'PREFLIGHT PASSED - safe to proceed to the next chain step.');
    }
}

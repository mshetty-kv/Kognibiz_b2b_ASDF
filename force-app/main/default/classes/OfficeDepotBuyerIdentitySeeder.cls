/**
 * OfficeDepotBuyerIdentitySeeder
 *
 * Canonical chain step 7a: Accounts -> Contacts (BR-01).
 * PRECONDITION: step 6 complete (entitlement policy and buyer group exist).
 * Traces to: FR-03 / US-03.
 *
 * EC-02 is structurally impossible here: this class creates Account first, then Contact
 * with a resolved AccountId, and it creates NO User at all. User provisioning is a separate
 * script (OfficeDepotBuyerUserProvisioner.execute()) for two reasons:
 *   1. Ordering - a portal User cannot exist before its Contact.
 *   2. MIXED_DML_OPERATION - User is a setup object and cannot be inserted in the same
 *      transaction as Account/Contact. Splitting the scripts is the fix, not a workaround.
 *
 * Also assigns an owner with a UserRole where possible: Salesforce refuses to enable a
 * customer portal user whose account owner has no role. Detected and reported here rather
 * than surfacing as an opaque failure in step 55.
 *
 * Bulkified: no SOQL or DML inside any loop.
 */
public with sharing class OfficeDepotBuyerIdentitySeeder {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotBuyerIdentitySeeder().run();
    }

    private static final String ACCOUNT_NAME = 'Northwind Office Group';

    /** FirstName, LastName, Email suffix key. */
    private static final List<List<String>> CONTACTS = new List<List<String>>{
        new List<String>{ 'Dana', 'Whitfield', 'dana.whitfield' },
        new List<String>{ 'Marcus', 'Ibarra', 'marcus.ibarra' }
    };

    private static final String EMAIL_DOMAIN = '@officedepot.invalid';

    private Id upsertAccount() {
        List<Account> found = [
            SELECT Id, OwnerId, Owner.UserRoleId FROM Account
            WHERE Name = :ACCOUNT_NAME WITH USER_MODE LIMIT 1
        ];
        Id accountId;
        if (!found.isEmpty()) {
            accountId = found[0].Id;
            System.debug(LoggingLevel.INFO, 'Account already present: ' + accountId);
            warnIfOwnerHasNoRole(found[0].Owner.UserRoleId);
            return accountId;
        }
        Account acct = new Account(
            Name = ACCOUNT_NAME,
            Description = 'Office Depot B2B storefront validation buyer account.',
            BillingStreet = '1200 Commerce Parkway',
            BillingCity = 'Austin',
            BillingPostalCode = '78701');
        applyBillingCountryAndState(acct);
        Database.SaveResult sr = Database.insert(acct, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('Account insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Account created: ' + sr.getId());

        List<User> me = [SELECT UserRoleId FROM User WHERE Id = :UserInfo.getUserId() WITH USER_MODE LIMIT 1];
        warnIfOwnerHasNoRole(me.isEmpty() ? null : me[0].UserRoleId);
        return sr.getId();
    }

    /**
     * Writes the billing country/state the way THIS org expects, without hardcoding either mode.
     *
     * When "State and Country/Territory Picklists" is enabled the org gains the companion fields
     * BillingCountryCode / BillingStateCode, the text fields become derived, and writing
     * BillingCountry = 'US' is rejected with:
     *   FIELD_INTEGRITY_EXCEPTION - "There's a problem with this country, even though it may
     *   appear correct. Please select a country/territory from the list of valid countries."
     * because the picklist's LABEL is "United States", not "US". When the feature is off there
     * are no *Code fields at all and the plain text field is the only option.
     *
     * Presence of BillingCountryCode in the describe map is the reliable runtime signal for
     * which mode the org is in. Scratch org 00DG100000EKcgz has the feature OFF; shared
     * Developer Edition 00DgL00000L7NwjUAF has it ON - hence the divergence.
     */
    private void applyBillingCountryAndState(Account acct) {
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('BillingCountryCode')) {
            acct.put('BillingCountryCode', 'US');
            acct.put('BillingStateCode', 'TX');
            System.debug(LoggingLevel.INFO,
                'State/Country picklists are ENABLED in this org; billing address set via ISO codes.');
        } else {
            acct.put('BillingCountry', 'US');
            acct.put('BillingState', 'TX');
            System.debug(LoggingLevel.INFO,
                'State/Country picklists are DISABLED in this org; billing address set as free text.');
        }
    }

    private void warnIfOwnerHasNoRole(Id roleId) {
        if (roleId == null) {
            System.debug(LoggingLevel.WARN,
                'Account owner has NO UserRole. Salesforce will reject portal user creation in step 55 ' +
                'with "PORTAL_USER_ALREADY_EXISTS_FOR_CONTACT" or a role-related error. ' +
                'Manual workaround: assign a UserRole to the account owner in Setup > Users.');
        }
    }

    private void upsertContacts(Id accountId) {
        Set<String> emails = new Set<String>();
        for (List<String> row : CONTACTS) {
            emails.add(row[2] + EMAIL_DOMAIN);
        }

        Set<String> existing = new Set<String>();
        for (Contact c : [
            SELECT Id, Email FROM Contact WHERE Email IN :emails WITH USER_MODE
        ]) {
            existing.add(c.Email);
        }

        List<Contact> toInsert = new List<Contact>();
        for (List<String> row : CONTACTS) {
            String email = row[2] + EMAIL_DOMAIN;
            if (existing.contains(email)) {
                continue;
            }
            toInsert.add(new Contact(
                AccountId = accountId, FirstName = row[0], LastName = row[1], Email = email));
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All buyer contacts already present.');
            return;
        }
        insert as user toInsert;
        System.debug(LoggingLevel.INFO, 'Contacts created: ' + toInsert.size());
    }

    public void run() {
        Id accountId = upsertAccount();
        upsertContacts(accountId);
        System.debug(LoggingLevel.INFO,
            'Step 7a (Accounts/Contacts) complete. Next: OfficeDepotBuyerUserProvisioner.execute() ' +
            '(separate transaction - User is a setup object).');
    }
}

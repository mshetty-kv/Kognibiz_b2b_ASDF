/**
 * OfficeDepotStoreLinker
 *
 * Canonical chain step 8: Memberships / Links (BR-01).
 * PRECONDITION: steps 2, 4, 5, 6 and 7a complete.
 * Traces to: FR-02 / US-02, FR-03 / US-03.
 *
 * Creates every link record that turns independent data into a working storefront:
 *   WebStoreCatalog     WebStore  <-> ProductCatalog
 *   WebStoreBuyerGroup  WebStore  <-> BuyerGroup
 *   WebStorePricebook   WebStore  <-> Pricebook2   (list + contract, both active)
 *   BuyerGroupMember    BuyerGroup<-> Account
 *   BuyerAccount        marks the Account as an active commerce buyer
 * BuyerGroupPricebook is created in step 40 because it is an entitlement-side link.
 *
 * All object and field API names verified by describe against org 00DgL00000L7NwjUAF
 * on 2026-09-21. Note WebStoreCatalog uses SalesStoreId (NOT WebStoreId) for its store
 * reference - a genuine platform inconsistency that a name-guessing implementation gets wrong.
 *
 * Bulkified: one query per link type, one DML per link type. No SOQL or DML in loops.
 */
public with sharing class OfficeDepotStoreLinker {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotStoreLinker().run();
    }

    private static final String STORE_NAME = 'Office Depot';
    private static final String CATALOG_NAME = 'Office Depot Catalog';
    private static final String BUYER_GROUP_NAME = 'Office Depot Business Buyers';
    private static final String ACCOUNT_NAME = 'Northwind Office Group';
    private static final Set<String> STORE_PRICEBOOKS = new Set<String>{
        'Office Depot List Price', 'Office Depot Contract Price'
    };

    private Id storeId;
    private Id catalogId;
    private Id buyerGroupId;
    private Id accountId;
    private Map<String, Id> pricebookByName = new Map<String, Id>();

    /** Resolves every prerequisite up front so a missing one fails before any DML happens. */
    private void resolvePrerequisites() {
        List<WebStore> stores = [SELECT Id FROM WebStore WHERE Name = :STORE_NAME WITH USER_MODE LIMIT 1];
        List<ProductCatalog> catalogs = [SELECT Id FROM ProductCatalog WHERE Name = :CATALOG_NAME WITH USER_MODE LIMIT 1];
        List<BuyerGroup> groups = [SELECT Id FROM BuyerGroup WHERE Name = :BUYER_GROUP_NAME WITH USER_MODE LIMIT 1];
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME WITH USER_MODE LIMIT 1];
        List<Pricebook2> books = [SELECT Id, Name FROM Pricebook2 WHERE Name IN :STORE_PRICEBOOKS WITH USER_MODE];

        List<String> missing = new List<String>();
        if (stores.isEmpty())   { missing.add('WebStore "' + STORE_NAME + '" (chain step 2)'); }
        if (catalogs.isEmpty()) { missing.add('ProductCatalog "' + CATALOG_NAME + '" (chain step 4)'); }
        if (groups.isEmpty())   { missing.add('BuyerGroup "' + BUYER_GROUP_NAME + '" (chain step 6)'); }
        if (accounts.isEmpty()) { missing.add('Account "' + ACCOUNT_NAME + '" (chain step 7a)'); }
        if (books.size() != STORE_PRICEBOOKS.size()) { missing.add('Pricebooks ' + STORE_PRICEBOOKS + ' (chain step 5)'); }
        if (!missing.isEmpty()) {
            throw new CommerceBusinessException('BR-01 VIOLATION - missing prerequisites: ' + String.join(missing, '; '));
        }

        this.storeId = stores[0].Id;
        this.catalogId = catalogs[0].Id;
        this.buyerGroupId = groups[0].Id;
        this.accountId = accounts[0].Id;
        for (Pricebook2 pb : books) {
            this.pricebookByName.put(pb.Name, pb.Id);
        }
    }

    private void linkCatalog() {
        List<WebStoreCatalog> existing = [
            SELECT Id FROM WebStoreCatalog
            WHERE SalesStoreId = :this.storeId AND ProductCatalogId = :this.catalogId
            WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'WebStoreCatalog link already present.');
            return;
        }
        Database.SaveResult sr = Database.insert(
            new WebStoreCatalog(SalesStoreId = this.storeId, ProductCatalogId = this.catalogId),
            false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('WebStoreCatalog insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'WebStoreCatalog linked.');
    }

    private void linkBuyerGroup() {
        List<WebStoreBuyerGroup> existing = [
            SELECT Id FROM WebStoreBuyerGroup
            WHERE WebStoreId = :this.storeId AND BuyerGroupId = :this.buyerGroupId
            WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'WebStoreBuyerGroup link already present.');
            return;
        }
        Database.SaveResult sr = Database.insert(
            new WebStoreBuyerGroup(WebStoreId = this.storeId, BuyerGroupId = this.buyerGroupId),
            false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('WebStoreBuyerGroup insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'WebStoreBuyerGroup linked.');
    }

    private void linkPricebooks() {
        Set<Id> existing = new Set<Id>();
        for (WebStorePricebook wsp : [
            SELECT Pricebook2Id FROM WebStorePricebook WHERE WebStoreId = :this.storeId WITH USER_MODE
        ]) {
            existing.add(wsp.Pricebook2Id);
        }
        List<WebStorePricebook> toInsert = new List<WebStorePricebook>();
        for (Id bookId : this.pricebookByName.values()) {
            if (!existing.contains(bookId)) {
                toInsert.add(new WebStorePricebook(
                    WebStoreId = this.storeId, Pricebook2Id = bookId, IsActive = true));
            }
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All WebStorePricebook links already present.');
            return;
        }
        insert as user toInsert;
        System.debug(LoggingLevel.INFO, 'WebStorePricebook links created: ' + toInsert.size());
    }

    private void linkBuyerGroupMember() {
        List<BuyerGroupMember> existing = [
            SELECT Id FROM BuyerGroupMember
            WHERE BuyerGroupId = :this.buyerGroupId AND BuyerId = :this.accountId
            WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'BuyerGroupMember already present.');
            return;
        }
        Database.SaveResult sr = Database.insert(
            new BuyerGroupMember(BuyerGroupId = this.buyerGroupId, BuyerId = this.accountId),
            false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('BuyerGroupMember insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'BuyerGroupMember created.');
    }

    /** BuyerStatus defaults to Pending; an unactivated buyer cannot transact. */
    private void activateBuyerAccount() {
        List<BuyerAccount> existing = [
            SELECT Id, BuyerStatus, IsActive FROM BuyerAccount
            WHERE BuyerId = :this.accountId WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            BuyerAccount ba = existing[0];
            if (ba.BuyerStatus != 'Active' || !ba.IsActive) {
                ba.BuyerStatus = 'Active';
                ba.IsActive = true;
                update as user ba;
                System.debug(LoggingLevel.INFO, 'BuyerAccount activated: ' + ba.Id);
            } else {
                System.debug(LoggingLevel.INFO, 'BuyerAccount already active.');
            }
            return;
        }
        Database.SaveResult sr = Database.insert(new BuyerAccount(
            Name = ACCOUNT_NAME, BuyerId = this.accountId, BuyerStatus = 'Active',
            IsActive = true, CommerceType = 'Buyer'), false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('BuyerAccount insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'BuyerAccount created and activated: ' + sr.getId());
    }

    /**
     * PHASE 1 of step 8: store links + buyer-account activation.
     *
     * BuyerGroupMember is deliberately NOT created here. Two empirical findings force the split,
     * both observed against scratch org 00DG100000EKcgz on 2026-09-21:
     *
     *  1. Ordering. The canonical chain lists memberships as "... BuyerGroupMember,
     *     BuyerGroupPricebook, BuyerAccount", which reads as though BuyerAccount comes last.
     *     It must come FIRST - inserting a BuyerGroupMember for an Account that is not yet a
     *     buyer fails with INVALID_FIELD on BuyerId: "This Account isn't a Buyer Account.
     *     Enable this Account as a buyer and try again."
     *
     *  2. Transaction boundary. Reordering alone is NOT enough. The platform's buyer check does
     *     not see a BuyerAccount that was inserted earlier in the SAME transaction, so the
     *     membership still fails - and because the exception rolls the transaction back, the
     *     catalog, buyer-group and pricebook links are lost too. (First run left all five link
     *     objects at 0 rows for exactly this reason.) BuyerAccount must therefore be COMMITTED
     *     before the membership is attempted.
     *
     * Call executeBuyerGroupMembership() afterwards, as a separate Apex invocation.
     */
    public void run() {
        resolvePrerequisites();
        linkCatalog();
        linkBuyerGroup();
        linkPricebooks();
        activateBuyerAccount();
        System.debug(LoggingLevel.INFO,
            'Step 8 phase 1 complete (links + BuyerAccount). ' +
            'Now run OfficeDepotStoreLinker.executeBuyerGroupMembership() in a SEPARATE transaction.');
    }

    /** PHASE 2 of step 8. Must run in its own transaction - see run(). */
    public static void executeBuyerGroupMembership() {
        OfficeDepotStoreLinker linker = new OfficeDepotStoreLinker();
        linker.resolvePrerequisites();
        linker.assertBuyerAccountCommitted();
        linker.linkBuyerGroupMember();
        System.debug(LoggingLevel.INFO, 'Step 8 phase 2 complete (BuyerGroupMember).');
    }

    /** Fails with a clear message rather than the platform's oblique INVALID_FIELD error. */
    private void assertBuyerAccountCommitted() {
        List<BuyerAccount> buyers = [
            SELECT Id, IsActive, BuyerStatus FROM BuyerAccount
            WHERE BuyerId = :this.accountId WITH USER_MODE LIMIT 1
        ];
        if (buyers.isEmpty() || !buyers[0].IsActive) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: Account "' + ACCOUNT_NAME + '" is not a committed, active ' +
                'BuyerAccount. Run OfficeDepotStoreLinker.execute() first and let it COMMIT ' +
                'before invoking this phase.');
        }
    }
}

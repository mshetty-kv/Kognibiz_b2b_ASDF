/**
 * OfficeDepotChainVerifier  -  READ ONLY. Performs NO DML.
 *
 * Canonical chain step 12 gate: proves every prior link actually exists in the org before
 * anybody claims the storefront is done.
 * Traces to: FR-05 / US-05, FR-06, NFR-01, NFR-02.
 *
 * The Constitution's Definition of Done says nothing counts until it is verified in the org.
 * This class is that verification. It prints a PASS/FAIL line per chain step so the
 * ASDF_ASSESSMENT.md scores can be grounded in observed output rather than intent.
 */
public with sharing class OfficeDepotChainVerifier {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotChainVerifier().run();
    }

    private static final String STORE_NAME = 'Office Depot';
    private static final String CATALOG_NAME = 'Office Depot Catalog';
    private static final String BUYER_GROUP_NAME = 'Office Depot Business Buyers';
    private static final String ACCOUNT_NAME = 'Northwind Office Group';
    private static final String SKU_PREFIX = 'OD-%';

    private final List<String> report = new List<String>();
    private Integer failures = 0;

    private void check(String step, Boolean ok, String detail) {
        this.report.add((ok ? '[PASS] ' : '[FAIL] ') + step + ' :: ' + detail);
        if (!ok) {
            this.failures++;
        }
    }

    public void run() {
        // Step 2 - WebStore and linked LWR site.
        List<WebStore> stores = [
            SELECT Id, Name, Type, StrikethroughPricebookId, OptionsGuestBrowsingEnabled, PaginationSize
            FROM WebStore WHERE Name = :STORE_NAME WITH USER_MODE LIMIT 1
        ];
        check('02 WebStore', !stores.isEmpty(), stores.isEmpty() ? 'missing' : String.valueOf(stores[0].Id));
        if (stores.isEmpty()) {
            emit();
            return;
        }
        Id storeId = stores[0].Id;

        List<WebStoreNetwork> networks = [
            SELECT Network.Name, Network.Status, Network.UrlPathPrefix
            FROM WebStoreNetwork WHERE WebStoreId = :storeId WITH USER_MODE LIMIT 1
        ];
        check('02 Linked LWR site', !networks.isEmpty(),
            networks.isEmpty() ? 'no WebStoreNetwork' :
            networks[0].Network.Name + ' status=' + networks[0].Network.Status +
            ' path=/' + networks[0].Network.UrlPathPrefix);

        // Step 3 - settings and internal integrations.
        List<AggregateResult> svc = [
            SELECT ServiceProviderType, COUNT(Id) total FROM StoreIntegratedService
            WHERE StoreId = :storeId WITH USER_MODE GROUP BY ServiceProviderType
        ];
        check('03 Integrations registered', !svc.isEmpty(), 'provider types=' + svc.size());
        check('03 Strikethrough pricebook set', stores[0].StrikethroughPricebookId != null,
            stores[0].StrikethroughPricebookId == null
                ? 'NOT SET - PLP/PDP will not show a struck-through M.R.P.'
                : String.valueOf(stores[0].StrikethroughPricebookId));

        // Step 4 - catalog, categories, products.
        List<ProductCatalog> catalogs = [SELECT Id FROM ProductCatalog WHERE Name = :CATALOG_NAME WITH USER_MODE LIMIT 1];
        check('04 ProductCatalog', !catalogs.isEmpty(), CATALOG_NAME);
        Integer categoryCount = catalogs.isEmpty() ? 0 : [SELECT COUNT() FROM ProductCategory WHERE CatalogId = :catalogs[0].Id];
        check('04 ProductCategory', categoryCount > 0, categoryCount + ' categories');
        Integer productCount = [SELECT COUNT() FROM Product2 WHERE StockKeepingUnit LIKE :SKU_PREFIX AND IsActive = true];
        check('04 Product2', productCount > 0, productCount + ' active Office Depot SKUs');
        Integer assignmentCount = [SELECT COUNT() FROM ProductCategoryProduct WHERE Product.StockKeepingUnit LIKE :SKU_PREFIX];
        check('04 Category assignment', assignmentCount > 0, assignmentCount + ' product-category links');

        // Step 5 - pricebooks and entries.
        Integer entryCount = [SELECT COUNT() FROM PricebookEntry WHERE Product2.StockKeepingUnit LIKE :SKU_PREFIX AND IsActive = true];
        check('05 PricebookEntry', entryCount > 0, entryCount + ' active entries');

        // Step 6 - entitlement.
        List<CommerceEntitlementPolicy> policies = [
            SELECT Id, IsActive, CanViewProduct, CanViewPrice FROM CommerceEntitlementPolicy
            WHERE Name = 'Office Depot Standard Entitlement' WITH USER_MODE LIMIT 1
        ];
        check('06 EntitlementPolicy active', !policies.isEmpty() && policies[0].IsActive
                && policies[0].CanViewProduct && policies[0].CanViewPrice,
            policies.isEmpty() ? 'missing' : 'active=' + policies[0].IsActive +
                ' viewProduct=' + policies[0].CanViewProduct + ' viewPrice=' + policies[0].CanViewPrice);
        Integer entitledProducts = policies.isEmpty() ? 0 :
            [SELECT COUNT() FROM CommerceEntitlementProduct WHERE PolicyId = :policies[0].Id];
        check('06 Products entitled', entitledProducts > 0, entitledProducts + ' entitled products');

        List<BuyerGroup> groups = [SELECT Id FROM BuyerGroup WHERE Name = :BUYER_GROUP_NAME WITH USER_MODE LIMIT 1];
        check('06 BuyerGroup', !groups.isEmpty(), BUYER_GROUP_NAME);

        // Step 7 - buyer identity.
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME WITH USER_MODE LIMIT 1];
        check('07a Account', !accounts.isEmpty(), ACCOUNT_NAME);
        Integer contactCount = [SELECT COUNT() FROM Contact WHERE Account.Name = :ACCOUNT_NAME];
        check('07a Contact', contactCount > 0, contactCount + ' contacts');
        List<User> buyers = [
            SELECT Id, Username, Profile.Name, IsActive FROM User
            WHERE Contact.Account.Name = :ACCOUNT_NAME WITH USER_MODE
        ];
        check('07b Buyer User', !buyers.isEmpty(),
            buyers.isEmpty() ? 'none' : buyers.size() + ' user(s), profile=' + buyers[0].Profile.Name);

        // Step 8 - links and permissions.
        check('08 WebStoreCatalog', [SELECT COUNT() FROM WebStoreCatalog WHERE SalesStoreId = :storeId] > 0, 'link present');
        check('08 WebStoreBuyerGroup', [SELECT COUNT() FROM WebStoreBuyerGroup WHERE WebStoreId = :storeId] > 0, 'link present');
        check('08 WebStorePricebook', [SELECT COUNT() FROM WebStorePricebook WHERE WebStoreId = :storeId AND IsActive = true] > 0, 'link present');
        check('08 BuyerGroupMember', groups.isEmpty() ? false :
            [SELECT COUNT() FROM BuyerGroupMember WHERE BuyerGroupId = :groups[0].Id] > 0, 'membership present');
        List<BuyerAccount> buyerAccounts = accounts.isEmpty() ? new List<BuyerAccount>() : [
            SELECT Id, BuyerStatus, IsActive FROM BuyerAccount WHERE BuyerId = :accounts[0].Id WITH USER_MODE LIMIT 1
        ];
        check('08 BuyerAccount active', !buyerAccounts.isEmpty() && buyerAccounts[0].IsActive
                && buyerAccounts[0].BuyerStatus == 'Active',
            buyerAccounts.isEmpty() ? 'missing' : 'status=' + buyerAccounts[0].BuyerStatus);

        if (!buyers.isEmpty()) {
            Integer psaCount = [
                SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId IN :buyers AND PermissionSet.Name = 'B2BBuyer'
            ];
            check('08b B2BBuyer assigned', psaCount > 0, psaCount + ' assignment(s)');
        }

        // Step 12 - transaction evidence (FR-05 / SM-02).
        // Correlated by AccountId, NOT by a store field on Order. Order.SalesStoreId exists in
        // the Developer Edition sandbox (56 rows carry it) but does not exist at all in scratch
        // org 00DG100000EKcgz. Guarding it behind a describe check is NOT sufficient: even
        // Database.countQuery with a literal string is schema-validated and still throws
        // System.QueryException "No such column 'SalesStoreId' on entity 'Order'" - verified by
        // running the guarded version, which failed despite containsKey() returning false.
        // The buyer account is the correlation that holds in both orgs.
        Integer orderCount = accounts.isEmpty()
            ? 0
            : [SELECT COUNT() FROM Order WHERE AccountId = :accounts[0].Id];
        check('12 Order placed', orderCount > 0,
            orderCount == 0 ? 'NO ORDER YET - end-to-end validation (SM-02) not satisfied' : orderCount + ' order(s)');

        emit();
    }

    private void emit() {
        for (String line : this.report) {
            System.debug(LoggingLevel.INFO, line);
        }
        System.debug(LoggingLevel.INFO, '=== CHAIN VERIFICATION: ' +
            (this.report.size() - this.failures) + ' passed, ' + this.failures + ' failed ===');
    }
}

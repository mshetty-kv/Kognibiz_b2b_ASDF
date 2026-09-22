/**
 * OfficeDepotStoreSettings
 *
 * Canonical chain step 3: Settings / Integrations (BR-01).
 * PRECONDITION: step 2 complete - WebStore "Office Depot" and its linked LWR site exist.
 * Traces to: FR-01 / US-01, FR-04 / US-04.
 *
 * Configures the store record itself and registers the INTERNAL (standard) commerce
 * integrations. Per BR-02 and Constitution "Simplicity over cleverness" we register the
 * Salesforce-provided internal providers and do NOT author external Apex services.
 *
 * Every Integration value below is a real picklist entry read from the org on 2026-09-21 via
 *   sf sobject describe --sobject StoreIntegratedService
 */
public with sharing class OfficeDepotStoreSettings {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotStoreSettings().run();
    }

    private static final String STORE_NAME = 'Office Depot';

    /**
     * Internal provider registrations. Key = ServiceProviderType, value = Integration.
     * NOTE: the org's StoreIntegratedService.Integration picklist exposes NO internal
     * Inventory provider, so inventory is intentionally absent (documented as a limitation).
     */
    private static final Map<String, String> INTERNAL_INTEGRATIONS = new Map<String, String>{
        'Price'      => 'Price__B2B_STOREFRONT__StandardPricing',
        'Promotions' => 'Promotions__B2B_STOREFRONT__StandardPromotions',
        'Shipment'   => 'Shipment__B2B_STOREFRONT__StandardShipment',
        'Tax'        => 'Tax__B2B_STOREFRONT__SfPaymentsTax'
    };

    /**
     * Tax fallback chain, most-preferred first.
     *
     * Tax__B2B_STOREFRONT__StandardTax is a valid, ACTIVE picklist value in both target orgs, but
     * inserting it against scratch org 00DG100000EKcgz raises a platform-level fault, not a
     * catchable DML error:
     *   UNKNOWN_EXCEPTION: An unexpected error occurred. Please include this ErrorId if you
     *   contact support: 464645055-399661 (139224812)
     * Isolated on 2026-09-21 by registering each provider one at a time - Price, Promotions,
     * Shipment and the checkout Flow all succeeded; only StandardTax faulted.
     * Tax__B2B_STOREFRONT__SfPaymentsTax registers cleanly, so it is the default above and
     * StandardTax is retained here only as a documented second choice.
     */
    private static final List<String> TAX_PROVIDER_FALLBACK = new List<String>{
        'Tax__B2B_STOREFRONT__SfPaymentsTax',
        'Tax__B2B_STOREFRONT__StandardTax'
    };

    /** Standard checkout flow registrations - configured, never rebuilt (BR-02). */
    private static final Map<String, String> CHECKOUT_FLOWS = new Map<String, String>{
        'Flow_CheckoutTemplate' => 'Flow__sfdc_checkout__CheckoutTemplate'
    };

    /**
     * Loads only Id and Name.
     *
     * Do NOT widen this SELECT. `AccessLevel.USER_MODE` validates the updateability of every
     * field POPULATED on the record being saved, not just the ones you changed. WebStore.Type is
     * create-only, so simply having selected it makes the later update fail with:
     *   CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY - "Operation failed due to fields being inaccessible
     *   on Sobject WebStore ... fieldNames: Type"
     * (observed against scratch org 00DG100000EKcgz, 2026-09-21). The configuration is therefore
     * applied to a fresh WebStore sObject carrying the Id plus only updateable fields.
     */
    private WebStore loadStore() {
        List<WebStore> stores = [
            SELECT Id, Name FROM WebStore WHERE Name = :STORE_NAME WITH USER_MODE LIMIT 1
        ];
        if (stores.isEmpty()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: WebStore "' + STORE_NAME + '" does not exist. ' +
                'Run scripts/bash/10_create_store_and_site.sh before this class.');
        }
        return stores[0];
    }

    /**
     * Strikethrough pricebook drives the dual "M.R.P. / price" presentation on PLP and PDP
     * (commerce_builder:searchResults showOriginalPrice, commerce_builder:productPricingDetails).
     * Returns null when the list pricebook has not been seeded yet - step 30 sets it.
     */
    private Id findListPricebookId() {
        List<Pricebook2> books = [
            SELECT Id FROM Pricebook2
            WHERE Name = 'Office Depot List Price' AND IsActive = true WITH USER_MODE LIMIT 1
        ];
        return books.isEmpty() ? null : books[0].Id;
    }

    private void applyStoreConfiguration(WebStore store) {
        // Fresh sObject carrying ONLY the Id and updateable fields - see loadStore().
        WebStore toUpdate = new WebStore(Id = store.Id);
        toUpdate.DefaultLanguage = 'en_US';
        toUpdate.SupportedLanguages = 'en_US';
        toUpdate.Country = 'US';
        toUpdate.DefaultTaxLocaleType = 'Net';
        toUpdate.PricingStrategy = 'LowestPrice';
        toUpdate.ProductGrouping = 'BestMatch';
        // 24 results maps cleanly onto the 4-across PLP grid in the visual reference.
        toUpdate.PaginationSize = 24;
        toUpdate.MaxValuesPerFacet = 100;
        // Left-rail facets on PLP are generated automatically rather than hand-built.
        toUpdate.OptionsAutoFacetingEnabled = true;
        toUpdate.OptionsCartCalculateEnabled = true;
        // B2B buyers are authenticated; no anonymous browsing or guest checkout.
        toUpdate.OptionsGuestBrowsingEnabled = false;
        toUpdate.OptionsGuestCheckoutEnabled = false;

        // SupportedCurrencies and CurrencyIsoCode only exist when multi-currency is enabled.
        // The Developer Edition sandbox has them (EUR/INR/JPY/USD); the single-currency scratch
        // org 00DG100000EKcgz does NOT - a static reference there fails to COMPILE, not just at
        // runtime. Setting it dynamically keeps one class deployable to both.
        if (Schema.SObjectType.WebStore.fields.getMap().containsKey('SupportedCurrencies')) {
            toUpdate.put('SupportedCurrencies', 'USD');
        }

        Id listBookId = findListPricebookId();
        if (listBookId != null) {
            toUpdate.StrikethroughPricebookId = listBookId;
        }

        Database.SaveResult sr = Database.update(toUpdate, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('WebStore update failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'WebStore configured: ' + store.Id +
            ' strikethroughPricebook=' + (listBookId == null ? 'NOT SET (run the pricebook seeder, then re-run this class)' : String.valueOf(listBookId)));
    }

    /** Bulkified: one query for existing registrations, one DML for the whole set. */
    private void registerIntegrations(WebStore store) {
        Set<String> existing = new Set<String>();
        for (StoreIntegratedService svc : [
            SELECT Id, Integration, ServiceProviderType
            FROM StoreIntegratedService WHERE StoreId = :store.Id WITH USER_MODE
        ]) {
            existing.add(svc.Integration);
        }

        Map<String, String> desired = new Map<String, String>();
        for (String providerType : INTERNAL_INTEGRATIONS.keySet()) {
            desired.put(INTERNAL_INTEGRATIONS.get(providerType), providerType);
        }
        for (String integrationName : CHECKOUT_FLOWS.values()) {
            desired.put(integrationName, 'Flow');
        }

        List<StoreIntegratedService> toInsert = new List<StoreIntegratedService>();
        for (String integrationName : desired.keySet()) {
            if (existing.contains(integrationName)) {
                System.debug(LoggingLevel.INFO, 'Integration already registered, skipping: ' + integrationName);
                continue;
            }
            toInsert.add(new StoreIntegratedService(
                StoreId = store.Id,
                Integration = integrationName,
                ServiceProviderType = desired.get(integrationName)
            ));
        }

        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All internal integrations already registered.');
            return;
        }

        // Registered ONE AT A TIME, each wrapped in its own try/catch, rather than as a single
        // bulk insert. This is a deliberate, narrow exception to the bulkification rule and the
        // reason is empirical: at least one valid provider value (StandardTax) raises an
        // uncatchable-at-row-level platform UNKNOWN_EXCEPTION. In a bulk insert that fault aborts
        // the entire statement, so four perfectly good registrations are lost because of one bad
        // one. The loop is bounded by the size of INTERNAL_INTEGRATIONS + CHECKOUT_FLOWS - a
        // fixed, single-digit count that is not driven by data volume - so there is no governor
        // limit exposure. A store is configured once, not per-record.
        for (StoreIntegratedService svc : toInsert) {
            registerOne(svc);
        }

        // If the preferred tax provider faulted, walk the documented fallback chain.
        if (!isProviderTypeRegistered(store.Id, 'Tax')) {
            for (String taxProvider : TAX_PROVIDER_FALLBACK) {
                if (isProviderTypeRegistered(store.Id, 'Tax')) {
                    break;
                }
                registerOne(new StoreIntegratedService(
                    StoreId = store.Id, Integration = taxProvider, ServiceProviderType = 'Tax'));
            }
            if (!isProviderTypeRegistered(store.Id, 'Tax')) {
                System.debug(LoggingLevel.ERROR,
                    'NO tax provider could be registered. Checkout will fail to calculate tax. ' +
                    'Register one manually: Commerce App > Office Depot > Integrations > Tax.');
            }
        }
    }

    /** Registers a single integration, absorbing platform faults so the chain can continue. */
    private void registerOne(StoreIntegratedService svc) {
        try {
            Database.SaveResult sr = Database.insert(svc, false, AccessLevel.USER_MODE);
            if (sr.isSuccess()) {
                System.debug(LoggingLevel.INFO, 'Registered integration: ' + svc.Integration);
            } else {
                System.debug(LoggingLevel.ERROR,
                    'FAILED to register ' + svc.Integration + ' :: ' + sr.getErrors());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'PLATFORM FAULT registering ' + svc.Integration + ' :: ' +
                e.getTypeName() + ' - ' + e.getMessage() +
                ' | Continuing; register this provider manually if it is required.');
        }
    }

    private Boolean isProviderTypeRegistered(Id storeId, String providerType) {
        return [
            SELECT COUNT() FROM StoreIntegratedService
            WHERE StoreId = :storeId AND ServiceProviderType = :providerType
        ] > 0;
    }

    public void run() {
        WebStore store = loadStore();
        applyStoreConfiguration(store);
        registerIntegrations(store);
        System.debug(LoggingLevel.INFO, 'Step 3 (Settings/Integrations) complete for ' + STORE_NAME);
    }
}

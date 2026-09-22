/**
 * OfficeDepotPricebookSeeder
 *
 * Canonical chain step 5: Pricebooks -> PricebookEntries (BR-01).
 * PRECONDITION: step 4 complete (products exist).
 * Traces to: FR-02 / US-02.
 *
 * Creates the two-pricebook structure that the visual reference depends on:
 *   - "Office Depot List Price"     -> the struck-through M.R.P. shown on PLP and PDP.
 *                                      Wired to WebStore.StrikethroughPricebookId in step 10.
 *   - "Office Depot Contract Price" -> the negotiated buyer-group price actually charged.
 * The delta between the two is what renders as the "You Save" slot in
 * commerce_builder:productPricingDetails and as the dual price on
 * commerce_builder:searchResults (showOriginalPrice + showNegotiatedPrice).
 *
 * Standard Pricebook entries are created first because a custom-pricebook entry cannot
 * exist without one. That is a platform dependency, enforced here rather than discovered
 * at runtime.
 *
 * Bulkified: no SOQL or DML inside any loop. No hardcoded Ids - the standard pricebook is
 * resolved by IsStandard = true, never by a literal 01s... Id.
 */
public with sharing class OfficeDepotPricebookSeeder {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotPricebookSeeder().run();
    }

    private static final String LIST_BOOK = 'Office Depot List Price';
    private static final String CONTRACT_BOOK = 'Office Depot Contract Price';

    /** SKU => list (M.R.P.) price. Contract price is derived per-SKU below. */
    private static final Map<String, Decimal> LIST_PRICES = new Map<String, Decimal>{
        'OD-PAP-0001' => 89.99,  'OD-PAP-0002' => 24.99,  'OD-PAP-0003' => 18.49,
        'OD-WRT-0001' => 32.99,  'OD-WRT-0002' => 14.99,  'OD-WRT-0003' => 21.99,
        'OD-FIL-0001' => 19.99,  'OD-FIL-0002' => 44.99,  'OD-LAP-0001' => 1149.00,
        'OD-LAP-0002' => 1899.00,'OD-PRN-0001' => 329.99, 'OD-PRN-0002' => 64.99,
        'OD-MON-0001' => 419.99, 'OD-MON-0002' => 129.99, 'OD-CHR-0001' => 289.99,
        'OD-CHR-0002' => 459.99, 'OD-DSK-0001' => 649.99, 'OD-DSK-0002' => 179.99,
        'OD-COF-0001' => 54.99,  'OD-CLN-0001' => 39.99
    };

    /** Contract discount applied to the list price to produce the negotiated B2B price. */
    private static final Decimal CONTRACT_DISCOUNT = 0.18;

    /**
     * Resolves the standard pricebook by IsStandard = true - never by a literal 01s... Id.
     *
     * Activates it if necessary. In a freshly created scratch org the standard pricebook exists
     * but ships with IsActive = false (observed in 00DG100000EKcgz: 01sG1000004nSP3IAM,
     * IsActive = false), and PricebookEntry inserts fail against an inactive book. The sandbox
     * org had it already active, so this only surfaces on a genuinely clean org - exactly the
     * class of defect AD-01 was hiding.
     */
    private Id resolveStandardPricebookId() {
        List<Pricebook2> standard = [
            SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1
        ];
        if (standard.isEmpty()) {
            throw new CommerceBusinessException('No standard Pricebook2 found in this org.');
        }
        if (!standard[0].IsActive) {
            standard[0].IsActive = true;
            update as user standard[0];
            System.debug(LoggingLevel.INFO, 'Standard pricebook was inactive; activated ' + standard[0].Id);
        }
        return standard[0].Id;
    }

    private Map<String, Id> upsertCustomPricebooks() {
        Set<String> names = new Set<String>{ LIST_BOOK, CONTRACT_BOOK };
        Map<String, Id> byName = new Map<String, Id>();
        for (Pricebook2 pb : [
            SELECT Id, Name FROM Pricebook2 WHERE Name IN :names WITH USER_MODE
        ]) {
            byName.put(pb.Name, pb.Id);
        }

        List<Pricebook2> toInsert = new List<Pricebook2>();
        if (!byName.containsKey(LIST_BOOK)) {
            toInsert.add(new Pricebook2(Name = LIST_BOOK, IsActive = true,
                Description = 'Office Depot list / M.R.P. pricing. Used as the strikethrough pricebook on the storefront.'));
        }
        if (!byName.containsKey(CONTRACT_BOOK)) {
            toInsert.add(new Pricebook2(Name = CONTRACT_BOOK, IsActive = true,
                Description = 'Office Depot negotiated contract pricing for entitled buyer groups.'));
        }
        if (!toInsert.isEmpty()) {
            insert as user toInsert;
            for (Pricebook2 pb : toInsert) {
                byName.put(pb.Name, pb.Id);
            }
        }
        System.debug(LoggingLevel.INFO, 'Custom pricebooks resolved: ' + byName.keySet());
        return byName;
    }

    private Map<String, Id> loadProductsBySku() {
        Map<String, Id> bySku = new Map<String, Id>();
        for (Product2 p : [
            SELECT Id, StockKeepingUnit FROM Product2
            WHERE StockKeepingUnit IN :LIST_PRICES.keySet() WITH USER_MODE
        ]) {
            bySku.put(p.StockKeepingUnit, p.Id);
        }
        if (bySku.size() != LIST_PRICES.size()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: expected ' + LIST_PRICES.size() + ' seeded products but found ' +
                bySku.size() + '. Run OfficeDepotCatalogSeeder.execute() first.');
        }
        return bySku;
    }

    /**
     * One query for all existing entries across all three books, one insert for the delta.
     * Standard entries must land before custom entries, so they are committed separately.
     */
    private void seedEntries(Id standardBookId, Map<String, Id> customBooks, Map<String, Id> productBySku) {
        Set<Id> productIds = new Set<Id>(productBySku.values());
        Set<String> existing = new Set<String>();
        for (PricebookEntry pbe : [
            SELECT Pricebook2Id, Product2Id FROM PricebookEntry
            WHERE Product2Id IN :productIds WITH USER_MODE
        ]) {
            existing.add(pbe.Pricebook2Id + '|' + pbe.Product2Id);
        }

        List<PricebookEntry> standardEntries = new List<PricebookEntry>();
        for (String sku : LIST_PRICES.keySet()) {
            Id productId = productBySku.get(sku);
            if (existing.contains(standardBookId + '|' + productId)) {
                continue;
            }
            standardEntries.add(new PricebookEntry(
                Pricebook2Id = standardBookId, Product2Id = productId,
                UnitPrice = LIST_PRICES.get(sku), IsActive = true, UseStandardPrice = false));
        }
        if (!standardEntries.isEmpty()) {
            insert as user standardEntries;
            System.debug(LoggingLevel.INFO, 'Standard pricebook entries created: ' + standardEntries.size());
        }

        Id listBookId = customBooks.get(LIST_BOOK);
        Id contractBookId = customBooks.get(CONTRACT_BOOK);
        List<PricebookEntry> customEntries = new List<PricebookEntry>();
        for (String sku : LIST_PRICES.keySet()) {
            Id productId = productBySku.get(sku);
            Decimal listPrice = LIST_PRICES.get(sku);
            if (!existing.contains(listBookId + '|' + productId)) {
                customEntries.add(new PricebookEntry(
                    Pricebook2Id = listBookId, Product2Id = productId,
                    UnitPrice = listPrice, IsActive = true, UseStandardPrice = false));
            }
            if (!existing.contains(contractBookId + '|' + productId)) {
                customEntries.add(new PricebookEntry(
                    Pricebook2Id = contractBookId, Product2Id = productId,
                    UnitPrice = (listPrice * (1 - CONTRACT_DISCOUNT)).setScale(2),
                    IsActive = true, UseStandardPrice = false));
            }
        }
        if (!customEntries.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(customEntries, false, AccessLevel.USER_MODE);
            Integer ok = 0;
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    ok++;
                } else {
                    System.debug(LoggingLevel.ERROR, 'PricebookEntry failed: ' + results[i].getErrors());
                }
            }
            System.debug(LoggingLevel.INFO, 'Custom pricebook entries created: ' + ok + '/' + customEntries.size());
        }
    }

    public void run() {
        Id standardBookId = resolveStandardPricebookId();
        Map<String, Id> customBooks = upsertCustomPricebooks();
        Map<String, Id> productBySku = loadProductsBySku();
        seedEntries(standardBookId, customBooks, productBySku);
        System.debug(LoggingLevel.INFO,
            'Step 5 (Pricebooks/Entries) complete. Re-run OfficeDepotStoreSettings.execute() ' +
            'to wire StrikethroughPricebookId now that the list book exists.');
    }
}

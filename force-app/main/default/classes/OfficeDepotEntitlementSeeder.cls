/**
 * OfficeDepotEntitlementSeeder
 *
 * Canonical chain step 6: Entitlement Policies -> Buyer Groups -> entitlement links (BR-01).
 * PRECONDITION: steps 4 and 5 complete (products and pricebooks exist).
 * Traces to: FR-02 / US-02.
 *
 * Domain principle enforced here: "Product visibility requires BOTH catalog/category
 * assignment AND an active entitlement policy." Step 20 did the catalog half; this class
 * does the entitlement half. Skipping it produces a storefront that renders but shows
 * zero products - the single most common B2B Commerce misconfiguration.
 *
 * Object model verified against org 00DgL00000L7NwjUAF on 2026-09-21:
 *   CommerceEntitlementPolicy   (CanViewProduct, CanViewPrice, IsActive)
 *   CommerceEntitlementBuyerGroup (PolicyId, BuyerGroupId)   - junction, not updateable
 *   CommerceEntitlementProduct    (PolicyId, ProductId)      - junction, not updateable
 * NOTE: there is NO CommerceEntitlementCatalog object in this org (describe returns
 * "The requested resource does not exist"), so entitlement is granted product-by-product.
 *
 * Bulkified: no SOQL or DML inside any loop.
 */
public with sharing class OfficeDepotEntitlementSeeder {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotEntitlementSeeder().run();
    }

    private static final String POLICY_NAME = 'Office Depot Standard Entitlement';
    private static final String BUYER_GROUP_NAME = 'Office Depot Business Buyers';
    private static final String CONTRACT_BOOK = 'Office Depot Contract Price';
    private static final String SKU_PREFIX = 'OD-';

    private Id upsertPolicy() {
        List<CommerceEntitlementPolicy> found = [
            SELECT Id, IsActive, CanViewProduct, CanViewPrice
            FROM CommerceEntitlementPolicy WHERE Name = :POLICY_NAME WITH USER_MODE LIMIT 1
        ];
        if (!found.isEmpty()) {
            CommerceEntitlementPolicy existing = found[0];
            if (!existing.IsActive || !existing.CanViewProduct || !existing.CanViewPrice) {
                existing.IsActive = true;
                existing.CanViewProduct = true;
                existing.CanViewPrice = true;
                update as user existing;
                System.debug(LoggingLevel.INFO, 'Entitlement policy re-activated: ' + existing.Id);
            }
            return existing.Id;
        }
        CommerceEntitlementPolicy policy = new CommerceEntitlementPolicy(
            Name = POLICY_NAME,
            Description = 'Grants Office Depot business buyers visibility of products and contract pricing.',
            CanViewProduct = true,
            CanViewPrice = true,
            IsActive = true);
        Database.SaveResult sr = Database.insert(policy, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('CommerceEntitlementPolicy insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Entitlement policy created: ' + sr.getId());
        return sr.getId();
    }

    private Id upsertBuyerGroup() {
        List<BuyerGroup> found = [
            SELECT Id FROM BuyerGroup WHERE Name = :BUYER_GROUP_NAME WITH USER_MODE LIMIT 1
        ];
        if (!found.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Buyer group already present: ' + found[0].Id);
            return found[0].Id;
        }
        BuyerGroup bg = new BuyerGroup(
            Name = BUYER_GROUP_NAME,
            Description = 'Contract-priced Office Depot business accounts.',
            Role = 'AccountBased');
        Database.SaveResult sr = Database.insert(bg, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('BuyerGroup insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Buyer group created: ' + sr.getId());
        return sr.getId();
    }

    private void linkPolicyToBuyerGroup(Id policyId, Id buyerGroupId) {
        List<CommerceEntitlementBuyerGroup> existing = [
            SELECT Id FROM CommerceEntitlementBuyerGroup
            WHERE PolicyId = :policyId AND BuyerGroupId = :buyerGroupId WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Policy already linked to buyer group.');
            return;
        }
        Database.SaveResult sr = Database.insert(
            new CommerceEntitlementBuyerGroup(PolicyId = policyId, BuyerGroupId = buyerGroupId),
            false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('CommerceEntitlementBuyerGroup insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Policy linked to buyer group.');
    }

    /** Entitles every seeded Office Depot SKU. One query in, one DML out. */
    private void entitleProducts(Id policyId) {
        String skuLike = SKU_PREFIX + '%';
        Map<Id, Product2> products = new Map<Id, Product2>([
            SELECT Id, StockKeepingUnit FROM Product2
            WHERE StockKeepingUnit LIKE :skuLike AND IsActive = true WITH USER_MODE
        ]);
        if (products.isEmpty()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: no Office Depot products found. Run OfficeDepotCatalogSeeder.execute() first.');
        }

        Set<Id> alreadyEntitled = new Set<Id>();
        for (CommerceEntitlementProduct cep : [
            SELECT ProductId FROM CommerceEntitlementProduct
            WHERE PolicyId = :policyId WITH USER_MODE
        ]) {
            alreadyEntitled.add(cep.ProductId);
        }

        List<CommerceEntitlementProduct> toInsert = new List<CommerceEntitlementProduct>();
        for (Id productId : products.keySet()) {
            if (!alreadyEntitled.contains(productId)) {
                toInsert.add(new CommerceEntitlementProduct(PolicyId = policyId, ProductId = productId));
            }
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'All products already entitled.');
            return;
        }
        List<Database.SaveResult> results = Database.insert(toInsert, false, AccessLevel.USER_MODE);
        Integer ok = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                System.debug(LoggingLevel.ERROR, 'CommerceEntitlementProduct failed: ' + sr.getErrors());
            }
        }
        System.debug(LoggingLevel.INFO, 'Products entitled: ' + ok + '/' + toInsert.size());
    }

    /** Binds the negotiated pricebook to the buyer group so entitled buyers get contract pricing. */
    private void linkContractPricebook(Id buyerGroupId) {
        List<Pricebook2> books = [
            SELECT Id FROM Pricebook2 WHERE Name = :CONTRACT_BOOK WITH USER_MODE LIMIT 1
        ];
        if (books.isEmpty()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: pricebook "' + CONTRACT_BOOK + '" not found. Run OfficeDepotPricebookSeeder.execute() first.');
        }
        Id bookId = books[0].Id;

        List<BuyerGroupPricebook> existing = [
            SELECT Id, IsActive FROM BuyerGroupPricebook
            WHERE BuyerGroupId = :buyerGroupId AND Pricebook2Id = :bookId WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Buyer group pricebook link already present.');
            return;
        }
        Database.SaveResult sr = Database.insert(
            new BuyerGroupPricebook(BuyerGroupId = buyerGroupId, Pricebook2Id = bookId, IsActive = true, Priority = 1),
            false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('BuyerGroupPricebook insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Contract pricebook bound to buyer group.');
    }

    public void run() {
        Id policyId = upsertPolicy();
        Id buyerGroupId = upsertBuyerGroup();
        linkPolicyToBuyerGroup(policyId, buyerGroupId);
        entitleProducts(policyId);
        linkContractPricebook(buyerGroupId);
        System.debug(LoggingLevel.INFO, 'Step 6 (Entitlements/BuyerGroups) complete.');
    }
}

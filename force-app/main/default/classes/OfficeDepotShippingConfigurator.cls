/**
 * OfficeDepotShippingConfigurator
 *
 * Canonical chain step 3d: Shipping Profile configuration (BR-01, part of Settings/Integrations).
 * PRECONDITION: steps 2, 4 and 5 complete - WebStore, products and pricebooks exist.
 * Traces to: FR-04 / US-04, FR-05 / US-05 (unblocks checkout), OQ-01 adjacent.
 *
 * WHY THIS CLASS EXISTS
 * Checkout was blocked with:
 *   "An integration error occurred in COMPUTE_SHIPPING. Contact your admin."
 * and, in a second message on the same response that was initially overlooked:
 *   "Please configure correct Shipping Profiles in the respective web store 0ZEG1000001HoZJOA0."
 *
 * "Shipping Profile" is the ShippingConfigurationSet object. The earlier fix attempt built only
 * OrderDeliveryMethod + a shipping Product2 + pricebook entries, which is the older/partial
 * model. Shipment__B2B_STOREFRONT__StandardShipment actually reads the shipping-profile chain:
 *
 *   ShippingConfigurationSet  (TargetRecordId -> WebStore)      the "Shipping Profile"
 *     |- ShippingRateGroup      (ShippingProfileId)
 *     |    |- ShippingRateArea    (ShippingRateGroupId, Countries)
 *     |         |- StandardShippingRate (ShippingZoneId, Price, ConditionFactor)
 *     |- ShippingConfigSetProduct (ShippingProfileId, Product2Id)   which products ship
 *
 *   ShippingCarrier -> ShippingCarrierMethod -> OrderDeliveryMethod.ShippingCarrierMethodId
 *
 * TargetRecordId -> WebStore is the specific link the error message complains about.
 *
 * All object and field API names verified by `sf sobject describe` against scratch org
 * 00DG100000EKcgz on 2026-09-21. Every one of these objects exists and is createable there.
 *
 * Bulkified: one query and one DML per object type, nothing inside a loop.
 * Idempotent: every record is resolved by natural key (Name / ExternalReference / Product2Id)
 * before insert, so re-running creates no duplicates.
 * No hardcoded Ids: the store is resolved by Name, products by ProductCode.
 */
public with sharing class OfficeDepotShippingConfigurator {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotShippingConfigurator().run();
    }

    private static final String STORE_NAME = 'Office Depot';
    private static final String PROFILE_NAME = 'Office Depot Shipping Profile';
    private static final String CARRIER_NAME = 'Office Depot Logistics';
    private static final String CARRIER_REF = 'OD-CARRIER-STD';
    private static final String METHOD_NAME = 'Standard Ground';
    private static final String METHOD_REF = 'OD-METHOD-GROUND';
    private static final String RATE_GROUP_NAME = 'Office Depot Domestic Rates';
    private static final String RATE_AREA_NAME = 'United States';
    private static final String RATE_NAME = 'Standard Ground Flat Rate';
    private static final String DELIVERY_METHOD_NAME = 'Standard Ground';
    private static final String SKU_PREFIX = 'OD-%';
    private static final Decimal FLAT_RATE = 9.99;

    /** The "shipping charge" product an OrderDeliveryMethod bills the freight against. */
    private static final String SHIPPING_SKU = 'OD-SHIP-STD';
    private static final String SHIPPING_PRODUCT_NAME = 'Office Depot Standard Ground Shipping';
    private static final Set<String> CHARGE_PRICEBOOKS = new Set<String>{
        'Office Depot List Price', 'Office Depot Contract Price'
    };

    private Id storeId;
    private Id profileId;
    private Id carrierMethodId;
    private Id shippingProductId;

    private void resolveStore() {
        List<WebStore> stores = [
            SELECT Id FROM WebStore WHERE Name = :STORE_NAME WITH USER_MODE LIMIT 1
        ];
        if (stores.isEmpty()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: WebStore "' + STORE_NAME + '" does not exist. ' +
                'Run scripts/bash/10_create_store_and_site.sh before this class.');
        }
        this.storeId = stores[0].Id;
    }

    /** The Shipping Profile itself, bound to the store through TargetRecordId. */
    private void upsertShippingProfile() {
        List<ShippingConfigurationSet> found = [
            SELECT Id, TargetRecordId, IsDefault FROM ShippingConfigurationSet
            WHERE Name = :PROFILE_NAME WITH USER_MODE LIMIT 1
        ];
        if (!found.isEmpty()) {
            ShippingConfigurationSet existing = found[0];
            if (existing.TargetRecordId != this.storeId || !existing.IsDefault) {
                existing.TargetRecordId = this.storeId;
                existing.IsDefault = true;
                update as user existing;
                System.debug(LoggingLevel.INFO, 'Shipping profile rebound to store: ' + existing.Id);
            } else {
                System.debug(LoggingLevel.INFO, 'Shipping profile already present: ' + existing.Id);
            }
            this.profileId = existing.Id;
            return;
        }
        ShippingConfigurationSet profile = new ShippingConfigurationSet(
            Name = PROFILE_NAME,
            TargetRecordId = this.storeId,
            IsDefault = true,
            ProcessTime = 1,
            ProcessTimeUnit = 'Days');
        Database.SaveResult sr = Database.insert(profile, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('ShippingConfigurationSet insert failed: ' + sr.getErrors());
        }
        this.profileId = sr.getId();
        System.debug(LoggingLevel.INFO, 'Shipping profile created: ' + this.profileId);
    }

    /** Carrier -> carrier method. ExternalReference is the natural key on both. */
    private void upsertCarrierAndMethod() {
        Id carrierId;
        List<ShippingCarrier> carriers = [
            SELECT Id FROM ShippingCarrier WHERE ExternalReference = :CARRIER_REF WITH USER_MODE LIMIT 1
        ];
        if (!carriers.isEmpty()) {
            carrierId = carriers[0].Id;
            System.debug(LoggingLevel.INFO, 'Shipping carrier already present: ' + carrierId);
        } else {
            ShippingCarrier carrier = new ShippingCarrier(
                Name = CARRIER_NAME, ExternalReference = CARRIER_REF, ShipFromCountry = 'US');
            Database.SaveResult sr = Database.insert(carrier, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                throw new CommerceBusinessException('ShippingCarrier insert failed: ' + sr.getErrors());
            }
            carrierId = sr.getId();
            System.debug(LoggingLevel.INFO, 'Shipping carrier created: ' + carrierId);
        }

        List<ShippingCarrierMethod> methods = [
            SELECT Id FROM ShippingCarrierMethod WHERE ExternalReference = :METHOD_REF WITH USER_MODE LIMIT 1
        ];
        if (!methods.isEmpty()) {
            this.carrierMethodId = methods[0].Id;
            System.debug(LoggingLevel.INFO, 'Shipping carrier method already present: ' + this.carrierMethodId);
            return;
        }
        // MaxTransitTime and TransitTimeUnit are both REQUIRED on this object.
        ShippingCarrierMethod method = new ShippingCarrierMethod(
            Name = METHOD_NAME,
            ExternalReference = METHOD_REF,
            ShippingCarrierId = carrierId,
            MinTransitTime = 3,
            MaxTransitTime = 5,
            TransitTimeUnit = 'Days',
            ShippingScope = 'Domestic',
            ProcessingTime = 1,
            ProcessingTimeUnit = 'Days');
        Database.SaveResult sr = Database.insert(method, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('ShippingCarrierMethod insert failed: ' + sr.getErrors());
        }
        this.carrierMethodId = sr.getId();
        System.debug(LoggingLevel.INFO, 'Shipping carrier method created: ' + this.carrierMethodId);
    }

    /** Rate group -> rate area (US) -> a real flat rate. This is what produces a shipping price. */
    private void upsertRates() {
        Id rateGroupId;
        List<ShippingRateGroup> groups = [
            SELECT Id FROM ShippingRateGroup
            WHERE Name = :RATE_GROUP_NAME AND ShippingProfileId = :this.profileId WITH USER_MODE LIMIT 1
        ];
        if (!groups.isEmpty()) {
            rateGroupId = groups[0].Id;
        } else {
            ShippingRateGroup g = new ShippingRateGroup(
                Name = RATE_GROUP_NAME, ShippingProfileId = this.profileId);
            Database.SaveResult sr = Database.insert(g, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                throw new CommerceBusinessException('ShippingRateGroup insert failed: ' + sr.getErrors());
            }
            rateGroupId = sr.getId();
            System.debug(LoggingLevel.INFO, 'Shipping rate group created: ' + rateGroupId);
        }

        Id rateAreaId;
        List<ShippingRateArea> areas = [
            SELECT Id FROM ShippingRateArea
            WHERE Name = :RATE_AREA_NAME AND ShippingRateGroupId = :rateGroupId WITH USER_MODE LIMIT 1
        ];
        if (!areas.isEmpty()) {
            rateAreaId = areas[0].Id;
        } else {
            // Regions is left blank so the area covers every US state, including CA where the
            // validation buyer's address (San Francisco, CA, 94105) sits.
            ShippingRateArea area = new ShippingRateArea(
                Name = RATE_AREA_NAME, ShippingRateGroupId = rateGroupId, Countries = 'US');
            Database.SaveResult sr = Database.insert(area, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                throw new CommerceBusinessException('ShippingRateArea insert failed: ' + sr.getErrors());
            }
            rateAreaId = sr.getId();
            System.debug(LoggingLevel.INFO, 'Shipping rate area created: ' + rateAreaId);
        }

        List<StandardShippingRate> rates = [
            SELECT Id FROM StandardShippingRate
            WHERE Name = :RATE_NAME AND ShippingZoneId = :rateAreaId WITH USER_MODE LIMIT 1
        ];
        if (!rates.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Standard shipping rate already present: ' + rates[0].Id);
            return;
        }
        // Banded on order price with a deliberately wide range so every cart qualifies.
        StandardShippingRate rate = new StandardShippingRate(
            Name = RATE_NAME,
            ShippingZoneId = rateAreaId,
            Price = FLAT_RATE,
            ConditionFactor = 'OrderPriceFactor',
            ConditionRangeMin = 0,
            ConditionRangeMax = 1000000,
            TransitTimeMin = 3,
            TransitTimeMax = 5,
            TransitTimeUnit = 'Days');
        Database.SaveResult sr = Database.insert(rate, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('StandardShippingRate insert failed: ' + sr.getErrors());
        }
        // Side effect worth knowing about: creating a StandardShippingRate also causes the
        // platform to auto-create a derived ShippingCarrierMethod named after the rate
        // ("Standard Ground Flat Rate"). That derived record - not the one created above - is
        // what surfaces in the checkout's availableDeliveryMethods. Both are expected; the
        // count stays stable across re-runs.
        System.debug(LoggingLevel.INFO, 'Standard shipping rate created: ' + sr.getId() + ' @ ' + FLAT_RATE);
    }

    /**
     * Associates every Office Depot product with the profile. One query in, one DML out.
     *
     * IMPORTANT PLATFORM RULE, discovered by attempting it:
     *   INVALID_OPERATION - "You can't add a product to the default shipping profile."
     * ShippingConfigSetProduct and ShippingConfigurationSet.IsDefault are MUTUALLY EXCLUSIVE.
     * A default profile already covers every product in the store implicitly, so explicit
     * per-product rows are both unnecessary and forbidden. Only a NON-default profile takes
     * explicit product associations.
     *
     * Note this also produced a secondary, misleading error on the remaining rows of the same
     * bulk insert - "Too many retries of batch save in the presence of Apex triggers with
     * failures" - which is a partial-save artefact, not a separate defect.
     */
    private void associateProducts() {
        ShippingConfigurationSet profile = [
            SELECT Id, IsDefault FROM ShippingConfigurationSet WHERE Id = :this.profileId WITH USER_MODE LIMIT 1
        ];
        Map<Id, Product2> products = new Map<Id, Product2>([
            SELECT Id, ProductCode FROM Product2
            WHERE ProductCode LIKE :SKU_PREFIX AND IsActive = true WITH USER_MODE
        ]);
        if (products.isEmpty()) {
            throw new CommerceBusinessException(
                'BR-01 VIOLATION: no Office Depot products found. Run OfficeDepotCatalogSeeder.execute() first.');
        }
        if (profile.IsDefault) {
            System.debug(LoggingLevel.INFO,
                'Profile is the store DEFAULT, so all ' + products.size() + ' active Office Depot ' +
                'products are covered implicitly. ShippingConfigSetProduct rows are rejected on a ' +
                'default profile (INVALID_OPERATION) and are intentionally not created.');
            return;
        }

        Set<Id> alreadyAssociated = new Set<Id>();
        for (ShippingConfigSetProduct scp : [
            SELECT Product2Id FROM ShippingConfigSetProduct
            WHERE ShippingProfileId = :this.profileId WITH USER_MODE
        ]) {
            alreadyAssociated.add(scp.Product2Id);
        }

        List<ShippingConfigSetProduct> toInsert = new List<ShippingConfigSetProduct>();
        for (Product2 p : products.values()) {
            if (alreadyAssociated.contains(p.Id)) {
                continue;
            }
            toInsert.add(new ShippingConfigSetProduct(
                Name = p.ProductCode, ShippingProfileId = this.profileId, Product2Id = p.Id));
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'All ' + products.size() + ' products already associated with the shipping profile.');
            return;
        }
        List<Database.SaveResult> results = Database.insert(toInsert, false, AccessLevel.USER_MODE);
        Integer ok = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                System.debug(LoggingLevel.ERROR, 'ShippingConfigSetProduct failed: ' + sr.getErrors());
            }
        }
        System.debug(LoggingLevel.INFO,
            'Products associated with shipping profile: ' + ok + '/' + toInsert.size() +
            ' (total covered: ' + products.size() + ')');
    }

    /**
     * Creates the shipping-charge Product2 and prices it in every store pricebook.
     *
     * OrderDeliveryMethod.ProductId is REQUIRED and must point at a real, priced product - this
     * is the line item the freight lands on in the resulting Order. Without a PricebookEntry in
     * the books the store actually uses, checkout resolves the delivery method but then fails to
     * price it.
     *
     * The SKU is deliberately outside the merchandised catalog: it gets no ProductCategory
     * assignment, so it never appears on the PLP or in search results even though it is active
     * and priced. (OfficeDepotStorefrontController also filters it out of the home-page rails by
     * name for the same reason.)
     *
     * Required custom fields are delegated to OfficeDepotCatalogSeeder so this class inherits the
     * same dynamic describe-driven handling rather than duplicating - and drifting from - it.
     */
    private void upsertShippingProduct() {
        List<Product2> found = [
            SELECT Id FROM Product2 WHERE StockKeepingUnit = :SHIPPING_SKU WITH USER_MODE LIMIT 1
        ];
        if (!found.isEmpty()) {
            this.shippingProductId = found[0].Id;
            System.debug(LoggingLevel.INFO, 'Shipping charge product already present: ' + this.shippingProductId);
        } else {
            // Type is deliberately left null so ProductClass derives to Simple. See the long
            // note in OfficeDepotCatalogSeeder - a VariationParent is not searchable and breaks
            // the search index build.
            Product2 p = new Product2(
                Name = SHIPPING_PRODUCT_NAME,
                ProductCode = SHIPPING_SKU,
                StockKeepingUnit = SHIPPING_SKU,
                Description = 'Flat-rate standard ground shipping charge. Not merchandised.',
                IsActive = true,
                ProductPurpose = 'Sell',
                QuantityUnitOfMeasure = 'Each');
            OfficeDepotCatalogSeeder.applyOrgSpecificRequiredFields(p, 'Cheap');
            Database.SaveResult sr = Database.insert(p, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                throw new CommerceBusinessException('Shipping Product2 insert failed: ' + sr.getErrors());
            }
            this.shippingProductId = sr.getId();
            System.debug(LoggingLevel.INFO, 'Shipping charge product created: ' + this.shippingProductId);
        }
        priceShippingProduct();
    }

    /**
     * Standard pricebook entry first, then the custom books - a custom entry cannot exist
     * without the standard one. Bulkified: one query for existing entries, one DML per stage.
     */
    private void priceShippingProduct() {
        List<Pricebook2> standard = [
            SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1
        ];
        if (standard.isEmpty()) {
            throw new CommerceBusinessException('No standard Pricebook2 found in this org.');
        }
        Id standardBookId = standard[0].Id;

        Set<Id> priced = new Set<Id>();
        for (PricebookEntry pbe : [
            SELECT Pricebook2Id FROM PricebookEntry
            WHERE Product2Id = :this.shippingProductId WITH USER_MODE
        ]) {
            priced.add(pbe.Pricebook2Id);
        }

        if (!priced.contains(standardBookId)) {
            Database.SaveResult sr = Database.insert(new PricebookEntry(
                Pricebook2Id = standardBookId, Product2Id = this.shippingProductId,
                UnitPrice = FLAT_RATE, IsActive = true, UseStandardPrice = false),
                false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                throw new CommerceBusinessException(
                    'Standard PricebookEntry for the shipping charge failed: ' + sr.getErrors());
            }
            priced.add(standardBookId);
            System.debug(LoggingLevel.INFO, 'Shipping charge priced in the standard pricebook.');
        }

        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        for (Pricebook2 pb : [
            SELECT Id, Name FROM Pricebook2 WHERE Name IN :CHARGE_PRICEBOOKS WITH USER_MODE
        ]) {
            if (!priced.contains(pb.Id)) {
                toInsert.add(new PricebookEntry(
                    Pricebook2Id = pb.Id, Product2Id = this.shippingProductId,
                    UnitPrice = FLAT_RATE, IsActive = true, UseStandardPrice = false));
            }
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Shipping charge already priced in every store pricebook.');
            return;
        }
        List<Database.SaveResult> results = Database.insert(toInsert, false, AccessLevel.USER_MODE);
        Integer ok = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                System.debug(LoggingLevel.ERROR, 'Shipping charge PricebookEntry failed: ' + sr.getErrors());
            }
        }
        System.debug(LoggingLevel.INFO, 'Shipping charge priced in ' + ok + ' custom pricebook(s).');
    }

    /**
     * Points the existing OrderDeliveryMethod at the new ShippingCarrierMethod.
     * Describe confirms OrderDeliveryMethod.ShippingCarrierMethodId is a real, updateable
     * reference, and the record created earlier had it null - which is why the delivery method
     * never surfaced on the checkout even though it was active.
     */
    private void linkDeliveryMethod() {
        List<OrderDeliveryMethod> methods = [
            SELECT Id, ShippingCarrierMethodId, ProductId, IsActive FROM OrderDeliveryMethod
            WHERE Name = :DELIVERY_METHOD_NAME WITH USER_MODE LIMIT 1
        ];
        if (methods.isEmpty()) {
            // Nothing else in the chain creates this record. Site creation does not generate one,
            // and the StandardShippingRate insert only auto-derives an INACTIVE
            // "<rate name>" method with a null ShippingCarrierMethodId - which never surfaces in
            // the checkout's availableDeliveryMethods. Create the real one here, fully wired.
            Database.SaveResult created = Database.insert(new OrderDeliveryMethod(
                Name = DELIVERY_METHOD_NAME,
                ProductId = this.shippingProductId,
                ShippingCarrierMethodId = this.carrierMethodId,
                IsActive = true), false, AccessLevel.USER_MODE);
            if (!created.isSuccess()) {
                throw new CommerceBusinessException(
                    'OrderDeliveryMethod insert failed: ' + created.getErrors());
            }
            System.debug(LoggingLevel.INFO,
                'OrderDeliveryMethod created: ' + created.getId() +
                ' product=' + this.shippingProductId + ' carrierMethod=' + this.carrierMethodId);
            return;
        }
        OrderDeliveryMethod odm = methods[0];
        if (odm.ShippingCarrierMethodId == this.carrierMethodId && odm.IsActive
                && odm.ProductId == this.shippingProductId) {
            System.debug(LoggingLevel.INFO, 'OrderDeliveryMethod already fully wired.');
            return;
        }
        odm.ShippingCarrierMethodId = this.carrierMethodId;
        odm.ProductId = this.shippingProductId;
        odm.IsActive = true;
        Database.SaveResult sr = Database.update(odm, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('OrderDeliveryMethod update failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO,
            'OrderDeliveryMethod ' + odm.Id + ' linked to ShippingCarrierMethod ' + this.carrierMethodId);
    }

    public void run() {
        resolveStore();
        upsertShippingProfile();
        upsertCarrierAndMethod();
        upsertRates();
        associateProducts();
        // Must precede linkDeliveryMethod(): OrderDeliveryMethod.ProductId is required.
        upsertShippingProduct();
        linkDeliveryMethod();
        System.debug(LoggingLevel.INFO,
            'Step 3d (Shipping Profile) complete for store ' + this.storeId +
            '. Recompute the checkout to surface delivery methods.');
    }
}

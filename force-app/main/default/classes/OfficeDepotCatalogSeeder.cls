/**
 * OfficeDepotCatalogSeeder
 *
 * Canonical chain step 4: Catalog -> Categories -> Products -> Category assignment (BR-01).
 * PRECONDITION: steps 1-3 complete.
 * Traces to: FR-02 / US-02.
 *
 * Idempotent: re-running resolves by natural key (Name / StockKeepingUnit), never by hardcoded Id.
 * Bulkified: no SOQL or DML inside any loop.
 *
 * Product2 in target org 00DgL00000L7NwjUAF carries a universally-required custom picklist
 * Specification__c (values: Best Seller, Cheap, High Value) left over from a previous store
 * build. Every insert below sets it; omitting it makes the entire insert fail. This is a
 * direct consequence of AD-01 being false (the org is not clean) and is logged in
 * docs/ASDF_ASSESSMENT.md rather than silently worked around.
 */
public with sharing class OfficeDepotCatalogSeeder {
    /** Static entry point. Invoked by scripts/bash orchestration and re-runnable/idempotent. */
    public static void execute() {
        new OfficeDepotCatalogSeeder().run();
    }

    private static final String CATALOG_NAME = 'Office Depot Catalog';

    /**
     * category name => parent category name (null = top level). Parents are inserted first.
     *
     * "All Products" is a single navigational root. The four merchandising groups hang off it so
     * the storefront breadcrumb reads "All Products > Office Supplies > Paper and Notebooks",
     * matching the reference store. Ordering in this list matters: upsertCategories() does a
     * parents-then-children pass, so a grandchild's parent must itself appear before it.
     */
    private static final List<List<String>> CATEGORY_TREE = new List<List<String>>{
        new List<String>{ 'All Products', null },
        new List<String>{ 'Office Supplies', 'All Products' },
        new List<String>{ 'Technology', 'All Products' },
        new List<String>{ 'Furniture', 'All Products' },
        new List<String>{ 'Breakroom and Cleaning', 'All Products' },
        new List<String>{ 'Paper and Notebooks', 'Office Supplies' },
        new List<String>{ 'Writing and Correction', 'Office Supplies' },
        new List<String>{ 'Filing and Storage', 'Office Supplies' },
        new List<String>{ 'Laptops and Desktops', 'Technology' },
        new List<String>{ 'Printers and Ink', 'Technology' },
        new List<String>{ 'Monitors and Accessories', 'Technology' },
        new List<String>{ 'Chairs', 'Furniture' },
        new List<String>{ 'Desks', 'Furniture' },
        new List<String>{ 'Coffee and Snacks', 'Breakroom and Cleaning' },
        new List<String>{ 'Cleaning Supplies', 'Breakroom and Cleaning' }
    };

    /** SKU, Name, leaf category, Specification__c, description. */
    private static final List<List<String>> PRODUCTS = new List<List<String>>{
        new List<String>{ 'OD-PAP-0001', 'Office Depot Multipurpose Paper, Letter, 20 lb, 10-Ream Case', 'Paper and Notebooks', 'Best Seller', 'Bright white 92 US brightness multipurpose paper. 5,000 sheets per case. Acid free.' },
        new List<String>{ 'OD-PAP-0002', 'Office Depot Perforated Writing Pads, Letter, Wide Ruled, 12-Pack', 'Paper and Notebooks', 'Cheap', 'Micro-perforated legal pads with sturdy chipboard backing. 50 sheets per pad.' },
        new List<String>{ 'OD-PAP-0003', 'Office Depot Spiral Notebooks, 1-Subject, College Ruled, 6-Pack', 'Paper and Notebooks', 'Cheap', '70 sheets per notebook, three-hole punched, assorted cover colours.' },
        new List<String>{ 'OD-WRT-0001', 'Office Depot Retractable Gel Pens, Medium Point, Black, 36-Pack', 'Writing and Correction', 'Best Seller', 'Smooth quick-dry gel ink with contoured rubber grip. 0.7 mm medium point.' },
        new List<String>{ 'OD-WRT-0002', 'Office Depot Dry Erase Markers, Chisel Tip, Assorted, 12-Pack', 'Writing and Correction', 'Cheap', 'Low-odour chisel tip markers for whiteboards and glass boards.' },
        new List<String>{ 'OD-WRT-0003', 'Office Depot Highlighters, Chisel Tip, Assorted Colours, 24-Pack', 'Writing and Correction', 'Cheap', 'Smear-guard ink safe for most inkjet and laser prints.' },
        new List<String>{ 'OD-FIL-0001', 'Office Depot Hanging File Folders, Letter Size, 1/5 Cut, 25-Box', 'Filing and Storage', 'Cheap', '11 pt stock hanging folders with reinforced top edge and clear tabs.' },
        new List<String>{ 'OD-FIL-0002', 'Office Depot Heavy-Duty Storage Boxes, Letter and Legal, 12-Pack', 'Filing and Storage', 'High Value', 'Double-wall corrugated storage with lift-off lid and reinforced handles.' },
        new List<String>{ 'OD-LAP-0001', 'Office Depot ProBook 14 inch Business Laptop, 16 GB RAM, 512 GB SSD', 'Laptops and Desktops', 'High Value', '14 inch full HD anti-glare display, 16 GB DDR5, 512 GB NVMe SSD, Windows 11 Pro.' },
        new List<String>{ 'OD-LAP-0002', 'Office Depot ProBook 16 inch Workstation, 32 GB RAM, 1 TB SSD', 'Laptops and Desktops', 'High Value', '16 inch QHD display, 32 GB DDR5, 1 TB NVMe SSD, discrete graphics, Windows 11 Pro.' },
        new List<String>{ 'OD-PRN-0001', 'Office Depot LaserJet Pro Monochrome Printer, Duplex, Wireless', 'Printers and Ink', 'Best Seller', 'Up to 40 ppm mono, automatic duplex, wireless and gigabit ethernet.' },
        new List<String>{ 'OD-PRN-0002', 'Office Depot Remanufactured Toner Cartridge, Black, High Yield', 'Printers and Ink', 'Cheap', 'High-yield remanufactured cartridge. Approx. 3,000 page yield.' },
        new List<String>{ 'OD-MON-0001', 'Office Depot 27 inch QHD Business Monitor, USB-C, Height Adjustable', 'Monitors and Accessories', 'High Value', '27 inch 2560x1440 IPS panel, 90 W USB-C power delivery, full ergonomic stand.' },
        new List<String>{ 'OD-MON-0002', 'Office Depot Dual Monitor Arm, Clamp Mount, Gas Spring', 'Monitors and Accessories', 'Cheap', 'Supports two displays up to 32 inch and 9 kg each, integrated cable routing.' },
        new List<String>{ 'OD-CHR-0001', 'Office Depot ErgoTask Mesh Task Chair, Adjustable Lumbar', 'Chairs', 'Best Seller', 'Breathable mesh back, 4D armrests, adjustable lumbar, synchro-tilt mechanism.' },
        new List<String>{ 'OD-CHR-0002', 'Office Depot Executive Bonded Leather Chair, High Back', 'Chairs', 'High Value', 'High-back bonded leather executive chair with padded arms and tilt lock.' },
        new List<String>{ 'OD-DSK-0001', 'Office Depot Electric Sit-Stand Desk, 60 x 30, Dual Motor', 'Desks', 'High Value', 'Dual-motor height adjustable frame, 25 to 50 inch range, four memory presets.' },
        new List<String>{ 'OD-DSK-0002', 'Office Depot Compact Computer Desk, 48 x 24, Laminate Top', 'Desks', 'Cheap', 'Scratch-resistant laminate top with steel frame and cable management tray.' },
        new List<String>{ 'OD-COF-0001', 'Office Depot Breakroom Coffee, Medium Roast, 42-Pack Fractional', 'Coffee and Snacks', 'Best Seller', '100 percent arabica medium roast fractional packs, 1.75 oz each.' },
        new List<String>{ 'OD-CLN-0001', 'Office Depot Disinfecting Surface Wipes, 75-Count, 6-Pack', 'Cleaning Supplies', 'Cheap', 'Ready-to-use disinfecting wipes for hard non-porous office surfaces.' }
    };

    private Id upsertCatalog() {
        List<ProductCatalog> found = [
            SELECT Id, Name FROM ProductCatalog WHERE Name = :CATALOG_NAME WITH USER_MODE LIMIT 1
        ];
        if (!found.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Catalog already present: ' + found[0].Id);
            return found[0].Id;
        }
        ProductCatalog cat = new ProductCatalog(Name = CATALOG_NAME);
        Database.SaveResult sr = Database.insert(cat, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw new CommerceBusinessException('ProductCatalog insert failed: ' + sr.getErrors());
        }
        System.debug(LoggingLevel.INFO, 'Catalog created: ' + sr.getId());
        return sr.getId();
    }

    /**
     * Inserts the category tree one LEVEL at a time so ParentCategoryId is always resolvable at
     * arbitrary depth.
     *
     * A fixed two-pass (roots, then everything else) implementation only works for a two-level
     * tree. The reference store is three levels deep ("All Products" > "Office Supplies" >
     * "Paper and Notebooks"), and in a two-pass version the grandchildren are built against a
     * byName map that does not yet contain their parents, so the run aborts with a spurious
     * "BR-01 VIOLATION: parent category ... missing".
     *
     * Bulkified: one DML per tree LEVEL (a small, fixed number bounded by CATEGORY_TREE's shape,
     * not by data volume), never one per category. The loop is bounded by tree depth and exits
     * as soon as a pass inserts nothing, so a malformed tree cannot spin.
     */
    private Map<String, Id> upsertCategories(Id catalogId) {
        Map<String, Id> byName = new Map<String, Id>();
        for (ProductCategory pc : [
            SELECT Id, Name FROM ProductCategory WHERE CatalogId = :catalogId WITH USER_MODE
        ]) {
            byName.put(pc.Name, pc.Id);
        }

        // Stable sort order per category, derived from its position in the declared tree.
        Map<String, Integer> sortOrderByName = new Map<String, Integer>();
        Map<String, String> parentByName = new Map<String, String>();
        Integer sortOrder = 0;
        for (List<String> row : CATEGORY_TREE) {
            sortOrderByName.put(row[0], sortOrder);
            parentByName.put(row[0], row[1]);
            sortOrder += 10;
        }

        Set<String> remaining = new Set<String>(parentByName.keySet());
        remaining.removeAll(byName.keySet());

        while (!remaining.isEmpty()) {
            List<ProductCategory> level = new List<ProductCategory>();
            for (String name : remaining) {
                String parentName = parentByName.get(name);
                // Ready when it is a root, or when its parent is already committed.
                if (parentName == null || byName.containsKey(parentName)) {
                    level.add(new ProductCategory(
                        Name = name,
                        CatalogId = catalogId,
                        ParentCategoryId = parentName == null ? null : byName.get(parentName),
                        IsNavigational = true,
                        SortOrder = sortOrderByName.get(name)));
                }
            }
            if (level.isEmpty()) {
                // Nothing became resolvable this pass => the declared tree references a parent
                // that is not itself declared. Fail loudly rather than looping forever.
                throw new CommerceBusinessException(
                    'BR-01 VIOLATION: unresolvable parent category for ' + remaining);
            }
            insert as user level;
            for (ProductCategory pc : level) {
                byName.put(pc.Name, pc.Id);
                remaining.remove(pc.Name);
            }
        }

        System.debug(LoggingLevel.INFO, 'Categories resolved: ' + byName.size());
        return byName;
    }

    /**
     * Sets org-specific required custom fields on Product2, but ONLY where they exist.
     *
     * Portability matters here. The sandbox org 00DgL00000L7NwjUAF carries a leftover
     * universally-required picklist Specification__c (Best Seller / Cheap / High Value) plus a
     * checkbox Is_Conveyable__c; omitting Specification__c there makes the whole insert fail with
     * REQUIRED_FIELD_MISSING. The clean scratch org 00DG100000EKcgz has NO custom fields on
     * Product2 at all, so referencing them statically would not even compile there.
     *
     * Describing the field map at runtime and using dynamic put() makes one class correct in
     * both orgs without hardcoding either org's shape.
     */
    /** Cached describe of the required custom fields, computed once per transaction. */
    private static List<Schema.DescribeFieldResult> requiredCustomFieldsCache;

    /**
     * Discovers every custom field on Product2 that the ORG will reject an insert without:
     * custom + createable + not nillable + no platform default. Nothing is named statically, so
     * the class stays correct in a clean org (where the list is empty) and in a contaminated one.
     *
     * isNillable() == false is the describe-level signal for "universally required". A field
     * with isDefaultedOnCreate() == true supplies its own value and must be left alone, which is
     * why Is_Conveyable__c is filtered out here rather than assumed.
     */
    private static List<Schema.DescribeFieldResult> requiredCustomFields() {
        if (requiredCustomFieldsCache != null) {
            return requiredCustomFieldsCache;
        }
        requiredCustomFieldsCache = new List<Schema.DescribeFieldResult>();
        for (Schema.SObjectField f : Schema.SObjectType.Product2.fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isCustom() && d.isCreateable() && !d.isNillable() && !d.isDefaultedOnCreate()) {
                requiredCustomFieldsCache.add(d);
            }
        }
        if (!requiredCustomFieldsCache.isEmpty()) {
            List<String> names = new List<String>();
            for (Schema.DescribeFieldResult d : requiredCustomFieldsCache) {
                names.add(d.getName() + '(' + d.getType() + ')');
            }
            System.debug(LoggingLevel.WARN,
                'ORG CONTAMINATION: Product2 carries ' + names.size() + ' universally-required ' +
                'custom field(s) that are not part of this project: ' + names + '. Populating them ' +
                'dynamically so the insert can succeed. See docs/ASDF_ASSESSMENT.md (AD-01).');
        }
        return requiredCustomFieldsCache;
    }

    /**
     * Populates org-specific required custom fields on a Product2 without naming any of them.
     *
     * `semanticHint` is the project's own merchandising label for the product ("Best Seller",
     * "Cheap", "High Value"). Where a discovered picklist happens to accept that value it is
     * used, so the data stays meaningful rather than arbitrary; otherwise the first ACTIVE
     * picklist value is taken. Non-picklist types get a type-appropriate placeholder.
     *
     * No SOQL and no DML here - describe results only - so calling this per product inside the
     * build loop carries no governor cost.
     */
    public static void applyOrgSpecificRequiredFields(Product2 p, String semanticHint) {
        for (Schema.DescribeFieldResult d : requiredCustomFields()) {
            String fieldName = d.getName();
            Schema.DisplayType t = d.getType();

            if (t == Schema.DisplayType.PICKLIST || t == Schema.DisplayType.MULTIPICKLIST) {
                List<String> active = new List<String>();
                Boolean hintIsValid = false;
                for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                    if (!pe.isActive()) {
                        continue;
                    }
                    active.add(pe.getValue());
                    if (pe.getValue() == semanticHint) {
                        hintIsValid = true;
                    }
                }
                if (hintIsValid) {
                    p.put(fieldName, semanticHint);
                } else if (!active.isEmpty()) {
                    p.put(fieldName, active[0]);
                }
            } else if (t == Schema.DisplayType.BOOLEAN) {
                p.put(fieldName, true);
            } else if (t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.DOUBLE
                    || t == Schema.DisplayType.PERCENT) {
                p.put(fieldName, 0.0);
            } else if (t == Schema.DisplayType.INTEGER || t == Schema.DisplayType.LONG) {
                p.put(fieldName, 0);
            } else if (t == Schema.DisplayType.DATE) {
                p.put(fieldName, Date.today());
            } else if (t == Schema.DisplayType.DATETIME) {
                p.put(fieldName, System.now());
            } else if (t == Schema.DisplayType.STRING || t == Schema.DisplayType.TEXTAREA
                    || t == Schema.DisplayType.URL || t == Schema.DisplayType.EMAIL
                    || t == Schema.DisplayType.PHONE) {
                Integer len = d.getLength() == null || d.getLength() <= 0 ? 255 : d.getLength();
                p.put(fieldName, semanticHint == null ? 'N/A' : semanticHint.left(len));
            } else {
                System.debug(LoggingLevel.ERROR,
                    'Required custom field ' + fieldName + ' has unsupported type ' + t +
                    '; cannot auto-populate. The Product2 insert will fail until it is given a ' +
                    'default or made optional in the org.');
            }
        }
    }

    private Map<String, Id> upsertProducts() {
        Set<String> skus = new Set<String>();
        for (List<String> row : PRODUCTS) {
            skus.add(row[0]);
        }

        Map<String, Id> bySku = new Map<String, Id>();
        for (Product2 p : [
            SELECT Id, StockKeepingUnit FROM Product2
            WHERE StockKeepingUnit IN :skus WITH USER_MODE
        ]) {
            bySku.put(p.StockKeepingUnit, p.Id);
        }

        List<Product2> toInsert = new List<Product2>();
        for (List<String> row : PRODUCTS) {
            if (bySku.containsKey(row[0])) {
                continue;
            }
            // DO NOT SET Product2.Type.
            //
            // Product2.ProductClass is read-only and DERIVED. Setting Type = 'Base' makes
            // Salesforce derive ProductClass = 'VariationParent'; leaving Type null derives
            // ProductClass = 'Simple'. Proven side by side in scratch org 00DG100000EKcgz on
            // 2026-09-21:
            //     ZZ-PROBE-1  Type=null  ProductClass=Simple
            //     ZZ-PROBE-2  Type=Base  ProductClass=VariationParent
            //
            // A VariationParent is not itself searchable, so a catalog of them makes the search
            // index build FAIL with the badly-misleading message:
            //     "There are no searchable products for this store. Make sure your store has at
            //      least one active product marked as searchable, and try again."
            // Nothing in that message points at Type. Worse, Type is createable but NOT
            // updateable, so the only remedy is to delete and recreate every product.
            Product2 p = new Product2(
                Name = row[1],
                ProductCode = row[0],
                StockKeepingUnit = row[0],
                Description = row[4],
                IsActive = true,
                ProductPurpose = 'Sell',
                QuantityUnitOfMeasure = 'Each'
            );
            applyOrgSpecificRequiredFields(p, row[3]);
            toInsert.add(p);
        }
        if (!toInsert.isEmpty()) {
            insert as user toInsert;
            for (Product2 p : toInsert) {
                bySku.put(p.StockKeepingUnit, p.Id);
            }
        }
        System.debug(LoggingLevel.INFO, 'Products resolved: ' + bySku.size());
        return bySku;
    }

    private void assignProductsToCategories(Map<String, Id> categoryByName, Map<String, Id> productBySku) {
        Set<Id> productIds = new Set<Id>(productBySku.values());
        Set<String> existing = new Set<String>();
        for (ProductCategoryProduct pcp : [
            SELECT ProductId, ProductCategoryId FROM ProductCategoryProduct
            WHERE ProductId IN :productIds WITH USER_MODE
        ]) {
            existing.add(pcp.ProductId + '|' + pcp.ProductCategoryId);
        }

        List<ProductCategoryProduct> links = new List<ProductCategoryProduct>();
        for (List<String> row : PRODUCTS) {
            Id productId = productBySku.get(row[0]);
            Id categoryId = categoryByName.get(row[2]);
            if (productId == null || categoryId == null) {
                throw new CommerceBusinessException(
                    'BR-01 VIOLATION: cannot link SKU ' + row[0] + ' to category ' + row[2]);
            }
            if (existing.contains(productId + '|' + categoryId)) {
                continue;
            }
            links.add(new ProductCategoryProduct(
                ProductId = productId, ProductCategoryId = categoryId, IsPrimaryCategory = true));
        }
        if (!links.isEmpty()) {
            insert as user links;
        }
        System.debug(LoggingLevel.INFO, 'Category assignments created: ' + links.size());
    }

    public void run() {
        Id catalogId = upsertCatalog();
        Map<String, Id> categories = upsertCategories(catalogId);
        Map<String, Id> products = upsertProducts();
        assignProductsToCategories(categories, products);
        System.debug(LoggingLevel.INFO, 'Step 4 (Catalog/Categories/Products) complete.');
    }
}

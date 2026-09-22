/**
 * OfficeDepotStorefrontController
 *
 * Data layer for the custom Office Depot home-page LWCs.
 * Traces to: FR-04 / US-04 (storefront configuration) and the home-page customisation
 * deviation recorded in docs/ASDF_ASSESSMENT.md.
 *
 * WHY CONNECT API AND NOT SOQL  (this was measured, not assumed)
 * The first implementation read ProductCategoryProduct / Product2 / PricebookEntry directly with
 * `WITH USER_MODE`. It compiled, deployed and returned ZERO rows for a real storefront buyer.
 * Root cause, confirmed against EntityDefinition in this org:
 *     Product2.ExternalSharingModel              = Private
 *     ProductCatalog.ExternalSharingModel        = Private
 *     ProductCategory / ProductCategoryProduct   = ControlledByParent  (parent = ProductCatalog)
 * So an Experience Cloud (external) user is shared NO catalogue rows at all, whatever object
 * permissions are granted. B2B Commerce deliberately routes buyer catalogue access through the
 * commerce entitlement layer instead, which is reachable only through the Commerce APIs.
 * ConnectApi.CommerceSearch.searchProducts is therefore not a stylistic preference here - it is
 * the only supported way for a buyer to read the catalogue, and it enforces entitlement,
 * effective account and the buyer price book for us.
 *
 * SECURITY
 * `with sharing`. Catalogue and pricing come from ConnectApi, which applies commerce entitlement
 * for the effective account. The only system-mode reads are store CONFIGURATION (which WebStore
 * this Network belongs to, which Account the running user buys for, and the category tree) -
 * isolated in two `without sharing` inner classes and documented at each one. No customer data is
 * read in system mode.
 *
 * GOVERNOR LIMITS
 * Three SOQL queries for configuration (statically cached for the transaction) and 1 ConnectApi
 * call per rail, with the rail count hard-capped at 12. No SOQL, DML or ConnectApi call inside an
 * unbounded loop.
 *
 * RATINGS ARE SYNTHETIC. Product2 has no rating or review-count field in this org and none was
 * added. deriveRating / deriveReviewCount produce a STABLE pseudo-random value from the SKU so the
 * UI does not flicker between loads. They are presentation filler, not business data, and are
 * labelled as such in docs/ASDF_ASSESSMENT.md and docs/AGENT_CAPABILITY_GAPS.md.
 */
public with sharing class OfficeDepotStorefrontController {
    private static final String STORE_NAME = 'Office Depot';
    private static final String CATALOG_NAME = 'Office Depot Catalog';
    // Discovery probe only - the commerce search requires a term or a category id, and the root
    // category id is precisely what is being discovered. A constant, not a hardcoded record id.
    private static final String CATALOG_PROBE_TERM = 'Office Depot';

    /** A product as the rails and tiles render it. */
    public class ProductTile {
        @AuraEnabled public String productId;
        @AuraEnabled public String name;
        @AuraEnabled public String sku;
        @AuraEnabled public String categoryName;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Integer percentOff;
        @AuraEnabled public Decimal savings;
        @AuraEnabled public Decimal rating;
        @AuraEnabled public Integer reviewCount;
        @AuraEnabled public String imageKey;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String productUrl;
    }

    /** One horizontal "Bestsellers in <Category>" rail. */
    public class CategoryRail {
        @AuraEnabled public String categoryId;
        @AuraEnabled public String categoryName;
        @AuraEnabled public String categoryUrl;
        @AuraEnabled public Integer maxPercentOff;
        @AuraEnabled public List<ProductTile> products;
    }

    /**
     * STORE CONFIGURATION LOOKUP - deliberately `without sharing`.
     *
     * Both reads answer "which store am I on and which account am I buying for". They are
     * configuration, not customer data, and they are scoped to the running user own Network and
     * User record. A buyer has no sharing on WebStoreNetwork and frequently no FLS on
     * Contact.AccountId, so USER_MODE here fails for every legitimate buyer. Everything that
     * actually exposes catalogue or price data still goes through ConnectApi with this account as
     * the effective account, so entitlement is never bypassed.
     */
    private without sharing class StoreContext {
        public String webStoreId;
        public String effectiveAccountId;

        public StoreContext() {
            Id networkId = Network.getNetworkId();
            if (networkId != null) {
                List<WebStoreNetwork> links = [
                    SELECT WebStoreId FROM WebStoreNetwork WHERE NetworkId = :networkId LIMIT 1
                ];
                if (!links.isEmpty()) {
                    this.webStoreId = links[0].WebStoreId;
                }
            }
            if (this.webStoreId == null) {
                List<WebStore> stores = [SELECT Id FROM WebStore WHERE Name = :STORE_NAME LIMIT 1];
                if (!stores.isEmpty()) {
                    this.webStoreId = stores[0].Id;
                }
            }
            List<User> me = [
                SELECT AccountId, Contact.AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (!me.isEmpty()) {
                if (me[0].Contact != null && me[0].Contact.AccountId != null) {
                    this.effectiveAccountId = me[0].Contact.AccountId;
                } else if (me[0].AccountId != null) {
                    this.effectiveAccountId = me[0].AccountId;
                }
            }
        }
    }

    /** One node of the entitlement-aware category tree returned by the commerce search. */
    private class CategoryNode {
        String id;
        String name;
        Integer productCount;
    }

    /**
     * CATEGORY DISCOVERY - ConnectApi only. No SOQL touches the catalogue objects.
     *
     * MEASURED, not assumed. A `without sharing` `SELECT COUNT() FROM ProductCategory` executed
     * inside a real buyer session on this store returned **0**, while the identical query returns
     * 15 rows as an internal admin. ProductCatalog.ExternalSharingModel is Private and
     * ProductCategory is ControlledByParent, so an Experience Cloud user is shared no catalogue
     * rows at all and the `without sharing` keyword does not help: there is nothing to widen.
     * B2B Commerce mediates catalogue visibility through entitlement, which only the Commerce APIs
     * consult. Every category id and name below therefore comes from
     * ConnectApi.CommerceSearch.searchProducts, which resolves visibility server-side for the
     * effective account.
     *
     * The shape returned by ConnectApi for the category tree has no stable, referenceable Apex
     * type in this API version, so it is read through an untyped JSON round trip rather than being
     * bound to an internal wrapper class name that can change between releases.
     */
    private static List<CategoryNode> topLevelCategories(StoreContext ctx) {
        String rootId = rootCategoryId(ctx);
        if (String.isBlank(rootId)) {
            return new List<CategoryNode>();
        }
        return childrenOf(searchCategories(ctx, null, rootId));
    }

    /**
     * The catalogue root as the buyer sees it.
     *
     * searchProducts insists on a searchTerm or a categoryId, and the root category id is exactly
     * what is not yet known. A term search is therefore used purely as a discovery probe: its
     * category tree comes back rooted at the catalogue root, whose id is what is wanted. The probe
     * term matches the catalogue naming convention and is a constant, not a hardcoded record id.
     */
    private static String rootIdCache;
    private static Boolean rootResolved = false;
    private static String rootCategoryId(StoreContext ctx) {
        if (rootResolved) {
            return rootIdCache;
        }
        rootResolved = true;
        List<CategoryNode> roots = childrenOf(searchCategories(ctx, CATALOG_PROBE_TERM, null));
        if (!roots.isEmpty()) {
            rootIdCache = roots[0].id;
        }
        return rootIdCache;
    }

    /** Runs a minimal search purely to read back its category tree. */
    private static Map<String, Object> searchCategories(StoreContext ctx, String term, String categoryId) {
        ConnectApi.ProductSearchInput input = new ConnectApi.ProductSearchInput();
        input.pageSize = 1;
        input.page = 0;
        if (String.isNotBlank(term)) {
            input.searchTerm = term;
        }
        if (String.isNotBlank(categoryId)) {
            input.categoryId = categoryId;
        }
        ConnectApi.ProductSearchResults results =
            ConnectApi.CommerceSearch.searchProducts(ctx.webStoreId, ctx.effectiveAccountId, input);
        if (results == null || results.categories == null) {
            return null;
        }
        return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(results.categories));
    }

    private static List<CategoryNode> childrenOf(Map<String, Object> tree) {
        List<CategoryNode> nodes = new List<CategoryNode>();
        if (tree == null || !(tree.get('children') instanceof List<Object>)) {
            return nodes;
        }
        for (Object raw : (List<Object>) tree.get('children')) {
            if (!(raw instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> entry = (Map<String, Object>) raw;
            Object category = entry.get('category');
            if (!(category instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> detail = (Map<String, Object>) category;
            CategoryNode node = new CategoryNode();
            node.id = detail.get('id') == null ? null : String.valueOf(detail.get('id'));
            node.name = detail.get('name') == null ? null : String.valueOf(detail.get('name'));
            node.productCount = entry.get('productCount') == null
                ? 0
                : Integer.valueOf(String.valueOf(entry.get('productCount')));
            if (String.isNotBlank(node.id)) {
                nodes.add(node);
            }
        }
        return nodes;
    }

    private static StoreContext ctxCache;
    private static StoreContext context() {
        if (ctxCache == null) {
            ctxCache = new StoreContext();
        }
        return ctxCache;
    }

    /**
     * One "Bestsellers in <Category>" rail per top-level navigational category.
     *
     * @param maxCategories   how many rails to return (clamped 1..12, default 4)
     * @param productsPerRail how many products per rail (clamped 1..24, default 8)
     */
    @AuraEnabled
    public static List<CategoryRail> getBestsellerRails(Integer maxCategories, Integer productsPerRail) {
        Integer categoryLimit = clamp(maxCategories, 1, 12, 4);
        Integer productLimit = clamp(productsPerRail, 1, 24, 8);

        StoreContext ctx = context();
        if (String.isBlank(ctx.webStoreId)) {
            throw new AuraHandledException('This page is not associated with a web store.');
        }

        List<CategoryNode> categories;
        try {
            categories = topLevelCategories(ctx);
        } catch (Exception e) {
            throw new AuraHandledException('Catalog is unavailable: ' + e.getMessage());
        }
        if (categories.isEmpty()) {
            throw new AuraHandledException(
                'The commerce search returned no categories for this store. '
                + 'Check that the search index has been built for ' + STORE_NAME + '.');
        }

        List<CategoryRail> rails = new List<CategoryRail>();
        String firstFailure;
        for (CategoryNode category : categories) {
            if (rails.size() >= categoryLimit) {
                break;
            }
            try {
                CategoryRail rail = buildRail(ctx, category.id, category.name, productLimit);
                if (rail != null && !rail.products.isEmpty()) {
                    rails.add(rail);
                }
            } catch (Exception e) {
                if (firstFailure == null) {
                    firstFailure = category.name + ': ' + e.getMessage();
                }
            }
        }
        // A silent empty page is indistinguishable from a broken one. If every search failed,
        // say so rather than rendering the friendly 'no products' state.
        if (rails.isEmpty() && firstFailure != null) {
            throw new AuraHandledException('Product search failed. ' + firstFailure);
        }
        return rails;
    }

    /** Category deal tiles - same source, fewer products per tile. */
    @AuraEnabled
    public static List<CategoryRail> getCategoryDeals(Integer maxCategories) {
        Integer categoryLimit = clamp(maxCategories, 1, 12, 4);
        return getBestsellerRails(categoryLimit, 4);
    }

    /**
     * One ConnectApi search per rail. The search is the ONLY catalogue read - it returns the
     * entitled products, their media and, with includePrices, both the list price and the buyer
     * negotiated unit price in the same round trip.
     */
    private static CategoryRail buildRail(
        StoreContext ctx,
        String categoryId,
        String categoryName,
        Integer productLimit
    ) {
        ConnectApi.ProductSearchInput input = new ConnectApi.ProductSearchInput();
        input.categoryId = categoryId;
        input.page = 0;
        input.pageSize = productLimit;
        input.includePrices = true;

        ConnectApi.ProductSearchResults results =
            ConnectApi.CommerceSearch.searchProducts(ctx.webStoreId, ctx.effectiveAccountId, input);
        if (results == null || results.productsPage == null || results.productsPage.products == null) {
            return null;
        }

        CategoryRail rail = new CategoryRail();
        rail.categoryId = categoryId;
        rail.categoryName = categoryName;
        rail.categoryUrl = '/category/' + categoryId;
        rail.maxPercentOff = 0;
        rail.products = new List<ProductTile>();

        for (ConnectApi.ProductSummary summary : results.productsPage.products) {
            ProductTile tile = buildTile(summary, categoryName);
            if (tile.percentOff != null && tile.percentOff > rail.maxPercentOff) {
                rail.maxPercentOff = tile.percentOff;
            }
            rail.products.add(tile);
        }
        return rail;
    }

    private static ProductTile buildTile(ConnectApi.ProductSummary summary, String categoryName) {
        ProductTile tile = new ProductTile();
        tile.productId = summary.id;
        tile.name = summary.name;
        tile.categoryName = categoryName;
        tile.productUrl = '/product/' + summary.id;
        tile.sku = fieldValue(summary, 'StockKeepingUnit');

        if (summary.defaultImage != null
                && String.isNotBlank(summary.defaultImage.url)
                && !summary.defaultImage.url.contains('default-product-image')) {
            tile.imageUrl = summary.defaultImage.url;
        }
        tile.imageKey = imageKeyFor(tile.sku);
        tile.rating = deriveRating(tile.sku);
        tile.reviewCount = deriveReviewCount(tile.sku);

        if (summary.prices != null) {
            tile.price = toDecimal(summary.prices.unitPrice);
            tile.listPrice = toDecimal(summary.prices.listPrice);
            if (tile.price != null && tile.listPrice != null
                    && tile.listPrice > 0 && tile.listPrice > tile.price) {
                tile.savings = (tile.listPrice - tile.price).setScale(2);
                tile.percentOff = Integer.valueOf(
                    ((tile.listPrice - tile.price) / tile.listPrice * 100).setScale(0));
            }
        }
        return tile;
    }

    /**
     * Reads one field out of ConnectApi.ProductSummary.fields.
     *
     * The map value type for that member is not a stable, referenceable ConnectApi type in this
     * API version (`ConnectApi.ProductSearchField` does not compile), so the value is read through
     * an untyped JSON round trip. That is deliberate: it keeps the class compiling across API
     * versions instead of binding to an internal wrapper name.
     */
    private static String fieldValue(ConnectApi.ProductSummary summary, String fieldName) {
        if (summary.fields == null) {
            return null;
        }
        Map<String, Object> raw =
            (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(summary.fields));
        Object entry = raw.get(fieldName);
        if (!(entry instanceof Map<String, Object>)) {
            return null;
        }
        Object value = ((Map<String, Object>) entry).get('value');
        return value == null ? null : String.valueOf(value);
    }

    private static Decimal toDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    /** Shape for the utility header. */
    public class HeaderContext {
        @AuraEnabled public Integer cartItemCount;
        @AuraEnabled public String accountName;
        @AuraEnabled public String greetingName;
        @AuraEnabled public Boolean isAuthenticated;
    }

    /**
     * Header context for the running user: cart count, account name and greeting.
     *
     * `commerce_builder:cartBadge` is the right component when all that is needed is a badge, but
     * it cannot be composed into a custom header strip alongside the delivery-location selector
     * and the category-scoped search, so the count is surfaced here instead. Guests get zeros.
     *
     * Identity comes from UserInfo rather than SOQL: a community buyer frequently cannot read
     * Contact.Account.Name under USER_MODE, and the original single combined query meant one FLS
     * rejection silently wiped out the greeting AND the authenticated flag.
     */
    @AuraEnabled(cacheable=true)
    public static HeaderContext getHeaderContext() {
        HeaderContext ctx = new HeaderContext();
        ctx.cartItemCount = 0;
        ctx.greetingName = UserInfo.getFirstName();
        String userType = UserInfo.getUserType();
        ctx.isAuthenticated = userType != null && userType != 'Guest';

        try {
            String accountId = context().effectiveAccountId;
            if (String.isNotBlank(accountId)) {
                List<Account> accounts = [
                    SELECT Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1
                ];
                if (!accounts.isEmpty()) {
                    ctx.accountName = accounts[0].Name;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Account name unavailable: ' + e.getMessage());
        }

        try {
            AggregateResult[] counts = [
                SELECT SUM(Quantity) total
                FROM CartItem
                WHERE Cart.Status = 'Active' AND Cart.OwnerId = :UserInfo.getUserId()
                WITH USER_MODE
            ];
            if (!counts.isEmpty() && counts[0].get('total') != null) {
                ctx.cartItemCount = Integer.valueOf((Decimal) counts[0].get('total'));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Cart count unavailable: ' + e.getMessage());
        }
        return ctx;
    }

    /** Maps a SKU to one of the generated category illustrations used as an image fallback. */
    private static String imageKeyFor(String sku) {
        if (String.isBlank(sku) || sku.length() < 6) {
            return 'generic';
        }
        String segment = sku.substring(3, 6).toLowerCase();
        Set<String> known = new Set<String>{
            'pap', 'wrt', 'fil', 'lap', 'prn', 'mon', 'chr', 'dsk', 'cof', 'cln'
        };
        return known.contains(segment) ? segment : 'generic';
    }

    /** SYNTHETIC. Stable 3.5-5.0 rating derived from the SKU hash. */
    private static Decimal deriveRating(String sku) {
        Integer h = Math.abs(String.isBlank(sku) ? 0 : sku.hashCode());
        return (3.5 + Math.mod(h, 16) / 10.0).setScale(1);
    }

    /** SYNTHETIC. Stable pseudo review count derived from the SKU hash. */
    private static Integer deriveReviewCount(String sku) {
        Integer h = Math.abs(String.isBlank(sku) ? 0 : sku.hashCode());
        return 24 + Math.mod(h, 1850);
    }

    private static Integer clamp(Integer value, Integer low, Integer high, Integer fallback) {
        if (value == null) {
            return fallback;
        }
        if (value < low) {
            return low;
        }
        return value > high ? high : value;
    }
}

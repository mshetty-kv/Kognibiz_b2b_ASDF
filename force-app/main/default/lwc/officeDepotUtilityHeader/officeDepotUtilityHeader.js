import { LightningElement, api, wire } from 'lwc';
import getHeaderContext from '@salesforce/apex/OfficeDepotStorefrontController.getHeaderContext';

import basePath from '@salesforce/community/basePath';

/**
 * Resolves a store-relative path against the Experience Cloud site base path.
 *
 * WHY: a bare <a href="/cart"> resolves against the ORIGIN, not the site, so on a my.site.com
 * domain that hosts several communities the browser leaves the Office Depot store entirely and
 * lands in whichever community claims that path. basePath is '/officedepot' here, so every
 * internal link must be built through this helper. External and protocol-relative URLs pass
 * through untouched.
 */
const siteUrl = (target) => {
    if (!target) {
        return `${basePath}/`;
    }
    if (target.indexOf("//") === 0 || /^https?:/i.test(target) || /^(mailto|tel):/i.test(target)) {
        return target;
    }
    const clean = target.startsWith('/') ? target : `/${target}`;
    return `${basePath}${clean}`;
};

/**
 * officeDepotUtilityHeader
 *
 * The top utility strip: brand lockup, deliver-to selector, category-scoped search,
 * language selector, account menu, Returns & Orders, and cart with item badge.
 *
 * WHY THIS IS CUSTOM
 * The standard pieces exist individually - `commerce_builder:searchInput`,
 * `commerce_builder:cartBadge`, `commerce_builder:userProfileMenu`, `dxp_content_layout:siteLogo` -
 * and they are the right choice if you want the stock header. What does not exist is a single
 * strip that composes them with a delivery-location control and a category-scoped search
 * dropdown in one dark bar with this specific density. Assembling the standard components inside
 * a section gets close but cannot produce the scoped-search control, which is the defining
 * element of the reference header.
 *
 * BRANDING: the lockup is the Office Depot name in Office Depot red. No third-party logo,
 * wordmark or device is reproduced.
 */
export default class OfficeDepotUtilityHeader extends LightningElement {
    @api brandName = 'Office Depot';
    @api brandSuffix = 'Business';
    @api deliverToCity = 'San Francisco 94105';
    @api searchPlaceholder = 'Search Office Depot Business';
    @api showLanguage = false;
    @api languageLabel = 'EN';
    @api orderListUrl = '/OrderSummary/OrderSummary/Default';
    /*
     * The global search route's urlPrefix is 'global-search', but the route only resolves WITH a
     * search-term path segment: /global-search/<term>. A bare /global-search renders the site's
     * Invalid Page. The term is appended as a path segment in submitSearch(), never as ?term=.
     */
    @api searchUrl = '/global-search';

    searchTerm = '';
    selectedScope = 'All';
    ctx;

    @wire(getHeaderContext)
    wiredCtx({ data }) {
        if (data) {
            this.ctx = data;
        }
    }

    get scopes() {
        return [
            'All',
            'Office Supplies',
            'Technology',
            'Furniture',
            'Breakroom and Cleaning'
        ].map((s) => ({ key: s, label: s, value: s }));
    }

    get cartCount() {
        return this.ctx && this.ctx.cartItemCount ? this.ctx.cartItemCount : 0;
    }

    get cartCountLabel() {
        return String(this.cartCount);
    }

    get cartAriaLabel() {
        const n = this.cartCount;
        return n === 1 ? 'Shopping cart, 1 item' : `Shopping cart, ${n} items`;
    }

    get homeUrl() {
        return siteUrl("/");
    }

    get accountUrl() {
        return siteUrl("/myprofile");
    }

    /*
     * Two routes share the urlPrefix 'OrderSummary': the detail route (detail-1Os) and the list
     * route (list-1Os). The list route is only reachable at
     * /OrderSummary/OrderSummary/Default - urlPrefix, then object API name, then filter name.
     * A bare /OrderSummary renders the site's Invalid Page. Verified against the store's own
     * Default_My_Account_Menu NavigationMenuItem, whose Order History target is that exact path.
     */
    get ordersUrl() {
        return siteUrl(this.orderListUrl);
    }

    get cartUrl() {
        return siteUrl("/cart");
    }

    get greeting() {
        if (this.ctx && this.ctx.greetingName) {
            return `Hello, ${this.ctx.greetingName}`;
        }
        return 'Hello, sign in';
    }

    get accountLine() {
        return this.ctx && this.ctx.accountName ? this.ctx.accountName : 'Account & Lists';
    }

    handleTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleScopeChange(event) {
        this.selectedScope = event.target.value;
    }

    handleSearchKey(event) {
        if (event.key === 'Enter') {
            this.submitSearch();
        }
    }

    handleSearchClick() {
        this.submitSearch();
    }

    submitSearch() {
        const term = (this.searchTerm || '').trim();
        if (!term) {
            return;
        }
        /*
         * The search term is a PATH SEGMENT, not a query parameter. ?term= leaves the route
         * without its required segment and the site answers with Invalid Page.
         *
         * The category scope selector is intentionally not encoded into the URL: the standard
         * global-search route takes only the term, and there is no supported query parameter for
         * a category filter. Scoping is applied by the shopper on the results page facets.
         */
        window.location.assign(`${siteUrl(this.searchUrl)}/${encodeURIComponent(term)}`);
    }
}

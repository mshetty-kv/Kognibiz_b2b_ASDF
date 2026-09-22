import { LightningElement, api } from 'lwc';

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
 * officeDepotMegaFooter
 *
 * Multi-column link footer with a back-to-top bar, brand lockup, locale selectors, app-store
 * style badges and a dark legal bar.
 *
 * WHY THIS IS CUSTOM
 * `commerce_builder:linkList` and `commerce_builder:socialLinks` are the standard footer pieces
 * and they are perfectly good for a normal footer - the generated theme layout already uses
 * them. They cannot produce the reference's three-band structure (back-to-top strip, dark link
 * grid, darker legal bar) in a single component, and `linkList` has no notion of a column group
 * heading. This is presentation-only: it holds no data and makes no server calls.
 *
 * The "app badges" are plain text buttons, NOT reproductions of the App Store or Google Play
 * marks, which are themselves trademarks.
 */
export default class OfficeDepotMegaFooter extends LightningElement {
    @api brandName = 'Office Depot';
    @api legalLine = 'Office Depot B2B Commerce demo storefront. Built for ASDF capability validation.';
    @api showLocale = false;

    /*
     * Destination overrides, set as design-time attributes in the theme layout.
     *
     * WHY THESE ARE PROPERTIES AND NOT LITERALS: catalogUrl carries a ProductCategory record id,
     * and record ids must never be hardcoded in code. The id lives in the theme layout's
     * component attributes (Experience Builder configuration), so a different org or catalog is
     * a config change, not a code change. The defaults below are all route-only and always
     * resolve, so a missing attribute degrades to the home page rather than to a 404.
     */
    @api catalogUrl = '/';
    @api ordersUrl = '/OrderSummary/OrderSummary/Default';
    @api accountUrl = '/myprofile';

    get homeUrl() {
        return siteUrl('/');
    }

    get termsUrl() {
        return siteUrl('/terms-and-conditions');
    }

    get privacyUrl() {
        return siteUrl('/privacy-policy');
    }

    /*
     * Link rows. A row with url === null renders as plain, non-navigating text.
     *
     * WHY: the reference footer this layout imitates is a marketing footer - About, Careers,
     * Sustainability, Become a supplier and so on. This storefront has no such pages and there
     * is no honest route to send a buyer to. Pointing them at the home page produced links that
     * looked live and went nowhere; pointing them at a made-up route produced 404s. Rendering
     * them as text keeps the footer's shape without shipping a dead link.
     */
    get columns() {
        return [
            {
                key: 'c1',
                heading: 'Get to know us',
                links: [
                    this.textOnly('a1', 'About Office Depot Business'),
                    this.linkTo('a2', 'Our catalog', this.catalogUrl),
                    this.textOnly('a3', 'Sustainability'),
                    this.textOnly('a4', 'Careers')
                ]
            },
            {
                key: 'c2',
                heading: 'Make money with us',
                links: [
                    this.textOnly('b1', 'Sell to businesses'),
                    this.textOnly('b2', 'Become a supplier'),
                    this.textOnly('b3', 'Partner programme'),
                    this.linkTo('b4', 'Bulk and contract sales', this.catalogUrl)
                ]
            },
            {
                key: 'c3',
                heading: 'Business services',
                links: [
                    this.linkTo('c1a', 'Contract pricing', this.catalogUrl),
                    this.linkTo('c2a', 'Quantity discounts', this.catalogUrl),
                    this.linkTo('c3a', 'Invoicing and payment', this.accountUrl),
                    this.linkTo('c4a', 'Team accounts', this.accountUrl)
                ]
            },
            {
                key: 'c4',
                heading: 'Let us help you',
                links: [
                    this.linkTo('d1', 'Your account', this.accountUrl),
                    this.linkTo('d2', 'Your orders', this.ordersUrl),
                    this.linkTo('d3', 'Shipping and delivery', '/terms-and-conditions'),
                    this.linkTo('d4', 'Returns and replacements', this.ordersUrl),
                    this.textOnly('d5', 'Help centre')
                ]
            }
        ];
    }

    linkTo(key, label, target) {
        return { key, label, url: siteUrl(target), isLink: true };
    }

    textOnly(key, label) {
        return { key, label, url: null, isLink: false };
    }

    handleBackToTop() {
        if (typeof window !== 'undefined') {
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }
}

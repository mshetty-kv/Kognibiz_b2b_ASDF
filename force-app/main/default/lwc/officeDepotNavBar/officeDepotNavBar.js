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
 * officeDepotNavBar
 *
 * Secondary navigation strip: hamburger "All" launcher, primary shortcut links, and a
 * right-aligned "Lists" dropdown.
 *
 * WHY THIS IS CUSTOM
 * Two standard components come close and were both evaluated:
 *   - `experience:megaMenuNavigation` and `commerce_builder:drilldownNavigation` render the
 *     category tree, which is what the "All" launcher opens - but neither provides the flat
 *     shortcut strip beside it, and neither can be constrained to a single dark bar of this
 *     height.
 *   - `commerce_builder:wishlistShortcut` provides Lists, but as a bare heart ICON with only
 *     iconType/isOutlined to configure. The reference needs a labelled dropdown with multiple
 *     list entries and a "Create a List" action.
 * The category tree itself is still owned by the standard navigation data (ProductCategory
 * IsNavigational); this component links into it rather than re-implementing it.
 *
 * ACCESSIBILITY
 * The Lists dropdown is a real disclosure: aria-expanded/aria-haspopup on the trigger, Escape
 * closes and returns focus, and clicking outside dismisses it.
 */
export default class OfficeDepotNavBar extends LightningElement {
    @api allLabel = 'All';
    @api listsLabel = 'Lists';
    /*
     * Every default below is a route that resolves on its own with no record id, so a missing
     * design-time attribute degrades to a working page rather than to Invalid Page.
     *
     * categoryUrl is the exception: the "All" launcher should open the catalog root, which needs
     * a ProductCategory id. Record ids must not be hardcoded in code, so the real value is set as
     * a component attribute in the theme layout and the default here is the home page.
     *
     * Labels 2-5 (Today's Deals, Business Deals, Quantity Discounts, Savings Hub) have no backing
     * feature in this store - there is no promotion engine and no savings hub. They are pointed
     * at the catalog browse page, which is the nearest true destination: every tile there shows
     * the buyer's negotiated price against list. They are NOT pointed at invented routes.
     */
    @api link1Label = 'Buy Again';
    @api link1Url = '/OrderSummary/OrderSummary/Default';
    @api link2Label = "Today's Deals";
    @api link2Url = '/';
    @api link3Label = 'Business Deals';
    @api link3Url = '/';
    @api link4Label = 'Quantity Discounts';
    @api link4Url = '/';
    @api link5Label = 'Savings Hub';
    @api link5Url = '/';
    @api link6Label = 'Add team members';
    @api link6Url = '/myprofile';
    @api categoryUrl = '/';
    @api orderListUrl = '/OrderSummary/OrderSummary/Default';

    listsOpen = false;

    connectedCallback() {
        this._outsideHandler = (e) => {
            if (this.listsOpen && !this.template.contains(e.target)) {
                this.listsOpen = false;
            }
        };
        if (typeof document !== 'undefined') {
            document.addEventListener('click', this._outsideHandler);
        }
    }

    disconnectedCallback() {
        if (typeof document !== 'undefined' && this._outsideHandler) {
            document.removeEventListener('click', this._outsideHandler);
        }
    }

    get allUrl() {
        return siteUrl(this.categoryUrl);
    }

    get links() {
        return [
            { l: this.link1Label, u: this.link1Url },
            { l: this.link2Label, u: this.link2Url },
            { l: this.link3Label, u: this.link3Url },
            { l: this.link4Label, u: this.link4Url },
            { l: this.link5Label, u: this.link5Url },
            { l: this.link6Label, u: this.link6Url }
        ]
            .filter((x) => x.l)
            .map((x, i) => ({ key: `nav-${i}`, label: x.l, url: siteUrl(x.u) }));
    }

    get listItems() {
        return [
            { key: 'l1', label: 'Your Lists', url: siteUrl('/mylists') },
            { key: 'l2', label: 'Reorder favourites', url: siteUrl(this.orderListUrl) },
            { key: 'l3', label: 'Create a List', url: siteUrl('/mylists') }
        ];
    }

    get listsExpanded() {
        return this.listsOpen ? 'true' : 'false';
    }

    get listsMenuClass() {
        return this.listsOpen ? 'od-lists-menu od-lists-menu--open' : 'od-lists-menu';
    }

    handleListsToggle(event) {
        event.stopPropagation();
        this.listsOpen = !this.listsOpen;
    }

    handleKeydown(event) {
        if (event.key === 'Escape' && this.listsOpen) {
            this.listsOpen = false;
            const trigger = this.template.querySelector('.od-lists-trigger');
            if (trigger) {
                trigger.focus();
            }
        }
    }
}

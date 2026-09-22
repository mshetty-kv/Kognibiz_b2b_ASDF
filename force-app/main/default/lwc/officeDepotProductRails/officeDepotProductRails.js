import { LightningElement, api } from 'lwc';
import getBestsellerRails from '@salesforce/apex/OfficeDepotStorefrontController.getBestsellerRails';
import { productImage } from 'c/officeDepotImagery';

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
 * officeDepotProductRails
 *
 * Horizontal "Bestsellers in <Category>" rails, one per category, sourced from OUR catalogue.
 *
 * WHY THIS IS CUSTOM
 * The site does ship `b2c_lite_commerce:topSellers`, which is a horizontal product rail - but it
 * renders a single Einstein "Recommended For You" strip with only headerText/pageSize/browseStep
 * to configure. It cannot be pointed at a specific ProductCategory, cannot render one rail per
 * category, and exposes no slot for the rating/review/percent-off/savings-chip card anatomy the
 * reference shows. `commerce_builder:productCard` is a PDP-context component, not a rail.
 * So: standard component exists and was evaluated, but genuinely cannot meet the requirement.
 *
 * ACCESSIBILITY
 * Each rail is a labelled region; the scroller is keyboard-scrollable and arrow buttons carry
 * aria-labels. Page position is announced in a polite live region. Star ratings render as text
 * for assistive tech and as glyphs visually.
 */
export default class OfficeDepotProductRails extends LightningElement {
    @api maxCategories = 6;
    @api productsPerRail = 8;
    @api headingPrefix = 'Bestsellers in';
    @api showRatings = false;
    @api showSavingsChip = false;

    rails = [];
    loaded = false;
    error;
    pagePositions = {};

    /*
     * Imperative, NOT @wire. getBestsellerRails cannot be cacheable=true because
     * ConnectApi.CommerceSearch.searchProducts performs an internal DML, which a read-only
     * cacheable Apex context rejects - and @wire only accepts cacheable methods.
     */
    connectedCallback() {
        getBestsellerRails({
            maxCategories: Number(this.maxCategories),
            productsPerRail: Number(this.productsPerRail)
        })
            .then((data) => {
                this.error = undefined;
                this.rails = (data || []).map((rail) => this.decorateRail(rail));
                this.loaded = true;
            })
            .catch((error) => {
                this.error = this.reduceError(error);
                this.rails = [];
                this.loaded = true;
            });
    }

    decorateRail(rail) {
        const products = (rail.products || []).map((p) => {
            const hasDeal = p.percentOff != null && p.percentOff > 0;
            return {
                ...p,
                key: p.productId,
                productUrl: siteUrl(p.productUrl),
                // NOTE: CMS media URLs from ConnectApi are already absolute-from-origin
                // (/cms/delivery/media/...) and are served by a redirect at the ORIGIN, not under
                // the site base path. Prefixing them with basePath returns a hard 404 - verified.
                image: p.imageUrl || productImage(p.imageKey),
                imageAlt: p.name,
                priceLabel: this.money(p.price),
                listLabel: this.money(p.listPrice),
                showList: hasDeal && p.listPrice != null,
                percentLabel: hasDeal ? `${p.percentOff}% off` : '',
                savingsLabel: hasDeal ? `Save ${this.money(p.savings)}` : '',
                showSavings: this.showSavingsChip && hasDeal,
                showRating: this.showRatings && p.rating != null,
                stars: this.starGlyphs(p.rating),
                ratingText: p.rating != null ? `Rated ${p.rating} out of 5 stars` : '',
                reviewLabel: p.reviewCount != null ? this.compact(p.reviewCount) : ''
            };
        });

        const perPage = 5;
        const pageCount = Math.max(1, Math.ceil(products.length / perPage));
        return {
            ...rail,
            key: rail.categoryId,
            categoryUrl: siteUrl(rail.categoryUrl),
            heading: `${this.headingPrefix} ${rail.categoryName}`,
            regionLabel: `${this.headingPrefix} ${rail.categoryName}`,
            products,
            pageLabel: `Page 1 of ${pageCount}`,
            dealBadge: rail.maxPercentOff > 0 ? `Up to ${rail.maxPercentOff}% off` : '',
            hasDealBadge: rail.maxPercentOff > 0
        };
    }

    get hasRails() {
        return this.rails && this.rails.length > 0;
    }

    get isEmpty() {
        return this.loaded && !this.error && (!this.rails || this.rails.length === 0);
    }

    money(value) {
        if (value == null) {
            return '';
        }
        return `$${Number(value).toFixed(2)}`;
    }

    compact(n) {
        return n >= 1000 ? `${(n / 1000).toFixed(1)}K` : String(n);
    }

    starGlyphs(rating) {
        if (rating == null) {
            return '';
        }
        const full = Math.floor(rating);
        const half = rating - full >= 0.5;
        let out = '';
        for (let i = 0; i < 5; i++) {
            if (i < full) {
                out += '★';
            } else if (i === full && half) {
                out += '½';
            } else {
                out += '☆';
            }
        }
        return out;
    }

    /* Scrolls the rail by roughly one card page. */
    scrollRail(railId, direction) {
        const el = this.template.querySelector(`[data-scroller="${railId}"]`);
        if (!el) {
            return;
        }
        const amount = Math.max(240, el.clientWidth * 0.8);
        el.scrollBy({ left: direction * amount, behavior: 'smooth' });
    }

    handleScrollLeft(event) {
        this.scrollRail(event.currentTarget.dataset.rail, -1);
    }

    handleScrollRight(event) {
        this.scrollRail(event.currentTarget.dataset.rail, 1);
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error.message || 'Unable to load products';
    }
}

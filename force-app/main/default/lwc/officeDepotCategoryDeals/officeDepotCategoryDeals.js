import { LightningElement, api } from 'lwc';
import getCategoryDeals from '@salesforce/apex/OfficeDepotStorefrontController.getCategoryDeals';
import { categoryImage } from 'c/officeDepotImagery';

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
 * officeDepotCategoryDeals
 *
 * The "Office Supplies | Up to 30% off" style category deal tiles, each showing a 2x2 grid of
 * products from that category with the real maximum discount computed from OUR pricebooks.
 *
 * WHY THIS IS CUSTOM
 * `dxp_content_layout:grid` + `dxp_content_layout:list` can lay out a CMS collection, and that
 * is the right standard tool for editorial content. It cannot compute "up to N% off" from
 * PricebookEntry data, and it has no binding to ProductCategory. The percentage here is
 * genuine - it is derived from the list-vs-contract price delta, not typed in by an author.
 */
export default class OfficeDepotCategoryDeals extends LightningElement {
    @api heading = 'Deals by category';
    @api maxCategories = 4;

    deals = [];
    error;

    /* Imperative, NOT @wire: getCategoryDeals is not cacheable because the underlying
     * ConnectApi commerce search performs an internal DML. */
    connectedCallback() {
        getCategoryDeals({ maxCategories: Number(this.maxCategories) })
            .then((data) => {
                this.error = undefined;
                this.deals = (data || []).map((d) => ({
                    key: d.categoryId,
                    name: d.categoryName,
                    url: siteUrl(d.categoryUrl),
                    badge: d.maxPercentOff > 0 ? `Up to ${d.maxPercentOff}% off` : 'Shop now',
                    hasBadge: d.maxPercentOff > 0,
                    thumbs: (d.products || []).slice(0, 4).map((pr) => ({
                        key: pr.productId,
                        image: pr.imageUrl || categoryImage(pr.imageKey),
                        alt: pr.name,
                        url: siteUrl(pr.productUrl)
                    }))
                }));
            })
            .catch((error) => {
                this.error = (error.body && error.body.message) || 'Unable to load category deals';
                this.deals = [];
            });
    }

    get hasDeals() {
        return this.deals && this.deals.length > 0;
    }
}

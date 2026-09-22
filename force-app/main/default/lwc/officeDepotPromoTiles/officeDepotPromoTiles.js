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
 * officeDepotPromoTiles
 *
 * The 4-across promo tile row that sits directly under the hero in the reference layout
 * (Welcome Offer / Bills & Recharges / Business Essentials / Your business savings).
 *
 * STANDARD-FIRST NOTE: this row CAN be approximated with `community_layout:section` configured
 * to four 3-wide columns each holding a `dxp_content_layout:banner`. That was the approach
 * documented as Class 1 before customization was authorised, and it remains viable. It is built
 * as one component here for two concrete reasons: the four tiles need a shared card anatomy
 * (icon + eyebrow + title + body + CTA) that four independent banners cannot keep in sync, and
 * the reference tiles overlap the hero's lower edge, which a plain section cannot do. Content
 * stays fully editable in Experience Builder through the design-time properties below.
 */
export default class OfficeDepotPromoTiles extends LightningElement {
    @api overlapHero = false;

    @api tile1Icon = 'gift';
    @api tile1Title = 'Welcome offer';
    @api tile1Body = 'New to Office Depot Business? Your contract pricing is already applied.';
    @api tile1CtaLabel = 'See your price';
    @api tile1CtaUrl = '/';

    @api tile2Icon = 'receipt';
    @api tile2Title = 'Invoices & reordering';
    @api tile2Body = 'Reorder from past purchases and track every order in one place.';
    @api tile2CtaLabel = 'Go to orders';
    @api tile2CtaUrl = '/OrderSummary/OrderSummary/Default';

    @api tile3Icon = 'box';
    @api tile3Title = 'Business essentials';
    @api tile3Body = 'Paper, ink, breakroom and cleaning supplies in case quantities.';
    @api tile3CtaLabel = 'Shop essentials';
    @api tile3CtaUrl = '/';

    @api tile4Icon = 'chart';
    @api tile4Title = 'Your business savings';
    @api tile4Body = 'You save 18% against list price on every catalog item.';
    @api tile4CtaLabel = 'View savings';
    @api tile4CtaUrl = '/';

    get tiles() {
        return [
            { i: this.tile1Icon, t: this.tile1Title, b: this.tile1Body, c: this.tile1CtaLabel, u: this.tile1CtaUrl },
            { i: this.tile2Icon, t: this.tile2Title, b: this.tile2Body, c: this.tile2CtaLabel, u: this.tile2CtaUrl },
            { i: this.tile3Icon, t: this.tile3Title, b: this.tile3Body, c: this.tile3CtaLabel, u: this.tile3CtaUrl },
            { i: this.tile4Icon, t: this.tile4Title, b: this.tile4Body, c: this.tile4CtaLabel, u: this.tile4CtaUrl }
        ]
            .filter((x) => x.t)
            .map((x, idx) => ({
                key: `tile-${idx}`,
                title: x.t,
                body: x.b,
                cta: x.c,
                url: siteUrl(x.u),
                glyph: this.glyphFor(x.i)
            }));
    }

    get rowClass() {
        return this.overlapHero ? 'od-promo-row od-promo-row--overlap' : 'od-promo-row';
    }

    /* Unicode glyphs avoid shipping an icon font and stay decorative (aria-hidden in markup). */
    glyphFor(name) {
        const map = {
            gift: '\u{1F381}',
            receipt: '\u{1F9FE}',
            box: '\u{1F4E6}',
            chart: '\u{1F4C8}',
            truck: '\u{1F69A}',
            tag: '\u{1F3F7}'
        };
        return map[name] || '✦';
    }
}

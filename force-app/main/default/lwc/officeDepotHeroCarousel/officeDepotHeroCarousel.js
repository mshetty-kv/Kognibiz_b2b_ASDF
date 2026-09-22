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
 * officeDepotHeroCarousel
 *
 * WHY THIS IS CUSTOM: the site's standard palette offers `dxp_content_layout:banner`, which is a
 * STATIC single banner. Nothing in the retrieved bundle, and nothing found on the commerce or
 * dxp_content_layout namespaces, provides a rotating multi-slide hero with prev/next controls.
 * That gap was documented as Class 4 in docs/ASDF_ASSESSMENT.md before customization was
 * authorised; this component is the authorised fill for it.
 *
 * ACCESSIBILITY
 * - Region is labelled and marked aria-roledescription="carousel".
 * - Slides are aria-hidden when off-screen so screen readers announce only the active one.
 * - Left/Right arrow keys move between slides; the control strip is fully tabbable.
 * - Auto-advance pauses on hover, on keyboard focus, when the tab is hidden, and when the user
 *   presses the pause control. It is also disabled outright for users who have asked for
 *   reduced motion.
 * - A live region announces "Slide N of M" so the change is not silent.
 */
export default class OfficeDepotHeroCarousel extends LightningElement {
    /* ---- Experience Builder design-time properties ---- */
    @api autoAdvance = false;
    @api intervalSeconds = 6;
    @api carouselHeight = 340;

    @api slide1Eyebrow = 'Office Depot Business';
    @api slide1Title = 'Everything your workplace runs on';
    @api slide1Body = 'Contract pricing on 20+ business essentials, from paper to workstations.';
    @api slide1CtaLabel = 'Shop the catalog';
    @api slide1CtaUrl = '/';
    @api slide1Theme = 'navy';

    @api slide2Eyebrow = 'Save 18% every day';
    @api slide2Title = 'Your negotiated contract price, applied automatically';
    @api slide2Body = 'Every product shows your business price next to the list price.';
    @api slide2CtaLabel = 'See your pricing';
    @api slide2CtaUrl = '/';
    @api slide2Theme = 'teal';

    @api slide3Eyebrow = 'Workspace refresh';
    @api slide3Title = 'Desks, chairs and monitors built for long days';
    @api slide3Body = 'Ergonomic seating and sit-stand desks, ready for bulk ordering.';
    @api slide3CtaLabel = 'Shop furniture';
    @api slide3CtaUrl = '/';
    @api slide3Theme = 'amber';

    @api slide4Eyebrow = 'Breakroom and cleaning';
    @api slide4Title = 'Keep the whole floor stocked';
    @api slide4Body = 'Coffee, snacks and disinfecting supplies in case quantities.';
    @api slide4CtaLabel = 'Shop breakroom';
    @api slide4CtaUrl = '/';
    @api slide4Theme = 'plum';

    activeIndex = 0;
    paused = false;
    _timer;
    _prefersReducedMotion = false;

    connectedCallback() {
        if (typeof window !== 'undefined' && window.matchMedia) {
            this._prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        }
        this._visibilityHandler = () => {
            if (typeof document !== 'undefined' && document.hidden) {
                this.stopTimer();
            } else {
                this.startTimer();
            }
        };
        if (typeof document !== 'undefined') {
            document.addEventListener('visibilitychange', this._visibilityHandler);
        }
        this.startTimer();
    }

    disconnectedCallback() {
        this.stopTimer();
        if (typeof document !== 'undefined' && this._visibilityHandler) {
            document.removeEventListener('visibilitychange', this._visibilityHandler);
        }
    }

    get slides() {
        const raw = [
            {
                eyebrow: this.slide1Eyebrow, title: this.slide1Title, body: this.slide1Body,
                cta: this.slide1CtaLabel, url: siteUrl(this.slide1CtaUrl), theme: this.slide1Theme
            },
            {
                eyebrow: this.slide2Eyebrow, title: this.slide2Title, body: this.slide2Body,
                cta: this.slide2CtaLabel, url: siteUrl(this.slide2CtaUrl), theme: this.slide2Theme
            },
            {
                eyebrow: this.slide3Eyebrow, title: this.slide3Title, body: this.slide3Body,
                cta: this.slide3CtaLabel, url: siteUrl(this.slide3CtaUrl), theme: this.slide3Theme
            },
            {
                eyebrow: this.slide4Eyebrow, title: this.slide4Title, body: this.slide4Body,
                cta: this.slide4CtaLabel, url: siteUrl(this.slide4CtaUrl), theme: this.slide4Theme
            }
        ].filter((s) => s.title);

        const total = raw.length;
        return raw.map((s, i) => ({
            ...s,
            key: `slide-${i}`,
            index: i,
            isActive: i === this.activeIndex,
            ariaHidden: i === this.activeIndex ? 'false' : 'true',
            slideClass: `od-slide od-theme-${s.theme || 'navy'}${i === this.activeIndex ? ' od-slide--active' : ''}`,
            label: `Slide ${i + 1} of ${total}: ${s.title}`
        }));
    }

    get dots() {
        const total = this.slides.length;
        return this.slides.map((s, i) => ({
            key: `dot-${i}`,
            index: i,
            dotClass: `od-dot${i === this.activeIndex ? ' od-dot--on' : ''}`,
            label: `Go to slide ${i + 1} of ${total}`,
            pressed: i === this.activeIndex ? 'true' : 'false'
        }));
    }

    get viewportStyle() {
        const h = Number(this.carouselHeight) || 340;
        return `height:${h}px;`;
    }

    get trackStyle() {
        return `transform: translateX(-${this.activeIndex * 100}%);`;
    }

    get pauseLabel() {
        return this.paused ? 'Resume automatic slide rotation' : 'Pause automatic slide rotation';
    }

    get pauseGlyph() {
        return this.paused ? '▶' : '‖';
    }

    get liveMessage() {
        return `Slide ${this.activeIndex + 1} of ${this.slides.length}`;
    }

    get showAutoControls() {
        return this.autoAdvance && !this._prefersReducedMotion;
    }

    /* ---- navigation ---- */
    next() {
        const total = this.slides.length;
        this.activeIndex = total ? (this.activeIndex + 1) % total : 0;
    }

    previous() {
        const total = this.slides.length;
        this.activeIndex = total ? (this.activeIndex - 1 + total) % total : 0;
    }

    handleNext() {
        this.next();
        this.restartTimer();
    }

    handlePrevious() {
        this.previous();
        this.restartTimer();
    }

    handleDot(event) {
        this.activeIndex = Number(event.currentTarget.dataset.index);
        this.restartTimer();
    }

    handleTogglePause() {
        this.paused = !this.paused;
        if (this.paused) {
            this.stopTimer();
        } else {
            this.startTimer();
        }
    }

    handleKeydown(event) {
        if (event.key === 'ArrowRight') {
            event.preventDefault();
            this.handleNext();
        } else if (event.key === 'ArrowLeft') {
            event.preventDefault();
            this.handlePrevious();
        }
    }

    /* Pause while the user is hovering or reading via keyboard. */
    handleMouseEnter() {
        this.stopTimer();
    }

    handleMouseLeave() {
        this.startTimer();
    }

    handleFocusIn() {
        this.stopTimer();
    }

    handleFocusOut() {
        this.startTimer();
    }

    /* ---- timer ---- */
    startTimer() {
        this.stopTimer();
        if (!this.autoAdvance || this.paused || this._prefersReducedMotion) {
            return;
        }
        const seconds = Math.max(2, Number(this.intervalSeconds) || 6);
        this._timer = setInterval(() => this.next(), seconds * 1000);
    }

    stopTimer() {
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = undefined;
        }
    }

    restartTimer() {
        this.startTimer();
    }
}

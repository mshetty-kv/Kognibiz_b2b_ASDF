import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getObjectInfos } from "lightning/uiObjectInfoApi";
import basePath from "@salesforce/community/basePath";
import isGuest from "@salesforce/user/isGuest";
import { LABELS, SECTIONS } from "c/amazonAccountDashboardLabels";

const WEB_PATH_PREFIX = "/";
const OBJECT_PAGE_PREFIX = "object:";
const LOG_PREFIX = "[amazonAccountDashboard]";

/**
 * Builds a PageReference from a design-time page target.
 *   "/some-path"          -> standard__webPage, prefixed with the site base path
 *   "object:OrderSummary" -> standard__objectPage list view (filter "Default")
 *   "My_Profile"          -> comm__namedPage (route API name)
 */
export function toPageReference(target) {
    const value = (target || "").trim();
    if (!value) {
        return null;
    }
    if (value.startsWith(WEB_PATH_PREFIX)) {
        return { type: "standard__webPage", attributes: { url: `${basePath}${value}` } };
    }
    if (value.startsWith(OBJECT_PAGE_PREFIX)) {
        return {
            type: "standard__objectPage",
            attributes: { objectApiName: value.slice(OBJECT_PAGE_PREFIX.length), actionName: "list" },
            state: { filterName: "Default" }
        };
    }
    return { type: "comm__namedPage", attributes: { name: value } };
}

function clean(value) {
    return typeof value === "string" ? value.trim() : "";
}

/**
 * FS-001 Account Management Dashboard: an Amazon "Your Account" style card grid.
 * Presentation only - titles/subtitles come from Custom Labels, page targets and entitlement
 * gates from Experience Builder properties. Hiding a card is navigation hygiene, NOT
 * authorization: each destination page enforces its own access on the server.
 */
export default class AmazonAccountDashboard extends NavigationMixin(LightningElement) {
    @api showHeading;

    @api profileEnabled;
    @api profilePage;
    @api profileAccessObject;
    @api ordersEnabled;
    @api ordersPage;
    @api ordersAccessObject;
    @api quotesEnabled;
    @api quotesPage;
    @api quotesAccessObject;
    @api listsEnabled;
    @api listsPage;
    @api listsAccessObject;
    @api purchaseOrdersEnabled;
    @api purchaseOrdersPage;
    @api purchaseOrdersAccessObject;
    @api addressesEnabled;
    @api addressesPage;
    @api addressesAccessObject;
    @api departmentEnabled;
    @api departmentPage;
    @api departmentAccessObject;
    @api contactEnabled;
    @api contactPage;
    @api contactAccessObject;

    labels = LABELS;
    hrefs = {};
    accessibleObjects;
    accessError = false;
    warned = new Set();

    connectedCallback() {
        if (!isGuest) {
            this.generateHrefs();
        }
    }

    get isAuthenticated() {
        return !isGuest;
    }

    get displayHeading() {
        return this.showHeading !== false && Boolean(clean(LABELS.pageTitle));
    }

    /** Distinct object API names any enabled card is gated on; undefined keeps the wire idle. */
    get accessObjects() {
        const names = new Set();
        this.configuredSections().forEach((section) => {
            if (section.accessObject) {
                names.add(section.accessObject);
            }
        });
        return names.size ? Array.from(names).sort() : undefined;
    }

    get accessResolved() {
        return !this.accessObjects || this.accessError || this.accessibleObjects !== undefined;
    }

    @wire(getObjectInfos, { objectApiNames: "$accessObjects" })
    wiredObjectInfos({ data, error }) {
        if (data) {
            const allowed = new Set();
            (data.results || []).forEach((entry) => {
                if (entry && entry.statusCode === 200 && entry.result && entry.result.apiName) {
                    allowed.add(entry.result.apiName);
                }
            });
            this.accessibleObjects = allowed;
            this.accessError = false;
        } else if (error) {
            // Fail closed: gated cards stay hidden when access cannot be established.
            this.accessibleObjects = new Set();
            this.accessError = true;
            this.warnOnce("access", `${LOG_PREFIX} object access check failed; gated cards hidden.`);
        }
    }

    /** Sections switched on in Builder and carrying a usable page target. */
    configuredSections() {
        return SECTIONS.filter((section) => this[`${section.prop}Enabled`] !== false)
            .map((section) => ({
                ...section,
                page: clean(this[`${section.prop}Page`]),
                accessObject: clean(this[`${section.prop}AccessObject`])
            }))
            .filter((section) => {
                if (!section.page) {
                    this.warnOnce(`page-${section.key}`, `${LOG_PREFIX} no page configured for "${section.key}"; card omitted.`);
                    return false;
                }
                return true;
            });
    }

    get cards() {
        if (!this.accessResolved) {
            return [];
        }
        return this.configuredSections()
            .filter((section) => !section.accessObject || this.accessibleObjects.has(section.accessObject))
            .map((section) => {
                let title = clean(section.title);
                if (!title) {
                    this.warnOnce(`title-${section.key}`, `${LOG_PREFIX} empty title label for "${section.key}"; using fallback.`);
                    title = clean(LABELS.fallbackTitle);
                }
                const subtitle = clean(section.subtitle);
                if (!subtitle) {
                    this.warnOnce(`subtitle-${section.key}`, `${LOG_PREFIX} empty subtitle label for "${section.key}"; rendering without it.`);
                }
                return {
                    key: section.key,
                    title,
                    subtitle,
                    icon: section.icon,
                    href: this.hrefs[section.key] || `${basePath}/`
                };
            })
            .filter((card) => Boolean(card.title));
    }

    get hasCards() {
        return this.cards.length > 0;
    }

    generateHrefs() {
        this.configuredSections().forEach((section) => {
            const pageRef = toPageReference(section.page);
            if (pageRef.type === "standard__webPage") {
                this.setHref(section.key, pageRef.attributes.url);
                return;
            }
            this[NavigationMixin.GenerateUrl](pageRef)
                .then((url) => this.setHref(section.key, url))
                .catch(() => {
                    this.warnOnce(`url-${section.key}`, `${LOG_PREFIX} could not resolve page "${section.page}" for "${section.key}".`);
                });
        });
    }

    setHref(key, url) {
        if (url) {
            this.hrefs = { ...this.hrefs, [key]: url };
        }
    }

    handleCardSelect(event) {
        const key = event.detail && event.detail.key;
        const section = this.configuredSections().find((candidate) => candidate.key === key);
        const pageRef = section && toPageReference(section.page);
        if (pageRef) {
            this[NavigationMixin.Navigate](pageRef);
        }
    }

    warnOnce(id, message) {
        if (!this.warned.has(id)) {
            this.warned.add(id);
            console.warn(message);
        }
    }
}

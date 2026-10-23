import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { toPageReference } from "c/amazonAccountDashboard";
import { LABELS, PAGE_TITLES } from "c/amazonAccountDashboardLabels";

const LOG_PREFIX = "[amazonAccountBackNav]";

/**
 * FS-001 phase 2: "Your Account > {page}" breadcrumb plus a "Back to Your Account" pill,
 * placed at the top of each account sub-page. All text comes from Custom Labels; the
 * dashboard target and the current page are Experience Builder properties.
 */
export default class AmazonAccountBackNav extends NavigationMixin(LightningElement) {
    /** Dashboard target: route API name, "/path" or "object:ApiName" (see toPageReference). */
    @api targetPage;
    /** Key of the current page in PAGE_TITLES (profile, orders, quotes, ...). */
    @api currentPage;

    labels = LABELS;
    href;
    warnings = { title: false }; // not tracked: mutated during render

    connectedCallback() {
        const pageRef = this.pageReference;
        if (!pageRef) {
            console.warn(`${LOG_PREFIX} no target page configured; back navigation hidden.`);
            return;
        }
        if (pageRef.type === "standard__webPage") {
            this.href = pageRef.attributes.url;
            return;
        }
        this[NavigationMixin.GenerateUrl](pageRef)
            .then((url) => {
                this.href = url;
            })
            .catch(() => {
                console.warn(`${LOG_PREFIX} could not resolve page "${this.targetPage}".`);
            });
    }

    get pageReference() {
        return toPageReference(this.targetPage);
    }

    get isReady() {
        return Boolean(this.href);
    }

    get rootLabel() {
        return LABELS.pageTitle;
    }

    get currentTitle() {
        const key = (this.currentPage || "").trim();
        const title = key ? (PAGE_TITLES[key] || "").trim() : "";
        if (key && !title && !this.warnings.title) {
            this.warnings.title = true;
            console.warn(`${LOG_PREFIX} no title label for page "${key}"; breadcrumb shows the root only.`);
        }
        return title;
    }

    get hasCurrentTitle() {
        return Boolean(this.currentTitle);
    }

    handleNavigate(event) {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
            return;
        }
        event.preventDefault();
        this[NavigationMixin.Navigate](this.pageReference);
    }
}

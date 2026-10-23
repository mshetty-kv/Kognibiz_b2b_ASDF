import { LightningElement, api } from "lwc";

/**
 * Presentational account-dashboard card (FS-001). Knows nothing about routing or entitlements:
 * it renders what it is given and raises `cardselect` so the container can navigate.
 * The root is a real anchor, so Tab focuses it and Enter activates it natively (NFR-02),
 * and middle-click / open-in-new-tab still work through the generated href.
 */
export default class AmazonAccountDashboardCard extends LightningElement {
    @api cardKey;
    @api cardTitle;
    @api subtitle;
    @api iconName;
    @api href;

    get hasSubtitle() {
        return Boolean(this.subtitle);
    }

    handleClick(event) {
        // Modified clicks keep native browser behaviour (new tab / window).
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
            return;
        }
        event.preventDefault();
        this.dispatchEvent(new CustomEvent("cardselect", { detail: { key: this.cardKey } }));
    }
}

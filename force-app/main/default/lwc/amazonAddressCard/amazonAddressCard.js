import { LightningElement, api } from "lwc";
import LABELS from "c/amazonAddressLabels";

/**
 * Presentational address card (B2B-ADDR-001). Receives an address through @api and raises
 * `edit` / `remove` CustomEvents; it never touches data itself. Removal is two-step: the first
 * click swaps the footer for an inline confirmation (FR-06 / AC-10).
 */
export default class AmazonAddressCard extends LightningElement {
    @api address = {};
    @api busy = false;

    labels = LABELS;
    confirming = false;

    get typeLabel() {
        return this.address.addressType === "Billing" ? LABELS.billing : LABELS.shipping;
    }

    get streetLines() {
        return (this.address.street || "")
            .split(/\r?\n/)
            .filter((text) => text.trim().length)
            .map((text, index) => ({ key: `street-${index}`, text }));
    }

    get cityLine() {
        const region = this.address.region || this.address.regionCode || "";
        const cityRegion = [this.address.city, region].filter(Boolean).join(", ");
        return [cityRegion, this.address.postalCode].filter(Boolean).join(" ");
    }

    get editAssistive() {
        return `${LABELS.editAssistive} ${this.address.name}`;
    }

    get removeAssistive() {
        return `${LABELS.removeAssistive} ${this.address.name}`;
    }

    handleEdit() {
        this.dispatchEvent(new CustomEvent("edit", { detail: { addressId: this.address.addressId } }));
    }

    handleRemove() {
        this.confirming = true;
        // Move focus into the confirmation so keyboard and screen-reader users land on it.
        Promise.resolve().then(() => {
            const yes = this.template.querySelector(".danger");
            if (yes) {
                yes.focus();
            }
        });
    }

    handleCancelRemove() {
        this.confirming = false;
        Promise.resolve().then(() => {
            const remove = this.template.querySelector(".remove");
            if (remove) {
                remove.focus();
            }
        });
    }

    handleConfirmRemove() {
        this.dispatchEvent(new CustomEvent("remove", { detail: { addressId: this.address.addressId } }));
    }

    /** Lets the container close the confirmation if the delete fails. */
    @api
    resetConfirmation() {
        this.confirming = false;
    }
}

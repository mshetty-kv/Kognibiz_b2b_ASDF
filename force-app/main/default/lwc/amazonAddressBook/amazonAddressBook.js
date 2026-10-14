import { LightningElement, api, wire } from "lwc";
import getAddresses from "@salesforce/apex/AmazonAddressBookController.getAddresses";
import saveAddress from "@salesforce/apex/AmazonAddressBookController.saveAddress";
import removeAddress from "@salesforce/apex/AmazonAddressBookController.removeAddress";
import getCountryOptions from "@salesforce/apex/AmazonAddressBookController.getCountryOptions";
import LABELS from "c/amazonAddressLabels";

/** Turns any LDS / Apex error shape into a user-safe string. */
function reduceError(error) {
    if (!error) {
        return LABELS.errorGeneric;
    }
    if (Array.isArray(error.body)) {
        return error.body.map((item) => item.message).filter(Boolean).join(", ") || LABELS.errorGeneric;
    }
    if (error.body && typeof error.body.message === "string" && error.body.message) {
        return error.body.message;
    }
    return typeof error.message === "string" && error.message ? error.message : LABELS.errorGeneric;
}

/**
 * Smart container for the Amazon-style "Your Addresses" page (B2B-ADDR-001).
 * Owns all data access; renders Billing and Shipping sections (FR-01) each led by a dashed
 * "Add address" card (FR-02), and swaps in the Add/Edit form (FR-03). All persistence goes
 * through AmazonAddressBookController, which wraps the standard Commerce Buyer Experience API
 * over ContactPointAddress (FR-04, BR-01).
 */
export default class AmazonAddressBook extends LightningElement {
    /** Country pre-selected on a new address; configurable in Experience Builder. */
    @api defaultCountryCode = "US";

    labels = LABELS;
    addresses = [];
    countries = [];
    loading = true;
    busy = false;
    errorMessage;
    statusMessage = "";
    view = "list";
    editingAddress;
    newAddressType = "Shipping";

    @wire(getCountryOptions)
    wiredCountries({ data, error }) {
        if (data) {
            this.countries = data;
        } else if (error) {
            this.errorMessage = reduceError(error);
        }
    }

    connectedCallback() {
        this.loadAddresses();
    }

    get isFormView() {
        return this.view === "form";
    }

    get sections() {
        const build = (type, heading, addAssistive) => ({
            type,
            heading,
            addAssistive,
            headingId: `heading-${type.toLowerCase()}`,
            // Default address first, then newest first (server order).
            addresses: this.addresses
                .filter((address) => address.addressType === type)
                .map((address) => this.withDisplayNames(address))
                .sort((first, second) => Number(second.isDefault) - Number(first.isDefault))
        });
        return [
            build("Billing", LABELS.billingHeading, LABELS.addBillingAssistive),
            build("Shipping", LABELS.shippingHeading, LABELS.addShippingAssistive)
        ];
    }

    /** The Commerce API returns ISO codes; show the picklist labels on the card when known. */
    withDisplayNames(address) {
        const country = this.countries.find((item) => item.value === address.countryCode);
        const state = country && country.states ? country.states.find((item) => item.value === address.regionCode) : null;
        return {
            ...address,
            country: country ? country.label : address.country,
            region: state ? state.label : address.region
        };
    }

    async loadAddresses() {
        this.loading = true;
        try {
            this.addresses = (await getAddresses()) || [];
            this.errorMessage = undefined;
        } catch (error) {
            this.addresses = [];
            this.errorMessage = reduceError(error);
        } finally {
            this.loading = false;
        }
    }

    handleAdd(event) {
        this.newAddressType = event.currentTarget.dataset.type;
        this.editingAddress = undefined;
        this.errorMessage = undefined;
        this.view = "form";
    }

    handleEdit(event) {
        const addressId = event.detail.addressId;
        this.editingAddress = this.addresses.find((address) => address.addressId === addressId);
        this.errorMessage = undefined;
        this.view = "form";
    }

    handleCancel() {
        this.returnToList();
    }

    async handleSave(event) {
        this.busy = true;
        this.errorMessage = undefined;
        try {
            await saveAddress({ address: event.detail });
            this.statusMessage = LABELS.saved;
            this.returnToList();
            await this.loadAddresses();
        } catch (error) {
            this.errorMessage = reduceError(error);
        } finally {
            this.busy = false;
        }
    }

    async handleRemove(event) {
        const addressId = event.detail.addressId;
        this.busy = true;
        this.errorMessage = undefined;
        try {
            await removeAddress({ addressId });
            this.statusMessage = LABELS.removed;
            await this.loadAddresses();
            this.focusTitle();
        } catch (error) {
            // EC-03: the platform may refuse to delete an address in use; surface its message inline.
            this.errorMessage = reduceError(error);
            const card = this.template.querySelector(`c-amazon-address-card[data-id="${addressId}"]`);
            if (card) {
                card.resetConfirmation();
            }
        } finally {
            this.busy = false;
        }
    }

    returnToList() {
        this.view = "list";
        this.editingAddress = undefined;
        this.focusTitle();
    }

    focusTitle() {
        Promise.resolve().then(() => {
            const title = this.template.querySelector(".page-title");
            if (title) {
                title.focus();
            }
        });
    }
}

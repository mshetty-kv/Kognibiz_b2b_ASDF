import { LightningElement, api } from "lwc";
import LABELS from "c/amazonAddressLabels";

const FIELD_SELECTOR = "lightning-input, lightning-combobox, lightning-radio-group";
const REQUIRED_TEXT = ["name", "street1", "city", "postalCode"];

/**
 * Presentational Add/Edit address form (B2B-ADDR-001, FR-03 / FR-07).
 * Holds only a local draft and raises `save` (payload) or `cancel`; the container owns
 * persistence. Validation uses the base components' constraint API so errors render inline
 * beside each field (AC-07).
 */
export default class AmazonAddressForm extends LightningElement {
    @api countries = [];
    @api saving = false;
    @api defaultCountryCode;
    /** Existing address to edit; empty for a new one. */
    @api address;
    /** Type pre-selected for a new address - the section whose add card was clicked (AC-05). */
    @api addressType = "Shipping";

    labels = LABELS;
    draft = {};
    showSummaryError = false;
    isEdit = false;
    focused = false;

    connectedCallback() {
        const source = this.address;
        this.isEdit = Boolean(source && source.addressId);
        if (this.isEdit) {
            const lines = (source.street || "").split(/\r?\n/);
            this.draft = {
                addressId: source.addressId,
                addressType: source.addressType,
                isDefault: source.isDefault === true,
                name: source.name || "",
                phoneNumber: source.phoneNumber || "",
                street1: lines[0] || "",
                street2: lines.slice(1).join(" "),
                city: source.city || "",
                regionCode: source.regionCode || "",
                postalCode: source.postalCode || "",
                countryCode: source.countryCode || this.initialCountry
            };
        } else {
            this.draft = {
                addressType: this.addressType === "Billing" ? "Billing" : "Shipping",
                isDefault: false,
                name: "",
                phoneNumber: "",
                street1: "",
                street2: "",
                city: "",
                regionCode: "",
                postalCode: "",
                countryCode: this.initialCountry
            };
        }
    }

    renderedCallback() {
        if (!this.focused) {
            this.focused = true;
            const heading = this.template.querySelector(".form-title");
            if (heading) {
                heading.focus();
            }
        }
    }

    get initialCountry() {
        const list = this.countries || [];
        const preferred = list.find((country) => country.value === this.defaultCountryCode);
        if (preferred) {
            return preferred.value;
        }
        return list.length ? list[0].value : "";
    }

    get title() {
        return this.isEdit ? LABELS.formEditTitle : LABELS.formAddTitle;
    }

    get submitLabel() {
        return this.isEdit ? LABELS.submitEdit : LABELS.addAddress;
    }

    get countryOptions() {
        return (this.countries || []).map((country) => ({ label: country.label, value: country.value }));
    }

    get stateOptions() {
        const country = (this.countries || []).find((item) => item.value === this.draft.countryCode);
        return country && country.states ? country.states : [];
    }

    get hasStates() {
        return this.stateOptions.length > 0;
    }

    get typeOptions() {
        return [
            { label: LABELS.billing, value: "Billing" },
            { label: LABELS.shipping, value: "Shipping" }
        ];
    }

    handleFieldChange(event) {
        const name = event.target.name;
        this.draft = { ...this.draft, [name]: event.detail.value };
    }

    handleCountryChange(event) {
        this.draft = { ...this.draft, countryCode: event.detail.value, regionCode: "" };
    }

    handleDefaultChange(event) {
        this.draft = { ...this.draft, isDefault: event.target.checked };
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = [...this.template.querySelectorAll(FIELD_SELECTOR)];
        const valid = fields.reduce((ok, field) => field.reportValidity() && ok, true);
        const blankRequired = REQUIRED_TEXT.some((key) => !String(this.draft[key] || "").trim());
        if (!valid || blankRequired) {
            this.showSummaryError = true;
            const firstInvalid = fields.find((field) => !field.checkValidity());
            if (firstInvalid) {
                firstInvalid.focus();
            }
            return;
        }
        this.showSummaryError = false;
        const street = [this.draft.street1, this.draft.street2]
            .map((line) => String(line || "").trim())
            .filter(Boolean)
            .join("\n");
        this.dispatchEvent(
            new CustomEvent("save", {
                detail: {
                    addressId: this.draft.addressId || null,
                    addressType: this.draft.addressType,
                    isDefault: this.draft.isDefault === true,
                    name: this.draft.name.trim(),
                    phoneNumber: String(this.draft.phoneNumber || "").trim(),
                    street,
                    city: this.draft.city.trim(),
                    regionCode: this.hasStates ? this.draft.regionCode : null,
                    postalCode: this.draft.postalCode.trim(),
                    countryCode: this.draft.countryCode
                }
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent("cancel"));
    }
}

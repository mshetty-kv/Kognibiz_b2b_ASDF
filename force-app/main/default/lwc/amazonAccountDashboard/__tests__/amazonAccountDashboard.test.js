import { createElement } from "lwc";
import AmazonAccountDashboard, { toPageReference } from "c/amazonAccountDashboard";
import { getObjectInfos } from "lightning/uiObjectInfoApi";

const mockNavigate = jest.fn();
jest.mock(
    "lightning/navigation",
    () => {
        const Navigate = Symbol("Navigate");
        const GenerateUrl = Symbol("GenerateUrl");
        const NavigationMixin = (Base) =>
            class extends Base {
                [Navigate](pageRef) {
                    mockNavigate(pageRef);
                }
                [GenerateUrl](pageRef) {
                    return Promise.resolve(`/testing/generated/${pageRef.attributes.name || pageRef.attributes.objectApiName}`);
                }
            };
        NavigationMixin.Navigate = Navigate;
        NavigationMixin.GenerateUrl = GenerateUrl;
        return { NavigationMixin };
    },
    { virtual: true }
);
jest.mock("@salesforce/community/basePath", () => ({ __esModule: true, default: "/testing" }), { virtual: true });

const CONFIG = {
    profilePage: "My_Profile",
    ordersPage: "object:OrderSummary",
    ordersAccessObject: "OrderSummary",
    quotesPage: "Quote_Summary_List",
    quotesAccessObject: "Quote",
    listsPage: "Wishlist",
    purchaseOrdersPage: "My_Purchase_Orders__c",
    purchaseOrdersAccessObject: "KV_PO_Management__c",
    addressesPage: "/addresses",
    addressesAccessObject: "ContactPointAddress",
    departmentPage: "my_department__c",
    departmentAccessObject: "KV_Department__c",
    contactPage: "contactus__c"
};

const ALL_KEYS = ["profile", "orders", "quotes", "lists", "purchaseOrders", "addresses", "department", "contact"];

function objectInfos(allowed, denied = []) {
    return {
        results: [
            ...allowed.map((apiName) => ({ statusCode: 200, result: { apiName } })),
            ...denied.map(() => ({ statusCode: 403, result: [{ errorCode: "INSUFFICIENT_ACCESS" }] }))
        ]
    };
}

function mount(overrides = {}) {
    const element = createElement("c-amazon-account-dashboard", { is: AmazonAccountDashboard });
    Object.assign(element, CONFIG, overrides);
    document.body.appendChild(element);
    return element;
}

function cardKeys(element) {
    return Array.from(element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card")).map((card) => card.cardKey);
}

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-amazon-account-dashboard", () => {
    let warnSpy;
    beforeEach(() => {
        warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
    });
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        warnSpy.mockRestore();
    });

    it("renders nothing for gated cards until the access check resolves", async () => {
        const element = mount();
        await flush();
        expect(cardKeys(element)).toEqual([]);
        expect(element.shadowRoot.querySelector("h1").textContent).toBe("c.AmzAcct_PageTitle");
    });

    it("requests object access only for configured gate objects, deduplicated and sorted", async () => {
        mount();
        await flush();
        expect(getObjectInfos.getLastConfig()).toEqual({
            objectApiNames: ["ContactPointAddress", "KV_Department__c", "KV_PO_Management__c", "OrderSummary", "Quote"]
        });
    });

    it("renders all eight cards in sidebar order with label-sourced title, subtitle and icon", async () => {
        const element = mount();
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "KV_Department__c", "KV_PO_Management__c", "OrderSummary", "Quote"]));
        await flush();
        expect(cardKeys(element)).toEqual(ALL_KEYS);
        const orders = element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card")[1];
        expect(orders.cardTitle).toBe("c.AmzAcct_OrdersTitle");
        expect(orders.subtitle).toBe("c.AmzAcct_OrdersSubtitle");
        expect(orders.iconName).toBe("utility:package");
    });

    it("omits cards whose gate object the user cannot read, leaving no gap (EC-02)", async () => {
        const element = mount();
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "OrderSummary"], ["KV_Department__c", "KV_PO_Management__c", "Quote"]));
        await flush();
        expect(cardKeys(element)).toEqual(["profile", "orders", "lists", "addresses", "contact"]);
        expect(element.shadowRoot.querySelectorAll("li.grid-item")).toHaveLength(5);
    });

    it("fails closed: a failed access check hides every gated card but keeps ungated ones", async () => {
        const element = mount();
        getObjectInfos.error();
        await flush();
        expect(cardKeys(element)).toEqual(["profile", "lists", "contact"]);
        expect(warnSpy).toHaveBeenCalled();
    });

    it("hides a card switched off in Experience Builder", async () => {
        const element = mount({ purchaseOrdersEnabled: false, quotesEnabled: false });
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "KV_Department__c", "OrderSummary"]));
        await flush();
        expect(cardKeys(element)).toEqual(["profile", "orders", "lists", "addresses", "department", "contact"]);
    });

    it("omits a card with no page target and warns", async () => {
        const element = mount({ contactPage: "  " });
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "KV_Department__c", "KV_PO_Management__c", "OrderSummary", "Quote"]));
        await flush();
        expect(cardKeys(element)).not.toContain("contact");
        expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('"contact"'));
    });

    it("renders immediately when no card is gated", async () => {
        const element = mount({
            ordersAccessObject: "",
            quotesAccessObject: "",
            purchaseOrdersAccessObject: "",
            addressesAccessObject: "",
            departmentAccessObject: ""
        });
        await flush();
        expect(cardKeys(element)).toEqual(ALL_KEYS);
    });

    it("resolves hrefs: base-path prefix for /paths, generated URLs for named pages", async () => {
        const element = mount();
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "KV_Department__c", "KV_PO_Management__c", "OrderSummary", "Quote"]));
        await flush();
        const cards = element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card");
        expect(cards[0].href).toBe("/testing/generated/My_Profile");
        expect(cards[5].href).toBe("/testing/addresses");
    });

    it("navigates with the configured page reference when a card is selected", async () => {
        const element = mount();
        getObjectInfos.emit(objectInfos(["ContactPointAddress", "KV_Department__c", "KV_PO_Management__c", "OrderSummary", "Quote"]));
        await flush();
        const ordersCard = element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card")[1];
        ordersCard.dispatchEvent(new CustomEvent("cardselect", { detail: { key: "orders" } }));
        expect(mockNavigate).toHaveBeenCalledWith({
            type: "standard__objectPage",
            attributes: { objectApiName: "OrderSummary", actionName: "list" },
            state: { filterName: "Default" }
        });
    });
});

describe("toPageReference", () => {
    it("maps the three supported target formats and rejects blanks", () => {
        expect(toPageReference("/contact-us")).toEqual({ type: "standard__webPage", attributes: { url: "/testing/contact-us" } });
        expect(toPageReference("My_Profile")).toEqual({ type: "comm__namedPage", attributes: { name: "My_Profile" } });
        expect(toPageReference("object:OrderSummary").type).toBe("standard__objectPage");
        expect(toPageReference("")).toBeNull();
        expect(toPageReference(undefined)).toBeNull();
    });
});

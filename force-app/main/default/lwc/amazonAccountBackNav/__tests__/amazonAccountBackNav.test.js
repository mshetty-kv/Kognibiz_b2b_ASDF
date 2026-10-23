import { createElement } from "lwc";
import AmazonAccountBackNav from "c/amazonAccountBackNav";

const mockNavigate = jest.fn();
const mockGenerateUrl = jest.fn();
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
                    return mockGenerateUrl(pageRef);
                }
            };
        NavigationMixin.Navigate = Navigate;
        NavigationMixin.GenerateUrl = GenerateUrl;
        return { NavigationMixin };
    },
    { virtual: true }
);
jest.mock("@salesforce/community/basePath", () => ({ __esModule: true, default: "/testing" }), { virtual: true });

const flush = () => Promise.resolve().then(() => Promise.resolve());

function mount(props) {
    const element = createElement("c-amazon-account-back-nav", { is: AmazonAccountBackNav });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe("c-amazon-account-back-nav", () => {
    let warnSpy;
    beforeEach(() => {
        warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
        mockGenerateUrl.mockImplementation(() => Promise.resolve("/testing/your-account"));
    });
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        warnSpy.mockRestore();
    });

    it("renders the breadcrumb root link, the label-sourced current title and the back pill", async () => {
        const element = mount({ targetPage: "Your_Account__c", currentPage: "orders" });
        await flush();
        expect(mockGenerateUrl).toHaveBeenCalledWith({ type: "comm__namedPage", attributes: { name: "Your_Account__c" } });
        const root = element.shadowRoot.querySelector("a.crumb-link");
        expect(root.getAttribute("href")).toBe("/testing/your-account");
        expect(root.textContent).toBe("c.AmzAcct_PageTitle");
        const current = element.shadowRoot.querySelector('[aria-current="page"]');
        expect(current.textContent).toBe("c.AmzAcct_OrdersTitle");
        const back = element.shadowRoot.querySelector("a.back-button");
        expect(back.getAttribute("href")).toBe("/testing/your-account");
        expect(back.textContent).toContain("c.AmzAcct_BackToAccount");
        expect(element.shadowRoot.querySelector("nav").getAttribute("aria-label")).toBe("c.AmzAcct_BreadcrumbAssistive");
    });

    it("supports the order detail sub-page title", async () => {
        const element = mount({ targetPage: "Your_Account__c", currentPage: "orderDetail" });
        await flush();
        expect(element.shadowRoot.querySelector('[aria-current="page"]').textContent).toBe("c.AmzAcct_OrderDetailTitle");
    });

    it("shows only the root crumb and warns when the page key is unknown", async () => {
        const element = mount({ targetPage: "Your_Account__c", currentPage: "nope" });
        await flush();
        expect(element.shadowRoot.querySelector('[aria-current="page"]')).toBeNull();
        expect(element.shadowRoot.querySelector("a.back-button")).not.toBeNull();
        expect(warnSpy).toHaveBeenCalledTimes(1);
    });

    it("uses a base-path href for /path targets without generating a URL", async () => {
        const element = mount({ targetPage: "/your-account", currentPage: "profile" });
        await flush();
        expect(mockGenerateUrl).not.toHaveBeenCalled();
        expect(element.shadowRoot.querySelector("a.back-button").getAttribute("href")).toBe("/testing/your-account");
    });

    it("renders nothing and warns when no target page is configured", async () => {
        const element = mount({ targetPage: " ", currentPage: "profile" });
        await flush();
        expect(element.shadowRoot.querySelector(".back-nav")).toBeNull();
        expect(warnSpy).toHaveBeenCalled();
    });

    it("renders nothing when the target cannot be resolved", async () => {
        mockGenerateUrl.mockImplementation(() => Promise.reject(new Error("no route")));
        const element = mount({ targetPage: "Missing_Page__c", currentPage: "profile" });
        await flush();
        expect(element.shadowRoot.querySelector(".back-nav")).toBeNull();
        expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining("Missing_Page__c"));
    });

    it("navigates through NavigationMixin on a plain click of the back pill and the crumb", async () => {
        const element = mount({ targetPage: "Your_Account__c", currentPage: "quotes" });
        await flush();
        for (const selector of ["a.back-button", "a.crumb-link"]) {
            const click = new MouseEvent("click", { bubbles: true, cancelable: true });
            element.shadowRoot.querySelector(selector).dispatchEvent(click);
            expect(click.defaultPrevented).toBe(true);
        }
        expect(mockNavigate).toHaveBeenCalledTimes(2);
        expect(mockNavigate).toHaveBeenCalledWith({ type: "comm__namedPage", attributes: { name: "Your_Account__c" } });
    });

    it("leaves ctrl-click to the browser so the dashboard can open in a new tab", async () => {
        const element = mount({ targetPage: "Your_Account__c", currentPage: "quotes" });
        await flush();
        const click = new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true });
        element.shadowRoot.querySelector("a.back-button").dispatchEvent(click);
        expect(click.defaultPrevented).toBe(false);
        expect(mockNavigate).not.toHaveBeenCalled();
    });
});

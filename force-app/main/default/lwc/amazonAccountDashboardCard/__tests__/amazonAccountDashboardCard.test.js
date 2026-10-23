import { createElement } from "lwc";
import AmazonAccountDashboardCard from "c/amazonAccountDashboardCard";

function mount(props) {
    const element = createElement("c-amazon-account-dashboard-card", { is: AmazonAccountDashboardCard });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe("c-amazon-account-dashboard-card", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it("renders a focusable link with icon, title and subtitle", () => {
        const element = mount({
            cardKey: "orders",
            cardTitle: "Your Orders",
            subtitle: "Track, return, or buy things again",
            iconName: "utility:package",
            href: "/testing/OrderSummary/OrderSummary/Default"
        });
        const link = element.shadowRoot.querySelector("a.account-card");
        expect(link.getAttribute("href")).toBe("/testing/OrderSummary/OrderSummary/Default");
        expect(element.shadowRoot.querySelector(".card-title").textContent).toBe("Your Orders");
        expect(element.shadowRoot.querySelector(".card-subtitle").textContent).toBe("Track, return, or buy things again");
        expect(element.shadowRoot.querySelector("lightning-icon").iconName).toBe("utility:package");
        expect(element.shadowRoot.querySelector(".card-icon").getAttribute("aria-hidden")).toBe("true");
    });

    it("omits the subtitle element when the subtitle is empty", () => {
        const element = mount({ cardKey: "quotes", cardTitle: "Your Quotes", subtitle: "", iconName: "utility:file", href: "/q" });
        expect(element.shadowRoot.querySelector(".card-subtitle")).toBeNull();
    });

    it("raises cardselect and suppresses the default navigation on a plain click (Enter on a link fires click)", () => {
        const element = mount({ cardKey: "addresses", cardTitle: "Your Addresses", iconName: "utility:location", href: "/a" });
        const handler = jest.fn();
        element.addEventListener("cardselect", handler);
        const click = new MouseEvent("click", { bubbles: true, cancelable: true });
        element.shadowRoot.querySelector("a").dispatchEvent(click);
        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toEqual({ key: "addresses" });
        expect(click.defaultPrevented).toBe(true);
    });

    it("leaves modified clicks to the browser (open in new tab)", () => {
        const element = mount({ cardKey: "addresses", cardTitle: "Your Addresses", iconName: "utility:location", href: "/a" });
        const handler = jest.fn();
        element.addEventListener("cardselect", handler);
        const click = new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true });
        element.shadowRoot.querySelector("a").dispatchEvent(click);
        expect(handler).not.toHaveBeenCalled();
        expect(click.defaultPrevented).toBe(false);
    });
});

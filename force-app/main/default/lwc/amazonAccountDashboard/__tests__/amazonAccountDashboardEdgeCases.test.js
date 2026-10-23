import { createElement } from "lwc";
import AmazonAccountDashboard from "c/amazonAccountDashboard";

// EC-01: a deleted/blank label must not break the grid.
jest.mock("@salesforce/label/c.AmzAcct_QuotesSubtitle", () => ({ __esModule: true, default: " " }), { virtual: true });
jest.mock("@salesforce/label/c.AmzAcct_ListsTitle", () => ({ __esModule: true, default: "" }), { virtual: true });
jest.mock("@salesforce/community/basePath", () => ({ __esModule: true, default: "/testing" }), { virtual: true });

const flush = () => Promise.resolve().then(() => Promise.resolve());

describe("c-amazon-account-dashboard edge cases", () => {
    let warnSpy;
    beforeEach(() => {
        warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
    });
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        warnSpy.mockRestore();
    });

    it("renders a card without its subtitle and uses the fallback title when labels are blank", async () => {
        const element = createElement("c-amazon-account-dashboard", { is: AmazonAccountDashboard });
        Object.assign(element, { quotesPage: "Quote_Summary_List", listsPage: "Wishlist" });
        document.body.appendChild(element);
        await flush();

        const cards = element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card");
        expect(cards).toHaveLength(2);
        expect(cards[0].cardTitle).toBe("c.AmzAcct_QuotesTitle");
        expect(cards[0].subtitle).toBe("");
        expect(cards[1].cardTitle).toBe("c.AmzAcct_FallbackTitle");
        expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('subtitle label for "quotes"'));
        expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('title label for "lists"'));
    });
});

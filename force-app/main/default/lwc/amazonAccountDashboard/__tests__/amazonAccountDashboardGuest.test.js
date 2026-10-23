import { createElement } from "lwc";
import AmazonAccountDashboard from "c/amazonAccountDashboard";

jest.mock("@salesforce/user/isGuest", () => ({ __esModule: true, default: true }), { virtual: true });
jest.mock("@salesforce/community/basePath", () => ({ __esModule: true, default: "/testing" }), { virtual: true });

describe("c-amazon-account-dashboard for a guest", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it("renders no account cards and no heading", async () => {
        const element = createElement("c-amazon-account-dashboard", { is: AmazonAccountDashboard });
        Object.assign(element, { profilePage: "My_Profile", contactPage: "contactus__c" });
        document.body.appendChild(element);
        await Promise.resolve();
        expect(element.shadowRoot.querySelector("section")).toBeNull();
        expect(element.shadowRoot.querySelectorAll("c-amazon-account-dashboard-card")).toHaveLength(0);
    });
});

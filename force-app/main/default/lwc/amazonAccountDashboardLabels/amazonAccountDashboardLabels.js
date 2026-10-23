// Shared Custom Label bundle and section catalogue for the FS-001 Account Management Dashboard.
// Titles and subtitles come only from Custom Labels (FR-03). Page targets are NOT defined here:
// they arrive from Experience Builder design-time properties so no URL is hardcoded (NFR-03).
import AmzAcct_PageTitle from "@salesforce/label/c.AmzAcct_PageTitle";
import AmzAcct_GridAssistive from "@salesforce/label/c.AmzAcct_GridAssistive";
import AmzAcct_FallbackTitle from "@salesforce/label/c.AmzAcct_FallbackTitle";
import AmzAcct_ProfileTitle from "@salesforce/label/c.AmzAcct_ProfileTitle";
import AmzAcct_ProfileSubtitle from "@salesforce/label/c.AmzAcct_ProfileSubtitle";
import AmzAcct_OrdersTitle from "@salesforce/label/c.AmzAcct_OrdersTitle";
import AmzAcct_OrdersSubtitle from "@salesforce/label/c.AmzAcct_OrdersSubtitle";
import AmzAcct_QuotesTitle from "@salesforce/label/c.AmzAcct_QuotesTitle";
import AmzAcct_QuotesSubtitle from "@salesforce/label/c.AmzAcct_QuotesSubtitle";
import AmzAcct_ListsTitle from "@salesforce/label/c.AmzAcct_ListsTitle";
import AmzAcct_ListsSubtitle from "@salesforce/label/c.AmzAcct_ListsSubtitle";
import AmzAcct_PurchaseOrdersTitle from "@salesforce/label/c.AmzAcct_PurchaseOrdersTitle";
import AmzAcct_PurchaseOrdersSubtitle from "@salesforce/label/c.AmzAcct_PurchaseOrdersSubtitle";
import AmzAcct_AddressesTitle from "@salesforce/label/c.AmzAcct_AddressesTitle";
import AmzAcct_AddressesSubtitle from "@salesforce/label/c.AmzAcct_AddressesSubtitle";
import AmzAcct_DepartmentTitle from "@salesforce/label/c.AmzAcct_DepartmentTitle";
import AmzAcct_DepartmentSubtitle from "@salesforce/label/c.AmzAcct_DepartmentSubtitle";
import AmzAcct_ContactTitle from "@salesforce/label/c.AmzAcct_ContactTitle";
import AmzAcct_ContactSubtitle from "@salesforce/label/c.AmzAcct_ContactSubtitle";
import AmzAcct_BackToAccount from "@salesforce/label/c.AmzAcct_BackToAccount";
import AmzAcct_BreadcrumbAssistive from "@salesforce/label/c.AmzAcct_BreadcrumbAssistive";
import AmzAcct_OrderDetailTitle from "@salesforce/label/c.AmzAcct_OrderDetailTitle";

export const LABELS = Object.freeze({
    pageTitle: AmzAcct_PageTitle,
    gridAssistive: AmzAcct_GridAssistive,
    fallbackTitle: AmzAcct_FallbackTitle,
    backToAccount: AmzAcct_BackToAccount,
    breadcrumbAssistive: AmzAcct_BreadcrumbAssistive
});

// Order matches the legacy My Account sidebar (SM-01 navigation parity).
// `prop` is the prefix of the card's design-time properties: <prop>Enabled, <prop>Page, <prop>AccessObject.
export const SECTIONS = Object.freeze([
    { key: "profile", prop: "profile", icon: "utility:user", title: AmzAcct_ProfileTitle, subtitle: AmzAcct_ProfileSubtitle },
    { key: "orders", prop: "orders", icon: "utility:package", title: AmzAcct_OrdersTitle, subtitle: AmzAcct_OrdersSubtitle },
    { key: "quotes", prop: "quotes", icon: "utility:file", title: AmzAcct_QuotesTitle, subtitle: AmzAcct_QuotesSubtitle },
    { key: "lists", prop: "lists", icon: "utility:list", title: AmzAcct_ListsTitle, subtitle: AmzAcct_ListsSubtitle },
    {
        key: "purchaseOrders",
        prop: "purchaseOrders",
        icon: "utility:money",
        title: AmzAcct_PurchaseOrdersTitle,
        subtitle: AmzAcct_PurchaseOrdersSubtitle
    },
    {
        key: "addresses",
        prop: "addresses",
        icon: "utility:location",
        title: AmzAcct_AddressesTitle,
        subtitle: AmzAcct_AddressesSubtitle
    },
    {
        key: "department",
        prop: "department",
        icon: "utility:groups",
        title: AmzAcct_DepartmentTitle,
        subtitle: AmzAcct_DepartmentSubtitle
    },
    { key: "contact", prop: "contact", icon: "utility:chat", title: AmzAcct_ContactTitle, subtitle: AmzAcct_ContactSubtitle }
]);

// Page titles available to the back-navigation breadcrumb: every dashboard section plus sub-pages
// reached from a section (e.g. order detail). Keys are the values of amazonAccountBackNav.currentPage.
export const PAGE_TITLES = Object.freeze({
    ...Object.fromEntries(SECTIONS.map((section) => [section.key, section.title])),
    orderDetail: AmzAcct_OrderDetailTitle
});

export default LABELS;

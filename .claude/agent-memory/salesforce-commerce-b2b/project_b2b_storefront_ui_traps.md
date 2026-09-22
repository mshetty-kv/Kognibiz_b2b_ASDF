---
name: project-b2b-storefront-ui-traps
description: Storefront/LWR-layer B2B Commerce behaviours proved by experiment - buyers cannot SOQL the catalogue, searchProducts blocks cacheable Apex, CMS image upload recipe, base-path rules
metadata:
  type: project
---

Behaviours proved by actually loading the Office Depot storefront as a buyer on 2026-09-22.
Complements [[project-b2b-commerce-platform-traps]], which covers the data/setup chain; this one
covers the UI and buyer-session layer.

**An Experience Cloud buyer can read NO catalogue rows through SOQL - `without sharing` does not
help.** `SELECT COUNT() FROM ProductCategory` with no filters returns **0** in a buyer session and
15 as an admin. `Product2.ExternalSharingModel` and `ProductCatalog.ExternalSharingModel` are
**Private**; `ProductCategory`/`ProductCategoryProduct` are ControlledByParent off that catalog.
Object permissions are irrelevant and `without sharing` has nothing to widen. B2B Commerce routes
buyer catalogue visibility through entitlement, reachable only via the Commerce APIs.
- **Why this matters:** the failure is SILENT. The component renders its friendly empty state, the
  deploy is green, and the query works perfectly when you test it as yourself. Three cycles were
  lost before it was instrumented.
- **How to apply:** never build a custom commerce component on SOQL over catalogue objects. Use
  `ConnectApi.CommerceSearch.searchProducts(webStoreId, effectiveAccountId, input)` with
  `includePrices = true` - one call returns entitled products, list price, negotiated unit price
  and media. Always add a VISIBLE error path so a thrown exception is distinguishable from an
  empty result, and always verify in a buyer session, never as admin.

**`ConnectApi.CommerceSearch.searchProducts` cannot run in `@AuraEnabled(cacheable=true)`.** Its
limit report shows `Number of DML statements: 1`, and a cacheable method is read-only. Use plain
`@AuraEnabled` + an imperative call from `connectedCallback`; `@wire` is not available.
It also *requires* `searchTerm` and/or `categoryId` - and the category tree comes back in
`results.categories.children`, which is how to discover category ids without SOQL. The wrapper
types for `.fields` and `.categories` have no referenceable Apex type name; read them with
`JSON.deserializeUntyped(JSON.serialize(x))` instead of guessing a class name.

**CMS image upload IS possible over the API - only the encoding is undocumented.** ManagedContent
has zero createable fields, but `POST /services/data/vXX.0/connect/cms/contents` works as
**hand-built multipart** (Node/undici `FormData` FAILS because it adds a `filename` to the JSON
part):
- part `json`, `Content-Type: application/json`, **no filename**, body
  `{contentSpaceOrFolderId, contentType:"sfdc_cms__image", title, urlName,
   contentBody:{"sfdc_cms:media":{source:{type:"file", fileName, mimeType, size}}}}`
- part `contentData` with a filename - the binary. The part name must be exactly `contentData`.
- do NOT send `source.ref`; Salesforce assigns it. Any ref gives "This image reference isn't available."
- publish with `POST /connect/cms/contents/publish` body `{"contentIds":[...]}` - **ManagedContent
  record Ids (20Y...), not content keys**.
- then insert `ProductMedia` (ordinary DML) against the standard groups `productDetailImage`,
  `productListImage`, `tileImage`.
- finally rebuild the search index: `POST /services/data/vXX.0/commerce/management/webstores/{id}/search/indexes`
  with `{}`. NOT under `/connect/`. ~3.5 min for 20 products. Product media is cached in the index.
- **Gotcha that costs an hour:** a WebStore reads ONE specific CMS space and nothing exposes which.
  If an org has two same-named spaces, the right one is the one whose `createdDate` matches the
  WebStore's (the site's space is a different, later one). Wrong space = everything succeeds and
  the storefront still serves `/img/b2b/default-product-image.svg`.

**Base path: prefix navigation, never platform asset URLs.** A bare `href="/cart"` resolves against
the ORIGIN, so on a my.site.com domain hosting several communities it lands in someone else's site.
Import `@salesforce/community/basePath` and prefix every internal link. But CMS media URLs from
ConnectApi (`/cms/delivery/media/...`) are served by a redirect at the origin - prefixing those
with basePath returns a hard 404.

**Verify storefronts with a browser, not a deploy.** A previous pass concluded "attributes are the
culprit" and burned a session bisecting component `attributes` in `content.json`. Loading the site
in headless Chrome as the buyer showed four of the components had been rendering correctly all
along. `puppeteer-core` + the installed Chrome at
`C:/Program Files/Google/Chrome/Application/chrome.exe` works on this workstation; walk shadow
roots recursively to census custom elements and audit every `<a href>`.

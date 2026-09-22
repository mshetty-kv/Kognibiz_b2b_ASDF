# Agent Capability Gaps — Office Depot B2B Commerce (LWR) home page

Target org: `vscodeOrg` (`cthakur1@kognivera.com`, `00DgL00000L7NwjUAF`)
Store: WebStore `0ZEgL0000011d3ZWAQ` · Network `0DBgL000002Ws7NWAS` · site `Office_Depot1` → `/officedepot`
Date: 2026-09-22

This file records, honestly, every thing that could not be done straightforwardly, plus the
things that *looked* impossible and turned out not to be. It is written for the ASDF capability
assessment, so a precisely-scoped limitation is worth more than a confident claim.

Verification method used throughout: **headless Chrome (puppeteer-core driving the installed
Chrome), logged in as the real buyer `dana.whitfield@officedepot.invalid.00dgl000`**, walking
every shadow root of the rendered page and asserting on custom element names, their rendered
text, and every `<a href>`. A green `sf project deploy start` was never treated as evidence.

---

## Legend

| Class | Meaning |
| --- | --- |
| **AGENT** | A limitation of the agent / the way it was driven. Avoidable with better technique. |
| **PLATFORM** | A real Salesforce behaviour. No amount of agent skill removes it. |
| **SKILL-GAP** | An installed skill should have covered it and did not, or none exists. |

---

## GAP-01 — Experience Cloud buyers cannot read catalogue objects with SOQL at all

**Requirement.** Home-page rails must show "Bestsellers in \<Category\>" built from *our* catalog,
with the buyer's contract price next to the list price.

**Expected.** A `with sharing` Apex controller querying `ProductCategoryProduct`, `Product2` and
`PricebookEntry` `WITH USER_MODE`, granted object read via a permission set, returns the catalog
for the buyer.

**Actual.** The controller compiled, deployed green, returned 15 categories / 20 products when run
as an admin, and returned **zero rows** in a real buyer session. The component rendered its
friendly empty state — *"No products are available in your catalog yet."* — which is
indistinguishable from a correctly-empty catalog. No error, no debug log, nothing in the deploy.

Instrumenting the controller to return a diagnostic string and reading it off the rendered page as
Dana produced the decisive evidence:

```
DIAG store=0ZEgL0000011d3ZWAQ acct=001gL00001tzgWpQAI allCats=0 catalogCats=0 navCats=0
```

`SELECT COUNT() FROM ProductCategory` — **no filters at all** — returns `0` for the buyer, and it
returns `0` even from a class explicitly declared `without sharing`.

**Root cause.** From `EntityDefinition` in this org:

| Object | InternalSharingModel | ExternalSharingModel |
| --- | --- | --- |
| `Product2` | ReadWrite | **Private** |
| `ProductCatalog` | ReadWrite | **Private** |
| `ProductCategory` | ControlledByParent | ControlledByParent |
| `ProductCategoryProduct` | ControlledByParent | ControlledByParent |

An Experience Cloud (external) user is shared **no** catalogue rows whatsoever. Object permissions
are irrelevant — Dana has `PermissionsRead = true` on all four objects through three different
permission sets — and `without sharing` cannot help either, because there are no shares to widen.
B2B Commerce deliberately mediates buyer catalogue visibility through *commerce entitlement*,
which only the Commerce APIs consult.

**Class.** PLATFORM (the behaviour) + AGENT (three deploy cycles were spent before the failure was
instrumented rather than reasoned about).

**Workaround — implemented.** `OfficeDepotStorefrontController` now reads the catalogue solely via
`ConnectApi.CommerceSearch.searchProducts(webStoreId, effectiveAccountId, ProductSearchInput)`
with `includePrices = true`. One call returns the entitled products, the list price, the buyer's
negotiated unit price and the media reference. Zero SOQL touches a catalogue object.

**Design lesson for the assessment.** Any custom LWC over B2B Commerce data is pushed toward
ConnectApi / the commerce wire adapters, not Apex SOQL. The failure mode is **silent** and
**only reproducible in a buyer session**, so an agent that verifies by deploying, or by querying
as an admin, will report success and be wrong. This is the single most valuable finding in the
build.

---

## GAP-02 — `@AuraEnabled(cacheable=true)` is incompatible with the commerce search API

**Requirement.** Rails data loaded from Apex into an LWC.

**Expected.** `@AuraEnabled(cacheable=true)` + `@wire` — the normal, recommended pattern, and the
one the Constitution's Performance section asks for ("Use `@wire` over imperative Apex where
caching is beneficial").

**Actual.** The method returned an empty list with no error. The anonymous-Apex limit report for a
bare `searchProducts` call shows the reason:

```
Number of DML statements: 1 out of 150
```

`ConnectApi.CommerceSearch.searchProducts` performs an **internal DML**. A `cacheable=true` method
runs in a read-only context where DML is forbidden, so the call throws, and (in the original code)
was swallowed per-category.

**Class.** PLATFORM. Undocumented in the places you would look, and invisible unless you read the
limit report.

**Workaround — implemented.** `getBestsellerRails` / `getCategoryDeals` are plain `@AuraEnabled`
and the components call them imperatively from `connectedCallback`. Consequence: no Lightning
Data Service client cache for these calls, so the home page pays one round trip per load.

---

## GAP-03 — Silent empty states hide real failures

**Requirement.** N/A — this is a process finding.

**Actual.** The first two root causes both surfaced as the component's *friendly empty state*. An
empty catalog and a thrown exception looked identical on screen.

**Class.** AGENT.

**Workaround — implemented.** The controller now throws `AuraHandledException` with a specific
message when every category search fails or when the search returns no categories, and the LWC
renders the message in a visible `role="alert"` block. A `loaded` flag distinguishes "not yet
loaded" from "loaded and genuinely empty". This turned a two-hour guessing game into a one-cycle
diagnosis and should be the default posture for any commerce component.

---

## GAP-04 — Bare `href="/path"` escapes the Experience Cloud site

**Requirement.** Every link stays inside the Office Depot store.

**Expected.** `<a href="/my-account">` resolves inside the community.

**Actual.** It resolved against the **origin**, not the site. On a `my.site.com` domain hosting
eight communities, `/my-account` was answered by a different community entirely:

```
https://orgfarm-652bf1602b-dev-ed.develop.my.site.com/ESWOMSAgent1785143053407vforcesite/my-account
```

— i.e. a stranger's `ESW_OMS_Agent_1785143053407` site.

**Root cause.** LWR sites are served under a path prefix (`/officedepot`). A root-relative href
discards it.

**Class.** PLATFORM (by design) + AGENT (should have been the default from the first line of
markup).

**Workaround — implemented.** Every one of the seven components imports
`@salesforce/community/basePath` and routes every URL through a local `siteUrl()` helper;
hardcoded template hrefs became getters. **Verified**: all **88** anchors on the rendered home
page resolve under `/officedepot/`, enumerated across all shadow roots in Dana's session.

---

## GAP-05 — `ManagedContent` cannot be created with DML, and the documented CMS REST path is gone

**Requirement.** Real images on the products, so the rails and category tiles are not empty boxes.

**The chain.** `ManagedContent` (the image in CMS) + `ElectronicMediaGroup` (which slot) →
`ProductMedia` → `Product2`.

**What is *not* the problem** (an earlier assessment said "images cannot be created via API",
which is only half true and sent the reader down the wrong path):

* `ProductMedia` **is** fully DML-createable. `ProductId`, `ElectronicMediaId`,
  `ElectronicMediaGroupId`, `SortOrder`. 60 rows were inserted with ordinary Apex.
* `ElectronicMediaGroup` is not createable, but five standard groups already exist org-wide:
  `attachment`, `bannerImage`, `productDetailImage`, `productListImage`, `tileImage`.

**What *is* the problem.** `ManagedContent` describes with **zero createable fields**
(`isCreateable() == false`, and the createable-field list is literally empty). And:

| Route tried | Result |
| --- | --- |
| DML `insert new ManagedContent(...)` | Not createable |
| `POST /connect/cms/spaces/{spaceId}/contents` | `NOT_FOUND` — this path no longer exists |
| `GET /connect/cms` | `NOT_FOUND` — CMS is not listed in the `/connect` resource index |
| `DigitalExperienceBundle:content/<space>` metadata retrieve | Retrieves **only** `languageSettings`; CMS items are *not* in the bundle. Route disproven by inspection. |
| `POST /connect/cms/contents` with a JSON-only body | `INVALID_FIELD: This image reference isn't available.` for `ref` = ContentVersion id, ContentDocument id, or inline base64 |

**Resolution — SOLVED.** The current authoring endpoint is `POST /connect/cms/contents` and it
requires **`multipart/form-data`, hand-built**. `FormData` from Node/undici does *not* work,
because it emits a `filename` on the JSON part and Salesforce then reports
`POST_BODY_PARSE_ERROR: A request body is required.` The working request is:

```
POST /services/data/v67.0/connect/cms/contents
Content-Type: multipart/form-data; boundary=----ODB...

------ODB...
Content-Disposition: form-data; name="json"        <-- NO filename attribute
Content-Type: application/json

{"contentSpaceOrFolderId":"0ZugL000008NCdNSAW",
 "contentType":"sfdc_cms__image",
 "title":"...","urlName":"od-od-pap-0001",
 "contentBody":{"sfdc_cms:media":{"source":{
     "type":"file","fileName":"OD-PAP-0001.png","mimeType":"image/png","size":13063}}}}
------ODB...
Content-Disposition: form-data; name="contentData"; filename="OD-PAP-0001.png"
Content-Type: image/png

<binary>
------ODB...--
```

Two non-obvious details, both discovered by reading the error messages rather than the docs:

1. The binary part **must** be named `contentData` (`Binary data expected with name "contentData"`).
2. `source` must **not** carry a `ref` — Salesforce assigns the `ref` (a `0sN…` CMS media id)
   itself. Supplying any `ref` fails with *"This image reference isn't available."*

Publishing is `POST /connect/cms/contents/publish` with `{"contentIds":[...]}`, taking
**`ManagedContent` record Ids (`20Y…`), not content keys**. Every other field name
(`contentKeys`, `contents`, `idsOrKeys`, `contentKeyOrIds`) is rejected by the JSON parser.

**Class.** PLATFORM (undocumented/changed endpoint) + SKILL-GAP (see GAP-08).

**Status. SOLVED and verified in the browser.** 20 CMS images created, published, and 60
`ProductMedia` rows linked (`productDetailImage` + `productListImage` + `tileImage` per product).
`ConnectApi.CommerceSearch.searchProducts` now returns a real
`/cms/delivery/media/{contentKey}?version=1.1&channelId=…&oid=…` URL for every product, and those
images render on the home page with `naturalWidth = 600` in Dana's session.

**Correcting the record.** An earlier note in this project claimed *"images cannot be created via
API"*. That is **wrong and misleading**. Every link in the chain is API-createable:

* `ProductMedia` — ordinary DML. ✅
* `ManagedContent` — **not** DML-createable, but fully creatable through
  `POST /connect/cms/contents` as hand-built multipart. ✅
* the image **binary** — uploaded in the same multipart request as the `contentData` part. ✅
* publication — `POST /connect/cms/contents/publish`. ✅

Nothing in the product-imagery chain requires the Setup UI. The only thing that blocked it was
knowing the exact multipart encoding, which the API's own error messages reveal if you read them
one at a time.

---

## GAP-06 — The commerce search index caches product media; new images need a re-index

**Requirement.** Products on the home page show their real images.

**Expected.** Once `ProductMedia` exists, `ConnectApi.CommerceSearch.searchProducts` returns
`defaultImage.url` pointing at the CMS media.

**Actual.** Immediately after linking the media, the search returned the new `ProductMedia` **id**
but still the placeholder URL:

```json
{"id":"2pmgL00000IL9shQAD","mediaType":"Image","url":"/img/b2b/default-product-image.svg"}
```

**Root cause.** Product media is denormalised into the commerce search index. Creating
`ProductMedia` does not invalidate it.

**Class.** PLATFORM.

**Workaround — implemented.** A full index rebuild can be triggered over REST. The path is *not*
under `/connect`, which is why an earlier guess of
`/connect/commerce/management/...` returned "URL No Longer Exists":

```
POST /services/data/v67.0/commerce/management/webstores/{webStoreId}/search/indexes
Body: {}
→ 201 {"id":"0axgL000000MDY5","indexBuildType":"Full","indexStatus":"InProgress"}
```

Manual equivalent if the REST route ever changes: **Commerce App → your store → Search → Build
Index**.

**Belt and braces.** `officeDepotProductRails` and `officeDepotCategoryDeals` render
`p.imageUrl || generatedIllustration(p.imageKey)`, so the page never shows a broken image even
while the index is rebuilding.

**Cost.** A full rebuild of a 20-product index took about 3.5 minutes. Plan for it.

---

## GAP-06a — A WebStore reads ONE specific CMS space, and nothing tells you which

**Requirement.** Put the images in the space the store actually serves from.

**Actual.** This org contains **two** spaces both named `Office Depot Managed Content Space …` and
both described `ManagedContent for store Office Depot`, created 54 minutes apart by earlier
attempts:

| Space | apiName | Created | Result |
| --- | --- | --- | --- |
| `0ZugL000008NCdNSAW` | `…_1e3jRmjs` | 07:29:37 | images upload and publish fine, store still serves the placeholder |
| `0ZugL000008NB7qSAG` | `…_N3leDgNq` | 06:35:31 | **correct** — store serves the real image |

The first attempt used `1e3jRmjs` because that is the space tracked in
`force-app/.../digitalExperiences/content/`, i.e. the one associated with the **site**. The one the
**WebStore** reads is `N3leDgNq` — created at the same moment as the WebStore itself. A full index
rebuild against the wrong space still returned `/img/b2b/default-product-image.svg`, with no error
anywhere.

**Root cause.** The WebStore→CMS-space binding is not exposed on any queryable field.
`ManagedContentChannel` has no space lookup (`Id, IsDeleted, Name, Type, Options*, Domain,
DomainHostName, CacheControl*` only), and `GET /connect/cms/spaces/{id}` does not list channels.

**Class.** PLATFORM.

**Workaround — implemented.** Heuristic: the correct space is the one whose `createdDate` matches
the WebStore's. Confirmed empirically by uploading to both and re-indexing. Practical rule: if
media uploads cleanly, publishes, links to `ProductMedia`, survives a full index rebuild and the
storefront *still* shows `/img/b2b/default-product-image.svg`, you are in the wrong CMS space.

---

## GAP-06b — The CMS media URL must NOT be prefixed with the site base path

Directly contradicts GAP-04, and cost a deploy cycle. `ConnectApi` returns
`/cms/delivery/media/{key}?version=…&channelId=…&oid=…`. That path is served by a redirect at the
**origin**. Applying the same `siteUrl()` helper that every navigation link needs produces
`/officedepot/cms/delivery/media/…`, which is a hard **404**, and the page falls back to alt text.

Measured in the buyer session:

| URL form | Result |
| --- | --- |
| `/cms/delivery/media/…` | `opaqueredirect` → image loads, `naturalWidth = 600` ✅ |
| `/officedepot/cms/delivery/media/…` | `404 text/html` ❌ |

**Rule.** Base-path-prefix *navigation* targets; never prefix platform-issued asset URLs.

---

## GAP-07 — No licensed product photography; images are generated placeholders

**Requirement.** Live images on the products.

**Actual.** There is no licensed photography for these SKUs in this workspace, and Amazon's or any
retailer's imagery is out of bounds. The 20 images are **generated**: a 600×600 PNG per SKU,
rendered by driving headless Chrome over a small HTML/SVG template — a neutral tinted panel, a
line-art glyph for the product family (paper, pens, files, laptop, printer, monitor, chair, desk,
coffee, cleaning), and the Office Depot wordmark, product name and SKU beneath.

They are honest placeholders, not photographs. **State this in any demo.** Replacing them is now a
drop-in: re-run the same multipart upload with real files.

**Class.** Not a capability gap — an asset-availability gap. Recorded so nobody mistakes the tiles
for real merchandising.

**Note on the alternative that was *not* needed.** A `staticresource` + `@salesforce/resourceUrl`
bundle would also have put images on screen, and would have been quicker. It was rejected once the
CMS route was proven, because a static resource is invisible to the **standard** commerce
components — PDP, search results, cart and order history all read `ProductMedia`. Going through
CMS means the same 20 images now serve every surface of the store, not just the custom home page.
If the CMS route had stayed blocked, the static resource was the documented fallback and its
limitation would have been exactly that.

---

## GAP-08 — Installed skills did not cover the two hardest problems

`commerce-b2b-open-code-components-replace` and `-integrate` address swapping OOTB B2B components
for Salesforce's open-source equivalents inside `content.json`. The requirement here was the
opposite: **remove** `commerce_builder:layoutHeaderOne` outright and put bespoke components in the
theme layout's `header` region. Neither skill covers component *removal* from a theme layout, and
neither addresses the `sfdc_cms__view` / `sfdc_cms__themeLayout` JSON schema for custom `c:`
components, which is where the previous attempt got stuck.

Nothing in the installed catalogue covers CMS **image authoring** (`experience-cms-content-generate`
is about content, not the multipart binary upload), the commerce **search index rebuild**, or the
external-sharing behaviour in GAP-01. Those three cost the most time and were all solved by
probing the org's own REST surface and reading error messages carefully.

**Class.** SKILL-GAP.

---

## GAP-09 — The previous attempt's diagnosis was wrong, and that was expensive

The handover said: *"Attributes are the culprit. Bisecting per component."*

That was **incorrect**. The first thing done in this pass was to load the site as Dana in headless
Chrome. `c-office-depot-utility-header`, `c-office-depot-nav-bar`, `c-office-depot-promo-tiles`
and `c-office-depot-mega-footer` were all present in the DOM, fully styled, with correct text —
they had been rendering the whole time. The `attributes` blocks in
`sfdc_cms__themeLayout/commerceLayout/content.json` were fine. What was actually wrong was that the
OOTB `commerce_builder:layoutHeaderOne` ("alpine group") was still sitting between the custom
header and the page body, and the home view contained only one component.

**Class.** AGENT.

**Lesson.** Two minutes of headless-browser observation invalidated a diagnosis that had already
consumed an entire session. Observe the running system before forming a theory about it.

---

## GAP-10 — Things that genuinely need the Setup UI

Everything in this build was achieved through the CLI, the Metadata API or REST. The only items
that would require Setup / the Commerce App are:

| Item | Why |
| --- | --- |
| Search index rebuild | Possible over REST (GAP-06), but the endpoint is undocumented and unversioned in the docs; Commerce App → Search → Build Index is the supported route. |
| CMS content deletion | No delete route was found for `/connect/cms/contents/{key}`. Nine throwaway probe items (titled `probe …` / `p<timestamp>`) plus one unused 20-image set remain in the two Office Depot CMS spaces and would need removing through Digital Experiences → CMS Workspaces. All are additive and none affect the storefront. |
| Discovering which CMS space a WebStore reads | See GAP-06a. Not exposed on any queryable field; determined here by matching `createdDate` and confirmed by experiment. |

---

## Waived deliverables

No Apex test classes and no LWC Jest tests were written, per standing user direction for this
pass. The Constitution's Testing section (80 % / 95 % coverage, `System.runAs()`, Jest) is
therefore **not satisfied**, and that is recorded here rather than quietly marked green.

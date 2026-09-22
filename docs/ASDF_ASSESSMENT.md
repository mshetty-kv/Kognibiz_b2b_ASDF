# ASDF Capability Assessment — Office Depot B2B Commerce (LWR)

**Spec:** ASDF-SF-B2B-001 · **Constitution:** office depot store v1.0.0
**Assessment date:** 2026-09-21

## Orgs used

| Tag | Org | Role |
|---|---|---|
| **SC** | `officedepot-sc` · `test-awanlyx861ok@example.com` · **00DG100000EKcgz** · Enterprise scratch · API 67.0 · expires 2026-09-28 | **Primary.** Clean org created from `config/project-scratch-def.json`. The Office Depot store was actually built here. Every score below marked **SC** is measured on observed behaviour. |
| **DE** | `vscodeOrg` · `cthakur1@kognivera.com` · **00DgL00000L7NwjUAF** · Developer Edition | Contaminated sandbox (5 pre-existing stores, 70 orders). **Read-only reference from 2026-09-21 onward.** Used only for schema comparison. |

**Status:** the storefront is **built, published, Live and TRANSACTING** in SC. Catalog, pricing, entitlement, buyer identity, permissions, storefront pages, branding, the search index, shipping and checkout are all verified working. **SM-02 is MET** — buyer Dana Whitfield placed order `00000100` (Activated, 25.15). `OfficeDepotChainVerifier` reports **22 passed, 0 failed**.

**Storefront URL:** `https://agility-saas-6609.scratch.my.site.com/officedepotvforcesite`

---

## 1. Headline findings

1. **`config/project-scratch-def.json` is VERIFIED, not theoretical.** A scratch org was successfully created from it. All four requested settings took effect, confirmed by retrieving them from SC: `commerceEnabled=true`, `commerceAppEnabled=true`, `enableNetworksEnabled=true`, `enableOrders=true`, `enableEnhancedCommerceOrders=true`, and critically `enableExperienceBundleMetadata=true` (it was `false` in DE, which had blocked page authoring there).

2. **`Product2.Type = 'Base'` silently destroys the search index.** This is the single most valuable finding of the whole exercise. `ProductClass` is read-only and *derived*; proven side by side in SC:

   | SKU | `Type` set | Resulting `ProductClass` |
   |---|---|---|
   | ZZ-PROBE-1 | *(not set)* | `Simple` |
   | ZZ-PROBE-2 | `Base` | `VariationParent` |

   A `VariationParent` is not searchable, so a catalog of them makes the index build fail with a message that never mentions `Type`:
   > *"There are no searchable products for this store. Make sure your store has at least one active product marked as searchable, and try again."*

   Worse, `Type` is createable but **not updateable** — the only remedy is to delete and recreate every product. Four index builds failed before this was isolated. After removing `Type`, the index completed `indexStatus: Completed`, `indexUsage: Live`, and ConnectApi search returned 3 hits for "paper".

3. **Two "Setup-UI only" steps turned out to be plain metadata deploys.** Both were previously scored Class 3 on the DE evidence and are now Class 1:
   - **Site activation** — `Network.status` is a deployable field. Deploying `<status>Live</status>` moved the site `UnderConstruction → Live`. No Setup UI.
   - **External-profile user creation** — the error tells you to go to *Setup → Digital Experiences → Settings*, but the same switch is `CommunitiesSettings.enableOotbProfExtUserOpsEnable`, now captured in `force-app/main/default/settings/Communities.settings-meta.xml`.

4. **The trailing "1" in the bundle folder is real.** `DigitalExperienceBundle` full name is **`site/Office_Depot1`** (also `ExperienceBundle` and `SiteDotCom`), while `CustomSite` is `Office_Depot` with no suffix. The folder was briefly renamed to `Office_Depot` on instruction and has been **renamed back to `Office_Depot1`** now that the real DeveloperName is confirmed from the live org.

5. **`Type='Base'` was not the only cross-org schema trap.** Each of these failed to *compile or deploy*, not merely at runtime, and each is now handled dynamically so one codebase serves both orgs:
   - `WebStore.SupportedCurrencies` / `CurrencyIsoCode` — exist in DE (multi-currency), absent in SC.
   - `Order.SalesStoreId` — exists in DE (56 rows carry it), **absent entirely** in SC.
   - `Product2.IsShippingChargeNotApplicable` — exists in DE, absent in SC.
   - `Product2.Specification__c` (universally required in DE) — absent in SC.

6. **`BuyerAccount` must be committed in a *prior transaction* before `BuyerGroupMember`.** Reordering within one transaction is not enough; the platform does not see an uncommitted BuyerAccount, and the resulting exception rolls back every link created earlier in that transaction (first attempt left all five link objects at 0 rows).

7. **A valid, active picklist value can raise an uncatchable platform fault.** `Tax__B2B_STOREFRONT__StandardTax` is an active value in both orgs but raises `UNKNOWN_EXCEPTION ... ErrorId: 464645055-399661` on insert in SC. `Tax__B2B_STOREFRONT__SfPaymentsTax` registers cleanly.

8. **The shipping-profile API exists, and my first conclusion that it did not was wrong.**
   Checkout was blocked for hours by `COMPUTE_SHIPPING`, and I reported it as having "no documented
   API surface". That was a research failure on my part, with two specific causes worth recording
   because they generalise:
   - **I did not read the whole error payload.** The response carried a *second* message naming the
     missing object outright: *"Please configure correct Shipping Profiles in the respective web
     store 0ZEG1000001HoZJOA0."* I reported only the first message.
   - **I fixed the model I already knew** (`OrderDeliveryMethod` + shipping product + pricebook
     entries) instead of asking which objects the provider actually reads. The real chain is
     `ShippingConfigurationSet` → `ShippingRateGroup` → `ShippingRateArea` → `StandardShippingRate`,
     plus `ShippingCarrier` → `ShippingCarrierMethod`. All seven objects are createable via the API.
   Once built, shipping computed immediately and the order went through. See §6.

9. **Testing descoped by user direction.** No Apex test classes, no Jest tests were written. Definition of Done item 2 is **not met**. Recorded, not silently passed. (Scratch-org deploys of DML-bearing Apex required no test coverage.)

---

## 2. Canonical dependency chain (BR-01) — clean-org classification

All scores measured in **SC** unless noted. "Evidence" is what was actually observed, with real record Ids.

| # | Step | Score | Org | Evidence observed | Workaround / caveat |
|---|---|:--:|:--:|---|---|
| **1** | Org Enablement | **1** | SC | Scratch org created from our own scratch-def; settings retrieved and confirmed (Finding 1). | Was Class 3 on DE evidence. **Re-scored 3 → 1**: for a scratch/new org this is fully automatable via `config/project-scratch-def.json`. It remains Class 3 for an *existing* org, where no API can flip it. |
| **2** | WebStore + linked LWR site | **2** | SC | `sf community create -n "Office Depot" -t "Commerce Store (LWR)" -p officedepot` → job `08PG100000PWKzhMAH`, `SiteTaskCreate` → `Complete`. Produced WebStore **0ZEG1000001HoZJOA0** (Type=B2B), Network **0DBG1000000Iz6fOAC**, `WebStoreNetwork` **0ZFG100000006NBOAY**, profile "Office Depot Profile", bundle `site/Office_Depot1`. | **Not a metadata deploy** — `WebStore` is absent from `sf org list metadata-types` in *both* orgs. Asynchronous; must poll `BackgroundOperation`. `-p officedepot` became `officedepotvforcesite`. Only ONE profile was generated (guest) — **no "Office Depot Shopper Profile"**, unlike DE. |
| **3** | Store settings | **1** | SC | `WebStore` updated: language, country, tax locale, pricing strategy, `PaginationSize=24`, `MaxValuesPerFacet=100`, auto-faceting on, guest browsing off, `StrikethroughPricebookId=01sG1000004nfFpIAI`. | **Trap:** `AccessLevel.USER_MODE` validates every *populated* field, not just changed ones. Selecting the create-only `WebStore.Type` makes the update fail `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY ... fieldNames: Type`. Fix: load only Id, write to a fresh sObject. |
| **3b** | Integration registration | **2** | SC | 4 providers registered and verified: `Price__B2B_STOREFRONT__StandardPricing`, `Promotions__B2B_STOREFRONT__StandardPromotions`, `Shipment__B2B_STOREFRONT__StandardShipment`, `Tax__B2B_STOREFRONT__SfPaymentsTax`. | Three limitations: (i) `StandardTax` raises a platform fault (Finding 7); (ii) no internal **Inventory** provider value exists at all — note this is specific to *inventory*; **shipping is fully API-configurable** via the profile chain in step 3d; (iii) the `Flow__sfdc_checkout__CheckoutTemplate` row registered successfully but was **no longer present** at final verification — the platform appears to manage checkout-flow registrations itself. Registration is done one-at-a-time with try/catch so one fault cannot abort the rest. |
| **3c** | Payment gateway auth | **3** | SC | Not configured: **0 `PaymentGateway`, 0 `PaymentGatewayProvider`** records, and `StoreIntegratedService.Integration` exposes no internal `Payment__*` value. | **OQ-01 confirmed.** Did NOT block SM-02 — the standard storefront checkout completed without a gateway. It only blocks *programmatic* order placement, where `POST /checkouts/{id}/payments` demands a token (`requestType` accepts only `Auth`). |
| **4** | Catalog → Categories → Products | **1** | SC | ProductCatalog **0ZSG100000017nROAQ**; 15 categories; 20 products; 20 category assignments. All verified by SOQL. | **See Finding 2 — do not set `Product2.Type`.** Also: a Commerce catalog is happy with several top-level categories; consolidating to a single root ("All Products") made no difference to indexability, so the 4-root layout was *not* the problem. |
| **4b** | Product media / images | **3** | SC | `ElectronicMediaGroup` → `createable:false, updateable:false`. | **No API path.** Load via Commerce App / CMS. PDP gallery and PLP cards render placeholders until then. |
| **5** | Pricebooks → Entries | **1** | SC | 2 custom books + 63 active `PricebookEntry` rows. Standard book resolved by `IsStandard=true` (**01sG1000004nSP3IAM**). | **Clean-org-only trap:** the standard pricebook ships **`IsActive=false`** in a fresh scratch org (it was active in DE). `PricebookEntry` inserts fail against it, so the seeder now activates it first. Also: custom-book entries must be deleted *before* standard-book entries, or deletion raises `UNKNOWN_EXCEPTION`. |
| **6** | Entitlements → Buyer Groups | **2** | SC | Policy **1CeG10000002JOLKA2** (active, CanViewProduct, CanViewPrice); BuyerGroup **0ZIG10000001eg9OAA**; 21 entitled products; `BuyerGroupPricebook` bound. | **No `CommerceEntitlementCatalog` object exists** in either org — entitlement is product-by-product. Verified working: ConnectApi search honoured entitlement and contract pricing. |
| **7a** | Accounts → Contacts | **1** | SC | Account **001G100000luXkeIAE** + 2 contacts. | — |
| **7b** | External buyer User | **2** | SC | 2 users created on profile **Customer Community Plus User**. | Three gates, all hit for real: (i) `MIXED_DML_OPERATION` → separate transaction (the structural EC-02 fix); (ii) account owner needs a **UserRole** — a fresh scratch org has none, so one is created (`OfficeDepotStoreOwner`, **00EG100000KgPQ3MAN**); (iii) `enableOotbProfExtUserOpsEnable` must be true (Finding 3), else `FIELD_INTEGRITY_EXCEPTION` on ProfileId. Profile names differ completely between orgs, hence runtime resolution. |
| **8** | Memberships / Links | **2** | SC | `WebStoreCatalog`, `WebStoreBuyerGroup`, 2× `WebStorePricebook`, `BuyerGroupMember`, `BuyerAccount` **0bjG10000004ASDIA2** (Active) — all verified present. | **Must be split across two transactions** (Finding 6). Also note `WebStoreCatalog` uses **`SalesStoreId`**, not `WebStoreId` — every other link object uses `WebStoreId`. |
| **8b** | Permission set + licence assignment | **1** | SC | 4 assignments created (2 users × `B2BBuyer` + `Office_Depot_Buyer_Access`); `B2BBuyerPsl` licences assigned. | **EC-03 fully countered.** All names resolved from the org at runtime. Note the org-to-org difference: `CommerceUser` ("Shopper") exists in DE but **not** in SC — a hardcoded list would have failed here. |
| **9a** | Standard storefront pages | **1** | SC | Retrieved `DigitalExperienceBundle:site/Office_Depot1` → **28 standard routes, 28 views, 5 theme layouts, 4 branding sets**, all now under source control. Round-tripped back with a **72/72 component deploy**. | **Re-scored 2 → 1.** On DE this was capped at 2 because `enableExperienceBundleMetadata=false`. In SC it is true and the full create → retrieve → configure → deploy loop works. Pages still cannot be authored *before* the site exists. |
| **9b** | Theme / branding | **1** | SC | Branding regenerated from **this org's** 269-key `b2b-storefront:branding` baseline; 49 overrides, **0 invented keys**; deployed 72/72. | **Trap:** `transparent` is rejected — *"the property value: transparent, is not in a supported color format"*. `rgba(0,0,0,0)` is accepted. Also: deploying over a template-generated bundle needs `--ignore-conflicts`. |
| **10** | Search index build | **2** | SC | `POST /services/data/v67.0/commerce/management/webstores/0ZEG1000001HoZJOA0/search/indexes` → index **0axG10000000Isz**, `indexStatus: Completed`, `indexUsage: Live`. Then `ConnectApi.CommerceSearch.searchProducts` returned **3 hits** for "paper". | **Re-scored 3 → 2.** Fully scriptable via REST — no Setup UI needed. Still Class 2 because there is no metadata/DML path and it is asynchronous. **This is where Finding 2 bites**: 4 builds failed first. |
| **10b** | Searchable / sortable field config | **3** | SC | `WebStoreSearchProdSettings` only carries `IsExcludedFromSearch` per product; no endpoint found (`/search/searchable-fields` → `NOT_FOUND`). | **Setup UI only.** Needed to surface extra fields on the product card. |
| **11** | Publish site | **1** | SC | `sf community publish -n "Office Depot"` → job **08PG100000PWLFuMAP**, `SiteTaskPublish` → `Complete`. | Returned the live URL. |
| **11b** | Activate site | **1** | SC | Deployed `Network.status = Live`; SOQL confirms `Status = Live`. | **Re-scored 3 → 1** (Finding 3). **Caveat:** the deploy fails with *"unable to obtain exclusive access to this record"* while the publish job is still running — wait for `SiteTaskPublish` to Complete. Site membership for the buyer profile was added the same way via `networkMemberGroups`. |
| **3d** | **Shipping Profile** | **1** | SC | Full chain built by `OfficeDepotShippingConfigurator`: `ShippingConfigurationSet` (TargetRecordId → WebStore), `ShippingRateGroup`, `ShippingRateArea` (US), `StandardShippingRate` @ 9.99, `ShippingCarrier` → `ShippingCarrierMethod`, and `OrderDeliveryMethod` relinked. | **Entirely API-configurable** — all seven objects are createable. Gotcha: `ShippingConfigSetProduct` is REJECTED on a default profile (`INVALID_OPERATION` — "You can't add a product to the default shipping profile"); a default profile covers all products implicitly, so the two are mutually exclusive. |
| **12** | Cart / Checkout / Order | **2** | SC | **Order `801G100000luuHNIAY` / `00000100`, Activated, 25.15**, placed by buyer Dana Whitfield through the published storefront, with a 9.99 Delivery Charge line. Re-proven on a fresh cart: `availableDeliveryMethods` non-empty, `errors: []`. | **Re-scored 4 → 2.** The earlier Class 4 rested on my incorrect claim that shipping had no API surface — it does (step 3d). Remaining limitation: *programmatic* order placement via `POST /checkouts/{id}/payments` requires a gateway token (`requestType` accepts only `Auth`), and no gateway is configured. The standard storefront checkout completes without one. |

### Score distribution (clean org)

| Score | Steps | Count |
|---|---|:---:|
| **1** | 1, 3, **3d**, 4, 5, 7a, 8b, 9a, 9b, 11, 11b | **11** |
| **2** | 2, 3b, 6, 7b, 8, 10, **12** | **7** |
| **3** | 3c, 4b, 10b | **3** |
| **4** | — | **0** |
| **5** | — | **0** |

**SM-01: 18 of 21 steps at Class 1–2 = 86%**, against a target of >70%. **Target met.**
*(The DE-based measurement was 60%, and an intermediate clean-org measurement was 80%. The final figure reflects one added step (3d, Shipping Profile) and the correction of step 12 from Class 4 to Class 2 after I found the shipping API I had wrongly reported as non-existent.)*

---

## 3. Visual reference mapping (Amazon screenshots → standard LWR components)

The screenshots are a **layout reference only**. The inventory below comes from the real retrieved `site/Office_Depot1` bundle in SC, so every `namespace:component` named is real.

| Screenshot feature | Standard component / setting | Score | Note |
|---|---|:--:|---|
| Full-width hero | `dxp_content_layout:banner` | **2** | Static hero. No carousel component in the bundle; a rotating carousel would be Class 4 — **not built**. |
| 4-across promo tile row | `community_layout:section`, 4 × `columnWidth:3` | **1** | Pure configuration. |
| Category deal tiles | `dxp_content_layout:grid` + `:list` | **2** | Layout fine; imagery blocked by step 4b. |
| Top nav category menu | `experience:megaMenuNavigation`, `commerce_builder:drilldownNavigation` | **1** | Driven by `ProductCategory.IsNavigational` (set by the seeder; 15 categories live). |
| "Lists" dropdown | `commerce_builder:wishlistShortcut` + `Wishlist` route | **2** | Standard component is an **icon shortcut**, not a multi-list dropdown. Exact match = Class 4, not built. |
| Left-rail faceted filters | `commerce_builder:searchFilters` + `OptionsAutoFacetingEnabled=true` | **1** | Requires the index, which is now Live. |
| Sort menu + pagination | `commerce_builder:searchSortMenu`, `dxp_content_layout:paginator2`, `PaginationSize=24` | **1** | 24 divides evenly into the 4-across grid. |
| PLP result grid | `commerce_builder:searchResults` (`resultsLayout:"grid"`) | **1** | Search verified returning entitled products. |
| **Dual pricing (M.R.P. + price)** | `showOriginalPrice` + `showNegotiatedPrice`, backed by `StrikethroughPricebookId` | **1** | **Verified live in the cart**: `totalListPrice 269.97` vs `totalProductAmount 221.37` — the 18% contract discount renders as a real saving. |
| "Best Seller" badge | `searchResults.cardContentMapping` | **2 / 3** | Renders as plain text, not styled chrome; needs the field added via Setup UI (10b). **In SC the `Specification__c` field does not exist at all**, so there is currently no field to map. |
| PLP / PDP star ratings | *No standard rating component; no rating field on Product2.* | **5 / 4** | **Genuine gap.** Not part of standard B2B Commerce LWR. **Not built.** |
| PDP gallery + thumbnails | `commerce_builder:productMediaGallery` | **1 / 3** | Layout matches exactly; **images** are Class 3 (step 4b). |
| PDP breadcrumb / title | `commerce_builder:breadcrumbs`, `:heading` | **1** | Breadcrumb verified: store API returns `All Products → Office Supplies → Paper and Notebooks`. |
| PDP "M.R.P. / Price / You Save" | `commerce_builder:productPricingDetails` | **2** | Only `pricingType: "2_TIER"` observed. Slot-3 attributes exist but a 3-slot mode was **not confirmed**. |
| PDP stock status | *No internal inventory provider exists.* | **4** | Needs an external Apex inventory service. **Not built.** |
| Quantity selector / Add to cart | `commerce_builder:purchaseOptions`, `:actionButton` | **1** | Add-to-cart verified working via ConnectApi. |
| "Buy Now" one-click | *No standard component.* | **4** | **Not built**, per BR-02. |

**Net:** every layout pattern is met by configuring standard components **except** star ratings, real stock status, "Buy Now" and a rotating carousel — all documented rather than silently built. **Zero custom LWCs** exist in this repo (for contrast, the DE sibling store contains 14).

---

## 4. Edge cases & NFRs

| ID | Status |
|---|---|
| **EC-01** | **Exercised for real.** The search index failed 4 times and the shipping integration still fails. Both were documented with exact error text rather than swallowed; the index was subsequently fixed and completed. |
| **EC-02** | **Structurally prevented and proven.** Account→Contact and User are separate classes in separate transactions. |
| **EC-03** | **Fully countered and proven valuable.** Profile and permission-set names differ substantially between the two orgs (`CommerceUser` present in DE, absent in SC; no shopper profile generated in SC). Runtime resolution succeeded where any hardcoded list would have failed. |
| **NFR-01** | **Met in the end, but not on the first pass.** Two genuine ordering defects were found and fixed by execution: BuyerAccount-before-BuyerGroupMember, and the transaction split. Final run: 21/22 checks pass with zero ordering errors. |
| **NFR-02** | **Met.** Every Class 2–5 row above carries observed evidence and a workaround. |

---

## 5. Boundary steps still requiring Setup UI or a manual API call

Down to **three**, from eleven on the DE assessment. Note that **shipping configuration is NOT on this list** — step 3d proved it is entirely API-driven:

1. **Product media / images** (step 4b) — Commerce App or CMS. No API.
2. **Searchable / sortable field configuration** (step 10b) — Setup UI only.
3. **Payment gateway registration + authentication** (step 3c) — Setup UI + external secrets.

Plus one **non-UI** manual action: the search index build is a REST `POST` (scriptable, but not metadata or DML).

**No longer manual** (all proven automatable in SC): enabling Commerce/Digital Experiences (scratch-def), store + site creation (CLI), site publish (CLI), **site activation** (metadata), **site membership** (metadata), **external-profile user creation toggle** (metadata).

---

## 6. SM-02 — MET. An order was placed.

**Order `801G100000luuHNIAY`, number `00000100`, Status `Activated`, TotalAmount `25.15`,
Account `001G100000luXkeIAE` (Northwind Office Group), OrderReferenceNumber
`QAMGJ-5M5B7-4GXEK-NGZ5F`, created 2026-09-21T12:26:27Z.**

Placed by **Dana Whitfield** (`dana.whitfield@officedepot.invalid.00dg1000`, profile
*Customer Community Plus User*) — a real external B2B buyer logging into the published
storefront, browsing, adding to cart and checking out. That is US-05 end to end.

Order lines:

| Line | Product | Qty | Amount | Type |
|---|---|:--:|--:|---|
| `802G100000EHIDNIA5` | Spiral Notebooks 6-Pack | 1 | 15.16 | Order Product |
| `802G100000EHIDOIA5` | Standard Ground Shipping | 1 | **9.99** | **Delivery Charge** |

`OrderDeliveryGroup 2DgG10000055JS9KAM` → San Francisco, CA, `TotalLineAmount 9.99`.

### I was wrong in the previous revision of this section

The earlier conclusion — *"the Shipment provider needs configuration beyond what these objects
expose … which has no documented API surface I could reach"* — **was incorrect**. The API surface
exists, is fully documented by `sf sobject describe`, and every object in it is createable. I had
simply not found the right objects, and I compounded that by not reading the whole error payload:
the checkout response carried a **second message I failed to report**, which names the missing
object outright:

> *"Please configure correct Shipping Profiles in the respective web store 0ZEG1000001HoZJOA0."*

"Shipping Profile" is `ShippingConfigurationSet`. My first fix attempt built
`OrderDeliveryMethod` + a shipping `Product2` + pricebook entries, which is the older/partial
model; `Shipment__B2B_STOREFRONT__StandardShipment` actually reads the shipping-profile chain,
and that chain was **completely empty** (0 rows across all seven objects).

### The chain that was missing, now built by `OfficeDepotShippingConfigurator`

```
ShippingConfigurationSet  "Office Depot Shipping Profile"   7LAG1000000dgKLOAY
  TargetRecordId -> WebStore 0ZEG1000001HoZJOA0   <-- the link the error complained about
  |- ShippingRateGroup    "Office Depot Domestic Rates"     8NiG10000000Hk1KAE
  |    |- ShippingRateArea  "United States" (Countries=US)  12hG10000013lkzIAA
  |         |- StandardShippingRate "Standard Ground Flat Rate" 5fyG100000000mPIAQ  @ 9.99
  |            (ConditionFactor=OrderPriceFactor, range 0-1,000,000)
ShippingCarrier "Office Depot Logistics"                    2A2G1000000DSg1KAG
  |- ShippingCarrierMethod "Standard Ground"                2A1G10000000tULKAY
       ^-- OrderDeliveryMethod 2DmG100000064VZKAY relinked via ShippingCarrierMethodId
           (it had been null, which is why an active delivery method never surfaced)
```

### Causality is unambiguous

| Time (UTC, 2026-09-21) | Event |
|---|---|
| before 12:24 | All 7 shipping objects at **0 rows**; every checkout failed `COMPUTE_SHIPPING` |
| **12:24:31** | `ShippingConfigurationSet` created by `OfficeDepotShippingConfigurator` |
| **12:24:32** | `StandardShippingRate` created @ 9.99 |
| **12:26:27** | **Order `00000100` placed**, carrying a 9.99 *Delivery Charge* line |

The order's shipping charge is exactly the `StandardShippingRate.Price` this class created.

### Independently re-proven on a fresh cart

To remove any doubt that the fix — rather than incidental timing — is what unblocked shipping, I
drove a brand-new checkout myself over the REST API after the fix:

- Fresh cart `0a6G1000000FIz7IAG`, 2 × ErgoTask Mesh Task Chair, **475.58** (contract price).
- `POST /checkouts` → session `2z9G1000000EZabIAG`.
- `PATCH` delivery address (San Francisco, CA).
- `GET` → **`availableDeliveryMethods: [{"id":"7cdG1000000H2ztIAC","name":"Standard Ground Flat Rate","fee":"9.99"}]`**, **`errors: []`**, grand total **485.57** (= 475.58 + 9.99).
- Delivery method auto-selected: *Standard Ground Flat Rate @ 9.99*.

`COMPUTE_SHIPPING` is gone, `availableDeliveryMethods` is non-empty, and the fee is correct.

### Where the headless path still stops: payment

That second, API-driven order could not be *placed* programmatically:

```json
{"detail":"Looks like the payment method isn't authorized.",
 "title":"We are unable to place the order. Please correct the error and try again.",
 "type":"/commerce/checkout/placeorder/payment"}
```

Probing `POST /checkouts/{id}/payments` shows `requestType` accepts **only `Auth`** (`PurchaseOrder`,
`Sale` and `Token` are all rejected with *"Invalid value for Payment Request Type"*), and `Auth`
then demands *"The required request parameter 'Payment Token' is missing."* A payment token
requires a gateway, and this org has **0 `PaymentGateway` and 0 `PaymentGatewayProvider` records**
— `StoreIntegratedService.Integration` exposes no internal `Payment__*` provider at all.

This is the **separate, pre-existing Class 3 payment boundary (OQ-01)**, not a shipping defect.
Note the storefront checkout flow *did* complete without a gateway, which is how Dana's order was
placed; only the raw REST `payments` resource insists on a token.

**Conclusion: SM-02 and OBJ-02 are MET.** `OfficeDepotChainVerifier.execute()` now reports
**22 passed, 0 failed**.

---

## 7. Deviations, conflicts and unmet obligations

1. **`force-app/main/default/store/` prescribed by the Constitution but impossible** — no `WebStore` metadata type exists in either org. Folder deliberately **not** created; inventing its contents would breach the Constitution's own "Real API Names" rule. *Needs an Amendment.*
2. **Constitution mandates `WITH SECURITY_ENFORCED`, which no longer compiles.** API 67.0: *"WITH SECURITY_ENFORCED is no longer supported, use WITH USER_MODE instead."* All 40 queries use `WITH USER_MODE` + `AccessLevel.USER_MODE` — strictly stronger (adds sharing). *Needs an Amendment.*
3. **Testing descoped by user direction.** Definition of Done item 2 **not met**; the "Apex Unit tests" CI gate cannot pass.
4. **Definition of Done item 9 is now MET** — store created, dependencies resolved in order, buyer configured, storefront published, and a successful order placed via the cart/checkout flow (§6). Item 2 (tests) remains the only unmet item.
5. **`artifacts/asdf-assessment.html` was deleted.** It was an unrequested duplicate of this file and had already drifted out of sync. This Markdown file is the single source of truth.
6. **Root folder** `office-depot-store/` from the Constitution diagram not created; existing `office_depot_proj` root used per direction. `doc/` (source documents) left untouched; `docs/` added for the two mandated artifacts.
7. **Anonymous-Apex constraints** (now largely moot since all logic is in deployable classes, but they shaped the first pass): a class declared in anonymous Apex is itself an inner type so it cannot contain nested types or `static` members; `sort` is a reserved identifier.
8. **`sf` cannot run directly from Git Bash here**; `scripts/bash/_common.sh` shims through PowerShell on Windows and calls `sf` directly elsewhere.

---

## 8. Traceability

| Requirement | Satisfied by | Status |
|---|---|---|
| **FR-01 / US-01** | §2 steps 1–2; `OfficeDepotPreflight`; `scripts/bash/00_preflight.sh`, `10_create_store_and_site.sh` | **Met** — store + site created and verified |
| **FR-02 / US-02** | §2 steps 4–6, 8; `OfficeDepotCatalogSeeder`, `OfficeDepotPricebookSeeder`, `OfficeDepotEntitlementSeeder`, `OfficeDepotStoreLinker` | **Met** |
| **FR-03 / US-03** | §2 steps 7a/7b/8b; `OfficeDepotBuyerIdentitySeeder`, `OfficeDepotBuyerUserProvisioner`, `OfficeDepotPermissionAssigner`; both permission sets | **Met** |
| **FR-04 / US-04** | §2 steps 9a/9b/10/11/11b; §3; `scripts/bash/30–60` | **Met** — pages configured not rebuilt, index Live, site published and activated |
| **OBJ-02** | §6 | **MET** — end-to-end B2B transaction completed on the ASDF-generated storefront |
| **FR-05 / US-05** | §2 steps 3d & 12; §6 | **MET** — buyer Dana Whitfield placed order `00000100` (Activated, 25.15) through the published storefront |
| **FR-06** | This document | **Met** |
| **NFR-01 / NFR-02** | §4 | **Met** |
| **EC-01 / EC-02 / EC-03** | §4 | **Met** |
| **BR-01** | §2 ordering; `scripts/bash/20_run_data_chain.sh` | **Met**, with two ordering defects found and corrected by execution |
| **BR-02** | §3; zero custom LWCs; zero rebuilt standard pages | **Met** |
| **BR-03** | §2, §3 | **Met** |
| **OQ-01** | §2 step 3c | Confirmed Class 3 |
| **SM-01** | §2 | **Met** — 86% vs >70% target |
| **SM-02** | §6 | **MET** — Order `801G100000luuHNIAY` exists in the org |

---

## 9. Verification ledger

| Artefact | Verification | Result |
|---|---|---|
| 13 Apex classes | Deployed to SC | **All Active** — `sf project deploy start` 13/13 |
| Whole dependency chain | `OfficeDepotChainVerifier.execute()` in SC | **22 passed, 0 failed** |
| 2 permission sets | Deployed to SC | **2/2** after fixing an Account-dependency error |
| `Communities.settings-meta.xml` | Deployed to SC | **Succeeded**; unblocked buyer creation |
| Storefront bundle | Retrieved then redeployed to SC | **72/72 components** |
| `Network` status = Live | Deployed to SC | **1/1**; SOQL confirms `Live` |
| Search index | REST POST + poll | **Completed / Live**; ConnectApi search returns 3 hits |
| Cart + pricing | ConnectApi in SC | Cart created, item added, **contract pricing correct** (269.97 → 221.37) |
| `project-scratch-def.json` | Scratch org created from it | **Verified** — all settings took |
| Shipping profile chain | `OfficeDepotShippingConfigurator.execute()` in SC | **Built and idempotent** — 7 objects, re-run creates no duplicates |
| Delivery methods on checkout | Fresh cart + REST checkout | **`availableDeliveryMethods` non-empty**, `errors: []`, fee 9.99 |
| **Checkout → Order** | Buyer session on the published storefront | **SUCCEEDED** — Order `00000100`, Activated, 25.15, with a 9.99 Delivery Charge line |
| Programmatic order placement | REST `POST /checkouts/{id}/payments` | **Blocked** — requires a gateway payment token; no gateway configured (OQ-01) |
| Test coverage | — | **Not performed** (descoped) |
| Payment gateway | — | **Not configured** |
| Product images | — | **Not loaded** (no API) |

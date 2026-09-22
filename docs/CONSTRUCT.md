# CONSTRUCT — Office Depot B2B Commerce (LWR)

The single construct file referenced by the Constitution's Repository Structure. It defines
**what this repo generates, in what order, from what verified inputs, and what it deliberately
does not generate.**

- **Constitution:** `doc/CONSTITUTION (1).md` v1.0.0 — authoritative where documents conflict
- **Functional spec:** `doc/asdf-salesforce-b2b-commerce-validation-spec.md` (ASDF-SF-B2B-001)
- **Business context:** `doc/validate-whether-asdf-can-implement-a-complete-salesforce-b2b-commerce-lwr-sto-v1.md`
- **Domain principles:** `doc/project-context-v1 (1).md`
- **Assessment output:** `docs/ASDF_ASSESSMENT.md`

---

## 1. Construct intent

Build a **new** Salesforce B2B Commerce (LWR) storefront named **Office Depot**, with its own
Experience Cloud LWR site, by executing the canonical dependency chain from scratch — and
classify every step by *actual tested behaviour* (BR-03).

The storefront is an **office supplies / business essentials** catalogue. The four Amazon
Business screenshots supplied with the brief are a **visual layout reference only**; they
inform composition and density, never catalogue content or component choice.

**Non-goals:** reusing or mutating any of the five pre-existing stores; rebuilding any standard
page or flow; building custom LWCs; deploying to production.

---

## 2. Verified inputs

Everything this construct emits is derived from an org observation, never from recalled knowledge.

**Primary org (SC):** `officedepot-sc` / **00DG100000EKcgz** — clean Enterprise scratch org,
created from this repo's own `config/project-scratch-def.json`. The store was built here and
every capability score is measured here.
**Reference org (DE):** `vscodeOrg` / **00DgL00000L7NwjUAF** — contaminated Developer Edition
sandbox, **read-only** from 2026-09-21. Used only for schema comparison.

| Input | Source | Used for |
|---|---|---|
| Permission set + licence names | `SELECT Name FROM PermissionSet`; `SELECT DeveloperName FROM PermissionSetLicense` in **both** orgs | EC-03 guard. The two orgs differ: `CommerceUser` exists in DE, not SC. |
| Portal profile names | `SELECT Name, UserType FROM Profile` in both orgs | Runtime profile resolution — SC generated no shopper profile at all |
| Commerce object schemas | `sf sobject describe` × ~25 objects in both orgs | Field lists, picklist values, and the cross-org gaps in §6 |
| Permissionable object list | `SELECT SobjectType FROM ObjectPermissions GROUP BY SobjectType` | Both permission sets |
| Available metadata types | `sf org list metadata-types` | Proving `WebStore` has no metadata type in either org |
| Site template catalogue | `sf community list template` | `Commerce Store (LWR)` |
| Standard page + component inventory | `sf project retrieve start --metadata DigitalExperienceBundle:site/Office_Depot1` (SC) | Visual mapping; 28 routes / 28 views |
| Branding schema (269 keys) | same retrieve, `sfdc_cms__brandingSet/B2B_Commerce/content.json` (SC) | Office Depot branding set — 0 invented keys |
| Org settings | `sf project retrieve start --metadata Settings:Commerce Settings:Communities Settings:Order Settings:ExperienceBundle` | Enablement evidence; the `enableOotbProfExtUserOpsEnable` fix |
| Search index REST contract | live `GET`/`POST` on `/commerce/management/webstores/{id}/search/indexes` | `50_build_search_index.sh` |
| `ProductClass` derivation | Side-by-side probe products in SC (`ZZ-PROBE-1` vs `ZZ-PROBE-2`) | The `Type='Base'` finding that unblocked the search index |

---

## 3. Emitted artefacts

**All code and deployable metadata lives under `force-app/`.** `scripts/` holds orchestration only —
there is no loose Apex source outside the package directory.

```
force-app/main/default/
  classes/                                   ALL Apex - deployable classes, no loose .apex
    CommerceBusinessException.cls            BUSINESS_ERROR  (Constitution error table)
    CommerceAccessException.cls              AUTHORIZATION_ERROR
    OfficeDepotPreflight.cls                 step 1   READ ONLY, EC-02 + EC-03 guard
    OfficeDepotStoreSettings.cls             step 3   store config + internal integrations
    OfficeDepotShippingConfigurator.cls      step 3d  shipping profile chain (unblocks checkout)
    OfficeDepotCatalogSeeder.cls             step 4
    OfficeDepotPricebookSeeder.cls           step 5
    OfficeDepotEntitlementSeeder.cls         step 6
    OfficeDepotBuyerIdentitySeeder.cls       step 7a
    OfficeDepotBuyerUserProvisioner.cls      step 7b  separate txn (MIXED_DML / EC-02)
    OfficeDepotStoreLinker.cls               step 8   two phases, two transactions
    OfficeDepotPermissionAssigner.cls        step 8b
    OfficeDepotChainVerifier.cls             step 12  READ ONLY
  permissionsets/
    Office_Depot_Buyer_Access.permissionset-meta.xml
    Office_Depot_Commerce_Admin.permissionset-meta.xml
  settings/
    Communities.settings-meta.xml            enableOotbProfExtUserOpsEnable - NOT a Setup-UI step
  networks/
    Office Depot.network-meta.xml            status=Live + buyer profile membership
  digitalExperiences/site/Office_Depot1/     retrieved from the org, then configured
    sfdc_cms__route/    (28 standard routes)
    sfdc_cms__view/     (28 standard views)
    sfdc_cms__themeLayout/, sfdc_cms__theme/, sfdc_cms__styles/, sfdc_cms__appPage/, ...
    sfdc_cms__brandingSet/B2B_Commerce/      Office Depot palette, 269 verified keys

config/project-scratch-def.json              VERIFIED - org 00DG100000EKcgz was created from it

scripts/bash/                                orchestration ONLY, no business logic
  _common.sh          PowerShell shim, deploy_classes, deploy_settings,
                      ensure_owner_role, invoke_apex (halt-on-failure)
  00_preflight.sh                     step 1
  10_create_store_and_site.sh         step 2   CREATES ORG RECORDS
  20_run_data_chain.sh                steps 3-8 CREATES ORG RECORDS
  30_retrieve_experience_bundle.sh    step 9a
  40_deploy_storefront_config.sh      step 9b
  50_build_search_index.sh            step 10
  60_publish_and_verify.sh            steps 11-12

scripts/apex/hello.apex                      stock SFDX template file - left untouched
scripts/soql/account.soql                    stock SFDX template file - left untouched

docs/
  ASDF_ASSESSMENT.md                  living 1-5 classification matrix (clean-org scored)
  CONSTRUCT.md                        this file
```

**Why the folder is `Office_Depot1`, not `Office_Depot`:** the trailing "1" is the site's real
metadata DeveloperName, confirmed against the live org after creating it —
`sf org list metadata --metadata-type DigitalExperienceBundle` returns `site/Office_Depot1`
(as do `ExperienceBundle` and `SiteDotCom`), while `CustomSite` is `Office_Depot` with no suffix.

**Not emitted, deliberately:**

| Omitted | Reason |
|---|---|
| `force-app/main/default/store/` | No `WebStore` metadata type exists in either org. `WebStore` is a data record. Creating the folder would require inventing metadata. Flagged for Amendment in `ASDF_ASSESSMENT.md` §7.1. |
| Any `force-app/main/default/lwc/` | BR-02 + Frontend Standards. Every screenshot layout is met by standard components or documented as a Class 4/5 gap. **Zero custom LWCs.** |
| Replacement routes/views | Generated by the template. Correct sequence is create → retrieve → configure → redeploy. |
| Apex test classes, Jest tests | Descoped by explicit user direction. Recorded as an unmet Definition of Done item. |
| `artifacts/asdf-assessment.html` | Deleted - an unrequested duplicate that had already drifted from the Markdown. |
| Any credential or gateway secret | Constitution Security. Named Credentials / Custom Metadata only. |

## 4. Generation order (BR-01) — never reorder

```
 1  Org Enablement ....... config/project-scratch-def.json        [Class 1 for a new org]
 2  WebStore + LWR site .. sf community create                    [Class 2, async]
 3  Settings/Integrations  OfficeDepotStoreSettings.execute()
 3d Shipping Profile ..... OfficeDepotShippingConfigurator.execute()   [run after step 4/5]
 4  Catalog/Products ..... OfficeDepotCatalogSeeder.execute()
 5  Pricebooks/Entries ... OfficeDepotPricebookSeeder.execute()
 3' Settings re-run ...... OfficeDepotStoreSettings.execute()     (wires StrikethroughPricebookId)
 6  Entitlements/Groups .. OfficeDepotEntitlementSeeder.execute()
 7a Accounts/Contacts .... OfficeDepotBuyerIdentitySeeder.execute()
    UserRole ............. ensure_owner_role                      (portal users need an owner role)
 7b Buyer Users .......... OfficeDepotBuyerUserProvisioner.execute()   [separate transaction]
 8  Links + BuyerAccount . OfficeDepotStoreLinker.execute()
 8' BuyerGroupMember ..... OfficeDepotStoreLinker.executeBuyerGroupMembership()  [separate txn]
 8b Permissions .......... OfficeDepotPermissionAssigner.execute()
 9a Storefront pages ..... 30_retrieve_experience_bundle.sh
 9b Branding/permsets .... 40_deploy_storefront_config.sh
10  Search index ......... 50_build_search_index.sh               [REST POST]
11  Publish .............. sf community publish
11b Activate ............. deploy Network.status = Live           [metadata, NOT Setup UI]
12  Cart/Checkout/Order .. buyer-driven E2E validation            [DONE - order 00000100]
```

Four ordering constraints are non-obvious and were all discovered by **execution**, not reasoning.
Each is encoded in the code rather than left as a comment:

- **Step 3 runs twice.** `WebStore.StrikethroughPricebookId` cannot be set before step 5 creates
  the list pricebook, which cannot exist before step 4 creates the products it prices. All
  classes are idempotent, so the re-run is safe.
- **Step 7b is a separate transaction from 7a.** `User` is a setup sObject; combining them raises
  `MIXED_DML_OPERATION`. This is also the structural guarantee against EC-02.
- **Step 8 is split across two transactions.** `BuyerGroupMember` fails with
  *"This Account isn't a Buyer Account"* unless the `BuyerAccount` was **committed** by an earlier
  transaction. Reordering inside one transaction is not enough, and the resulting exception rolls
  back every link created before it.
- **Step 11b must wait for step 11.** Deploying `Network.status` while the publish job is still
  running fails with *"unable to obtain exclusive access to this record"*.

## 5. Visual reference → standard component contract

Full mapping with scores is in `docs/ASDF_ASSESSMENT.md` §3. Summary of the binding decisions:

- **Home** — `community_layout:section` (4 × `columnWidth: 3`) + `dxp_content_layout:banner`
- **Nav** — `experience:megaMenuNavigation` / `commerce_builder:drilldownNavigation`, driven by
  `ProductCategory.IsNavigational`; "Lists" → `commerce_builder:wishlistShortcut`
- **PLP** — `commerce_builder:searchResultsLayout` + `searchFilters` (left rail) + `searchResults`
  (`resultsLayout: "grid"`) + `searchSortMenu` + `dxp_content_layout:paginator2`
- **Dual pricing** — `showOriginalPrice` + `showNegotiatedPrice`, backed by
  `WebStore.StrikethroughPricebookId` → *Office Depot List Price*, with *Office Depot Contract
  Price* (18% off) as the negotiated book
- **PDP** — `commerce_builder:productMediaGallery` + `breadcrumbs` + `heading` +
  `productPricingDetails` + `purchaseOptions` + `actionButton`
- **Cart / Checkout** — untouched. `commerce_unified_checkout:*` and `commerce_builder:checkout*`
  as generated.

**Documented gaps (Class 4/5, deliberately not built):** star ratings, real stock status,
"Buy Now" one-click, rotating hero carousel, styled badge chrome.

---

## 6. Code standards applied

- **Apex:** `PascalCase` classes, `camelCase` methods, explicit `with sharing` on every class,
  **`WITH USER_MODE`** on every SOQL query, `AccessLevel.USER_MODE` on every DML, custom
  exceptions (`CommerceBusinessException`, `CommerceAccessException`) mapped to the
  Constitution's error-category table, zero SOQL/DML inside loops, zero hardcoded Ids
  (the standard pricebook is resolved by `IsStandard = true`; every other lookup is by
  `Name` / `DeveloperName`), every file under the 300-line target.
  > **Deviation from the Constitution, deliberate and verified.** Constitution Security mandates
  > `WITH SECURITY_ENFORCED`. At API 67.0 that clause no longer compiles — the org returns
  > *"WITH SECURITY_ENFORCED is no longer supported, use WITH USER_MODE instead."* `USER_MODE`
  > is the strictly stronger successor (it enforces sharing in addition to CRUD/FLS).
  > Flagged for the Amendment Process in `docs/ASDF_ASSESSMENT.md` §6.8.
- **Anonymous Apex constraints** (discovered by compiling, see `ASDF_ASSESSMENT.md` §6.9):
  custom exceptions are declared at the top level of each block, constants are instance
  `final` rather than `static final`, and `sort` is avoided as an identifier.
- **Metadata:** real API names only, each verified against the org before it was written.
- **Idempotency:** every seeder queries existing state and inserts only the delta, so a
  half-completed chain can be resumed without duplicates.
- **Fail-fast:** every seeder validates its own prerequisites and throws a message naming the
  missing chain step; `invoke_apex` halts the orchestration on the first failure (NFR-01).

---

## 7. Current status

**Built, published, Live and TRANSACTING in scratch org 00DG100000EKcgz.**

Storefront: `https://agility-saas-6609.scratch.my.site.com/officedepotvforcesite`

`OfficeDepotChainVerifier.execute()` reports **22 passed, 0 failed**. Buyer Dana Whitfield placed
order **`801G100000luuHNIAY` / `00000100`** (Activated, 25.15) through the published storefront,
including a 9.99 Delivery Charge produced by the shipping profile chain in step 3d.

Constitution Definition of Done item 9 and spec SM-02 / OBJ-02 are **met**. The only unmet
Definition of Done item is #2 (tests), descoped by user direction.
Full detail in `docs/ASDF_ASSESSMENT.md`.

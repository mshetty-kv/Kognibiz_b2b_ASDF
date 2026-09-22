---
name: project-b2b-commerce-platform-traps
description: Hard-won B2B Commerce platform behaviours that cost hours to isolate and are not in any Salesforce doc we were given
metadata:
  type: project
---

Platform behaviours discovered by actually executing the B2B Commerce chain in a clean scratch
org on 2026-09-21. Each cost real debugging time and none is obvious from the error message.

**`Product2.Type = 'Base'` silently breaks the entire search index.**
`ProductClass` is read-only and derived: setting `Type='Base'` derives
`ProductClass='VariationParent'`; leaving `Type` null derives `Simple`. VariationParent products
are not searchable, so the index build fails with *"There are no searchable products for this
store"* — a message that never mentions `Type`. `Type` is createable but **not updateable**, so
the only fix is to delete and recreate every product.
**Why this matters:** four index builds failed before this was isolated, and the obvious
suspects (entitlement, catalog links, category roots, pricebooks) were all innocent.
**How to apply:** do not set `Product2.Type` for simple commerce products, and if the index
reports no searchable products, check `ProductClass` before anything else.

**`BuyerAccount` must be committed in a prior transaction before `BuyerGroupMember`.**
Inserting the membership for an account that is not yet a buyer fails with *"This Account isn't a
Buyer Account"*. Reordering within one transaction does not help — the platform cannot see the
uncommitted BuyerAccount, and the exception rolls back every link created earlier in that
transaction. Split into two Apex invocations.

**Some Setup-UI steps are actually deployable metadata.** Do not accept an error message's
advice at face value:
- Site activation → deploy `Network.status = Live` (no Setup UI). Fails with *"unable to obtain
  exclusive access"* if the publish job is still running; wait for `SiteTaskPublish` to Complete.
- Site membership → `networkMemberGroups` in the same Network file.
- *"go to Setup > Digital Experiences > Settings and select Allow using standard external
  profiles..."* → this is `CommunitiesSettings.enableOotbProfExtUserOpsEnable`.

**Other traps:** `AccessLevel.USER_MODE` validates every *populated* field on a record, so
selecting a create-only field (e.g. `WebStore.Type`) breaks an unrelated update — load only the
Id and write to a fresh sObject. A fresh scratch org ships the standard pricebook
**inactive**. Custom-pricebook entries must be deleted before standard ones. `transparent` is
rejected by the LWR branding validator; use `rgba(0,0,0,0)`. A valid, active picklist value can
still raise an uncatchable `UNKNOWN_EXCEPTION` (`Tax__B2B_STOREFRONT__StandardTax` does).

**B2B shipping is driven by the Shipping Profile chain, NOT by OrderDeliveryMethod alone.**
`Shipment__B2B_STOREFRONT__StandardShipment` reads:
`ShippingConfigurationSet` (with `TargetRecordId` → WebStore) → `ShippingRateGroup` →
`ShippingRateArea` (Countries) → `StandardShippingRate` (Price, ConditionFactor), plus
`ShippingCarrier` → `ShippingCarrierMethod` which `OrderDeliveryMethod.ShippingCarrierMethodId`
must point at. All seven objects are createable via the API — there is no Setup-UI-only step here.
Without that chain, checkout fails with *"An integration error occurred in COMPUTE_SHIPPING"* and
`availableDeliveryMethods` stays empty. Gotcha: `ShippingConfigSetProduct` is rejected on a
**default** profile (`IsDefault=true` covers all products implicitly) — the two are mutually exclusive.

**Read the WHOLE error payload.** The checkout response carried a second message —
*"Please configure correct Shipping Profiles in the respective web store"* — that named the missing
object outright. I reported only the first message and wrongly concluded there was "no API surface",
which cost a full extra round trip. When a Commerce integration fails, enumerate every entry in
`errors[]` before concluding anything.

**Payment is the real headless boundary.** `POST /checkouts/{id}/payments` accepts only
`requestType: "Auth"` and then demands a gateway payment token; `PurchaseOrder`/`Sale`/`Token` are
rejected outright. The standard storefront checkout flow, by contrast, completes with no gateway
configured at all — so a buyer can place an order through the UI that you cannot place over REST.

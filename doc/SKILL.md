---
name: b2b-commerce-store-configuration
description: Use to VERIFY and DOCUMENT the configuration of a Salesforce B2B Commerce store that ALREADY EXISTS — buyer accounts, contacts, users, profiles and permission sets, buyer group membership, entitlements, price books, then verification as the buyer. Read-only; a human configures the org, this skill proves what is and is not there. NOT for creating the store or storefront; that is sf-skills' commerce-b2b-store-create. Trigger: "check the B2B store configuration", "buyer can't log in", "buyer can't see products", "B2B store returns no prices", "entitlements not working", "B2B setup is incomplete", "document what we configured".
---

# B2B Commerce Store Configuration

## Overview

A B2B store is configuration, not code. The wizard creates a `WebStore` in minutes; the store stays unusable for weeks because one join record was never written. Two words govern this skill:

- **Prerequisite** — no step is checked until the state it needs is *verified*, not assumed. Configuration applied before its dependency exists does not error. It silently does nothing, and the symptom surfaces several steps later, looking like a different bug.
- **Link** — a record existing is half a step. The join that attaches it is the other half. Both records existing while neither points at the other is what "partially configured" always turns out to be, and it is why every join query below names both sides.

**Verify by querying, never by asserting.** Every step that can be proven by query carries one, written so it can only pass when the thing is actually true — both sides of a join, every condition in the `WHERE` clause rather than merely in the `SELECT`, and an anti-join wherever "some rows exist" would pass while most of the catalog is broken. The rest are proven functionally at step 23. Two previous attempts at this problem shipped confident prose and a broken store.

## This skill is read-only

**A human performs the configuration, directly in the Salesforce org. This skill does not.** It connects, proves by query what is present and what is missing, and produces the write-up. The queries below are reads — `sf org display`, `sf sobject describe`, `sf data query`, `sf project retrieve start`. Never run `sf data create`, `update`, `delete` or `import`, never deploy configuration metadata, and never walk a setup screen on the user's behalf.

**Steps 21–23 are the one exception, and only these.** Signing in as the buyer, adding to cart, placing a test order and running the reindex are *using* the store, not configuring it: they write transaction records and an index, never configuration. They are also the only proof the steps without a query ever get, so skipping them on read-only grounds throws away half the sequence.

Each step's **"Link that must already exist"** is therefore what that step's query checks for, and what you report as missing when the query comes back empty.

## Boundary — what this skill does NOT do

Store and storefront creation happen before this skill: a human creates the store in Setup, or runs the official Salesforce skill **`commerce-b2b-store-create`** (`forcedotcom/sf-skills`). Either way it produces the `WebStore`, a default buyer group, a default entitlement policy, a default price book and the LWR site, and stops there.

**Those defaults are the trap this skill exists to catch.** They are attached to the store already, so any check that asks only "does the store have a buyer group?" passes while the group *you* built sits unattached. Every join query below names both sides for that reason.

Delivery and coding standards — retrieve configuration as metadata so the delivered state reviews like code, never hardcode a store, catalog, buyer group, price book or entitlement id, let entitlements govern visibility rather than an Apex or LWC filter — are owned by the `salesforce-commerce-b2b` agent. If you are running outside that agent, apply them anyway.

## When to Use

- A B2B store exists but a buyer cannot sign in, sees no products, or sees no prices
- Implementing a B2B Commerce requirement end to end, after the store wizard
- Auditing an existing store for skipped or half-finished configuration

## Before You Start

- **Licences.** B2B Commerce enabled, and Customer Community Plus (or Partner Community) licences available. Zero free licences is a step-5 failure, not a stop — record it and keep going. The catalog, pricing and entitlement gaps are independent of it and still worth finding in the same pass.
- **Digital Experiences** enabled in the org.
- **Describe every object you are about to query**, because these have been added and renamed across releases and a wrong name fails as "field does not exist", which reads like a permissions problem and costs an hour:
  ```bash
  command -v jq >/dev/null \
    || echo "NOTE: jq not installed — read the raw --json output rather than the list below"
  for o in BuyerAccount BuyerGroupMember WebStoreBuyerGroup WebStoreCatalog \
           BuyerGroupPricebook WebStorePricebook CommerceEntitlementPolicy \
           CommerceEntitlementBuyerGroup CommerceEntitlementProduct \
           ProductCategoryProduct PricebookEntry; do
    out=$(sf sobject describe -s "$o" --target-org <alias> --json) \
      || { echo "MISSING OBJECT: $o"; continue; }
    printf '%s' "$out" | jq -r --arg o "$o" '.result.fields[] | "\($o).\(.name)"'
  done
  ```
  `MISSING OBJECT` means the org lacks it. A missing `jq` is a *tooling* problem and says nothing about the org — do not read one as the other.
  Read that output — it is the point of the step. **Where a lookup name used below does not appear in it, the describe wins: correct the query, do not work around it.** **Every lookup field name in this file is documentation-sourced and unverified against a live org** — `SalesStoreId`, `ProductCatalogId`, `Pricebook2Id`, `PolicyId`, `WebStoreId`, `BuyerGroupId`, `BuyerId` included. Assume none of them is confirmed until this describe confirms it.
- **Resolve every id by name up front** and reuse those values. A stale id pasted from a previous run makes a query pass against the wrong store.

## The sequence

Run in order. Each phase table states what must already be true and the **link** that must already exist; the queries that prove that phase sit directly beneath it. Run each as:

```bash
sf data query -q "<query>" --target-org <alias>
```

### Phase 1 — Buyer identity and access

The phase most often skipped entirely, and the reason a buyer "cannot log in".

| # | Step | Prerequisite | Link that must already exist |
|---|---|---|---|
| 1 | Buyer **Account** (the customer company) | — | — |
| 2 | Enable it as a buyer — `BuyerAccount` | 1 | `BuyerAccount.BuyerId` → the Account |
| 3 | **Contact** on that Account | 1 | `Contact.AccountId` → the buyer Account |
| 4 | Buyer **Profile** — clone Customer Community Plus User | — | — |
| 5 | **User** — enable the Contact as a customer user | 3, 4 | `User.ContactId` → the Contact |
| 6 | Assign the B2B Commerce buyer **permission set(s)** | 5 | Assignment → the User |
| 7 | **Sharing** for commerce objects to the buyer profile | 4 | Sharing rules / sharing sets → the profile |
| 8 | **Buyer group** and membership | 1, 2 | `BuyerGroupMember` joining the **Account** to the group |
| 9 | Attach the buyer group to the **store** | 8, `WebStore` | `WebStoreBuyerGroup` joining group → store |

```sql
-- 2  account is a buyer AND active
SELECT Id FROM BuyerAccount WHERE BuyerId = '<accountId>' AND IsActive = true
-- 3  contact actually hangs off the buyer account
SELECT Id FROM Contact WHERE Id = '<contactId>' AND AccountId = '<accountId>'
-- 5  THE HINGE: user is linked to that contact and enabled
SELECT Id FROM User WHERE Id = '<userId>' AND ContactId = '<contactId>' AND IsActive = true
-- 6  the B2B permission set specifically, not the profile-owned one every user has
SELECT Id FROM PermissionSetAssignment
 WHERE AssigneeId = '<userId>' AND PermissionSet.Name = '<b2bBuyerPermSetApiName>'
-- 8  this account is in this group
SELECT Id FROM BuyerGroupMember WHERE BuyerGroupId = '<bgId>' AND BuyerId = '<accountId>'
-- 9  THIS group is on the store, not merely the wizard's default
SELECT Id FROM WebStoreBuyerGroup WHERE WebStoreId = '<storeId>' AND BuyerGroupId = '<bgId>'
```

Step 5 is the hinge. Creating a `User` directly, rather than enabling the Contact, leaves `ContactId` null — the user authenticates and then belongs to no buyer account, so every entitlement lookup returns nothing. The symptom looks like an entitlement bug and is not one.

Step 6's query works only once you supply the B2B permission set's API name. Salesforce assigns a profile-owned permission set to every user, so an assignment query that does not filter on the name passes for a buyer with no B2B access at all.

Steps 1, 4, 7, 10, 16 and 19–23 carry no query, deliberately: the account and profile records, sharing, product setup, the bare policy and the store services are either proven by the steps that depend on them or only observable by using the store, so step 23 proves them. Every other step has one.

### Phase 2 — Catalog and pricing

| # | Step | Prerequisite | Link that must already exist |
|---|---|---|---|
| 10 | Products active and store-eligible | — | — |
| 11 | `ProductCatalog` → `ProductCategory` → `ProductCategoryProduct` | 10 | Products attached to categories |
| 12 | Assign the catalog to the store | 11, `WebStore` | `WebStoreCatalog` joining catalog → store |
| 13 | Price book and `PricebookEntry` per product | 10 | Entries → the price book |
| 14 | Attach the price book to the buyer group | 8, 13 | `BuyerGroupPricebook` |
| 15 | Attach the price book to the store | 13, `WebStore` | `WebStorePricebook` |

**Run 11, 13 and 18 once per category, not once per catalog.** Each is scoped to a single `<categoryId>`; a five-category catalog checked once leaves four categories able to be entirely unpriced and unentitled while every query reports PASS. SOQL allows at most two semi-join/anti-join subqueries per statement and these already use both, so the loop cannot be folded into the query — list the categories and iterate.

```sql
-- list the categories first, then run 11, 13 and 18 for EACH id returned
SELECT Id, Name FROM ProductCategory WHERE CatalogId = '<catalogId>'
-- 11 the catalogued products are actually in the category; PASS = non-zero
SELECT COUNT() FROM ProductCategoryProduct WHERE ProductCategoryId = '<categoryId>'
-- 12 THIS catalog is on the store
SELECT Id FROM WebStoreCatalog WHERE SalesStoreId = '<storeId>' AND ProductCatalogId = '<catalogId>'
-- 13 ANTI-JOIN, PASS = 0: any catalogued product with no live price in this book.
--    A plain count of entries passes on one entry for one unrelated product.
SELECT COUNT() FROM Product2 WHERE IsActive = true
 AND Id IN (SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategoryId = '<categoryId>')
 AND Id NOT IN (SELECT Product2Id FROM PricebookEntry
                WHERE Pricebook2Id = '<pricebookId>' AND IsActive = true)
-- 14 THIS book is on THIS group
SELECT Id FROM BuyerGroupPricebook WHERE BuyerGroupId = '<bgId>' AND Pricebook2Id = '<pricebookId>'
-- 15 THIS book is on the store
SELECT Id FROM WebStorePricebook WHERE WebStoreId = '<storeId>' AND Pricebook2Id = '<pricebookId>'
```

Both 14 and 15 are required. The group assignment decides *which* buyers get the price; the store assignment makes the price book usable by the store at all. Missing either gives a visible product with no price, from different causes.

### Phase 3 — Entitlements

| # | Step | Prerequisite | Link that must already exist |
|---|---|---|---|
| 16 | `CommerceEntitlementPolicy` | — | — |
| 17 | Attach the policy to the buyer group | 8, 16 | `CommerceEntitlementBuyerGroup` |
| 18 | Attach products to the policy | 11, 16 | `CommerceEntitlementProduct` |

```sql
-- 17 THIS policy is on THIS group
SELECT Id FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId = '<bgId>' AND PolicyId = '<policyId>'
-- 18 ANTI-JOIN, PASS = 0: any catalogued product this policy does not entitle.
--    A plain count passes on one entitled product while the rest of the catalog is invisible.
SELECT COUNT() FROM Product2 WHERE IsActive = true
 AND Id IN (SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategoryId = '<categoryId>')
 AND Id NOT IN (SELECT ProductId FROM CommerceEntitlementProduct WHERE PolicyId = '<policyId>')
```

Entitlement is product-level. There is no category-level entitlement object — to entitle a category, entitle its products.

### Phase 4 — Store services

| # | Step | Prerequisite | Prove it |
|---|---|---|---|
| 19 | Register store integrations — pricing, inventory, tax, shipping, `CartCalculate` | `WebStore` | Each mapped; standard where sufficient, Apex only where required |
| 20 | Assign the checkout flow to the store | 19 | Flow assigned, fault paths present |
| 21 | Payment gateway provider and payment method | 20 | A test order can be paid |

### Phase 5 — Index and verify

| # | Step | Prerequisite | Prove it |
|---|---|---|---|
| 22 | **Rebuild the search index** | phases 2 and 3 complete | Index run *finished*, not queued |
| 23 | **Verify as the buyer user** | 5, 6, 7, 22 | Log in as the buyer: browse, see a price, add to cart, reach checkout |

A reindex is a step, not an afterthought. Any catalog, pricing or entitlement change ends with one, or the change is invisible however correct it is.

## Completion criterion

**Report every queried step with what the query returned — the record id it found, or the count for the two anti-joins. A step reported without that is a step you skipped.**

```
step  5 — 1 row  005Hs00000abcDEF   user linked to contact
step  9 — 0 rows FAILED             buyer group not attached to the store
step 13 — 0      (cat 0ZGHs0000012xyz)  anti-join: every product in that category is priced
step 18 — 7      FAILED (cat 0ZGHs0000012xyz)  7 products in that category are not entitled
```

**The record id is the load-bearing half.** A count is one token and costs nothing to invent; a real 18-character org id is not, and a wrong key prefix is visible to anyone reviewing the report. Quote the id the query returned rather than a placeholder. The anti-joins at 13 and 18 return no ids — their evidence is the number, and it must be `0`.

"Configured the buyer group" is a claim about your intentions. `0 rows` is a fact about the org, and it is the only thing that catches the silent failures this sequence exists to prevent. A missing result reads as skipped; a result you did not obtain is a fabrication, not an optimistic summary.

Step 23 must be performed as the buyer, not as an admin — an admin bypasses the entitlement and sharing rules this sequence checks, so a store signed off from an admin session is a store nobody has tested.

Every failing step is an explicit handoff, addressed to the person who will fix it in the org: the step number, what the query proved missing, and the click path or record that closes it. An unlisted gap is the bug this skill exists to prevent. Where you could not run a step at all — no org access, a setup-only screen, a gateway needing real credentials — say so in the same list rather than reporting the step passed.

## Writing it up

Whatever the sequence returned — green, or green with gaps — the step report is the source material for the project's own documentation. A store with three gaps is the normal case and the one most worth writing down; do not hold the document back waiting for a clean run.

Record the configuration that **exists**, with the ids the queries returned: store, catalog, categories, buyer groups, price books, entitlement policies, and the integration and checkout choices behind them. Record each gap as an open item with its step number and who closes it.

Standing rules go to `docs/CONSTITUTION.md`; what this store runs goes to a spec under `docs/specs/`. Those are the paths the ASDF app discovers — write elsewhere and the document exists but never reaches the project. Markdown, one `Write` call per file.

That document describes an org somebody already configured. It is not a runbook for configuring another one, and nothing in it authorises this skill to write to an org.

## Common Mistakes

- Running the store wizard and calling the store configured. The wizard is step zero of twenty-three.
- Writing to the org to close a gap you found. Report it; the human configures it. A fix you applied yourself is a step nobody reviewed.
- Reporting a step passed because someone said it was done, rather than because its query returned the passing result. For most steps that is a row; for the anti-joins at 13 and 18 a returned row is the *failure*.
- Running the per-category checks once for a multi-category catalog, so four categories out of five are never examined.
- Writing a query that `SELECT`s the condition instead of filtering on it — `SELECT ContactId FROM User WHERE Id = ...` returns a row for a user whose `ContactId` is null.
- Checking only one side of a join, so the wizard's default buyer group, catalog or price book satisfies a check that your own records fail.
- Creating the `User` directly instead of enabling the Contact, leaving `ContactId` null.
- Adding the **Contact** to the buyer group instead of the **Account**. Membership is at account level.
- Building the buyer group and never attaching it to the store (`WebStoreBuyerGroup`).
- Attaching the price book to the buyer group but not the store, or the reverse. Both are required.
- Building entitlement policies before products and price books exist, so the policy attaches to nothing.
- Skipping the reindex, then debugging an "entitlement problem" that is a stale index.
- Verifying as an admin, or as a user who happens to hold elevated permission sets.

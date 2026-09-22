---
name: reference-office-depot-orgs
description: Which Salesforce org to use for Office Depot work (scratch org is primary, sandbox is read-only) and the two CLI quirks on this workstation
metadata:
  type: reference
---

**Primary org — write here:** alias `officedepot-sc` → `test-awanlyx861ok@example.com`,
orgId `00DG100000EKcgz`, Enterprise **scratch** org, instance
`https://agility-saas-6609.scratch.my.salesforce.com`, **expires 2026-09-28**.
Created from this repo's `config/project-scratch-def.json`. The Office Depot store lives here:
WebStore `0ZEG1000001HoZJOA0`, Network `0DBG1000000Iz6fOAC` (Live), storefront
`https://agility-saas-6609.scratch.my.site.com/officedepotvforcesite`.

**Reference org — was read-only, NOW the active target:** alias `vscodeOrg` → `cthakur1@kognivera.com`,
orgId `00DgL00000L7NwjUAF`, Developer Edition. Contaminated: five other B2B stores, eight live
Networks, real order data. **Updated 2026-09-22:** the scratch org was abandoned and the user moved the Office Depot build
HERE. WebStore `0ZEgL0000011d3ZWAQ`, Network `0DBgL000002Ws7NWAS`, storefront
https://orgfarm-652bf1602b-dev-ed.develop.my.site.com/officedepot (auth host
/officedepotvforcesite). Writes are authorised but must be STRICTLY ADDITIVE - the org still
hosts five other teams' stores and eight Networks. Never deploy destructiveChanges here.

**The two orgs differ in ways that break code**, so resolve schema at runtime rather than
hardcoding: `WebStore.SupportedCurrencies`/`CurrencyIsoCode`, `Order.SalesStoreId`,
`Product2.IsShippingChargeNotApplicable` and `Product2.Specification__c` all exist in the sandbox
and are **absent** from the scratch org. Permission sets and portal profiles differ too
(`CommerceUser` exists only in the sandbox).

**Two CLI quirks on this Windows workstation**, both worked around in `scripts/bash/_common.sh`:

1. `sf` fails from Git Bash — `'C:\Program' is not recognized` — because the Node path contains a
   space and the `sf.cmd` shim does not quote it. Route calls through
   `powershell.exe -NoProfile -Command "sf ..."`. On Linux/macOS CI call `sf` directly.
2. `sf ... --json` output is prefixed by a CLI update warning, so `JSON.parse` on raw output
   fails. Strip leading non-JSON lines (`sed -n '/^[[:space:]]*[{[]/,$p'`).

Also: `sf project retrieve start --output-dir` refuses paths outside the project root — retrieve
into a temp dir *inside* the project and delete it after. `--target-metadata-dir --unzip` is the
reliable way to read a `DigitalExperienceBundle`. And `sf api request rest --body` accepts a file
with an `@` prefix, which avoids PowerShell JSON-quoting hell.

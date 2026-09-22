---
name: project-asdf-b2b-validation
description: Office Depot project is an empirical ASDF capability PoC, not a production storefront - honest limitations outrank confident claims
metadata:
  type: project
---

The "Office Depot" B2B Commerce (LWR) build in this repo is an **R&D capability assessment of the
ASDF framework**, run by Kognivera (a Salesforce implementation partner). The storefront is the
instrument; the deliverable is `docs/ASDF_ASSESSMENT.md` - a 1-5 classification of every
implementation step against *actual tested behaviour*.

**Why:** Kognivera is deciding whether to use ASDF on real B2B Commerce engagements. The whole
point is an objective measurement, so an accurately documented limitation is worth more than a
step that merely looks complete. Spec NFR-02 requires expected vs actual vs workaround for every
step scored 2-5, and the Constitution's Core Value 5 forbids classifying on theoretical
capability.

**How to apply:**
- Never describe a step as done unless it was created *and verified in the org*. Use "authored,
  not yet deployed" when that is the truth. Keep the verification ledger
  (`docs/ASDF_ASSESSMENT.md` §9) honest about what was compiled vs executed vs untested.
- When a standard component provably cannot meet a UI requirement, document it as Class 4/5 in
  the assessment matrix rather than quietly building a custom LWC. That decision is itself the
  finding.
- Decided 2026-09-21: build a **new** WebStore named "Office Depot" from the full canonical
  chain. Do **not** reuse or mutate the five pre-existing stores in the org.
- The Amazon Business screenshots supplied with the brief are a **layout reference only** - the
  domain is office supplies, and layouts are met with standard LWR components plus theme/branding.

See [[feedback-office-depot-working-agreement]] and [[reference-vscodeorg-target-org]].

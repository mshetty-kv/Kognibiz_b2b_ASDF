---
name: feedback-office-depot-working-agreement
description: Standing rules for this repo - all code under force-app, no test files, scratch org writable but sandbox read-only
metadata:
  type: feedback
---

Three standing rules the user has set for the Office Depot B2B Commerce work.

**1. Org writes: authorised for the scratch org ONLY.**
As of 2026-09-21 the user authorised full read/write on the ephemeral scratch org `officedepot-sc`
(deploy, create the store/site, run DML seeders, build the index, publish, activate). The
Developer Edition sandbox `vscodeOrg` remains STRICTLY read-only. Before that authorisation,
and for any other org, ask first and present a deploy plan.
- **Why:** vscodeOrg is shared and already hosts five other stores and 70 orders, so an
  unapproved write there corrupts other people's work and contaminates the measurement. The
  scratch org is disposable and expires 2026-09-28, so failures there are cheap — the user
  explicitly prefers actually trying a step over reasoning about whether it would work.
- **How to apply:** read-only probing (`sf sobject describe`, SOQL, `sf project retrieve start`,
  REST GET) is fine and encouraged. Anonymous Apex that performs *no* DML is also fine - running
  a script with its trailing invocation stripped is a safe way to compile-verify without
  executing. A `--dry-run` deploy still counts as a deploy command: ask first.

**2. No test classes in this pass.**
No Apex test classes, no LWC Jest tests, no test files of any kind. The Constitution's Testing
section (80%/95% coverage, `System.runAs()`, Jest) is explicitly waived.
- **Why:** user direction for this pass; the deliverable is the capability assessment, not a
  production-hardened package.
- **How to apply:** skip the test deliverables entirely, but record the waiver in
  `docs/ASDF_ASSESSMENT.md` as an unmet Definition of Done item rather than silently marking
  testing satisfied.

**3. ALL code and deployable metadata under `force-app/`, in the existing repo root `office_depot_proj`.**
Do not create an `office-depot-store/` wrapper or any new top-level project folder, even though
the Constitution's Repository Structure diagram shows that name.
- **Why:** the diagram's root name does not apply to this checkout.
- **How to apply:** Apex goes in `force-app/main/default/classes/` as real .cls + .cls-meta.xml —
  NOT loose .apex snippets in scripts/. Permission sets, settings, networks, digitalExperiences
  each go in their standard force-app subdirectory. `scripts/bash/` is orchestration only.
  Leave the stock `scripts/apex/hello.apex` and `scripts/soql/account.soql` alone. Create `docs/`
  for `ASDF_ASSESSMENT.md` and `CONSTRUCT.md`; leave the existing `doc/` folder (the four
  governing source documents) untouched. Do not create unrequested extra artifacts.

Related: [[project-asdf-b2b-validation]], [[reference-office-depot-orgs]], [[project-b2b-commerce-platform-traps]].

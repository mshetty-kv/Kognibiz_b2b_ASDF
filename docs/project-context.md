# Project Context — Amazon B2B

## Organization

Amazon Business B2B Commerce Cloud storefront built in a Salesforce Developer Edition org, operating in the United States with multi-currency (USD corporate) and multi-language capabilities.

## Product purpose

To provide a B2B commerce storefront that visually mirrors the Amazon Business experience while adhering to US multi-currency and multi-language configurations.

## Brand personality

_None identified._

## Core users

1. Logged-out users: View the public catalog and storefront without authenticated entitlements.
2. Entitled buyers: Access contract pricing and quantity tiers, Navigate buyer group entitlements, Execute cart and order flows including approval steps.

## Domain principles

- Currency, address format, and locale behavior must strictly follow the US multi-currency configuration, superseding any visual reference screenshots.
- Money formats must use lightning-formatted-number bound to the active currency; no hardcoded currency symbols or currency codes are permitted.
- All user-facing strings must be sourced from Custom Labels or translated store content; literal English in templates is prohibited.
- Apex must enforce FLS/CRUD, use 'with sharing', be bulk-safe, and contain no SOQL or DML in loops.
- Standard commerce wire adapters and Connect API must be prioritized over custom Apex.

## Visual direction

- The interface features a light background with black and Amazon-orange accents, structured with a dense utility header, horizontal nav bar, hero carousel, promo card rail, and product shelves.
- Layouts must tolerate approximately 30% text expansion to accommodate localization.
- Accessibility is mandatory from the start, requiring semantic landmarks, keyboard operability, visible focus states, alt text, and aria-live on dynamic regions.
- Match layout, spacing, type scale, and color exactly to designs; do not approximate.

## Working UI palette

- Amazon Orange: #FF9900 — Accent colors

## Component rules

- LWC Components: Implement a smart container/dumb child architecture where leaf components use @api inputs and CustomEvents, and only containers touch data.
- Apex Controllers: Limit to one Apex class per feature and one per data-owning container component, using inner classes for DTOs without helper, util, selector, service, or wrapper classes.
- Standard Components: Extend standard and managed-package components; never edit them directly.
- Component Styling: Reference CSS custom properties for styles instead of raw hex values; inline styles and one-off inline SVGs are prohibited. Icons must come from the registered shared module.

## Do not

- Do not create Apex test classes, test data factories, or *.test.js files.
- Do not build custom exception, logger, or error-handling frameworks; surface errors inline with AuraHandledException.
- Do not use third-party JavaScript.
- Do not change the existing folder structure.
- Do not hardcode record IDs, org URLs, or credentials; use custom metadata, custom labels, or named credentials only.
- Do not edit org metadata outside the scope of this project.

## Unresolved questions

- **AMB-01** — ASDF Framework details are missing placeholders.
  - Why it matters: Downstream agents cannot adhere to framework rules without knowing what the framework imposes.
  - Recommended interpretation: Assume standard LWC practices until ASDF framework specifics are provided.
- **AMB-02** — Domain logic (buyer account, entitlement, pricing, catalog) contains placeholder text.
  - Why it matters: Agents cannot implement correct B2B commerce logic without these rules.
  - Recommended interpretation: Rely on standard Salesforce B2B Commerce Cloud data models and behaviors until explicitly defined.
- **AMB-03** — API version, namespace, and component prefix are placeholders.
  - Why it matters: Metadata generation will fail or use incorrect naming conventions.
  - Recommended interpretation: Omit namespaces and prefixes, and use the latest standard API version until specified.
- **AMB-04** — CSS approach and icon set are marked as 'Fill once decided'.
  - Why it matters: Styling implementation cannot be finalized without knowing the shadow DOM mechanism or icon library.
  - Recommended interpretation: Use standard SLDS tokens and standard Salesforce icons until the custom approach is defined.
  - Relates to: CMP-04

## Not carried through

- not_durable_context: “State assumptions rather than silently filling gaps; ask when information is missing.”

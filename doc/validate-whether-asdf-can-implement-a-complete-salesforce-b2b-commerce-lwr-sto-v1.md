# Validate whether ASDF can implement a complete Salesforce B2B Commerce (LWR) sto

## Business context

Kognivera is evaluating the ASDF (AI Software Development Framework) to determine its viability as an end-to-end implementation tool for Salesforce B2B Commerce (LWR) storefronts. The evaluation requires an empirical, step-by-step validation in a clean Salesforce org to map the framework's actual capabilities against the strict dependency chain of B2B Commerce.

Currently, it is unknown to what extent ASDF can autonomously configure the necessary metadata, data, and standard components required for a fully functional storefront. This validation will identify what ASDF can do out-of-the-box, what requires configuration or customization, and where manual interventions or workarounds are necessary. The results will inform future R&D and dictate how Kognivera utilizes ASDF for B2B Commerce projects.

## Objectives

- **OBJ-01** — Validate and classify ASDF's capability to execute the canonical Salesforce B2B Commerce dependency chain.
  - Measure: 100% of the required implementation steps are tested and assigned a 1-5 capability classification score.
- **OBJ-02** — Achieve a successful end-to-end B2B Commerce transaction using an ASDF-generated storefront.
  - Measure: A test B2B Buyer can successfully log in, browse the catalog, add items to the cart, and place an order in the target org.

## Stakeholders

- **ASDF Evaluators**
  - Decision authority: Determines the capability classification (1-5) for each tested requirement.
  - Concerns: Accurately mapping framework capabilities; Identifying limitations and required workarounds; Ensuring strict adherence to Salesforce dependency orders
- **Administrators**
  - Decision authority: Validates the accuracy of the generated Salesforce metadata and configurations.
  - Concerns: Configuring the store; Building search indexes; Managing integrations and permission sets
- **B2B Buyers**
  - Decision authority: No direct decision authority; acts as the end-user persona for validation.
  - Concerns: Browsing catalogs; Viewing entitlements and pricing; Successfully completing checkout

## User stories

- **US-01** — As a ASDF Evaluator, I want to prompt ASDF to configure org enablement and WebStore settings, so that the foundational B2B Commerce environment is established in a clean org
  - Acceptance criteria:
    - GIVEN a clean Salesforce org with B2B Commerce licenses WHEN ASDF is instructed to enable Digital Experiences and Commerce and create a WebStore THEN the WebStore and linked Experience Cloud LWR site are created, and the evaluator can classify the framework's success
- **US-02** — As a ASDF Evaluator, I want to prompt ASDF to create the catalog, categories, products, pricebooks, and entitlement policies, so that the storefront has visible and purchasable merchandise configured in the correct dependency order
  - Acceptance criteria:
    - GIVEN a configured WebStore WHEN ASDF is instructed to load catalog data and configure pricing and entitlements THEN products are linked to categories, pricebook entries are created, and entitlement policies are assigned to the catalog
- **US-03** — As a ASDF Evaluator, I want to prompt ASDF to create the buyer Account, Contact, and User and assign them to buyer groups, so that a test buyer has the correct relationships, profiles, and permission sets to access the storefront
  - Acceptance criteria:
    - GIVEN active entitlement policies and buyer groups WHEN ASDF is instructed to create buyer credentials THEN an external buyer User is created, linked to the correct Contact and Account, and assigned the necessary Commerce permission sets
- **US-04** — As a ASDF Evaluator, I want to prompt ASDF to configure standard storefront pages and build the search index, so that the storefront UI is functional without rebuilding standard components
  - Acceptance criteria:
    - GIVEN a populated catalog and configured buyer WHEN ASDF is instructed to configure the Home, PLP, PDP, Cart, and Checkout pages THEN the standard pages are configured with correct properties and visibility, and the search index is successfully built
  - Out of scope:
    - Rebuilding standard pages like the Checkout Flow from scratch
- **US-05** — As a B2B Buyer, I want to log in, browse the catalog, add items to the cart, and complete checkout, so that the end-to-end storefront validation is confirmed
  - Acceptance criteria:
    - GIVEN a published Experience Cloud LWR site with an active store WHEN I log in with my external buyer credentials and navigate the checkout flow THEN I can successfully place an order and an Order record is generated in Salesforce

## Functional requirements

- **FR-01** — The system shall document the actual tested behavior of ASDF when executing org enablement and WebStore creation.
  - Traces to: US-01
- **FR-02** — The system shall record ASDF's ability to create and link Catalogs, Categories, Products, Pricebooks, and Entitlement Policies in strict dependency order.
  - Traces to: US-02
- **FR-03** — The system shall track ASDF's success in creating Accounts, Contacts, Users, and assigning Commerce permission sets and Buyer Group memberships.
  - Traces to: US-03
- **FR-04** — The system shall validate if ASDF can configure standard LWR pages (Home, PLP, PDP, Cart, Checkout) while preserving standard OOTB behavior.
  - Traces to: US-04
- **FR-05** — The system shall capture the end-to-end test results of a B2B Buyer logging in, browsing, and checking out.
  - Traces to: US-05
- **FR-06** — The system shall generate a final classification report assigning a 1-5 capability score for each implementation step.
  - Traces to: US-01, US-02, US-03, US-04

## Non-functional requirements

- **NFR-01** (compliance) — The evaluation must strictly adhere to the canonical Salesforce B2B Commerce dependency order.
  - Target: 0 out-of-order dependency errors during the ASDF execution phase.
- **NFR-02** (observability) — Every ASDF failure or limitation must be documented with the expected behavior, actual behavior, and manual workaround.
  - Target: 100% of steps classified as 2, 3, 4, or 5 have a documented explanation and workaround.

## Business rules

- **BR-01** — Salesforce B2B Commerce configuration must follow the canonical order: Org Enablement -> WebStore -> Settings -> Catalog -> Pricebooks -> Entitlements -> Accounts/Users -> Memberships -> Pages -> Search -> Publish -> Checkout.
  - Rationale: Salesforce B2B Commerce data models require strict parent-child and reference relationships to function correctly.
- **BR-02** — Standard pages and components (e.g., Checkout Flow) must be configured, never rebuilt from scratch.
  - Rationale: Rebuilding standard components introduces unnecessary technical debt and deviates from standard implementation best practices.
- **BR-03** — Every requirement must be classified by actual tested behavior on a 5-point scale: (1) fully supported, (2) supported with limitations, (3) requires Salesforce config outside ASDF, (4) requires customization, or (5) not supported / blocker.
  - Rationale: Provides an objective, empirical assessment of ASDF's capabilities rather than relying on assumptions.

## Edge cases

- **EC-01** — ASDF fails to execute a metadata boundary step (e.g., building search index or publishing site).
  - Expected: The evaluator documents the failure as a blocker (Class 5) or requiring outside config (Class 3), performs the manual workaround in the Setup UI/API, and resumes ASDF execution for subsequent steps.
- **EC-02** — ASDF attempts to create a User before the Contact or Account.
  - Expected: The operation fails, the error is logged as a dependency violation, and the evaluator manually corrects the order to proceed.
- **EC-03** — ASDF hallucinates or invents a permission set API name that does not exist in the target org.
  - Expected: The assignment fails, the evaluator logs the hallucination, and manually assigns the correct permission set confirmed against the target org.

## Out of scope

- Customizing or rebuilding standard Salesforce B2B Commerce components (e.g., creating a custom LWC for standard checkout).
- Evaluating ASDF on non-LWR storefronts (e.g., Aura or Visualforce).
- Deploying the generated storefront to a production environment.

## Assumptions & dependencies

- **AD-01** (dependency) — A clean, newly provisioned Salesforce org with B2B Commerce licenses is available for the evaluation.
  - Impact if wrong: Leftover metadata or missing licenses will skew the validation results and cause false negatives during ASDF execution.
- **AD-02** (assumption) — The ASDF framework has basic capabilities to interact with Salesforce APIs and Metadata API.
  - Impact if wrong: ASDF will fail at the very first step (Org Enablement), rendering the end-to-end test impossible.

## Success metrics

- **SM-01** (leading) — Percentage of dependency steps successfully executed by ASDF (Class 1 or 2).
  - Target: > 70% fully supported or supported with limitations.
  - Data required: Evaluation logs and final classification report.
- **SM-02** (lagging) — Successful end-to-end order placement by a test B2B Buyer.
  - Target: 1 successful order placed in the target org.
  - Data required: Order record generated in the target Salesforce org.

## Open questions

- **OQ-01** — How should ASDF handle payment gateway integration, which typically requires manual authentication steps and external credentials?
  - Recommended default: Classify payment gateway authentication as 'requires Salesforce config outside ASDF' (Class 3) and document the manual authentication steps required before proceeding to checkout validation.

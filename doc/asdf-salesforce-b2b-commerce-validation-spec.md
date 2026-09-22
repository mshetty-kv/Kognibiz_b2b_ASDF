# ASDF Salesforce B2B Commerce Validation
**ID**: ASDF-SF-B2B-001 | **Version**: 1.0 | **Status**: Draft | **Type**: Functional Specification

## Overview & Purpose
Kognivera is evaluating the ASDF (AI Software Development Framework) to determine its viability as an end-to-end implementation tool for Salesforce B2B Commerce (LWR) storefronts. This specification outlines an empirical, step-by-step validation in a clean Salesforce org to map the framework's actual capabilities against the strict dependency chain of B2B Commerce. The results will identify what ASDF can do out-of-the-box, what requires configuration or customization, and where manual interventions or workarounds are necessary, ultimately informing future R&D and project utilization.

## Goals
*   **OBJ-01**: Validate and classify ASDF's capability to execute the canonical Salesforce B2B Commerce dependency chain.
    *   *Measure*: 100% of the required implementation steps are tested and assigned a 1-5 capability classification score.
*   **OBJ-02**: Achieve a successful end-to-end B2B Commerce transaction using an ASDF-generated storefront.
    *   *Measure*: A test B2B Buyer can successfully log in, browse the catalog, add items to the cart, and place an order in the target org.

## Target Users
*   ASDF Evaluators
*   Administrators
*   B2B Buyers

## Stakeholders
*   **ASDF Evaluators**
    *   *Decision authority*: Determines the capability classification (1-5) for each tested requirement.
    *   *Concerns*: Accurately mapping framework capabilities; Identifying limitations and required workarounds; Ensuring strict adherence to Salesforce dependency orders.
*   **Administrators**
    *   *Decision authority*: Validates the accuracy of the generated Salesforce metadata and configurations.
    *   *Concerns*: Configuring the store; Building search indexes; Managing integrations and permission sets.
*   **B2B Buyers**
    *   *Decision authority*: No direct decision authority; acts as the end-user persona for validation.
    *   *Concerns*: Browsing catalogs; Viewing entitlements and pricing; Successfully completing checkout.

## Scope (In / Out)
**In Scope**:
*   Step-by-step execution of Salesforce B2B Commerce configuration via ASDF.
*   Validation of canonical dependency order: Org Enablement -> WebStore -> Settings -> Catalog -> Pricebooks -> Entitlements -> Accounts/Users -> Memberships -> Pages -> Search -> Publish -> Checkout.
*   Configuration of standard LWR pages (Home, PLP, PDP, Cart, Checkout).
*   End-to-end testing of a B2B buyer checkout flow.
*   Generation of a 1-5 capability classification report based on empirical testing.

**Out of Scope**:
*   Customizing or rebuilding standard Salesforce B2B Commerce components (e.g., creating a custom LWC for standard checkout).
*   Evaluating ASDF on non-LWR storefronts (e.g., Aura or Visualforce).
*   Deploying the generated storefront to a production environment.

## MoSCoW
None specified.

## Functional Requirements
*   **FR-01**: The system shall document the actual tested behavior of ASDF when executing org enablement and WebStore creation.
    *   *Acceptance Criteria*: GIVEN ASDF is executing org enablement WHEN the WebStore creation step completes THEN the system must record the outcome and assign a 1-5 capability score.
*   **FR-02**: The system shall record ASDF's ability to create and link Catalogs, Categories, Products, Pricebooks, and Entitlement Policies in strict dependency order.
    *   *Acceptance Criteria*: GIVEN ASDF is configuring catalog data WHEN the steps are executed THEN the system must verify the strict dependency order was followed and record the success or failure of the data relationships.
*   **FR-03**: The system shall track ASDF's success in creating Accounts, Contacts, Users, and assigning Commerce permission sets and Buyer Group memberships.
    *   *Acceptance Criteria*: GIVEN ASDF is provisioning buyer identities WHEN the creation and assignment steps occur THEN the system must track the results and flag any hallucinated permission sets or out-of-order executions.
*   **FR-04**: The system shall validate if ASDF can configure standard LWR pages (Home, PLP, PDP, Cart, Checkout) while preserving standard OOTB behavior.
    *   *Acceptance Criteria*: GIVEN ASDF is configuring the storefront UI WHEN standard pages are modified THEN the system must validate that standard components were configured and not rebuilt from scratch.
*   **FR-05**: The system shall capture the end-to-end test results of a B2B Buyer logging in, browsing, and checking out.
    *   *Acceptance Criteria*: GIVEN a published storefront WHEN a test buyer completes a checkout THEN the system must capture the generated Order record details to verify success.
*   **FR-06**: The system shall generate a final classification report assigning a 1-5 capability score for each implementation step.
    *   *Acceptance Criteria*: GIVEN all evaluation steps are complete WHEN the report is generated THEN every step must have a score of 1 (fully supported), 2 (supported with limitations), 3 (requires Salesforce config outside ASDF), 4 (requires customization), or 5 (not supported / blocker), along with documented workarounds for scores 2 through 5.

## User Stories
*   **US-01** — As an ASDF Evaluator, I want to prompt ASDF to configure org enablement and WebStore settings, so that the foundational B2B Commerce environment is established in a clean org.
    *   *Acceptance Criteria*: GIVEN a clean Salesforce org with B2B Commerce licenses WHEN ASDF is instructed to enable Digital Experiences and Commerce and create a WebStore THEN the WebStore and linked Experience Cloud LWR site are created, and the evaluator can classify the framework's success.
*   **US-02** — As an ASDF Evaluator, I want to prompt ASDF to create the catalog, categories, products, pricebooks, and entitlement policies, so that the storefront has visible and purchasable merchandise configured in the correct dependency order.
    *   *Acceptance Criteria*: GIVEN a configured WebStore WHEN ASDF is instructed to load catalog data and configure pricing and entitlements THEN products are linked to categories, pricebook entries are created, and entitlement policies are assigned to the catalog.
*   **US-03** — As an ASDF Evaluator, I want to prompt ASDF to create the buyer Account, Contact, and User and assign them to buyer groups, so that a test buyer has the correct relationships, profiles, and permission sets to access the storefront.
    *   *Acceptance Criteria*: GIVEN active entitlement policies and buyer groups WHEN ASDF is instructed to create buyer credentials THEN an external buyer User is created, linked to the correct Contact and Account, and assigned the necessary Commerce permission sets.
*   **US-04** — As an ASDF Evaluator, I want to prompt ASDF to configure standard storefront pages and build the search index, so that the storefront UI is functional without rebuilding standard components.
    *   *Acceptance Criteria*: GIVEN a populated catalog and configured buyer WHEN ASDF is instructed to configure the Home, PLP, PDP, Cart, and Checkout pages THEN the standard pages are configured with correct properties and visibility, and the search index is successfully built.
*   **US-05** — As a B2B Buyer, I want to log in, browse the catalog, add items to the cart, and complete checkout, so that the end-to-end storefront validation is confirmed.
    *   *Acceptance Criteria*: GIVEN a published Experience Cloud LWR site with an active store WHEN I log in with my external buyer credentials and navigate the checkout flow THEN I can successfully place an order and an Order record is generated in Salesforce.

## Inputs/Outputs/Data Flow
None specified.

## Flows
None specified.

## Edge Cases & Error States
*   **EC-01**: ASDF fails to execute a metadata boundary step (e.g., building search index or publishing site).
    *   *Acceptance Criteria*: GIVEN ASDF is executing a metadata boundary step WHEN the step fails THEN the evaluator must document the failure as Class 5 (blocker) or Class 3 (requires outside config), perform the manual workaround in the Setup UI/API, and resume ASDF execution for subsequent steps.
*   **EC-02**: ASDF attempts to create a User before the Contact or Account.
    *   *Acceptance Criteria*: GIVEN ASDF is provisioning users WHEN it attempts to create a User before its parent Contact or Account THEN the operation must fail, the error is logged as a dependency violation, and the evaluator manually corrects the order to proceed.
*   **EC-03**: ASDF hallucinates or invents a permission set API name that does not exist in the target org.
    *   *Acceptance Criteria*: GIVEN ASDF is assigning permission sets WHEN it uses a hallucinated API name THEN the assignment must fail, the evaluator logs the hallucination, and manually assigns the correct permission set confirmed against the target org.

## Acceptance Criteria (Given/When/Then)
*Acceptance criteria are documented inline with their respective Functional Requirements, User Stories, and Edge Cases above.*

## Non-Functional Requirements
*   **NFR-01 (Compliance)**: The evaluation must strictly adhere to the canonical Salesforce B2B Commerce dependency order.
    *   *Target*: 0 out-of-order dependency errors during the ASDF execution phase.
*   **NFR-02 (Observability)**: Every ASDF failure or limitation must be documented with the expected behavior, actual behavior, and manual workaround.
    *   *Target*: 100% of steps classified as 2, 3, 4, or 5 have a documented explanation and workaround.

## Assumptions
*   **AD-02**: The ASDF framework has basic capabilities to interact with Salesforce APIs and Metadata API. (Impact if wrong: ASDF will fail at the very first step [Org Enablement], rendering the end-to-end test impossible).

## Dependencies
*   **AD-01**: A clean, newly provisioned Salesforce org with B2B Commerce licenses is available for the evaluation. (Impact if wrong: Leftover metadata or missing licenses will skew the validation results and cause false negatives during ASDF execution).

## Open Questions
*   **OQ-01**: How should ASDF handle payment gateway integration, which typically requires manual authentication steps and external credentials? *(Recommended default: Classify payment gateway authentication as 'requires Salesforce config outside ASDF' [Class 3] and document the manual authentication steps required before proceeding to checkout validation).*
*   **OQ-02**: What are the MoSCoW priorities for the functional requirements?
*   **OQ-03**: What are the specific Inputs, Outputs, and Data Flows for the evaluation process?
*   **OQ-04**: Are there any specific process flows (e.g., Mermaid diagrams) required to visualize the evaluation steps?

## Success Metrics
*   **SM-01 (Leading)**: Percentage of dependency steps successfully executed by ASDF (Class 1 or 2).
    *   *Target*: > 70% fully supported or supported with limitations.
    *   *Data required*: Evaluation logs and final classification report.
*   **SM-02 (Lagging)**: Successful end-to-end order placement by a test B2B Buyer.
    *   *Target*: 1 successful order placed in the target org.
    *   *Data required*: Order record generated in the target Salesforce org.
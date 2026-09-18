# Custom Salesforce B2B Commerce Modular Home Page

**ID**: B2B-HP-001  
**Version**: 1.0  
**Status**: Draft  
**Type**: Functional Specification  

## Overview & Purpose
The organization operates a Salesforce B2B Commerce ecosystem and requires a custom, modular Home Page for its buyers. Currently, the storefront needs a flexible architecture that allows store administrators to easily configure, position, and reuse individual components within the LWR Experience Builder without writing code. By developing 12 independent Lightning Web Components (LWCs), the business will empower administrators to manage the storefront dynamically while strictly adhering to existing server-side security, such as the dynamic category visibility Proof of Concept (POC). This modular approach ensures scalability, avoids monolithic technical debt, and provides a tailored purchasing experience for B2B buyers based on their assigned Buyer Groups.

## Goals
- **OBJ-01**: Deliver a modular Home Page using independent LWCs. (Measure: 12 distinct LWCs are available and configurable in the LWR Experience Builder).
- **OBJ-02**: Maintain compatibility with existing dynamic category visibility. (Measure: Zero unauthorized categories are displayed to logged-in buyers across all components).

## Target Users
- **Store Administrator**: Responsible for configuring the home page layout, branding, and component placement within the Experience Builder.
- **B2B Buyer**: End-user navigating the storefront to find relevant products, view authorized categories, and make purchases.

## Stakeholders
- **Store Administrator**
  - *Decision authority*: Approves the configurability and layout options of the LWCs in Experience Builder.
  - *Concerns*: Ease of configuring the home page; ability to reposition components without developer assistance.
- **B2B Buyer**
  - *Decision authority*: None.
  - *Concerns*: Finding relevant products quickly; only seeing authorized categories and accurate B2B pricing.

## Scope (In / Out)
**In Scope**:
- Development and deployment of 12 distinct, independent LWCs: Header, Site Logo, Top Promo, Nav Menu, Search, User/Account, Hero Banner, Product Categories, Featured Products, Promo Content, Quick Links, and Footer.
- Exposing `@api` properties for static UI LWCs to allow configuration in the Experience Builder.
- Integration of the Product Categories LWC with the existing server-side dynamic category visibility POC.
- Integration of the Featured Products and Search LWCs with standard Salesforce B2B Commerce APIs.

**Out of Scope**:
- Creating a new Salesforce org, B2B Commerce store, Web Store, or catalog.
- Modifying or recreating the existing Dynamic Category Visibility POC logic.
- Creating custom objects to store configuration data.
- Selecting complex product variations (e.g., size, color) directly from the Home Page.

## MoSCoW
None specified.

## Functional Requirements
- **FR-01**: The system shall provide 12 distinct, independently deployable LWCs (Header, Site Logo, Top Promo, Nav Menu, Search, User/Account, Hero Banner, Product Categories, Featured Products, Promo Content, Quick Links, and Footer).
  - *Acceptance Criteria*: GIVEN the deployment package is installed WHEN an administrator opens the LWR Experience Builder THEN 12 distinct custom LWCs are available in the component palette.
- **FR-02**: The system shall expose `@api` properties for all configurable elements (images, text, links) within the static UI LWCs to the Experience Builder.
  - *Acceptance Criteria*: GIVEN an administrator has placed a static UI LWC on the page WHEN they select the component THEN the property panel displays configurable fields for images, headings, subheadings, CTAs, and navigation links.
- **FR-03**: The Product Categories LWC shall retrieve and display categories strictly using the existing server-side dynamic category visibility POC.
  - *Acceptance Criteria*: GIVEN a logged-in buyer is viewing the Home Page WHEN the Product Categories LWC loads THEN it only displays categories authorized by the server-side POC for their Buyer Group.
- **FR-04**: The Featured Products LWC shall display the product image, name, and B2B price, and execute the standard Add to Cart function.
  - *Acceptance Criteria*: GIVEN a buyer is viewing the Featured Products LWC WHEN they click "Add to Cart" THEN the product is added to their cart via standard B2B APIs and a success message is displayed.
- **FR-05**: The User/Account LWC shall display the logged-in buyer's information and toggle available actions based on the current authentication status.
  - *Acceptance Criteria*: GIVEN a user is viewing the Home Page WHEN they are logged in THEN the User/Account LWC shows their buyer info and authenticated actions, AND WHEN they are logged out THEN it shows guest/login actions.
- **FR-06**: The system shall use standard B2B Commerce APIs for search functionality within the Search LWC.
  - *Acceptance Criteria*: GIVEN a buyer uses the Search LWC WHEN they submit a search term THEN the component queries the standard B2B Commerce Search API and navigates to the standard search results page.

## User Stories
- **US-01**: As a Store Administrator, I want to configure independent UI components (Hero Banner, Promotional Content, Quick Links, Header, Footer, Top Promo, Site Logo) in the Experience Builder, so that I can customize the Home Page layout and branding without modifying code.
  - *Acceptance Criteria*: GIVEN I am in the LWR Experience Builder WHEN I select any of the static UI LWCs (e.g., Hero Banner) THEN I can configure its exposed `@api` properties such as images, headings, subheadings, CTAs, and navigation links.
- **US-02**: As a B2B Buyer, I want to view Product Categories on the Home Page, so that I can navigate to authorized product listings tailored to my Buyer Group.
  - *Acceptance Criteria*: GIVEN I am a logged-in buyer with an assigned Buyer Group WHEN I view the Product Categories LWC THEN I only see the categories permitted by the existing dynamic category visibility POC.
- **US-03**: As a B2B Buyer, I want to view Featured Products and add them to my cart directly from the Home Page, so that I can quickly purchase promoted items without navigating to individual product pages.
  - *Acceptance Criteria*: GIVEN I am viewing the Featured Products LWC WHEN I click Add to Cart for a specific product THEN the item is added to my B2B Commerce cart using standard Salesforce APIs and I see a success confirmation.
- **US-04**: As a B2B Buyer, I want to use the Search, Navigation Menu, and User/Account components, so that I can find products, navigate the site, and manage my account state.
  - *Acceptance Criteria*: GIVEN I am on the Home Page WHEN I enter a term in the Search LWC and submit THEN I am navigated to the standard B2B Commerce search results page.

## Inputs/Outputs/Data Flow
None specified.

## Flows
None specified.

## Edge Cases & Error States
- **EC-01**: A logged-in buyer's Buyer Group has no authorized categories.
  - *Expected State*: The Product Categories LWC displays a configurable empty state message or hides itself gracefully without throwing an error.
- **EC-02**: A featured product has no price defined for the buyer's price book.
  - *Expected State*: The Add to Cart button is disabled or hidden, and a 'Price Unavailable' message is shown.
- **EC-03**: The standard Search API times out or fails.
  - *Expected State*: The Search LWC displays a user-friendly error message advising the buyer to try again later.

## Acceptance Criteria (Given/When/Then)
*(Note: Happy path acceptance criteria are documented inline within the Functional Requirements and User Stories sections. The following criteria govern the Edge Cases and Error States.)*
- **AC-01 (Empty Categories)**: GIVEN a logged-in buyer has no authorized categories WHEN the Product Categories LWC renders THEN it displays a configurable empty state message or hides itself without throwing a system error.
- **AC-02 (Missing Price)**: GIVEN a featured product lacks a price in the active buyer's price book WHEN the Featured Products LWC renders THEN the Add to Cart button is disabled or hidden AND a 'Price Unavailable' message is displayed.
- **AC-03 (Search Failure)**: GIVEN the standard B2B Commerce Search API is unavailable or times out WHEN a buyer submits a search query THEN the Search LWC displays a user-friendly error message advising them to try again later.

## Non-Functional Requirements
- **NFR-01 (Usability)**: All LWCs must be responsive across standard devices. Target: 100% of components render without horizontal scrolling on mobile viewports down to 320px width.
- **NFR-02 (Maintainability)**: Components must not be monolithic. Target: Exactly 12 separate LWC folders with their own `js-meta.xml` files are deployed.
- **NFR-03 (Security)**: Custom Apex must enforce Salesforce security models. Target: 100% of custom Apex classes enforce CRUD/FLS and use the `with sharing` keyword.

## Assumptions
- **BR-01**: Category visibility must be strictly enforced on the server-side to prevent unauthorized access to restricted product categories via client-side manipulation.
- **BR-02**: There will be no hardcoding of IDs or names for Buyer Groups, Categories, or Products, ensuring components remain reusable across different environments, sandboxes, and stores.

## Dependencies
- **AD-01**: The existing Dynamic Category Visibility POC is deployed and functional in the target environment. *(Impact if wrong: The Product Categories LWC will not be able to filter categories correctly, potentially exposing unauthorized products.)*
- **AD-02**: Standard B2B Commerce APIs for Cart, Search, and Pricing are active and accessible. *(Impact if wrong: Featured Products and Search LWCs will fail to function.)*

## Open Questions
- **OQ-01**: Should the Featured Products LWC allow selecting product variations (e.g., size, color) before adding to cart? *(Recommended default: No, restrict Featured Products to simple products for the MVP to utilize standard Add to Cart APIs easily without complex UI additions.)*
- **OQ-02**: How many Featured Products should be displayed at maximum to ensure optimal performance? *(Recommended default: Limit the display to a maximum of 4 products.)*
- **OQ-03**: Should the Top Promotional Bar support multiple rotating messages? *(Recommended default: No, support a single static configurable message for the initial release to reduce complexity.)*
- **OQ-04**: What is the MoSCoW prioritization for the requirements? (None specified).
- **OQ-05**: What are the specific Inputs, Outputs, and Data Flows for the components? (None specified).
- **OQ-06**: What are the specific user or system flows (e.g., step-by-step navigation flows)? (None specified).

## Success Metrics
- **SM-01 (Leading) — Component Modularity**: 100% of the 12 specified LWCs are successfully deployed and available in Experience Builder. *(Data required: Salesforce metadata deployment logs and Experience Builder component list.)*
- **SM-02 (Lagging) — Home Page Load Time**: The fully assembled Home Page loads in under 3 seconds on desktop connections. *(Data required: Browser performance metrics and Salesforce page load analytics.)*
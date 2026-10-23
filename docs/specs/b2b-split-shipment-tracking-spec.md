# B2B Split Shipment Tracking

**ID:** SPEC-B2B-SPLIT-SHIP
**Version:** 1.0
**Status:** Draft
**Type:** Functional Specification

## Overview & Purpose
In B2B commerce, large or complex orders are frequently fulfilled from multiple warehouse locations or have varying product availability dates. Currently, buyers lack granular visibility when a single order is split into multiple shipments, leading to confusion and increased customer support inquiries. 

To improve the post-purchase experience and mirror best-in-class B2B storefronts, this feature introduces Split Shipment tracking on the Order Detail Page. It leverages Salesforce out-of-the-box (OOTB) capabilities and existing tracking components to display individual shipment statuses, delivery dates, and tracking numbers while maintaining a cohesive overall order status.

## Goals
- **OBJ-01:** Provide granular tracking visibility for orders fulfilled via multiple shipments.
  - *Measure:* 100% of multi-shipment orders display individual shipment details on the Order Detail Page.
- **OBJ-02:** Reduce buyer inquiries regarding partial order fulfillment.
  - *Measure:* 15% reduction in customer support tickets related to order tracking and missing items within 3 months of launch.

## Target Users
- **Entitled Buyer:** B2B customers who need to know exactly when specific items in an order will arrive and require clear visibility into tracking numbers for each package.

## Stakeholders
- **Entitled Buyer:** End-user consuming the tracking information. (Decision authority: None)
- **Fulfillment Operations:** Approves the mapping of OOTB shipment data to the frontend. Requires the system to accurately reflect backend shipment routing without custom integration overhead.

## Scope (In / Out)
**In Scope:**
- Displaying multiple standard Salesforce Shipment records associated with a single Order on the Order Detail Page.
- Displaying shipment number, products, quantities, status, delivery date, and tracking number for each shipment.
- Reusing existing shipment tracking LWC components.
- Aggregating child shipment statuses to display a 'Partially Fulfilled' overall order status.
- Enforcing data visibility rules based on authorized B2B accounts.

**Out of Scope:**
- Customizing the backend fulfillment routing logic or order management system (OMS) rules that physically split the order.
- Building new shipment tracking components from scratch instead of extending standard/existing ones.
- Implementing custom exception or error-handling frameworks for shipment data retrieval.

## MoSCoW
None specified.

## Functional Requirements
- **FR-01:** The system shall retrieve and display multiple standard Salesforce Shipment records associated with a single Order.
  - *Acceptance Criteria:* GIVEN an order has multiple associated Shipment records, WHEN the Order Detail Page is loaded, THEN the system retrieves and displays all standard Salesforce Shipment records linked to that Order.
- **FR-02:** The system shall display the shipment number, products, quantities, status, delivery date, and tracking number for each shipment on the Order Detail Page.
  - *Acceptance Criteria:* GIVEN a shipment record is retrieved, WHEN it is rendered on the UI, THEN the shipment number, products, quantities, status, delivery date, and tracking number are visible to the user.
- **FR-03:** The system shall reuse existing shipment tracking LWC components, passing the relevant shipment IDs to render the tracking information.
  - *Acceptance Criteria:* GIVEN the UI is rendering tracking details, WHEN the component loads, THEN it utilizes the existing shipment tracking LWC by passing the shipment ID rather than utilizing a newly created custom component.
- **FR-04:** The system shall aggregate the statuses of all child shipments to determine and display a 'Partially Fulfilled' overall order status when applicable.
  - *Acceptance Criteria:* GIVEN an order has multiple shipments with mixed statuses (e.g., dispatched and pending), WHEN the order header is displayed, THEN the overall order status is calculated and displayed as 'Partially Shipped'.
- **FR-05:** The system shall enforce data visibility rules so that buyers can only view shipments linked to orders owned by their authorized B2B account.
  - *Acceptance Criteria:* GIVEN a user is authenticated, WHEN they attempt to query or view shipments for an order not owned by their authorized account, THEN the system blocks the retrieval and displays an access denied state.

## User Stories
- **US-01:** As an Entitled Buyer, I want to view multiple shipments for a single order on the Order Detail Page, so that I know how and when my individual items are being delivered.
  - **Scenario: View split shipments on an order**
    - GIVEN I have an order that has been split into multiple shipments
    - WHEN I navigate to the Order Detail Page for that order
    - THEN I see a distinct section for each shipment containing its shipment number, products, quantities, status, delivery date, and tracking number
  - **Scenario: View a shipment without a tracking number**
    - GIVEN I have a shipment that has been created but not yet dispatched
    - WHEN I view the shipment details on the Order Detail Page
    - THEN I see the shipment status and delivery date, but the tracking number is hidden or displays a pending state
  - **Scenario: Attempt to view shipments for an unauthorized account**
    - GIVEN I am authenticated but not authorized for a specific B2B account
    - WHEN I attempt to access an Order Detail Page belonging to that account via direct URL
    - THEN I am denied access and cannot view the order or its shipments

- **US-02:** As an Entitled Buyer, I want to see an overall order status that reflects partial fulfillment, so that I understand the high-level progress of my entire order at a glance.
  - **Scenario: Order is partially fulfilled**
    - GIVEN an order has multiple shipments and at least one shipment has been dispatched, but others are pending
    - WHEN I view the order header
    - THEN the overall order status is displayed as 'Partially Shipped'
  - **Scenario: Order is completely fulfilled**
    - GIVEN all shipments associated with an order have been dispatched
    - WHEN I view the order header
    - THEN the overall order status is displayed as 'Shipped' or 'Completed'

## Inputs/Outputs/Data Flow
- **Inputs:** 
  - User Context (Authenticated User ID, Authorized Account ID).
  - Order ID (from the Order Detail Page context).
- **Outputs:** 
  - List of Salesforce Shipment records (Shipment Number, Products, Quantities, Status, Delivery Date, Tracking Number).
  - Aggregated Overall Order Status.
- **Data Flow:** 
  1. The Order Detail Page LWC requests shipment data for the current Order ID.
  2. The Apex controller receives the request and enforces FLS/CRUD and `with sharing` rules based on the user's authorized B2B account.
  3. Apex queries standard Salesforce Shipment records associated with the Order ID.
  4. Apex returns the list of Shipment records and the calculated aggregate order status to the frontend.
  5. The frontend LWC iterates over the Shipment records, passing Shipment IDs to the existing tracking LWC components for rendering.

## Flows
None specified.

## Edge Cases & Error States
- **EC-01 (Mixed Product Types):** An order contains a mix of physical shippable products and digital/non-shippable products.
  - *Handling:* Digital products are excluded from the physical shipment tracking sections and are displayed in a separate 'Digital Delivery' or 'Fulfilled' section on the order.
- **EC-02 (Partial Cancellation):** A specific shipment is cancelled after the order is placed, but other shipments remain active.
  - *Handling:* The cancelled shipment is displayed with a 'Cancelled' status, and the overall order status recalculates based only on the remaining active shipments.
- **EC-03 (High Volume Shipments):** An order is split into an unusually high number of shipments (e.g., > 20).
  - *Handling:* The UI gracefully stacks or paginates the shipment cards to maintain page performance and avoid hitting Apex heap or SOQL limits.
- **Error State (Missing Tracking):** A shipment record exists but the carrier has not yet generated a tracking ID.
  - *Handling:* The tracking number field is hidden or displays a pending state to prevent rendering null/undefined values.
- **Error State (Unauthorized Access):** A user attempts to view an order/shipment belonging to an account they do not have access to.
  - *Handling:* The system denies access, returning no shipment data, and displays a standard unauthorized error.

## Acceptance Criteria (Given/When/Then)
*Consolidated criteria for system behaviors and edge cases not explicitly covered in User Stories:*

- **Scenario: Enforcing Business Rule for Tracking Number Display (BR-02)**
  - GIVEN a standard Salesforce Shipment record is retrieved
  - WHEN the tracking number field is null or undefined
  - THEN the UI hides the tracking number field or displays a "pending" indicator instead of a blank or null value.
- **Scenario: Handling Mixed Product Types (EC-01)**
  - GIVEN an order contains both physical and digital products
  - WHEN the Order Detail Page renders
  - THEN digital products are excluded from physical shipment cards AND are displayed in a separate 'Digital Delivery' or 'Fulfilled' section.
- **Scenario: Handling Cancelled Shipments (EC-02)**
  - GIVEN an order has multiple shipments and one shipment is cancelled
  - WHEN the Order Detail Page renders
  - THEN the cancelled shipment card displays a 'Cancelled' status AND the overall order status is calculated using only the remaining active shipments.
- **Scenario: Handling High Volume Shipments (EC-03)**
  - GIVEN an order is split into more than 20 shipments
  - WHEN the Order Detail Page renders
  - THEN the UI paginates or stacks the shipment cards to ensure page performance and prevent truncation or layout breakage.

## Non-Functional Requirements
- **NFR-01 (Security):** Apex controllers fetching shipment data must enforce FLS/CRUD and use 'with sharing'. 
  - *Target:* 100% of Apex classes pass automated security scanning with no SOQL/DML in loops.
- **NFR-02 (Usability):** The UI layout for split shipments must tolerate text expansion for localization without breaking the grid. 
  - *Target:* Tolerates up to 30% text expansion with 0 truncated strings or overlapping elements.
- **NFR-03 (Accessibility):** The shipment display region must use semantic landmarks and aria-live attributes for dynamic tracking updates. 
  - *Target:* 0 WCAG 2.1 AA violations during automated accessibility testing.
- **NFR-04 (Maintainability):** All user-facing strings in the shipment components must be sourced from Custom Labels or translated store content. 
  - *Target:* 0 hardcoded English strings in HTML templates or JavaScript files.

## Assumptions
- **BR-01:** An order is eligible to be split into multiple shipments if its line items are fulfilled from different locations or have different delivery dates. (Reflects standard supply chain realities).
- **BR-02:** A tracking number is only displayed if it is populated on the underlying Shipment record.
- **AD-02:** The ASDF framework relies on standard LWC practices (smart container/dumb child architecture). If wrong, component architecture may need to be refactored to comply with proprietary ASDF patterns once defined.

## Dependencies
- **AD-01:** The Salesforce org has OOTB Order Management or B2B Commerce data models enabled that support linking multiple Shipment records to a single Order. (Impact if wrong: The frontend will not have a standard data structure to query, requiring custom object creation which violates the OOTB-first directive).

## Open Questions
- **OQ-01:** What are the exact standard picklist values used for the overall order status when an order is partially fulfilled? *(Recommended default: Use 'Partially Shipped' as the standard status value).*
- **OQ-02:** Are there specific visual layout differences from the Amazon Business India reference that conflict with the US multi-currency base? *(Recommended default: Follow the US base configuration for all currency, date, and locale formatting, but adopt the structural layout of the India reference).*
- **OQ-03:** How should shipping costs be displayed when an order is split? Are they displayed per shipment or aggregated at the order level? *(Recommended default: Display shipping costs aggregated at the overall Order level to avoid confusing buyers with prorated shipping fees).*
- **OQ-04:** What is the MoSCoW prioritization for the listed requirements?
- **OQ-05:** Are there specific step-by-step user flows or system sequence diagrams required for this feature?

## Success Metrics
- **SM-01 (Leading):** Order Detail Page views with multi-shipment interactions (e.g., expanding tracking details).
  - *Target:* > 40% of users with split shipments interact with the tracking component.
  - *Data required:* Frontend analytics tracking clicks on shipment tracking elements.
- **SM-02 (Lagging):** Customer support ticket volume for 'Where is my order?' on partially fulfilled orders.
  - *Target:* 15% reduction in ticket volume.
  - *Data required:* Service Cloud case categorization data mapped to multi-shipment orders.
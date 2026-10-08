# B2B Commerce Shipment Tracking

**ID:** SPEC-ST-001
**Version:** 1.0
**Status:** Draft
**Type:** Functional Specification

## Overview & Purpose
B2B buyers require visibility into their order fulfillment status, specifically shipment tracking and expected delivery dates, to manage their inventory and operations effectively. Currently, this information may require manual follow-up or lacks centralized visibility within the storefront. 

By implementing native shipment tracking using Salesforce Order Management System (OMS) capabilities, buyers can self-serve this information directly from the Order Summary Details page. This approach reduces support overhead (WISMO - 'Where is my order?' inquiries) and improves the post-purchase experience while strictly adhering to the constraint of using standard Salesforce data models without external carrier API integrations.

## Goals
*   **OBJ-01:** Reduce customer support inquiries related to order status and shipment tracking.
    *   *Measure:* 15% reduction in WISMO (Where is my order?) support cases within 3 months of launch.
*   **OBJ-02:** Increase buyer self-service engagement for post-purchase activities.
    *   *Measure:* 20% of active buyers interact with the Shipment Tracking feature on the Order Detail page monthly.

## Target Users
*   **B2B Buyer:** Needs accurate and timely visibility into shipment status, carrier, and expected delivery dates. Requires clear distinction between shipped and pending items for partially fulfilled orders.

## Stakeholders
*   **B2B Buyer:** End user consuming the tracking information. (Decision authority: None)
*   **OMS Administrator:** Approves OMS configuration and data flow. Ensures standard Salesforce OMS objects are correctly populated and minimizes custom development.

## Scope (In / Out)
**In Scope:**
*   Displaying Shipment records associated with an Order Summary on the Order Detail page.
*   Displaying specific shipment fields: Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date.
*   Displaying Products and Quantities (Shipment Items) per shipment.
*   Providing a 'Track Shipment' action linking to the carrier's portal via dynamically generated URLs.
*   Enforcing standard Salesforce sharing rules for shipment visibility.
*   Verifying and performing required standard OMS configurations for shipment tracking without external integration.

**Out of Scope:**
*   Integration with external carrier APIs (e.g., FedEx, UPS) for real-time status updates.
*   Integration with external ERP or third-party OMS systems.
*   Creation of custom objects to store shipment data (must use standard Salesforce Shipment and Fulfillment Order objects).

## MoSCoW
None specified.

## Functional Requirements
*   **FR-01:** The system shall display a list of Shipment records associated with the Order Summary on the Order Detail page.
    *   *Acceptance Criteria:* GIVEN an Order Summary has associated Shipment records, WHEN the buyer views the Order Detail page, THEN a list of all related Shipments is displayed.
*   **FR-02:** The system shall display the following fields for each Shipment: Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, and Expected Delivery Date.
    *   *Acceptance Criteria:* GIVEN a Shipment record is displayed, WHEN the buyer views the shipment section, THEN the Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, and Expected Delivery Date are visible.
*   **FR-03:** The system shall display the Products and Quantities (Shipment Items) included in each specific Shipment.
    *   *Acceptance Criteria:* GIVEN a Shipment contains specific items, WHEN the buyer views the shipment details, THEN the specific Products and Quantities included in that shipment are listed.
*   **FR-04:** The system shall provide a 'Track Shipment' action that uses the stored Tracking Number and Carrier to navigate the user to the carrier's tracking portal.
    *   *Acceptance Criteria:* GIVEN a Shipment has a populated Carrier and Tracking Number, WHEN the buyer clicks 'Track Shipment', THEN they are redirected to the carrier's tracking web page in a new tab using a dynamically generated URL.
*   **FR-05:** The system shall enforce standard Salesforce sharing rules to ensure buyers can only view Shipments linked to Order Summaries they are authorized to access.
    *   *Acceptance Criteria:* GIVEN a buyer is logged in, WHEN they attempt to view shipment data, THEN they can only see Shipments linked to Order Summaries placed by their account or buyer group.
*   **FR-06:** The system implementation shall check if the required shipment tracking configuration exists in the OMS; if not, it shall perform the required configuration natively with no external integration.
    *   *Acceptance Criteria:* GIVEN the shipment tracking feature is being deployed, WHEN the OMS configuration is evaluated, THEN the system verifies or implements the required standard configurations AND ensures no external integrations are used.

## User Stories
*   **US-01:** As a B2B buyer, I want to view shipment details and track my shipments on the Order Summary details page, so that I can see the shipment status, expected delivery information, and products included in each shipment for my order.
    *   *Acceptance Criteria:* See Acceptance Criteria section for detailed Given/When/Then scenarios (View single shipment, View multiple shipments, Tracking unavailable, Track shipped package).

## Inputs/Outputs/Data Flow
None specified.

## Flows
None specified.

## Edge Cases & Error States
*   **EC-01 (Missing Tracking Data):** Tracking number is blank or unavailable from the OMS.
    *   *Expected State:* Display 'Pending' or 'Unavailable' in the Tracking Number field and hide/disable the 'Track Shipment' action.
*   **EC-02 (Unrecognized Carrier):** Carrier is unrecognized or lacks a configured tracking URL template.
    *   *Expected State:* Display the Carrier name and Tracking Number as plain text, but hide/disable the 'Track Shipment' action to prevent broken links.
*   **EC-03 (Delivered Status):** Shipment status is 'Delivered'.
    *   *Expected State:* Display the status clearly as 'Delivered'. The 'Track Shipment' action remains available for historical reference.

## Acceptance Criteria (Given/When/Then)
**Happy Path Scenarios:**
*   **View single shipment details:** GIVEN I am an entitled B2B buyer viewing an Order Summary that has one associated Shipment, WHEN I navigate to the Order Detail page, THEN I see a shipment section displaying the Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date, and the specific Products and Quantities included.
*   **View multiple shipments for a partially fulfilled order:** GIVEN I am an entitled B2B buyer viewing an Order Summary that has been partially fulfilled across multiple Shipments, WHEN I navigate to the Order Detail page, THEN I see each Shipment displayed independently with its own status, tracking details, and specific products/quantities.
*   **Track a shipped package:** GIVEN I am viewing a Shipment with a populated Carrier and Tracking Number, WHEN I click the 'Track Shipment' action, THEN I am redirected to the carrier's standard tracking web page in a new tab, using a dynamically generated URL based on the tracking number.
*   **Data Security/Visibility:** GIVEN I am a B2B buyer, WHEN I access the Order Detail page, THEN I only see Shipment records strictly inherited from the Order Summary visibility rules tied to my account or buyer group.
*   **OMS Configuration Verification:** GIVEN the shipment tracking feature is being deployed, WHEN the OMS configuration is evaluated, THEN the system verifies or implements the required standard configurations natively AND ensures no external integrations are used.

**Edge Case Scenarios:**
*   **Tracking information is unavailable (EC-01):** GIVEN I am viewing a Shipment where the Tracking Number has not yet been populated by the OMS, WHEN I review the shipment details, THEN the Tracking Number and Expected Delivery Date fields indicate the information is pending or unavailable, AND the Track Shipment action is disabled or hidden.
*   **Unrecognized Carrier (EC-02):** GIVEN I am viewing a Shipment where the Carrier is unrecognized or lacks a URL template, WHEN I review the shipment details, THEN the Carrier name and Tracking Number are displayed as plain text, AND the Track Shipment action is disabled or hidden.
*   **Delivered Shipment (EC-03):** GIVEN I am viewing a Shipment where the status is 'Delivered', WHEN I review the shipment details, THEN the status is displayed as 'Delivered', AND the Track Shipment action remains available and clickable.

## Non-Functional Requirements
*   **NFR-01 (Usability):** The shipment tracking interface layouts must tolerate text expansion to accommodate multi-language localization. Target: 30% text expansion without breaking the grid or overlapping elements.
*   **NFR-02 (Accessibility):** The shipment list and tracking actions must be fully accessible. Target: 100% compliance with WCAG 2.1 AA, including semantic landmarks, keyboard operability, and visible focus states.
*   **NFR-03 (Security):** Any custom Apex controllers required to fetch Shipment data must enforce strict security controls. Target: 100% of Apex classes use 'with sharing' and enforce FLS/CRUD checks before returning data.

## Assumptions
*   **BR-01:** Shipment visibility is strictly inherited from Order Summary visibility, ensuring B2B buyers only see fulfillment data for orders placed by their account or buyer group.
*   **BR-02:** Tracking URLs must be constructed using standard Salesforce configuration or custom metadata, without invoking external carrier APIs.
*   **BR-03:** A single Order Summary can have multiple Fulfillment Orders and Shipments, supporting partial fulfillment and multi-warehouse shipping scenarios.
*   **AD-02:** The OMS or downstream fulfillment process populates the Carrier, Tracking Number, Shipment Date, and Expected Delivery Date on the standard Salesforce Shipment object. (Impact if wrong: The UI will consistently display empty states for tracking information).

## Dependencies
*   **AD-01:** Salesforce Order Management (OMS) is provisioned and configured to generate Fulfillment Orders and Shipments from Order Summaries. (Impact if wrong: The standard data model required for this feature will not exist, requiring a complete redesign of the fulfillment architecture).

## Open Questions
*   **OQ-01:** Does the standard B2B Commerce Order Summary component support displaying related Shipment records and Shipment Items OOTB, or is a custom LWC required to meet the specific UI requirements? *(Recommended default: Assume a custom LWC is required to display the exact requested fields and multi-shipment layout).*
*   **OQ-02:** How should the 'Track Shipment' URL be constructed given the restriction on external APIs? *(Recommended default: Create a Custom Metadata Type that maps standard Carrier names to their base tracking URLs, and append the Tracking Number dynamically in the LWC).*
*   **OQ-03:** What are the MoSCoW priorities for the listed functional requirements?
*   **OQ-04:** What are the specific Inputs, Outputs, and Data Flows between the OMS and the storefront UI?
*   **OQ-05:** Are there any specific user flow diagrams or step-by-step flow requirements for how the user navigates to the Order Detail page?

## Success Metrics
*   **SM-01 (Lagging):** WISMO Support Cases. Target: 15% reduction in order status related support tickets. (Data required: Service Cloud case categorization data for order inquiries).
*   **SM-02 (Leading):** Track Shipment Action Usage. Target: 20% of users viewing a shipped order click the 'Track Shipment' action. (Data required: Storefront analytics tracking clicks on the 'Track Shipment' button/link).
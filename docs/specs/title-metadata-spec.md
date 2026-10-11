# Title & metadata
**Title:** Shipment Tracking Functional Specification  
**ID:** FS-SHIP-001  
**Version:** 1.0  
**Status:** Draft  
**Type:** Functional Specification  

# Overview & Purpose
B2B buyers require visibility into their order fulfillment status, specifically shipment tracking and expected delivery dates, to manage their inventory and operations effectively. Currently, this information may require manual follow-up or lacks centralized visibility within the storefront. 

By implementing native shipment tracking using Salesforce Order Management System (OMS) capabilities, buyers can self-serve this information directly from the Order Summary Details page. This approach reduces support overhead (WISMO - 'Where is my order?' inquiries) and improves the post-purchase experience while strictly adhering to the constraint of using standard Salesforce data models without external carrier API integrations.

# Goals
*   **OBJ-01:** Reduce customer support inquiries related to order status and shipment tracking. Measure: 15% reduction in WISMO (Where is my order?) support cases within 3 months of launch.
*   **OBJ-02:** Increase buyer self-service engagement for post-purchase activities. Measure: 20% of active buyers interact with the Shipment Tracking feature on the Order Detail page monthly.

# Target Users
*   **B2B Buyer:** Needs accurate and timely visibility into shipment status, carrier, and expected delivery dates. Requires clear distinction between shipped and pending items for partially fulfilled orders.

# Stakeholders
*   **B2B Buyer:** End user consuming the tracking information. (Decision authority: None)
*   **OMS Administrator:** Approves OMS configuration and data flow. Ensures standard Salesforce OMS objects (Fulfillment Order, Shipment) are correctly populated and minimizes custom development by leveraging OOTB capabilities.

# Scope (In / Out)
**In Scope:**
*   Display of standard Salesforce Shipment records associated with an Order Summary on the Order Detail page using a Custom LWC Component and Apex.
*   Configuration of required field data in the built-in Salesforce OMS if current configurations are not present.
*   Display of specific shipment fields: Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date.
*   Display of Products and Quantities (Shipment Items) per shipment.
*   Dynamic generation of tracking URLs based on standard Salesforce configuration or custom metadata.
*   Support for multiple shipments per order (partial fulfillment).
*   Enforcement of standard Salesforce sharing rules for visibility.

**Out of Scope:**
*   Real-time tracking status updates fetched via external carrier APIs (e.g., FedEx, UPS).
*   Integration with external ERP or third-party OMS systems.
*   Creation of custom objects to store shipment data (must use standard Salesforce Shipment and Fulfillment Order objects).

# MoSCoW
None specified.

# Functional Requirements
*   **FR-01:** The system shall use a Custom LWC Component and Apex to display a list of Shipment records associated with the Order Summary on the Order Detail page.
*   **FR-02:** The system shall display the following fields for each Shipment: Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, and Expected Delivery Date.
*   **FR-03:** The system shall display the Products and Quantities (Shipment Items) included in each specific Shipment.
*   **FR-04:** The system shall provide a 'Track Shipment' action that uses the stored Tracking Number and Carrier to navigate the user to the carrier's tracking portal.
*   **FR-05:** The system shall enforce standard Salesforce sharing rules to ensure buyers can only view Shipments linked to Order Summaries they are authorized to access.
*   **FR-06:** The system shall check if required shipment configurations are present in OMS; if not, the required field data must be configured natively in the built-in Salesforce OMS without any external integration.
*   **BR-01:** Shipment visibility is strictly inherited from Order Summary visibility to ensure B2B buyers only see fulfillment data for orders placed by their account or buyer group.
*   **BR-02:** Tracking URLs must be constructed using standard Salesforce configuration or custom metadata, without invoking external carrier APIs.
*   **BR-03:** The system must support a single Order Summary having multiple Fulfillment Orders and Shipments natively.

# User Stories
*   **US-01:** As a B2B buyer, I want to view shipment details and track my shipments on the Order Summary details page, so that I can see the shipment status, expected delivery information, and products included in each shipment for my order.
    *   *Given* I am an entitled B2B buyer viewing an Order Summary that has one associated Shipment, *When* I navigate to the Order Detail page, *Then* I see a shipment section displaying the Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date, and the specific Products and Quantities included.
    *   *Given* I am an entitled B2B buyer viewing an Order Summary that has been partially fulfilled across multiple Shipments, *When* I navigate to the Order Detail page, *Then* I see each Shipment displayed independently with its own status, tracking details, and specific products/quantities.
    *   *Given* I am viewing a Shipment where the Tracking Number has not yet been populated by the OMS, *When* I review the shipment details, *Then* the Tracking Number and Expected Delivery Date fields indicate the information is pending or unavailable, and the Track Shipment action is disabled or hidden.
    *   *Given* I am viewing a Shipment with a populated Carrier and Tracking Number, *When* I click the 'Track Shipment' action, *Then* I am redirected to the carrier's standard tracking web page in a new tab, using a dynamically generated URL based on the tracking number.

# Inputs/Outputs/Data Flow
**Inputs:**
*   Order Summary ID (from the current page context).
*   Standard Salesforce Shipment object data (Shipment Number, Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date).
*   Standard Salesforce Shipment Item object data (Products, Quantities).
*   Custom Metadata / Standard Configuration for Carrier URL templates.

**Outputs:**
*   Rendered Shipment Tracking UI on the Order Detail page via Custom LWC.
*   Dynamically generated Carrier Tracking URL.

**Data Flow:**
None specified.

# Flows
None specified.

# Edge Cases & Error States
*   **EC-01 (Missing Tracking Info):** Tracking number is blank or unavailable from the OMS. 
    *   *Expected:* Display 'Pending' or 'Unavailable' in the Tracking Number field and hide/disable the 'Track Shipment' action.
*   **EC-02 (Unrecognized Carrier):** Carrier is unrecognized or lacks a configured tracking URL template. 
    *   *Expected:* Display the Carrier name and Tracking Number as plain text, but hide/disable the 'Track Shipment' action to prevent broken links.
*   **EC-03 (Delivered Status):** Shipment status is 'Delivered'. 
    *   *Expected:* Display the status clearly as 'Delivered'. The 'Track Shipment' action remains available for historical reference.

# Acceptance Criteria (Given/When/Then)
*   **AC-01 (Validates FR-01, FR-02, FR-03):** 
    *   **Given** I am an entitled B2B buyer viewing an Order Summary that has one associated Shipment, 
    *   **When** I navigate to the Order Detail page, 
    *   **Then** I see a shipment section rendered by the Custom LWC displaying the Shipment Number, Shipment Status, Carrier, Tracking Number, Shipment Date, Expected Delivery Date, and the specific Products and Quantities included.
*   **AC-02 (Validates FR-01, FR-02, FR-03, BR-03):** 
    *   **Given** I am an entitled B2B buyer viewing an Order Summary that has been partially fulfilled across multiple Shipments, 
    *   **When** I navigate to the Order Detail page, 
    *   **Then** I see each Shipment displayed independently with its own status, tracking details, and specific products/quantities.
*   **AC-03 (Validates FR-04, BR-02):** 
    *   **Given** I am viewing a Shipment with a populated Carrier and Tracking Number, 
    *   **When** I click the 'Track Shipment' action, 
    *   **Then** I am redirected to the carrier's standard tracking web page in a new tab, using a dynamically generated URL based on the tracking number.
*   **AC-04 (Validates EC-01):** 
    *   **Given** I am viewing a Shipment where the Tracking Number has not yet been populated by the OMS, 
    *   **When** I review the shipment details, 
    *   **Then** the Tracking Number and Expected Delivery Date fields indicate the information is pending or unavailable, and the Track Shipment action is disabled or hidden.
*   **AC-05 (Validates EC-02):** 
    *   **Given** I am viewing a Shipment where the Carrier is unrecognized or lacks a configured tracking URL template, 
    *   **When** I review the shipment details, 
    *   **Then** the Carrier name and Tracking Number are displayed as plain text, and the 'Track Shipment' action is hidden or disabled.
*   **AC-06 (Validates EC-03):** 
    *   **Given** I am viewing a Shipment where the status is 'Delivered', 
    *   **When** I review the shipment details, 
    *   **Then** the status is clearly displayed as 'Delivered' and the 'Track Shipment' action remains available.
*   **AC-07 (Validates FR-05, BR-01):** 
    *   **Given** I am a B2B buyer attempting to view a Shipment, 
    *   **When** the Shipment belongs to an Order Summary outside of my account or buyer group's authorized access, 
    *   **Then** the system denies access and does not display the Shipment data.
*   **AC-08 (Validates FR-06):**
    *   **Given** the shipment tracking feature is being implemented,
    *   **When** the system checks for required shipment field configurations in the built-in Salesforce OMS,
    *   **Then** the configurations are confirmed to be present, or they are newly configured to ensure the Custom LWC and Apex can retrieve the data natively without external integration.

# Non-Functional Requirements
*   **NFR-01 (Usability):** The shipment tracking interface layouts must tolerate text expansion to accommodate multi-language localization. Target: 30% text expansion without breaking the grid or overlapping elements.
*   **NFR-02 (Accessibility):** The shipment list and tracking actions must be fully accessible. Target: 100% compliance with WCAG 2.1 AA, including semantic landmarks, keyboard operability, and visible focus states.
*   **NFR-03 (Security):** Any custom Apex controllers required to fetch Shipment data must enforce strict security controls. Target: 100% of Apex classes use 'with sharing' and enforce FLS/CRUD checks before returning data.

# Assumptions
*   **AD-02:** The OMS or downstream fulfillment process populates the Carrier, Tracking Number, Shipment Date, and Expected Delivery Date on the standard Salesforce Shipment object. (Impact if wrong: The UI will consistently display empty states for tracking information, defeating the purpose of the feature).

# Dependencies
*   **AD-01:** Salesforce Order Management (OMS) is provisioned and configured to generate Fulfillment Orders and Shipments from Order Summaries. (Impact if wrong: The standard data model required for this feature will not exist, requiring a complete redesign of the fulfillment architecture).

# Open Questions
*   **OQ-01:** How should the 'Track Shipment' URL be constructed given the restriction on external APIs? *(Recommended default: Create a Custom Metadata Type that maps standard Carrier names to their base tracking URLs, and append the Tracking Number dynamically in the LWC).*
*   **OQ-02:** What are the MoSCoW priorities for the functional requirements?
*   **OQ-03:** What are the specific visual/UI flows and data flow diagrams for this feature?

# Success Metrics
*   **SM-01 (Lagging) - WISMO Support Cases:** 15% reduction in order status related support tickets. (Data required: Service Cloud case categorization data for order inquiries).
*   **SM-02 (Leading) - Track Shipment Action Usage:** 20% of users viewing a shipped order click the 'Track Shipment' action. (Data required: Storefront analytics tracking clicks on the 'Track Shipment' button/link).
# B2B Commerce Shopping Cart Page
**ID:** SPEC-CART-001 | **Version:** 1.0 | **Status:** Draft | **Type:** Functional Specification

## Overview & Purpose
The Shopping Cart page is a critical conversion juncture in the B2B Commerce storefront. Entitled buyers require a consolidated view of their selected products, including accurate contract pricing, quantity tiers, and real-time inventory status before proceeding to checkout. This feature provides a seamless way to manage active carts and defer purchasing decisions via a 'Saved for Later' feature. By leveraging standard Salesforce B2B Commerce data models (Cart and CartItem), Connect API, and Omnichannel Inventory (OCI), the solution ensures a scalable, performant, and visually consistent experience adhering to US multi-currency and multi-language configurations.

## Goals
*   **OBJ-01:** Enable entitled buyers to review and manage their cart items with accurate pricing and stock visibility. (Measure: 100% of cart items display contract pricing and OCI stock status).
*   **OBJ-02:** Reduce cart abandonment by allowing users to save items for future purchase. (Measure: Track the number of items moved to 'Saved for Later' versus deleted from the cart).

## Target Users
*   **Entitled Buyer:** Logged-in users with active entitlement policies who need clear visibility of discounts, final pricing, easy quantity adjustments, and the ability to save items for later.

## Stakeholders
*   **Entitled Buyer:** 
    *   *Decision authority:* None
    *   *Concerns:* Clear visibility of discounts and final pricing; easy adjustment of quantities; ability to save items for later without losing them.
*   **B2B Storefront Administrator:** 
    *   *Decision authority:* Approves technical architecture and standard component usage.
    *   *Concerns:* Adherence to standard Salesforce B2B Commerce data models; proper localization and currency formatting.

## Scope
**In Scope:**
*   Retrieval and display of active cart items via standard B2B Commerce Connect API.
*   Display of product images, names, variant attributes, contract pricing, MRP strikethrough, and discount percentages.
*   Real-time stock status visibility via Omnichannel Inventory (OCI).
*   Quantity adjustments via stepper with automatic cart recalculation.
*   'Delete' and 'Save for Later' actions for cart items.
*   Dedicated 'Saved for Later' tab to view and move items back to the active cart.
*   Order subtotal summary panel and 'Proceed to Checkout' navigation.
*   Multi-currency formatting and multi-language support via Custom Labels.

**Out of Scope:**
*   Guest checkout flows.
*   Custom tax calculation logic within the cart (deferred to standard checkout).
*   Complex quoting or request-for-quote (RFQ) flows from the cart page.

## MoSCoW
None specified.

## Functional Requirements
*   **FR-01:** The system shall retrieve and display active cart items using standard B2B Commerce Connect API wire adapters.
    *   *Acceptance Criteria:* GIVEN a user has an active cart, WHEN the cart page loads, THEN the system successfully retrieves cart data using Connect API without custom Apex queries.
*   **FR-02:** The system shall display the product image, name, and selected variant attributes (e.g., color, size, style) for each line item.
    *   *Acceptance Criteria:* GIVEN a cart item with variant attributes, WHEN rendered on the page, THEN the image, name, and specific attributes are visibly displayed.
*   **FR-03:** The system shall display the item price, including the Maximum Retail Price (MRP) with a strikethrough and the calculated discount percentage derived from the Pricebook or Price Adjustment Schedule.
    *   *Acceptance Criteria:* GIVEN an item with an active discount, WHEN rendered, THEN the UI displays the final price, the original MRP with a strikethrough, and the correct discount percentage.
*   **FR-04:** The system shall display real-time stock status for each item by querying Omnichannel Inventory (OCI) where enabled.
    *   *Acceptance Criteria:* GIVEN OCI is enabled, WHEN the cart page loads, THEN each line item displays its current real-time stock availability.
*   **FR-05:** The system shall provide a quantity stepper for each line item that updates the CartItem record and triggers a recalculation of the cart.
    *   *Acceptance Criteria:* GIVEN an active cart item, WHEN the user adjusts the quantity stepper, THEN the CartItem record is updated and the cart subtotal recalculates automatically.
*   **FR-06:** The system shall provide 'Delete' and 'Save for Later' actions for each active cart item.
    *   *Acceptance Criteria:* GIVEN an active cart item, WHEN the user selects 'Delete' or 'Save for Later', THEN the item is respectively removed from the cart or moved to the saved list.
*   **FR-07:** The system shall maintain a 'Saved for Later' tab backed by CartItem records (using a specific type or status), allowing users to view these items and move them back to the active cart.
    *   *Acceptance Criteria:* GIVEN a user has saved items, WHEN navigating to the 'Saved for Later' tab, THEN the items are displayed and can be successfully moved back to the active cart.
*   **FR-08:** The system shall display an order subtotal summary panel and a 'Proceed to Checkout' button that navigates the user to the standard checkout flow.
    *   *Acceptance Criteria:* GIVEN an active cart with available items, WHEN viewing the summary panel, THEN the accurate subtotal is displayed and the checkout button routes to the standard checkout flow.
*   **BR-01:** All monetary values must be formatted using `lightning-formatted-number` bound to the active currency.
    *   *Acceptance Criteria:* GIVEN a monetary value on the page, WHEN rendered, THEN it displays the correct currency symbol and formatting for the user's active currency context.
*   **BR-02:** All user-facing strings must be sourced from Custom Labels or translated store content.
    *   *Acceptance Criteria:* GIVEN the cart UI, WHEN rendered in a supported language, THEN no hardcoded English strings appear and all text is properly translated.
*   **BR-03:** Only entitled buyers can access the cart and checkout flows.
    *   *Acceptance Criteria:* GIVEN an unauthenticated or unentitled user, WHEN attempting to access the cart page, THEN they are denied access and redirected appropriately.

## User Stories
*   **US-01:** As an Entitled Buyer, I want to view my active cart items including product images, names, variants, pricing, and stock status, so that I can verify my intended purchases before proceeding to checkout.
*   **US-02:** As an Entitled Buyer, I want to adjust the quantity of items in my cart using a stepper, so that I can easily increase or decrease the number of items I want to buy.
*   **US-03:** As an Entitled Buyer, I want to delete items or move them to a 'Saved for Later' list, so that I can curate my active cart without permanently losing track of items I might want to buy in the future.
*   **US-04:** As an Entitled Buyer, I want to view my order subtotal and proceed to checkout, so that I can see the total cost of my active cart and initiate the purchase process.

## Inputs/Outputs/Data Flow
*   **Inputs:**
    *   Cart and CartItem records (via Connect API).
    *   Omnichannel Inventory (OCI) real-time stock data.
    *   Pricebook / Price Adjustment Schedules (for MRP and discount calculations).
    *   User's active currency and locale settings.
    *   Custom Labels / Translated store content.
*   **Outputs:**
    *   Updated CartItem records (quantity changes, status changes for 'Saved for Later', deletions).
    *   Recalculated Cart subtotal.
*   **Data Flow:** None specified.

## Flows
None specified.

## Edge Cases & Error States
*   **EC-01: Empty Cart**
    *   *Condition:* The user navigates to the cart, but the active cart is empty.
    *   *Expected Behavior:* Display an empty state message (via Custom Labels) and a 'Continue Shopping' button navigating back to the catalog.
*   **EC-02: Quantity Exceeds Stock**
    *   *Condition:* The user increases the quantity of an item beyond the available OCI stock.
    *   *Expected Behavior:* The quantity stepper prevents further increments, and an inline error message informs the user of the maximum available stock.
*   **EC-03: Item Inactive or Unentitled**
    *   *Condition:* An item in the active cart becomes inactive or is removed from the entitlement policy.
    *   *Expected Behavior:* The item is flagged as unavailable, the price is removed from the subtotal, and the 'Proceed to Checkout' button is disabled until the user removes the item.

## Acceptance Criteria (Given/When/Then)
*   **View Active Cart (US-01):** GIVEN I have items in my active cart WHEN I navigate to the Shopping Cart page THEN I see a list of line items displaying the product image, name, selected variant, price with MRP strikethrough, discount percentage, and stock status.
*   **Adjust Quantity (US-02):** GIVEN I am viewing my active cart WHEN I click the quantity stepper to increase or decrease an item's quantity THEN the cart updates the line item total and the order subtotal automatically.
*   **Save for Later (US-03):** GIVEN I am viewing my active cart WHEN I click 'Save for Later' on a line item THEN the item is removed from the active cart, the subtotal updates, and the item appears in the 'Saved for Later' tab.
*   **Proceed to Checkout (US-04):** GIVEN I have at least one available item in my active cart WHEN I review the order summary panel THEN I see the calculated subtotal and an enabled 'Proceed to Checkout' button.
*   **Empty Cart (EC-01):** GIVEN my active cart has no items WHEN I navigate to the Shopping Cart page THEN I see a localized empty state message and a 'Continue Shopping' button.
*   **Stock Limit Reached (EC-02):** GIVEN an item has limited OCI stock WHEN I attempt to increase the quantity beyond available stock THEN the stepper is disabled for further increments and an inline error displays the maximum available stock.
*   **Unavailable Item (EC-03):** GIVEN an item in my cart is no longer active or entitled WHEN I view the cart THEN the item is marked unavailable, its price is excluded from the subtotal, and checkout is disabled until it is removed.

## Non-Functional Requirements
*   **NFR-01 (Performance):** The shopping cart page must load and render active cart items efficiently. Initial page load and rendering of up to 50 cart items must complete in under 2.5 seconds.
*   **NFR-02 (Accessibility):** Dynamic updates to the cart (e.g., quantity changes, subtotal recalculations) must be announced to assistive technologies. 100% of dynamic cart updates must utilize `aria-live` regions.
*   **NFR-03 (Usability):** The cart layout must accommodate translated strings without breaking the UI structure. Layouts must tolerate at least 30% text expansion.

## Assumptions
*   **AD-03:** Standard Salesforce B2B Commerce Connect APIs support moving items between active and 'Saved for Later' states without custom Apex DML. (Impact if wrong: Custom Apex controllers will need to be built, increasing technical debt and violating the preference for standard APIs).

## Dependencies
*   **AD-01:** Omnichannel Inventory (OCI) is configured and accessible for the storefront. (Impact if wrong: Stock status cannot be displayed, and inventory validation will fail or require fallback logic).
*   **AD-02:** Price Adjustment Schedules or Pricebooks are correctly configured to provide the MRP and discount percentages. (Impact if wrong: The UI will not be able to display the MRP strikethrough or discount percentage accurately).

## Open Questions
*   **OQ-01:** How long should items remain in the 'Saved for Later' list before expiring? *(Recommended default: Items remain indefinitely until the user deletes them, purchases them, or the product is deactivated in the catalog).*
*   **OQ-02:** Should 'Saved for Later' items reserve inventory in OCI? *(Recommended default: No, inventory is only reserved during the active checkout process to prevent stock hoarding).*
*   **OQ-03:** Are there specific purchase quantity rules (minimum, maximum, increment) that need to be enforced by the stepper? *(Recommended default: Enforce standard B2B Commerce purchase quantity rules if they are defined on the product record).*
*   **OQ-04:** What are the MoSCoW priorities for the functional requirements? (None specified in input).
*   **OQ-05:** What are the exact step-by-step user flows or system data flow diagrams for the cart interactions? (None specified in input).

## Success Metrics
*   **SM-01 (Leading) - Cart-to-Checkout Progression Rate:** Greater than 65% of users who view an active cart click 'Proceed to Checkout'. (Data required: Storefront analytics tracking cart page views and checkout button clicks).
*   **SM-02 (Lagging) - Cart Abandonment Rate:** Decrease cart abandonment by 10% quarter-over-quarter. (Data required: Order history and abandoned cart reports).
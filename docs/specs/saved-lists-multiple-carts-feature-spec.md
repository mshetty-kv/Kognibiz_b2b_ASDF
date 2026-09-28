# Saved Lists (Multiple Carts) Feature

**ID:** FS-SAVED-LISTS-001  
**Version:** 1.0  
**Status:** Draft  
**Type:** Functional Specification  

## Overview & Purpose
Buyers currently lack a way to save items for future purchase without cluttering their active checkout cart, as the 'Lists' tab is currently a placeholder. To visually and functionally mirror the Amazon Business experience, this feature implements saved lists by leveraging Salesforce B2B Commerce's secondary cart type ('Template' cart). This enables users to create, manage, and store lists of items for future procurement cycles and seamlessly transition them to their active checkout cart when ready, driving future conversions and improving the buyer experience.

## Goals
* **OBJ-01:** Enable buyers to save products for future purchase without adding them to the active checkout cart.
* **OBJ-02:** Drive future sales through saved intent.

## Target Users
* **Entitled Buyer:** End users who browse and purchase products, requiring a way to save items for later.
* **Storefront Administrator:** System administrators responsible for managing storefront performance, data storage, and cart cleanup jobs.

## Stakeholders
* **Entitled Buyer**
  * *Decision authority:* None
  * *Concerns:* Easily saving items for later without initiating checkout; Organizing saved items into distinct, named lists; Quickly moving items from a list to the active cart.
* **Storefront Administrator**
  * *Decision authority:* Configuration of cart cleanup jobs
  * *Concerns:* System performance with multiple carts per user; Data storage limits regarding abandoned template carts.

## Scope (In / Out)
**In Scope:**
* Creation, deletion, and management of secondary carts with the 'Template' type.
* Viewing a directory of lists and the detailed contents of individual lists.
* Fetching and displaying real-time entitled pricing and availability for saved items.
* Adding items to lists from Product Detail Pages (PDP), Product List Pages (PLP), and the active Cart page.
* Copying line items from a 'Template' cart to the active 'Checkout' cart.

**Out of Scope:**
* Collaborative or shared lists across multiple buyers in a group.
* Subscribe and Save functionality.
* Uploading lists via CSV.

## MoSCoW
None specified.

## Functional Requirements
* **FR-01:** The system shall allow the creation of a secondary cart with the type 'Template' and a user-defined name. *(Traces to US-01)*
* **FR-02:** The system shall allow users to update the name of, or delete, an existing 'Template' cart they own. *(Traces to US-01)*
* **FR-03:** The system shall retrieve and display a list of all 'Template' carts associated with the current user's account. *(Traces to US-02)*
* **FR-04:** The system shall display the line items of a selected 'Template' cart, utilizing standard commerce wire adapters to fetch current entitled pricing and availability. *(Traces to US-02)*
* **FR-05:** The system shall expose an 'Add to List' LWC action on Product Detail Pages, Product List Pages, and the active Cart page. *(Traces to US-03)*
* **FR-06:** The system shall allow copying a line item from a 'Template' cart to the active 'Checkout' cart via the Connect API. *(Traces to US-04)*
* **BR-01:** List items must reflect real-time pricing and entitlement. The system must fetch current pricing when the list is viewed.
* **BR-02:** All user-facing text in the Lists feature must be sourced from Custom Labels to ensure full US multi-language configuration compliance.

## User Stories
* **US-01:** As an Entitled Buyer, I want to create, rename, and delete custom lists, so that I can organize my saved items according to my procurement needs.
* **US-02:** As an Entitled Buyer, I want to view my lists and their contents, so that I can review what I have saved for future purchases.
* **US-03:** As an Entitled Buyer, I want to add items to a list from product pages and my active cart, so that I can seamlessly save items I discover or decide not to buy immediately.
* **US-04:** As an Entitled Buyer, I want to move items from a list to my active cart, so that I can purchase the items I previously saved.

## Inputs/Outputs/Data Flow
None specified.

## Flows
None specified.

## Edge Cases & Error States
* **EC-01:** A product saved in a list is no longer entitled to the buyer or is out of stock.
  * *Expected State:* The item remains in the list but displays an 'Unavailable' or 'Out of Stock' badge. The 'Add to Cart' button for that specific item is disabled.
* **EC-02:** The user attempts to create a list with an empty name.
  * *Expected State:* The 'Save' or 'Create' button is disabled until a valid, non-empty string is entered.
* **EC-03:** An API error occurs when moving an item from a list to the active cart.
  * *Expected State:* The system surfaces a localized error inline using `AuraHandledException`; the item is not removed from the list.

## Acceptance Criteria (Given/When/Then)
* **List Creation:** GIVEN I am an authenticated buyer on the Lists tab WHEN I click 'Create List', enter a valid name, and submit THEN a new Template cart is created with that name and appears in my directory of lists.
* **List Deletion:** GIVEN I have an existing list WHEN I select the 'Delete' action for that list and confirm THEN the Template cart is permanently removed and no longer displays in my directory.
* **View List Directory:** GIVEN I navigate to the Lists tab WHEN the page loads THEN I see a directory of all my saved lists (Template carts).
* **View List Details:** GIVEN I am viewing my directory of lists WHEN I click on a specific list name THEN I am navigated to a detail view showing all products, quantities, and current entitled prices for that list.
* **Add to List from PDP:** GIVEN I am viewing a Product Detail Page (PDP) WHEN I click 'Add to List' and select a target list from the dropdown THEN the product is added to the selected Template cart and a success confirmation is shown inline.
* **Save for Later from Cart:** GIVEN I have items in my active checkout cart WHEN I click 'Save for later' or 'Add to List' on a cart line item THEN the item is added to the selected list and removed from the active checkout cart.
* **Move to Cart from List:** GIVEN I am viewing the details of a specific list WHEN I click 'Add to Cart' on a line item THEN the item is added to my active checkout cart and remains in the list for future reference.
* **Empty List Name (EC-02):** GIVEN I am creating a list WHEN I leave the name field empty THEN the 'Save' or 'Create' button is disabled.
* **Unavailable Item (EC-01):** GIVEN I am viewing a list detail page WHEN an item in the list is out of stock or no longer entitled THEN the item displays an 'Unavailable' or 'Out of Stock' badge AND the 'Add to Cart' button for that item is disabled.
* **API Error on Move (EC-03):** GIVEN I am moving an item from a list to the active cart WHEN an API error occurs THEN a localized error is surfaced inline AND the item is not removed from the list.

## Non-Functional Requirements
* **NFR-01 (Usability):** List management UI components and modals must tolerate text expansion for multi-language support. Layouts must remain unbroken and legible with up to 30% text expansion.
* **NFR-02 (Accessibility):** Dynamic updates, such as adding an item to a list or moving it to the cart, must be announced to screen readers. 100% of inline success/error messages must use `aria-live` regions.
* **NFR-03 (Performance):** Adding an item to a list or moving it to the active cart must be highly responsive. Connect API calls for list item manipulation must complete in under 2 seconds at the 95th percentile.

## Assumptions
* **AD-02:** The standard Salesforce cart model allows custom naming of 'Template' carts. (Impact if wrong: A minor schema update may be required to store the custom list name in a custom field on the WebCart object).

## Dependencies
* **AD-01:** Salesforce B2B Commerce Connect API supports the creation and management of secondary carts with the 'Template' type. (Impact if wrong: Custom Apex would be required to manage custom objects for lists, violating the directive to prioritize standard commerce wire adapters).

## Open Questions
* **OQ-01:** Where exactly should the 'Add to List' button appear across the storefront? *(Recommended default from requirements: On Product Detail Pages (PDP), Product List Pages (PLP), and within the active Cart).*
* **OQ-02:** When an item is 'moved' from a list to the active cart, should it be removed from the list or kept in the list? *(Recommended default from requirements: Keep it in the list to allow buyers to use lists as recurring templates).*
* **OQ-03:** What are the specific Acceptance Criteria for renaming an existing list? (US-01 mentions renaming, but no criteria are provided).
* **OQ-04:** What is the MoSCoW prioritization for the listed requirements?
* **OQ-05:** What are the specific Inputs, Outputs, and Data Flows for this feature?
* **OQ-06:** Are there any visual system flows or diagrams required for this feature?

## Success Metrics
* **SM-01 (Leading) - List Feature Adoption:** 15% of active entitled buyers create at least one list within the first quarter of launch. (Data required: Count of unique users owning at least one 'Template' cart).
* **SM-02 (Lagging) - List to Cart Conversion:** 10% of items added to lists are eventually moved to an active cart and purchased. (Data required: Order product history traced back to items originating from a 'Template' cart).
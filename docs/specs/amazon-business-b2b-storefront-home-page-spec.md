# Amazon Business B2B Storefront Home Page

**ID:** SPEC-B2B-HOME-001
**Version:** 1.0
**Status:** Draft
**Type:** Functional Specification

## Overview & Purpose
The organization is building an Amazon Business B2B Commerce Cloud storefront on Salesforce. The home page must visually mirror the Amazon experience while strictly adhering to US multi-currency and multi-language configurations. This specification defines the component tree, data mapping, and behavior for the header, navigation, hero carousel, promo rail, and product shelves, ensuring all data is sourced dynamically from Salesforce without the use of mock data.

## Goals
*   **OBJ-01:** Deliver a responsive, data-driven home page using standard B2B Commerce wire adapters and Connect API. (Measure: 100% of page content renders from real Salesforce data with zero hardcoded mock arrays).
*   **OBJ-02:** Ensure modular stability and graceful degradation across all page sections. (Measure: A data fetch failure in one section results in a localized error state without blanking the rest of the page).

## Target Users
*   **B2B Buyer:** Users seeking to find products easily via search and navigation, view accurate contract pricing and quantity discounts, and manage cart and account settings.
*   **Store Administrator:** Users responsible for managing promotional content (hero, promo rail), configuring category trees and product shelves, and ensuring localization and currency settings apply correctly.

## Stakeholders
*   **B2B Buyer:** Decision authority: None.
*   **Store Administrator:** Decision authority: Content and configuration approval.

## Scope
**In Scope:**
*   Implementation of the `storefrontHeader` container component (including location modal and search bar).
*   Implementation of the `categoryMenu` component.
*   Implementation of the `heroCarousel` container and leaf components.
*   Implementation of the `promoRail` container and leaf components.
*   Implementation of the `productShelf` container and leaf components.
*   Strict enforcement of US multi-currency configuration (USD corporate) superseding visual references.
*   Strict Smart Container / Dumb Child architecture (Lightning Web Components).

**Out of Scope:**
*   Implementation of the page footer.
*   Use of mock data, hardcoded JSON arrays, or placeholder content.

## MoSCoW
None specified.

## Functional Requirements

*   **FR-01: Storefront Header**
    The system shall implement a `storefrontHeader` container component using standard B2B adapters (`getCartSummary`, `getSessionContext`). It shall pass data to leaf components like `locationModal` (`@api currentLocation`, `@api isOpen`, emits `updatelocation`) and `searchBar` (`@api categories`, emits `searchsubmit`).
    *   **Acceptance Criteria:**
        *   **Given** the home page is loading, **When** the `storefrontHeader` initializes, **Then** it successfully retrieves data via `getCartSummary` and `getSessionContext` and passes it to the `locationModal` and `searchBar` leaf components.

*   **FR-02: Category Menu**
    The system shall implement a `categoryMenu` component that fetches the category tree using the Connect API `commerce/webstores/{webstoreId}/categories` endpoint and renders the hierarchy.
    *   **Acceptance Criteria:**
        *   **Given** a user interacts with the category navigation, **When** the `categoryMenu` component is invoked, **Then** it fetches and displays the full category tree from the Connect API endpoint.

*   **FR-03: Hero Carousel**
    The system shall implement a `heroCarousel` container component that fetches slide data. It shall pass data to `heroSlide` leaf components via `@api slideData` and handle prev/next/pause events internally.
    *   **Acceptance Criteria:**
        *   **Given** the hero carousel has fetched slide data, **When** the component renders, **Then** it passes the data to `heroSlide` leaf components and internally processes prev, next, and pause events.

*   **FR-04: Promo Rail**
    The system shall implement a `promoRail` container component that fetches promotional cards. It shall pass data to `promoCard` leaf components via `@api cardData` and `@api variant` (offer, service, category, metric).
    *   **Acceptance Criteria:**
        *   **Given** the promo rail has fetched promotional data, **When** the component renders, **Then** it passes the data and variant type to the `promoCard` leaf components.

*   **FR-05: Product Shelf**
    The system shall implement a `productShelf` container component that fetches product data using Connect API (`commerce/webstores/{webstoreId}/search` or pricing endpoints). It shall pass data to `productTile` leaf components via `@api product` and `@api currencyCode`, listening for `addtocart` events.
    *   **Acceptance Criteria:**
        *   **Given** a product shelf is rendered, **When** a user interacts with a product tile, **Then** the `productShelf` container listens for and captures the `addtocart` event emitted by the `productTile` leaf component.

## User Stories

*   **US-01:** As a B2B Buyer, I want to use the utility header and navigation, so that I can search for products, update my location, view my cart, and access category menus.
    *   **Acceptance Criteria:**
        *   **Given** I am on the home page, **When** I click the 'All' hamburger menu, **Then** I see the full category tree sourced from the store's data.
        *   **Given** I type in the search input, **When** I pause for 300ms, **Then** the typeahead triggers and a submit navigates to results with the selected category scope applied.

*   **US-02:** As a B2B Buyer, I want to view the hero carousel and promo card rail, so that I am aware of current offers, business solutions, and terms.
    *   **Acceptance Criteria:**
        *   **Given** I am viewing the home page with default OS settings, **When** the hero carousel is visible, **Then** it auto-advances through slides and pauses when I hover or focus on it.
        *   **Given** I have 'prefers-reduced-motion' enabled in my OS, **When** the hero carousel loads, **Then** it does not auto-advance.

*   **US-03:** As a B2B Buyer, I want to view product shelves, so that I can easily resume shopping or discover deals with my specific contract pricing.
    *   **Acceptance Criteria:**
        *   **Given** I am an entitled buyer, **When** I scroll to a product shelf, **Then** I see product tiles with images, names, and my specific contract pricing formatted in the active currency.

## Inputs/Outputs/Data Flow
*   **Inputs:**
    *   Salesforce Connect API (`commerce/webstores/{webstoreId}/categories`, `commerce/webstores/{webstoreId}/search`, pricing endpoints).
    *   Standard B2B Commerce wire adapters (`getCartSummary`, `getSessionContext`).
    *   Marketing content data source (CMS or Custom Object).
    *   User interactions (clicks, search input, scroll).
*   **Outputs:**
    *   Rendered UI components (Header, Navigation, Hero Carousel, Promo Rail, Product Shelves).
    *   CustomEvents emitted by leaf components (`updatelocation`, `searchsubmit`, `addtocart`).
*   **Data Flow:**
    *   Data is fetched exclusively by Smart Container components (e.g., `storefrontHeader`, `heroCarousel`, `productShelf`) via wire adapters or Connect API.
    *   Data is passed downward to Dumb Child leaf components (e.g., `locationModal`, `heroSlide`, `productTile`) strictly via `@api` properties.
    *   User actions in leaf components emit CustomEvents upward to be handled by the Smart Containers.

## Flows
None specified.

## Edge Cases & Error States

*   **EC-01: Section Data Fetch Failure**
    *   **Given** the home page is loading, **When** a specific section (e.g., promo rail) fails to fetch data from Salesforce, **Then** the failing section displays a localized error state and degrades gracefully without blanking the rest of the page.
*   **EC-02: Empty Product Shelf**
    *   **Given** a product shelf query executes, **When** the query returns zero products, **Then** the shelf renders its empty state as defined by the design, rather than collapsing entirely or showing an error.
*   **EC-03: Unauthenticated User Access**
    *   **Given** a logged-out user views the home page, **When** the page renders, **Then** the account menu shows a sign-in prompt, and product shelves display public catalog data without entitled contract pricing.

## Acceptance Criteria (Given/When/Then)
*(Acceptance criteria are distributed across the Functional Requirements, User Stories, and Edge Cases sections above to ensure every requirement and scenario is strictly verifiable.)*

## Non-Functional Requirements

*   **NFR-01 (Performance):** Below-the-fold shelves and images must lazy-load with explicit dimensions to prevent layout shifts. Target: 0 Cumulative Layout Shift (CLS) score during page load and scroll.
*   **NFR-02 (Accessibility):** Dynamic regions must use `aria-live`, and animations must respect user motion preferences. Target: 100% compliance with `prefers-reduced-motion` media query for the hero carousel.
*   **NFR-03 (Usability):** The layout must tolerate text expansion for multi-language support. Target: UI components remain intact without text clipping or overlapping for up to 30% text expansion.
*   **BR-01 (Business Rule):** US multi-currency configuration strictly supersedes visual references. Money formats must use `lightning-formatted-number` bound to the active currency.
*   **BR-02 (Business Rule):** Strict Smart Container / Dumb Child architecture. Only container components may invoke wire adapters, Connect API, or Apex. Leaf components must rely entirely on `@api` inputs and emit CustomEvents.

## Assumptions
*   **AD-02:** Marketing content (Hero Carousel slides and Promo Rail cards) will be stored in Salesforce CMS or a Custom Object. (Impact if wrong: The components will have no data source to query, blocking the dynamic rendering requirement).
*   **Architecture Assumption:** The project utilizes Salesforce Lightning Web Components (LWC) as the frontend framework, inferred from the explicit requirements for `@api` decorators, `lightning-formatted-number`, and standard B2B wire adapters.

## Dependencies
*   **AD-01:** Standard B2B Commerce wire adapters and Connect API support the required data retrieval for cart, categories, and product pricing. (Impact if wrong: Custom Apex with `with sharing` and FLS enforcement will need to be written, increasing development time).

## Open Questions
*   **OQ-01:** What is the exact Salesforce data source for the Hero Carousel and Promo Card Rail, as standard B2B Commerce does not include native objects for these? *(Recommended default: Use Salesforce CMS to author and deliver the marketing content via the Connect API).*
*   **OQ-02:** Which specific Connect API endpoint or standard adapter should be used for the 'Pick up where you left off' product shelf? *(Recommended default: Use the standard B2B Commerce recently viewed products adapter, falling back to a custom Apex query on the RecentlyViewed object if necessary).*
*   **OQ-03:** What is the MoSCoW prioritization for the listed features? (None specified in the provided requirements).
*   **OQ-04:** Are there specific step-by-step user flows that need to be documented as flowcharts? (None specified in the provided requirements).

## Success Metrics
*   **SM-01 (Lagging):** Console Errors. Target: 0 console errors during page load, navigation, and state changes. (Data required: Browser console logs during QA testing).
*   **SM-02 (Leading):** Keyboard Accessibility. Target: 100% of interactive controls are reachable and operable via keyboard only. (Data required: Manual accessibility testing results).
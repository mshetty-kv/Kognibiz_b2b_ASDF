# kognibiz Engineering Constitution

**Version:** 1.0.0
*This constitution is the supreme engineering authority for the kognibiz project.*

## Mission

Build a reliable, secure, maintainable, observable, and scalable **B2B Commerce Storefront on Salesforce**, using **Apex for backend business logic and integrations** and **Lightning Web Components (LWC) for a modular, responsive storefront experience**.

## Core Values

| Value | Over | Anti-Value |
| :--- | :---: | :--- |
| **Testing** | over | Trust |
| **Automation** | over | Manual processes |
| **Explicitness** | over | Magic |
| **Maintainability** | over | Shortcuts |
| **Observability** | over | Assumptions |
| **Simplicity** | over | Cleverness |
| **Security** | over | Convenience |
| **Correctness** | over | Speed |

## Technology Stack

**Required Technologies / Frameworks:**
*   **Platform:** Salesforce Lightning Platform, Salesforce B2B Commerce
*   **Backend:** Apex, SOQL, SOSL
*   **Frontend:** Lightning Web Components (LWC)
*   **Testing:** Apex Test Framework, Jest (for LWC)
*   **Tooling:** Salesforce CLI (SFDX), Node.js (for local tooling/linting)

**Forbidden Technologies / Practices:**
*   Plain JavaScript in application code (use TypeScript/ES6+ standards where applicable in LWC).
*   Unmaintained dependencies.
*   Experimental libraries in production without explicit architectural approval.

**Compatibility Targets:**
*   All the latest browser versions (Chrome, Firefox, Safari, Edge).

## Repository Structure

The repository follows the standard Salesforce DX (SFDX) project structure to ensure compatibility with Salesforce deployment tools and CI/CD pipelines.

```text
kognibiz/
├── force-app/main/default/
│   ├── classes/            # Apex classes, controllers, and services
│   ├── lwc/                # Lightning Web Components (HTML, JS, CSS, XML)
│   ├── objects/            # Custom objects and field definitions
│   ├── permissionsets/     # Security and access control definitions
│   ├── staticresources/    # Static assets (images, fonts, etc.)
│   └── labels/             # Custom labels for localization
├── scripts/                # Build, deployment, and data seeding scripts
├── config/                 # Scratch org definitions and project config
├── sfdx-project.json       # Salesforce project configuration
└── package.json            # Node dependencies for LWC testing, linting, and formatting
```

## Language/Code Standards

**Component/File Size Limits:**
*   **Target:** 300 lines of code per file.
*   **Mandatory Refactor:** 500 lines of code per file.

**Naming Conventions:**

| Element | Convention | Example |
| :--- | :--- | :--- |
| **Apex Classes** | PascalCase | `ProductService`, `CartController` |
| **Apex Methods** | camelCase | `getProducts()`, `updateCart()` |
| **Apex Variables** | camelCase | `productId`, `cartItems` |
| **LWC Folders** | camelCase | `productCard`, `cartSummary` |
| **LWC JS Classes** | PascalCase | `ProductCard`, `CartSummary` |
| **LWC JS Props/Funcs** | camelCase | `productName`, `handleAddToCart()` |
| **LWC HTML/CSS** | Match folder name | `productCard.html`, `productCard.css` |
| **Labels/Metadata** | PascalCase / SF Standard | `CheckoutErrorMessage` |
| **Test Classes** | Append `Test` | `ProductServiceTest` |
| **Test Methods** | camelCase, descriptive | `testGetProductsSuccess()` |
| **Constants** | SCREAMING_SNAKE_CASE | `MAX_CART_ITEMS` |

*Avoid:* Abbreviations, unclear names, single-letter variables, and inconsistent naming across Apex and LWC.

## Frontend Standards

**UI Framework & Rendering Model:**
LWC components render the storefront UI and handle user interactions, while Apex manages server-side business logic, Salesforce data access, and integrations. Prefer server-side data retrieval through Apex for authoritative business data and use client-side JavaScript only for UI state, interactions, validation, and browser-specific behavior. Keep components modular, reactive, accessible, and performant.

**State Management Preference Order:**
1.  **Apex/Salesforce data:** Source of truth for persistent business data and transactional state.
2.  **LWC component state:** Use reactive properties (`@track` where required) for local UI state and temporary interaction state.
3.  **Parent-to-child / child-to-parent communication:** Use `@api` properties and custom events for state shared between closely related components.
4.  **Lightning Message Service (LMS):** Use for state or events that must be shared across unrelated components.
5.  **Client-side storage:** Use `sessionStorage` or `localStorage` *only* when persistence across page navigation or sessions is explicitly required.
*(Avoid global/shared client-side state when local component state or server-side Salesforce state is sufficient.)*

**Styling Approach:**
Use **Salesforce Lightning Design System (SLDS)** as the sanctioned styling system for all LWC components. Prefer standard SLDS classes and Salesforce base components before writing custom CSS. Use component-scoped CSS only when SLDS does not provide the required styling. Avoid introducing external CSS frameworks or global styles without explicit justification.

## Backend/API & Validation Standards

**API Response Contract:**
All Apex controllers exposing data to LWC or external systems must return a standardized ASDF envelope:
```json
{
  "success": true,
  "data": { ... },
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

**Input/Output Validation Rules:**
*   Validate environment variables / custom metadata.
*   Validate route handlers / Apex `@AuraEnabled` parameters.
*   Validate server actions.
*   Validate forms.
*   Validate query strings.
*   Validate webhooks / REST endpoints.

**Validation Library / Approach:**
Apex native validation using typed wrapper/DTO classes, explicit parameter validation, Apex Schema methods, and custom validation utilities where required. LWC uses JavaScript validation for user experience, but Apex remains the authoritative validation layer.

## Error Handling

Errors must be explicitly caught, categorized, and handled. Do not swallow exceptions.

**Error Categories:**
*   `VALIDATION_ERROR`
*   `AUTHORIZATION_ERROR`
*   `AUTHENTICATION_ERROR`
*   `BUSINESS_ERROR`
*   `EXTERNAL_SERVICE_ERROR`
*   `INFRASTRUCTURE_ERROR`
*   `UNKNOWN_ERROR`

## Logging

All significant system events, errors, and state changes must be logged using a structured format.

**Required Structured Log Fields:**
*   `event`
*   `timestamp`
*   `requestId`
*   `userId` (if applicable/authenticated)
*   `metadata` (contextual data payload)

## Security

**Authentication & Authorization Location:**
Authentication and authorization must be enforced server-side in Apex and Salesforce security controls. LWC may control UI visibility but must **never** be trusted for access decisions. Enforce object/field permissions (`WITH SECURITY_ENFORCED`), sharing rules, buyer access, and business authorization on the server before performing protected operations.

**Secrets Handling:**
*   Read from environment variables / Salesforce Named Credentials.
*   Read from a secret manager / Encrypted Custom Fields.
*   **Never** commit secrets to version control.

## Accessibility

**Compliance Level:** WCAG 2.2 AA
All LWC components must utilize semantic HTML, proper ARIA attributes, and maintain keyboard navigability.

## Performance

**Performance Budgets:**
Target Core Web Vitals at “Good” thresholds:
*   **LCP (Largest Contentful Paint):** ≤ 2.5s
*   **INP (Interaction to Next Paint):** ≤ 200ms
*   **CLS (Cumulative Layout Shift):** ≤ 0.1

**Optimization Rules:**
Optimize images, lazy-load non-critical content, minimize JavaScript and unnecessary component rendering, use efficient Apex/Salesforce queries (avoid SOQL in loops), cache read-only data where appropriate (`@AuraEnabled(cacheable=true)`), and avoid unnecessary server round trips. Prefer Salesforce/LWC platform capabilities over custom performance frameworks.

## Testing

**Minimum Coverage:**
*   **Overall:** Minimum 80% test coverage.
*   **Critical Paths:** 95% coverage required for critical B2B Commerce business logic (cart, pricing, inventory, checkout, order processing, authorization, and integrations).
*   *Note:* New or modified code must include appropriate Apex and LWC tests.

**Required Test Types:**
*   **Unit:** Every utility & business rule (Apex Test Classes, LWC Jest).
*   **Integration:** Every service boundary.
*   **E2E:** Login, checkout, onboarding, payments, permissions.

## CI/CD

**CI Gates per PR:**
*   Linting (ESLint for LWC, PMD for Apex)
*   Typecheck / Compilation (SFDX deploy check)
*   Unit tests passing
*   Integration tests passing
*   E2E tests passing (on release)
*   Security scans passing (on release)

## Documentation

Code must be self-documenting where possible. Complex business logic in Apex must include ApexDoc comments. LWC components must include a `README.md` or inline documentation explaining `@api` properties and fired events.

## Observability

**Observability Requirements:**
*   **Metrics:** Latency, throughput, and failure rates for critical endpoints.
*   **Structured JSON logs:** For all backend operations and caught exceptions.
*   **Distributed tracing:** Where supported by Salesforce Event Monitoring or external integrations.

## AI Development Rules

**AI-Generated Code Policy:**
AI code is **UNTRUSTED** — it must be reviewed, tested, and validated by a human engineer before merging.

**Agent Restrictions (Without Human Approval):**
*   May NOT deploy to production.
*   May NOT rotate credentials.
*   May NOT modify infrastructure.
*   May NOT approve pull requests.

## Prompt / MCP / RAG Standards

*   **Prompts:** Must be version-controlled, documented, and tested. Prompt changes require peer review.
*   **MCP Integrations:** Must follow least-privilege access, be fully auditable, and easily revocable.
*   **RAG Sources:** Must be trusted, versioned, and source-attributed in outputs.

## Code Review Standards

Every Pull Request must explicitly answer two questions in its description:
1.  **Why?** (The business or technical justification)
2.  **What changed?** (A summary of the implementation)

## Git Standards

**Branch Conventions:**
Use lowercase kebab-case with a type prefix:
*   `feature/*` — New functionality (e.g., `feature/product-search`)
*   `bugfix/*` — Bug fixes (e.g., `bugfix/cart-total`)
*   `hotfix/*` — Urgent production fixes (e.g., `hotfix/checkout-error`)
*   `chore/*` — Maintenance, configuration, tooling (e.g., `chore/update-dependencies`)

**Commit Conventions:**
Use conventional commit prefixes:
*   `feat` — New feature
*   `fix` — Bug fix
*   `refactor` — Code restructuring without behavior change
*   `test` — Tests
*   `docs` — Documentation
*   `perf` — Performance improvements
*   `chore` — Maintenance/tooling

## Dependency Rules

Any new dependency (NPM package for tooling/LWC, or managed package in Salesforce) must:
*   Pass a security scan.
*   Pass a license review.
*   Be actively maintained.
*   *Rule of thumb:* Prefer building over adding a dependency when the requirement is small.

## Definition of Done

A task is not complete until all of the following are true:
*   [ ] Requirements implemented.
*   [ ] Tests written.
*   [ ] Tests passing.
*   [ ] Typecheck / Compilation passing.
*   [ ] Lint passing.
*   [ ] Security review completed.
*   [ ] Documentation updated.
*   [ ] Accessibility validated.
*   [ ] Performance validated.
*   [ ] Code reviewed.

## Non-Negotiable Rules (NEVER / ALWAYS)

*   **ALWAYS** enforce object, field, and sharing security in Apex (`WITH SECURITY_ENFORCED`).
*   **NEVER** trust the client (LWC) for authorization, pricing, or checkout validation.
*   **NEVER** commit secrets, passwords, or API keys to the repository.
*   **ALWAYS** write tests for new functionality; code without tests will be rejected.
*   **NEVER** use SOQL or DML statements inside `for` loops.
*   **ALWAYS** use the standard ASDF response envelope for client-facing Apex controllers.

## Amendment Process

Changes to this constitution require:
Written proposal → Architecture review → Team approval → Version increment.
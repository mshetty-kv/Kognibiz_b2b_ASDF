# kognibiz Engineering Constitution
**Version:** 1.0.0

This constitution declares itself the supreme engineering authority for the kognibiz project. All code, architecture, and tooling decisions must comply with these rules.

## Mission
Build a reliable, secure, maintainable, observable, and scalable **B2B Commerce Storefront on Salesforce**, using **Apex for backend business logic and integrations** and **Lightning Web Components (LWC) for a modular, responsive storefront experience**.

## Core Values
1. **Testing over trust**
2. **Automation over manual processes**
3. **Explicitness over magic**
4. **Maintainability over shortcuts**
5. **Observability over assumptions**
6. **Simplicity over cleverness**
7. **Security over convenience**
8. **Correctness over speed**

## Technology Stack

| Category | Technology |
| :--- | :--- |
| **Backend / Business Logic** | Apex, SOQL, SOSL |
| **Frontend UI** | Lightning Web Components (LWC) |
| **Styling** | Salesforce Lightning Design System (SLDS) |
| **Testing** | ApexUnit (Backend), Jest (Frontend LWC) |
| **Tooling / CLI** | Salesforce DX (SFDX) / Salesforce CLI |

**Forbidden Technologies / Practices:**
* Plain JavaScript in application code (use LWC standards).
* Unmaintained dependencies.
* Experimental libraries in production without approval.

**Compatibility Targets:**
* All the Latest browser versions.

## Repository Structure
The repository follows the standard Salesforce DX (SFDX) project structure to ensure compatibility with Salesforce CLI and deployment pipelines.

```text
kognibiz/
├── config/                     # Scratch org definitions and project configuration
├── force-app/main/default/     # Primary Salesforce metadata directory
│   ├── classes/                # Apex classes and backend logic
│   ├── lwc/                    # Lightning Web Components (HTML, JS, CSS, XML)
│   ├── triggers/               # Apex triggers (minimal logic, delegate to handler classes)
│   ├── objects/                # Custom objects and field definitions
│   ├── permissionsets/         # Security and access control definitions
│   └── staticresources/        # Static assets (images, fonts, etc.)
├── scripts/                    # Build, deployment, and data seeding scripts
├── package.json                # Node.js dependencies (Jest, Prettier, ESLint)
└── sfdx-project.json           # SFDX project configuration
```

## Language/Code Standards

**Component/File Size Limits:**
* **Target:** 300 lines
* **Mandatory Refactor:** 500 lines

**Naming Conventions:**
* **Apex classes:** PascalCase, e.g., `ProductService`, `CartController`
* **Apex methods:** camelCase, e.g., `getProducts()`, `updateCart()`
* **Apex variables:** camelCase, e.g., `productId`, `cartItems`
* **LWC components:** camelCase folder names, e.g., `productCard`, `cartSummary`
* **LWC JavaScript classes:** PascalCase, e.g., `ProductCard`, `CartSummary`
* **LWC JavaScript properties/functions:** camelCase, e.g., `productName`, `handleAddToCart()`
* **LWC HTML/CSS files:** match the component folder name, e.g., `productCard.html`, `productCard.css`
* **Custom labels, metadata, and configuration:** use clear, descriptive PascalCase or Salesforce-standard naming conventions
* **Test classes:** append `Test`, e.g., `ProductServiceTest`
* **Test methods:** descriptive camelCase names, e.g., `testGetProductsSuccess()`
* **Constants:** SCREAMING_SNAKE_CASE, e.g., `MAX_CART_ITEMS`
* **Avoid:** abbreviations, unclear names, single-letter variables, and inconsistent naming across Apex and LWC.

## Frontend Standards

**UI Rendering:**
LWC components render the storefront UI and handle user interactions, while Apex manages server-side business logic, Salesforce data access, and integrations. Prefer server-side data retrieval through Apex for authoritative business data and use client-side JavaScript only for UI state, interactions, validation, and browser-specific behavior; keep components modular, reactive, accessible, and performant.

**State Management Preference Order:**
1. **Apex/Salesforce data** — Source of truth for persistent business data and transactional state.
2. **LWC component state** — Use reactive properties (`@track` where required) for local UI state and temporary interaction state.
3. **Parent-to-child / child-to-parent communication** — Use `@api` properties and custom events for state shared between closely related components.
4. **Lightning Message Service (LMS)** — Use for state or events that must be shared across unrelated components.
5. **Client-side storage** — Use `sessionStorage` or `localStorage` only when persistence across page navigation or sessions is explicitly required.
*Avoid global/shared client-side state when local component state or server-side Salesforce state is sufficient.*

**Styling Approach:**
Use **Salesforce Lightning Design System (SLDS)** as the sanctioned styling system for all LWC components. Prefer standard SLDS classes and Salesforce base components before writing custom CSS; use component-scoped CSS only when SLDS does not provide the required styling. Avoid introducing external CSS frameworks or global styles without explicit justification.

## Backend/API & Validation Standards

**API Response Contract:**
All `@AuraEnabled` Apex methods and custom REST APIs must return a standardized ASDF envelope wrapper class:
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
* Validate environment variables (Custom Metadata/Named Credentials).
* Validate route handlers / API endpoints.
* Validate server actions (`@AuraEnabled` methods).
* Validate forms.
* Validate query strings.
* Validate webhooks.

**Validation Library / Approach:**
Apex native validation using typed wrapper/DTO classes, explicit parameter validation, Apex Schema methods, and custom validation utilities where required. LWC uses JavaScript validation for user experience, but Apex remains the authoritative validation layer.

## Error Handling
Errors must be categorized into one of the following standard types:
* `VALIDATION_ERROR`
* `AUTHORIZATION_ERROR`
* `AUTHENTICATION_ERROR`
* `BUSINESS_ERROR`
* `EXTERNAL_SERVICE_ERROR`
* `INFRASTRUCTURE_ERROR`
* `UNKNOWN_ERROR`

## Logging
All structured logs must include the following fields:
* `event`
* `timestamp`
* `requestId`
* `userId` (optional/if applicable)
* `metadata` (optional/contextual data)

## Security
* **Authentication & Authorization Location:** Authentication and authorization must be enforced server-side in Apex and Salesforce security controls. LWC may control UI visibility but must never be trusted for access decisions. Enforce object/field permissions (`WITH SECURITY_ENFORCED`), sharing rules, buyer access, and business authorization on the server before performing protected operations.
* **Secrets Handling:** Secrets must be managed via Salesforce Named Credentials, Protected Custom Metadata, or external Secret Managers. Never commit secrets to the repository.
* **Compliance:** No specific external compliance regimes are in scope for this PoC, but standard Salesforce security best practices apply.

## Accessibility
* **Compliance Level:** WCAG 2.2 AA.
* Ensure all custom LWC components utilize semantic HTML and appropriate ARIA attributes when SLDS base components do not suffice.

## Performance
* **Budgets (Core Web Vitals):** Target "Good" thresholds: LCP ≤ 2.5s, INP ≤ 200ms, and CLS ≤ 0.1.
* **Optimization Rules:** Optimize images, lazy-load non-critical content, minimize JavaScript and unnecessary component rendering, use efficient Apex/Salesforce queries (avoid SOQL in loops), cache read-only data where appropriate (`@AuraEnabled(cacheable=true)`), and avoid unnecessary server round trips. Prefer Salesforce/LWC platform capabilities over custom performance frameworks.

## Testing
* **Minimum Coverage:** Minimum 80% overall test coverage. **95% coverage required** for critical B2B Commerce business logic (cart, pricing, inventory, checkout, order processing, authorization, and integrations).
* **Required Test Types:**
  * **Unit:** Every utility & business rule (ApexUnit, Jest).
  * **Integration:** Every service boundary.
  * **E2E:** Login, checkout, onboarding, payments, permissions.
* New or modified code must include appropriate Apex and LWC tests.

## CI/CD
Every Pull Request must pass the following gates:
1. Lint (ESLint for LWC, PMD for Apex)
2. Typecheck / Compilation (SFDX deploy check)
3. Unit tests
4. Integration tests
5. E2E tests (on release)
6. Security scans (on release)

## Documentation
* **README:** Must contain setup instructions, SFDX scratch org creation steps, and local testing commands.
* **Architecture Decision Records (ADRs):** Required for any changes to state management patterns, integration architectures, or data models.
* **Code Comments:** Document "Why" not "What" for complex business logic in Apex.

## Observability
* **Metrics:** Latency, throughput, and failures (via Salesforce Event Monitoring / custom logging).
* **Logs:** Structured JSON logs (persisted to custom objects or external logging services).
* **Tracing:** Distributed tracing for external integrations.

## AI Development Rules
* **AI-Generated Code Policy:** AI code is UNTRUSTED — must be reviewed, tested, and validated before merge.
* **Agent Restrictions (without human approval):**
  * May NOT deploy to production.
  * May NOT rotate credentials.
  * May NOT modify infrastructure.
  * May NOT approve pull requests.

## Prompt/MCP/RAG Standards
* **Prompts:** Must be version-controlled, documented, and tested. Prompt changes require peer review.
* **MCP Integrations:** Must be least-privilege, auditable, and revocable.
* **RAG Sources:** Must be trusted, versioned, and source-attributed.

## Code Review Standards
Every Pull Request must explicitly answer:
1. **Why?** (Business/Technical justification)
2. **What changed?** (Summary of modifications)

## Git Standards
**Branch Naming Conventions:**
Use lowercase kebab-case with a type prefix:
* `feature/*` — New functionality (e.g., `feature/product-search`)
* `bugfix/*` — Bug fixes (e.g., `bugfix/cart-total`)
* `hotfix/*` — Urgent production fixes (e.g., `hotfix/checkout-error`)
* `chore/*` — Maintenance, configuration, tooling

**Commit Message Prefixes:**
* `feat` — New feature
* `fix` — Bug fix
* `refactor` — Code restructuring without behavior change
* `test` — Tests
* `docs` — Documentation
* `perf` — Performance improvements
* `chore` — Maintenance/tooling

## Dependency Rules
Any new dependency (NPM package for tooling/LWC or unmanaged Salesforce package) must:
1. Pass a security scan.
2. Pass a license review.
3. Be actively maintained.
4. *Rule of thumb:* Prefer building over adding a dependency when the requirement is small.

## Definition of Done
A task is not complete until all the following are true:
- [ ] Requirements implemented
- [ ] Tests written
- [ ] Tests passing
- [ ] Typecheck / Compilation passing
- [ ] Lint passing
- [ ] Security review completed
- [ ] Documentation updated
- [ ] Accessibility validated
- [ ] Performance validated
- [ ] Code reviewed

## Non-Negotiable Rules (NEVER / ALWAYS)
* **NEVER** trust the LWC client for authentication, authorization, or data validation.
* **NEVER** commit secrets, passwords, or API keys to the repository.
* **NEVER** write SOQL or DML statements inside `for` loops in Apex.
* **ALWAYS** enforce object and field-level security (`WITH SECURITY_ENFORCED`) in Apex queries.
* **ALWAYS** return the standard ASDF envelope from Apex `@AuraEnabled` methods.
* **ALWAYS** write tests for critical B2B commerce logic (cart, pricing, checkout) to meet the 95% threshold.

## Amendment Process
Written proposal → architecture review → team approval → version increment.
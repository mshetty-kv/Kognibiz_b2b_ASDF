# Constitution: office depot store (Version: 1.0.0)

*Assumption: As the project shape, languages, and required technologies were delegated, they have been defined as a Salesforce B2B Commerce (LWR) Metadata Repository using Salesforce DX (SFDX), Apex, LWC (JavaScript/HTML/CSS), and XML. Framework defaults have been adapted to idiomatic Salesforce practices where applicable.*

## Mission
To rigorously validate and document the capability of the ASDF framework to automate an end-to-end Salesforce B2B Commerce (LWR) implementation from a clean org. This project acts as an R&D Proof of Concept (PoC) to test ASDF's ability to correctly resolve Salesforce dependencies in strict order, configure standard storefront pages without rebuilding them, and accurately classify every requirement by actual tested behavior (OOTB vs. Configuration vs. Customization vs. Manual).

## Core Values
1. **Correctness over speed**: Dependency order in Salesforce is absolute; never skip a prerequisite step.
2. **Security over convenience**: Enforce Salesforce sharing rules, Field-Level Security (FLS), and CRUD permissions strictly.
3. **Simplicity over cleverness**: Configure standard pages and components; never rebuild standard OOTB behavior.
4. **Maintainability over shortcuts**: Use real Salesforce metadata types and API names exclusively.
5. **Observability over assumptions**: Classify ASDF support based on *actual tested behavior*, not theoretical capability.
6. **Explicitness over magic**: Document every manual workaround required when ASDF cannot automate a step.
7. **Automation over manual processes**: Maximize SFDX and Metadata API automation before falling back to manual steps.
8. **Testing over trust**: The PoC succeeds only when validated end-to-end via a successful buyer checkout flow.

## Technology Stack

### Required Technologies
*   **Platform**: Salesforce B2B Commerce (LWR), Salesforce Experience Cloud
*   **Tooling**: Salesforce CLI (SFDX), Metadata API, Tooling API
*   **Languages**: Apex (Backend), JavaScript/TypeScript (LWC), SOQL/SOSL (Data), XML (Metadata)
*   **Frameworks**: Lightning Web Components (LWC), Salesforce Lightning Design System (SLDS)

### Forbidden Technologies & Practices
*   Plain JavaScript in application code (outside of standard LWC requirements; use TypeScript where compilation is supported).
*   Unmaintained dependencies or experimental libraries.
*   Hardcoded Salesforce IDs (always query or use DeveloperNames).
*   SOQL queries or DML statements inside loops.
*   Direct database modifications outside of Salesforce APIs/SOQL.
*   Rebuilding standard B2B Commerce components (e.g., Cart, Checkout) when OOTB configuration suffices.

## Repository Structure
The repository must follow the standard Salesforce DX (SFDX) project structure.

```text
office-depot-store/
├── force-app/main/default/
│   ├── classes/            # Apex controllers and services
│   ├── lwc/                # Lightning Web Components
│   ├── experiences/        # Experience Cloud LWR site metadata
│   ├── digitalExperiences/ # Digital Experience bundles
│   ├── network/            # Network (Community) configuration
│   ├── permissionsets/     # Buyer and Admin permission sets
│   ├── profiles/           # Buyer profiles
│   ├── objects/            # Custom objects or standard object extensions
│   └── store/              # WebStore metadata
├── config/
│   └── project-scratch-def.json # Scratch org definition with B2B features enabled
├── scripts/
│   ├── apex/               # Anonymous Apex for data seeding (Products, Pricebooks)
│   └── bash/               # Orchestration scripts for dependency order execution
├── docs/
│   ├── ASDF_ASSESSMENT.md  # OOTB vs Config vs Customization vs Manual tracking
│   └── CONSTRUCT.md        # The single construct file used for generation
└── sfdx-project.json       # SFDX project configuration
```

## Language/Code Standards
*   **Apex**: Use `PascalCase` for class names and `camelCase` for methods/variables. Classes must declare sharing explicitly (`with sharing` or `without sharing`).
*   **LWC**: Use `camelCase` for folder and file names. Use `PascalCase` for the component class name.
*   **Metadata**: Use standard Salesforce API naming conventions (e.g., `Snake_Case__c` for custom fields).
*   **Component/File Size Limits**: 300 lines target, 500 mandatory refactor.
*   **Real API Names**: Use only valid Salesforce metadata types and API names. Hallucinated metadata types are strictly prohibited.

## Frontend Standards
*   **Standard First**: For every standard page (Home, PLP, PDP, Search, Category, Cart, Checkout, Order Confirmation, Order History, Order Detail, Account/Profile, Login/Registration), configure components and properties via metadata. Do not build custom LWCs unless standard components cannot meet the requirement.
*   **Styling**: Use Salesforce Lightning Design System (SLDS) tokens and classes. Avoid custom CSS unless absolutely necessary for branding not supported by LWR theme properties.
*   **Data Binding**: Use standard B2B Commerce wire adapters and imperative Apex only when standard data providers fall short.

## Backend/API & Validation Standards
*   **Bulkification**: All Apex triggers and services must be bulkified to handle up to 200 records per transaction.
*   **B2B APIs**: Utilize standard `ConnectApi` (Chatter in Apex) namespaces for Commerce operations (Pricing, Cart, Checkout) rather than custom SOQL/DML where standard APIs exist.
*   **Dependency Order Execution**: Backend setup must strictly follow: Org Enablement -> WebStore -> Settings -> Catalog -> Pricebooks -> Entitlements -> Buyer Groups -> Accounts/Contacts/Users -> Profiles/Perms -> Storefront Config -> Search Index -> Publish.

## Error Handling
Errors must be caught, handled gracefully, and mapped to the following categories (using custom Apex Exceptions where applicable):

| Category | Salesforce Implementation |
| :--- | :--- |
| `VALIDATION_ERROR` | `System.IllegalArgumentException`, DML `DMLException` |
| `AUTHENTICATION_ERROR` | Site login failures, invalid session handling |
| `AUTHORIZATION_ERROR` | `System.NoAccessException`, FLS/CRUD violations |
| `BUSINESS_ERROR` | Custom `CommerceBusinessException` (e.g., out of stock) |
| `EXTERNAL_SERVICE_ERROR` | `System.CalloutException` (Tax, Shipping, Payment integrations) |
| `INFRASTRUCTURE_ERROR` | Governor limit exceptions (`System.LimitException`) |
| `UNKNOWN_ERROR` | Unhandled generic `System.Exception` |

*In LWC, backend errors must be propagated using `AuraHandledException` to ensure secure and readable client-side error messages.*

## Logging
*Assumption: Observability relies on Salesforce native tools.*
*   **Required structured log fields**: `event`, `timestamp`, `requestId`, `userId`, `metadata`.
*   **Implementation**: Use a custom `Log__c` object or Platform Events (`LogEvent__e`) for persistent Apex logging, as standard debug logs are ephemeral.
*   **Client-side**: Use `console.error` for LWC development, but do not expose sensitive stack traces to the buyer in production.

## Security
*   **Authentication & Authorization**: Must occur server-side. Enforce `WITH SECURITY_ENFORCED` in SOQL queries or use `stripInaccessible()`.
*   **Secrets Handling**: Store API keys and integration credentials in Salesforce Named Credentials or Custom Metadata Types. Never commit secrets to the repository.
*   **Dependency Policy**: Any managed package or external dependency must pass security scan, pass license review, be maintained, and prefer building over adding a dependency when smaller.

## Performance
*   **Governor Limits**: Code must strictly adhere to Salesforce Governor Limits (e.g., 100 SOQL queries, 150 DML statements per synchronous transaction).
*   **LWC Rendering**: Minimize reactive property mutations to prevent unnecessary re-renders. Use `@wire` over imperative Apex where caching is beneficial.

## Testing
*   **Minimum Coverage**: 80% minimum overall, 95% for critical business logic (Checkout, Pricing, Cart).
*   **Required Test Types**:
    *   **Apex Unit Tests**: Must use `System.runAs()` to test buyer personas. Must assert against expected outcomes, not just execute code for coverage.
    *   **LWC Jest Tests**: Required for any custom frontend components.
    *   **E2E Validation**: Manual or automated validation of the full checkout flow (Login -> Browse -> PLP -> PDP -> Cart -> Checkout -> Order).

## CI/CD
*   **CI Gates per PR**: Lint (ESLint for LWC), Typecheck (if using TS), Apex Unit tests, SFDX Validation Deployment (`sfdx force:source:deploy --checkonly`).
*   **Validation**: Every PR must successfully validate against a clean scratch org configured for B2B Commerce.

## Documentation
*   **ASDF Assessment Matrix**: The repository must contain a living document (`ASDF_ASSESSMENT.md`) classifying every requirement as:
    1. Fully supported
    2. Supported with limitations
    3. Requires Salesforce config outside ASDF
    4. Requires customization (Apex/LWC/Flow/API)
    5. Not supported / blocker
*   **Blockers**: For anything ASDF cannot do, document the requirement, expected behavior, actual ASDF behavior, and manual workaround.

## Observability
*   Monitor Salesforce Setup Audit Trail for metadata changes.
*   Monitor Commerce App logs and Background Sync logs for Search Index and Pricing sync statuses.

## AI Development Rules
*   **AI-generated code policy**: AI code is UNTRUSTED — must be reviewed, tested, and validated before merge.
*   **Agent restrictions (each without human approval)**:
    *   May NOT deploy to production.
    *   May NOT rotate credentials.
    *   May NOT modify infrastructure (outside of ephemeral scratch orgs).
    *   May NOT approve pull requests.

## Prompt / MCP / RAG Standards
*   Prompts must be version-controlled, documented, and tested.
*   Prompt changes require review.
*   MCP integrations must be least-privilege, auditable, and revocable.
*   RAG sources must be trusted, versioned, and source-attributed (e.g., official Salesforce B2B Commerce Developer Guides).

## Code Review Standards
Every PR must answer:
1. What changed?
2. Why?
3. Risks? (Specifically regarding Salesforce governor limits and B2B dependencies)
4. Rollback plan?
5. Testing evidence? (Including OOTB vs Custom classification updates)

## Git Standards
*   **Branches**: `feature/*`, `bugfix/*`, `hotfix/*`, `chore/*`.
*   **Commit types**: `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, `chore`.

## Dependency Rules
*   Must pass security scan.
*   Must pass license review.
*   Must be maintained.
*   Prefer building over adding a dependency when smaller.

## Definition of Done
1. Requirements implemented.
2. Tests written and passing (Apex & Jest).
3. Typecheck and Lint passing.
4. Security review completed (FLS/CRUD/Sharing verified).
5. Documentation updated (Specifically the OOTB vs Config vs Customization assessment).
6. Accessibility validated (for any custom LWC).
7. Performance validated (Governor limits checked).
8. Code reviewed.
9. **End-to-End Validation**: Store created, dependencies resolved in order, buyer configured, storefront published, and a successful order placed via the cart/checkout flow.

## Non-Negotiable Rules
*   **NEVER** skip or reorder the Salesforce B2B Commerce dependency chain (Org -> WebStore -> Settings -> Catalog -> Pricebooks -> Entitlements -> Buyer Groups -> Accounts -> Users -> Storefront -> Index -> Publish).
*   **NEVER** rebuild a standard Salesforce B2B page (e.g., Cart, Checkout) if standard OOTB configuration can achieve the requirement.
*   **ALWAYS** classify ASDF capabilities based on actual tested behavior in a clean org, not assumptions.
*   **ALWAYS** use real Salesforce metadata types and API names.

## Amendment Process
Written proposal → architecture review → team approval → version increment.
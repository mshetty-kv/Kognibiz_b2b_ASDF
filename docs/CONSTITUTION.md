# Buyer Group Based Category Visibility Constitution
Version: 1.0.0

This document is the supreme engineering authority for the Buyer Group Based Category Visibility codebase. Where another document, implementation, or convenience conflicts with this constitution, this constitution wins unless amended through the process below.

## Mission
Build a Salesforce B2B Commerce proof of concept that dynamically exposes only the product categories mapped to the logged-in user's Buyer Group. The solution must be secure, maintainable, browser-compatible, and enforced server-side rather than relying on UI hiding.

## Core Values
1. Correctness over speed.
2. Security over convenience.
3. Simplicity over cleverness.
4. Maintainability over shortcuts.
5. Observability over assumptions.
6. Explicitness over magic.
7. Automation over manual processes.
8. Testing over trust.

POC scope permits lighter operational gates, but never permits bypassing authorization, CRUD/FLS, sharing, or server-side filtering.

## Technology Stack
### Required
| Area | Standard |
|---|---|
| Platform | Salesforce B2B Commerce |
| Server | Apex with sharing and bulk-safe service/controller patterns |
| Client | Lightning Web Components |
| Data access | SOQL, Salesforce APIs, and supported B2B Commerce data models |
| Metadata | Salesforce source-format metadata and permission sets |
| Testing | Apex unit tests and focused integration-oriented tests |
| Security | CRUD/FLS checks, sharing enforcement, least privilege, server-side authorization |
| Compatibility | All supported browsers; use platform-supported APIs and progressive enhancement where applicable |

### Forbidden
| Practice | Rule |
|---|---|
| Hardcoded identity data | Do not hardcode Buyer Group names, category names, record IDs, or user-specific mappings. |
| Client-only authorization | Do not use LWC visibility as the security boundary. |
| Unsafe Apex | No missing sharing declaration, unbounded queries, SOQL/DML in loops, or unchecked user-controlled identifiers. |
| Insecure data access | No bypass of CRUD, FLS, sharing, or least-privilege permissions. |
| Dependency risk | No unmaintained dependency or experimental library in production without explicit approval. |
| Plain JavaScript | Do not introduce plain JavaScript application conventions where typed or platform-native patterns are available. |

## Repository Structure
Use the existing repository structure. Do not create a replacement project layout. New files must be placed beside the existing Salesforce source, test, metadata, and documentation conventions. Preserve existing package configuration, deployment configuration, naming, and module boundaries.

## Language/Code Standards
| Standard | Requirement |
|---|---|
| Apex style | Use classes with clear ownership, `with sharing` by default, small methods, meaningful names, and explicit types. |
| Apex safety | Enforce CRUD/FLS before returning or mutating records; use `Security.stripInaccessible` where appropriate; use bind variables; fail closed on missing context. |
| Bulkification | Accept collections where practical, query once per operation, use maps/sets, and perform DML outside loops. |
| SOQL | Select only required fields, use selective filters, avoid dynamic SOQL unless necessary, and bind all user-derived values. |
| LWC style | Keep presentation separate from server authorization and data retrieval. Use accessible semantic markup and supported Lightning base patterns. |
| Naming | Use Salesforce API naming conventions for metadata and Apex. Use descriptive nouns and verbs; avoid one-letter variables. |
| Size | Target 300 lines per source file; mandatory refactor at 500 lines unless a documented platform constraint applies. |
| Error handling | Use typed, actionable exceptions and user-safe messages. Never use empty catches or bare `System.debug` as a substitute for handling. |

## Frontend Standards
Use Lightning Web Components with platform-supported rendering and browser APIs. The LWC may display the server-returned category set, loading state, empty state, and safe error state. It must never infer authorization from Buyer Group names or attempt to reproduce the access decision independently.

Use standard Lightning base components where they meet the need. Keep state local unless shared state is required. Render categories from server data rather than static configuration. Maintain keyboard access, semantic labels, predictable focus, and responsive behavior across all supported browsers.

## Backend/API & Validation Standards
The Apex service/controller is the authorization boundary. It must derive the logged-in user context from Salesforce runtime context, resolve the user's effective Buyer Group membership through supported relationships, resolve category mappings from Salesforce data, and return only authorized categories.

The implementation must:
- use `with sharing` unless a documented platform requirement proves otherwise;
- avoid trusting Buyer Group, category, or user identifiers supplied by the client;
- enforce object and field access before querying or returning data;
- fail closed when the user, Buyer Group membership, mapping, or required permission is unavailable;
- query in bulk-safe shapes and deduplicate categories;
- avoid exposing internal mapping details or unauthorized category metadata;
- keep mapping data configurable through Salesforce records or metadata rather than code constants.

Validate all server boundaries, including request parameters, query strings, forms, environment/configuration inputs, and webhook-like inputs where present. Prefer Salesforce-native validation and typed Apex contracts.

## Error Handling
Use these categories where applicable: `VALIDATION_ERROR`, `AUTHENTICATION_ERROR`, `AUTHORIZATION_ERROR`, `BUSINESS_ERROR`, `EXTERNAL_SERVICE_ERROR`, `INFRASTRUCTURE_ERROR`, and `UNKNOWN_ERROR`.

Errors must fail closed for authorization decisions. Return concise, user-safe messages from Apex and retain diagnostic detail only in approved structured logs. The LWC must not reveal whether a hidden category exists when the caller is unauthorized.

## Logging
Use structured logs with these fields where available:

| Field | Requirement |
|---|---|
| `event` | Stable event name describing the operation. |
| `timestamp` | Event time in a consistent format. |
| `requestId` | Correlation identifier when available. |
| `userId` | Optional Salesforce user identifier subject to data-minimization rules. |
| `metadata` | Safe diagnostic context without secrets or sensitive personal data. |

Never log passwords, tokens, secrets, or sensitive personal data. Do not log complete authorization payloads or unnecessary Buyer Group/category details.

## Security
Authentication and authorization must occur server-side. Client state, hidden markup, route parameters, and LWC properties are untrusted.

The solution must apply Salesforce sharing, CRUD/FLS, permission sets, least privilege, and secure query patterns. Permissions must grant only the object and field access required to read configured Buyer Group/category relationships and display authorized categories. Tests must cover unauthorized users, users without Buyer Group membership, unmapped Buyer Groups, inaccessible records/fields, empty results, and attempts to supply alternate identifiers.

Secrets must come from environment variables or an approved secret manager where applicable. Never commit secrets. Dependencies must pass security scanning, license review, maintenance review, and a smaller-dependency assessment.

## Accessibility
Target WCAG 2.2 AA. Use semantic markup, keyboard navigation, accessible names, visible focus, appropriate status messaging, and screen-reader support. Category lists and empty/error states must remain understandable without color alone. Validate the LWC in supported browsers and with the repository's available accessibility checks.

## Performance
Default budgets are LCP < 2.5s, CLS < 0.1, and INP < 200ms where browser performance is measurable. Keep queries selective, return only fields required by the category view, avoid duplicate requests, and use loading and empty states without layout instability. Performance work must not weaken authorization or data minimization.

## Testing
This is a POC, so coverage may be best-effort, but critical authorization and filtering logic requires meaningful automated tests.

Required coverage includes:
- Apex service behavior for valid Buyer Group mappings;
- multiple Buyer Groups and overlapping category mappings;
- no membership and no mapping cases;
- unauthorized and insufficient CRUD/FLS scenarios;
- server-side proof that unentitled categories are never returned;
- bulk inputs and duplicate mappings;
- empty, error, and loading states in the LWC;
- browser-compatible rendering and keyboard behavior where the project test tooling supports it.

Use deterministic test data factories. Do not depend on org-specific record IDs, names, or preexisting configuration. Tests must assert returned data and security outcomes, not only execution or coverage percentage.

## CI/CD
At minimum, pull requests should run linting where configured, Apex compilation/validation, Apex tests, LWC tests where present, and security checks where available. A green pipeline and human approval are required before a production deployment. POC deployments may use a narrower pipeline only when the skipped gate and residual risk are documented.

## Documentation
Document the data model assumptions, configurable Buyer Group-to-category mapping, permission sets, deployment order, setup prerequisites, supported browser expectation, server-side authorization flow, test strategy, and known POC limitations. Documentation must explain how an administrator adds or changes mappings without editing Apex or LWC source.

## Observability
Use structured JSON logs, metrics for latency/throughput/failures where the project supports them, and distributed tracing where integration boundaries require it. At minimum, make authorization failures, configuration gaps, query failures, and unexpected exceptions diagnosable without logging sensitive data.

## AI Development Rules
AI-generated code is untrusted. A human must review, test, validate, and approve it before merge. Agents may not deploy to production, rotate credentials, modify infrastructure, or approve pull requests without human approval. Humans own the final engineering verdict.

## Prompt/MCP/RAG Standards
Prompts must be version-controlled, documented, and tested. Prompt changes require review. MCP integrations must be least-privilege, auditable, and revocable. RAG sources must be trusted, versioned, and source-attributed. AI tools must not invent Salesforce object relationships, permissions, or API names without validation.

## Code Review Standards
Every pull request must answer:
- What changed?
- Why was it needed?
- What are the security, data-access, and regression risks?
- What is the rollback plan?
- What testing evidence supports the change?

Reviewers must specifically verify that category filtering is enforced by Apex, mappings are configuration-driven, no names or IDs are hardcoded, CRUD/FLS and sharing are respected, queries are bulk-safe, and unauthorized categories cannot be recovered through client manipulation.

## Git Standards
Use branches named `feature/*`, `bugfix/*`, `hotfix/*`, or `chore/*`. Use commit types `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, and `chore`. Keep commits focused and explain behavior changes clearly.

## Dependency Rules
Prefer Salesforce platform capabilities and existing repository dependencies. Every new dependency requires a maintenance, security, license, compatibility, and removal-cost assessment. Prefer building a small local solution over adding a dependency when the resulting code remains clearer and safer.

## Definition of Done
- Requirements are implemented, including configurable Buyer Group-to-category visibility.
- Server-side authorization returns only entitled categories.
- No Buyer Group names, category names, or IDs are hardcoded.
- Apex uses sharing, CRUD/FLS enforcement, secure queries, and bulkification.
- LWC renders server-authorized results and handles loading, empty, and error states.
- Permissions are least-privilege and documented.
- Apex and LWC tests cover positive, negative, security, and configuration-gap cases.
- Type and compile checks pass where configured.
- Lint and security checks pass where configured.
- Documentation is updated.
- Accessibility is validated to the POC target.
- Performance implications are reviewed.
- Code is reviewed and approved by a human.

## Non-Negotiable Rules
### NEVER
- Never rely on UI hiding as authorization.
- Never hardcode Buyer Group names, category names, or record IDs.
- Never trust client-supplied authorization context.
- Never bypass sharing, CRUD, FLS, or least privilege.
- Never query or perform DML in loops.
- Never expose unauthorized categories through errors, debug output, or alternate endpoints.
- Never commit secrets.
- Never merge unreviewed AI-generated code.

### ALWAYS
- Always enforce category visibility in Apex before data reaches the LWC.
- Always derive the logged-in user's context from Salesforce runtime context.
- Always keep mappings configurable through Salesforce data or metadata.
- Always use selective, bind-variable SOQL and bulk-safe collections.
- Always test both allowed and denied outcomes.
- Always return user-safe errors and structured diagnostic logs.
- Always preserve browser compatibility and accessibility.
- Always require human review before production deployment.

## Amendment Process
Written proposal -> architecture review -> team approval -> version increment. Amendments must identify the affected rules, reason for change, security and operational impact, migration implications, and required test/documentation updates. Until approved and versioned, this constitution remains authoritative.

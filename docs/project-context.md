# Project Context — B2B testing

## Organization

The organization operates a Salesforce B2B Commerce ecosystem, utilizing Buyer Groups to manage customer access and purchasing experiences.

## Product purpose

A Proof of Concept (POC) that dynamically restricts product category visibility to match the specific Buyer Group of the logged-in user.

## Brand personality

_None identified._

## Core users

1. B2B Buyers: View only the product categories authorized for their assigned Buyer Group..

## Domain principles

- Category visibility and filtering must be strictly enforced on the server-side.
- System architecture must adhere to Salesforce best practices, including security, sharing rules, CRUD/FLS enforcement, and bulkification.
- Data relationships between Buyer Groups and Categories must be dynamic and data-driven.

## Visual direction

_None identified._

## Working UI palette

_None identified._

## Component rules

_None identified._

## Do not

- Do not hardcode Buyer Group names, Category names, or IDs.
- Do not rely solely on client-side or UI-level hiding for category filtering.

## Unresolved questions

_None identified._

## Not carried through

- not_durable_context: “First read and follow the existing constitution.md and project-context.md files, and use the existing repository structure without creating a new structure.”
- not_durable_context: “Implement the required Salesforce configuration, Apex service/controller, LWC, permissions, test classes, and documentation”

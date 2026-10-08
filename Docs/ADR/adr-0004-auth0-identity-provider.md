---
title: "ADR-0004: Auth0 as the Identity Provider"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "security"]
supersedes: ""
superseded_by: ""
---

# ADR-0004: Auth0 as the Identity Provider

## Status

**Accepted**

## Context

FR-02 requires Apple, Google, and email sign-in, with tokens validated by the API and sign-in that keeps working after a period offline. R0 check-ins and the admin verification queue need real identities, so accounts ship in R0 even though the PRD scope table lists accounts in R1. The Implementation Plan resolves that in favor of R0.
The admin queue needs a permission model that separates admins from drivers. The developer already runs Auth0 for RVS.

## Decision

Use Auth0 as the single IdP for the MAUI app, the Blazor WASM admin app, and the API. The API validates JWT bearer tokens on every call. Authorization policies are per-permission, read from the Auth0 `permissions` claim through RBAC, never per-role. User-owned data is always filtered by the user id taken from the token.

## Consequences

### Positive

- **POS-001**: Apple, Google, and email connections are configuration, not code. Sign in with Apple is required by App Store rules when other social logins are offered.
- **POS-002**: First-party SDKs exist for ASP.NET Core, MAUI (Auth0.OidcClient), and Blazor WASM.
- **POS-003**: Reuses RVS tenant setup experience and patterns.
- **POS-004**: Per-permission policies let new roles be added in Auth0 without code changes.

### Negative

- **NEG-001**: Monthly active user pricing grows with the consumer base after R1.
- **NEG-002**: Offline drive mode must work with an expired access token. Check-ins queue in the outbox and sync after a refresh, so refresh-token handling on device must be robust.
- **NEG-003**: Vendor lock-in for user identities; migrating later means exporting users and re-linking social accounts.

## Alternatives Considered

### Microsoft Entra External ID

- **ALT-001**: **Description**: Azure-native customer identity (successor to Azure AD B2C).
- **ALT-002**: **Rejection Reason**: Less mature MAUI and social login experience, and no existing setup to reuse.

### ASP.NET Core Identity, self-hosted

- **ALT-003**: **Description**: Accounts stored in PostgreSQL with our own token issuance.
- **ALT-004**: **Rejection Reason**: Puts password storage, Apple and Google federation, and token security on a solo developer.

## Implementation Notes

- **IMP-001**: Create the Auth0 tenant with Apple and Google connections in M0. Per-environment tenant values go in GitHub environment variables, and client secrets go in Key Vault.
- **IMP-002**: Every API endpoint group calls `.RequireAuthorization()`; anonymous endpoints opt out explicitly. Integration tests assert auth on every endpoint.
- **IMP-003**: Never accept an owner id from the route or body. Use `IUserContextAccessor`, never `HttpContext`, in services.

## References

- **REF-001**: [PRD, FR-02](../ASOT/RigRoom-PRD.md#functional-requirements)
- **REF-002**: [Implementation Plan, Assumptions and defaults](../ASOT/RigRoom-Implementation-Plan.md#assumptions-and-defaults)
- **REF-003**: [ADR-0001: Native .NET MAUI mobile app](adr-0001-native-maui-mobile-app.md)

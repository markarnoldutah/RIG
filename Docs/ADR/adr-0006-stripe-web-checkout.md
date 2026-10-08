---
title: "ADR-0006: Stripe Web Checkout for Subscriptions"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "payments"]
supersedes: ""
superseded_by: ""
---

# ADR-0006: Stripe Web Checkout for Subscriptions

## Status

**Accepted**

## Context

FR-15 (R1) adds a Pro plan at about $30 a year that unlocks corridor downloads, offline drive mode, background alerts, and the web planner. At that price, a 15–30% store commission is a large share of revenue. US apps may currently link out to web checkout with no Apple commission. Apple has proposed 5–15%, and a Supreme Court ruling is expected by June 2027.
This ADR records the decision now so the R0 schema and API leave room for it. **No billing code is built in R0.**

## Decision

Sell subscriptions through Stripe web checkout, linked from the app for US users. The API owns entitlements: a Stripe webhook updates the user's entitlement, and the app reads it through the API and caches it for offline use. In-app purchase stays a buildable fallback behind the same entitlement interface. Decide in July 2027 whether IAP must ship at launch.

## Consequences

### Positive

- **POS-001**: Avoids store commission on subscriptions while link-out remains commission-free.
- **POS-002**: One entitlement source serves phone and web, so a purchase on desktop unlocks the phone.
- **POS-003**: Stripe handles tax, receipts, renewals, and dunning.

### Negative

- **NEG-001**: Legal and policy uncertainty: an Apple link-out fee or a ruling could change the economics mid-R1.
- **NEG-002**: Link-out adds purchase friction compared with native IAP sheets, which may lower conversion.
- **NEG-003**: Two purchase paths to keep buildable (Stripe and the IAP fallback), with entitlement reconciliation between them.

## Alternatives Considered

### In-app purchase only

- **ALT-001**: **Description**: StoreKit and Google Play Billing subscriptions.
- **ALT-002**: **Rejection Reason**: Store commission on every renewal, and no direct path for web planner purchases.

### Paddle or RevenueCat

- **ALT-003**: **Description**: Merchant-of-record or subscription aggregation services.
- **ALT-004**: **Rejection Reason**: Extra fees and another vendor. RevenueCat can be reconsidered if IAP ships alongside Stripe.

## Implementation Notes

- **IMP-001**: R1-c milestone: a tester buys Pro on the web, and the phone unlocks offline packs.
- **IMP-002**: Stripe calls go through a typed client with standard resilience. Automatic retries are disabled on non-idempotent calls unless they carry an idempotency key. Webhooks are verified by signature.
- **IMP-003**: Entitlements are cached on device so Pro features keep working offline between syncs.

## References

- **REF-001**: [PRD, Monetization](../ASOT/Big-Rig-Pullout-Map-PRD.md#monetization)
- **REF-002**: [Implementation Plan, R1 Beta plan](../ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#r1-beta-plan)
- **REF-003**: [ADR-0004: Auth0 as the identity provider](adr-0004-auth0-identity-provider.md)

---
title: "ADR-0001: Native .NET MAUI (XAML) for the Mobile App"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "mobile"]
supersedes: ""
superseded_by: ""
---

# ADR-0001: Native .NET MAUI (XAML) for the Mobile App

## Status

**Accepted**

## Context

The product is a map-heavy driving app for iOS and Android. Drive mode must work with no signal, show the next fitting stops from GPS within 1 second of a fix, and later (R1) fire background next-stop alerts with the screen off. That needs direct access to background location, geofencing, local notifications, and a fast offline map.
The developer's stack is .NET (ASP.NET Core, Blazor), and business logic such as the rig-fit rule and linear referencing must run identically on the phone and the server.

## Decision

Build `RigRoom.Mobile` as a native .NET MAUI app with XAML UI and MVVM (CommunityToolkit.Mvvm), targeting `net10.0-android` and `net10.0-ios` only. Use the Mapsui native MAUI control with offline tile packs. Share logic through .NET class libraries (`RigRoom.Domain`, `RigRoom.Contracts`, `RigRoom.ApiClient`) rather than shared UI.

## Consequences

### Positive

- **POS-001**: Native controls give smoother map panning, platform-standard lists and sheets, and better accessibility than a WebView UI. This matters in a moving vehicle.
- **POS-002**: Direct access to background location, geofencing, and local notifications without a JavaScript bridge. R1 background alerts depend on this.
- **POS-003**: Drive mode runs the same `RigRoom.Domain` code (NetTopologySuite, rig-fit rule) as the API, so on-device and server answers cannot drift.
- **POS-004**: One language and toolchain across mobile, web, and API, which suits a solo developer working with Claude Code.

### Negative

- **NEG-001**: Two UI stacks: XAML on mobile, Razor on web. UI code is not shared.
- **NEG-002**: Builds need the `maui` workload plus platform SDKs (Xcode on a current macOS for iOS; JDK and Android SDK for Android). CI and machines without them build `RigRoom.NoMobile.slnf`.
- **NEG-003**: Offline vector rendering in Mapsui is unproven for this use and is the top platform risk.

## Alternatives Considered

### MAUI Blazor Hybrid

- **ALT-001**: **Description**: MAUI shell hosting Razor components in a BlazorWebView, sharing UI with `RigRoom.Web`.
- **ALT-002**: **Rejection Reason**: The UI renders in a WebView, with weaker scroll and gesture feel on a map-heavy screen and a less clean path to CarPlay later.

### Progressive Web App

- **ALT-003**: **Description**: Installable web app sharing the Blazor WASM codebase.
- **ALT-004**: **Rejection Reason**: No background location, so R1 next-stop alerts (FR-08) and automatic stop detection (FR-10) are impossible.

### MapLibre Native bindings instead of Mapsui

- **ALT-005**: **Description**: Bind the native MapLibre SDKs for vector tile rendering.
- **ALT-006**: **Rejection Reason**: More binding work to own. Kept as the fallback if the Mapsui spike fails.

## Implementation Notes

- **IMP-001**: The M0 Mapsui spike must render an offline US-50 pack on a mid-range Android phone and an iPhone in airplane mode by Oct 25, 2026. If it fails, fall back to raster MBTiles packs or MapLibre Native bindings.
- **IMP-002**: Mac Catalyst and Windows targets were removed from the template; R0 ships through TestFlight and Play internal testing only.
- **IMP-003**: `ApplicationId` is a placeholder until the brand decision. Set it before the first store upload, because store IDs cannot be renamed.
- **IMP-004**: View models and outbox retry logic live in testable class libraries so xUnit covers them without a device.

## References

- **REF-001**: [PRD, Platform decisions](../ASOT/RigRoom-PRD.md#platform-decisions)
- **REF-002**: [Implementation Plan, Risks, spikes and fallbacks](../ASOT/RigRoom-Implementation-Plan.md#risks-spikes-and-fallbacks)
- **REF-003**: [ADR-0004: Auth0 as the identity provider](adr-0004-auth0-identity-provider.md)

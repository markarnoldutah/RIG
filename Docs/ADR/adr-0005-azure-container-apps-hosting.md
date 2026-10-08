---
title: "ADR-0005: Azure Container Apps for API, Valhalla, and Pipeline Jobs"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "infrastructure"]
supersedes: ""
superseded_by: ""
---

# ADR-0005: Azure Container Apps for API, Valhalla, and Pipeline Jobs

## Status

**Accepted**

## Context

Three kinds of server workload need hosting: the ASP.NET Core API, the Valhalla routing engine (a third-party image needing a mounted tile volume), and Python pipeline stages that run on a schedule (ingest, candidates, imagery, terrain, pack builds). R0 traffic is about 10 testers, and hosting must stay around $50–100 a month for dev and prod together.
Everything must be defined in Bicep and deployed by GitHub Actions, and there is one developer to operate it.

## Decision

Run all server components as containers in one Azure Container Apps environment per Azure environment. The API and Valhalla are Container Apps with min 0 replicas in R0. Pipeline stages are Container Apps Jobs on cron schedules. Images are built once in `deploy.yml`, pushed to Azure Container Registry (Basic), and promoted to prod by digest.

## Consequences

### Positive

- **POS-001**: One hosting model covers a web API, an off-the-shelf container (Valhalla) with an Azure Files mount, and scheduled jobs.
- **POS-002**: Scale to zero keeps R0 cost near the floor.
- **POS-003**: No Kubernetes cluster to patch or operate.
- **POS-004**: Promote-by-digest makes prod run exactly the image dev validated.

### Negative

- **NEG-001**: Cold starts at min 0 replicas add latency to the first request. R1 moves the API to min 1 replica.
- **NEG-002**: Valhalla may be too heavy for scale-to-zero (ADR-0003), which could force a warm replica.
- **NEG-003**: Less control over networking and sidecars than AKS, which is acceptable at this scale.

## Alternatives Considered

### Azure App Service

- **ALT-001**: **Description**: Web App for the API, as in RVS.
- **ALT-002**: **Rejection Reason**: No scheduled jobs and a poor fit for running the Valhalla image with mounted tiles.

### Azure Kubernetes Service

- **ALT-003**: **Description**: Managed Kubernetes for all workloads.
- **ALT-004**: **Rejection Reason**: Kubernetes to operate and a cost floor far above the R0 budget.

### Azure Container Instances

- **ALT-005**: **Description**: Single container groups on demand.
- **ALT-006**: **Rejection Reason**: No autoscaling, ingress, or scheduled jobs.

## Implementation Notes

- **IMP-001**: Bicep in `infra/` defines the environment, registry, Azure Files share for Valhalla tiles, and Key Vault and Application Insights wiring from M0.
- **IMP-002**: Managed identity for ACR pull, Key Vault, Blob, and PostgreSQL. GitHub Actions authenticates with OIDC federated credentials, so there are no long-lived Azure secrets.
- **IMP-003**: Success criteria: R0 hosting within $50–100 a month, and route requests under 2 s once warm.

## References

- **REF-001**: [PRD, Platform decisions](../ASOT/Big-Rig-Pullout-Map-PRD.md#platform-decisions)
- **REF-002**: [Implementation Plan, Infrastructure and CI/CD](../ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#infrastructure-and-cicd)
- **REF-003**: [ADR-0003: Self-hosted Valhalla](adr-0003-valhalla-truck-routing.md)

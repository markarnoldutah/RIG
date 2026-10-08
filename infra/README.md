# Infrastructure

Bicep modules and per-environment parameter files for every Azure resource. This folder is the source of truth for Azure configuration: nothing is created by hand in the portal, and GitHub Actions deploys it.

R0 runs two environments, `dev` and `prod`. The resource list and R1 changes are in the [Implementation Plan](../Docs/ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#infrastructure-and-cicd). The hosting choice is recorded in [ADR-0005](../Docs/ADR/adr-0005-azure-container-apps-hosting.md).

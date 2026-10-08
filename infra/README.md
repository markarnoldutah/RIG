# Infrastructure

Bicep modules and per-environment parameter files for every Azure resource. This folder is the source of truth for Azure configuration: nothing is created by hand in the portal, and GitHub Actions deploys it.

R0 runs two environments, `dev` and `prod`. The resource list and R1 changes are in the [Implementation Plan](../Docs/ASOT/RigRoom-Implementation-Plan.md#infrastructure-and-cicd). The hosting choice is recorded in [ADR-0005](../Docs/ADR/adr-0005-azure-container-apps-hosting.md).

## Layout

| Path | Contents |
| --- | --- |
| `main.bicep` | Subscription-scope entry point. Creates `rg-rigroom-{env}` and calls every module, so a fresh subscription needs nothing created first. |
| `types.bicep` | Shared parameter types. |
| `env/{env}.bicepparam` | One parameter file per environment. A new environment (staging in R1) is one new file plus an entry in `environmentName`'s allowed list. |
| `modules/identity.bicep` | User-assigned managed identities: `app` (API and jobs) and `migrator` (EF migrations, PostgreSQL Entra admin). |
| `modules/monitoring.bicep` | Log Analytics workspace and workspace-based Application Insights. |
| `modules/registry.bicep` | Container Registry, Basic, admin user off, `AcrPull` for both identities. |
| `modules/keyvault.bicep` | Key Vault with RBAC authorization, `Key Vault Secrets User` for both identities. |
| `modules/storage.bicep` | Storage account with private Blob containers `packs`, `imagery`, `photos` and the `valhalla-tiles` Azure Files share. The app identity gets `Storage Blob Data Contributor` and `Storage Blob Delegator` (to sign user delegation SAS). |
| `modules/postgres.bicep` | PostgreSQL Flexible Server, Burstable `Standard_B1ms`, `POSTGIS` allow-listed in `azure.extensions`, Entra-only auth, database `rigroom`. |
| `modules/container-apps-environment.bicep` | Container Apps environment (Consumption workload profile) logging to Log Analytics. Apps and jobs are added by later milestones. |

Globally unique names (registry, Key Vault, storage, PostgreSQL) carry a six-character suffix derived from the subscription and environment, so they are stable across redeploys.

## Decisions baked into the templates

- **No passwords or keys in parameters.** PostgreSQL has password auth disabled; workloads authenticate with their managed identity. The `migrator` identity is the Entra admin and, in its first migration, runs `CREATE EXTENSION postgis` and grants the `app` identity its database role.
- **Storage keeps shared-key access on** because Container Apps mounts Azure Files (Valhalla tiles) with the account key. Blob containers are private, and apps reach them only through user delegation SAS.
- **Dev is disposable.** `dev.bicepparam` sets a 7-day Key Vault soft-delete window and leaves purge protection off. Prod keeps the defaults (90 days, purge protection on).
- **Region** is `westus3` for dev, the closest region to the Nevada and Utah corridors with Burstable PostgreSQL and Container Apps workload profiles.
- **PostgreSQL firewall** allows Azure services (`0.0.0.0`). Add a workstation range through `postgresClientIpRanges` in the parameter file when needed.

## Validate and deploy

```bash
cd infra
bicep lint main.bicep
bicep build-params env/dev.bicepparam --stdout > /dev/null

az deployment sub what-if --location westus3 --name rigroom-dev --parameters env/dev.bicepparam
az deployment sub create  --location westus3 --name rigroom-dev --parameters env/dev.bicepparam
```

What-if reports every resource as `Create` on a fresh subscription except one `Unsupported` entry: the PostgreSQL Entra administrator. Its resource name must be the migrator's object id, which does not exist until deployment, so what-if cannot preview it. That entry is expected.

The deploying principal needs `Owner` (or `Contributor` plus `Role Based Access Control Administrator`) on the subscription, because the templates create the resource group and role assignments. In CI this is the GitHub Actions OIDC principal; its setup will live in `.github/workflows/README.md`.

ARM registers resource providers on first deployment. If a locked-down subscription blocks that, register `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.DBforPostgreSQL`, `Microsoft.KeyVault`, `Microsoft.ManagedIdentity`, `Microsoft.OperationalInsights`, `Microsoft.Insights`, and `Microsoft.Storage` once with `az provider register --namespace <name>`.

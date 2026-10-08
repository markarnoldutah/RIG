---
name: az-cost-optimize
description: Analyze the Bicep in infra/ and the deployed Azure resources for cost savings, then (after confirmation) file GitHub issues per optimization plus an epic. Use when the user asks about Azure costs, spend, right-sizing, or cost optimization.
---

# Azure Cost Optimize

Analyze RigRoom's Bicep and deployed Azure resources, recommend cost savings with evidence, and — only after the user confirms — create one GitHub issue per optimization plus one epic.

## Ground rules

- **Read-only against Azure.** Use `list`/`show`/`metrics`/`query` commands only. Never scale, stop, delete, or update a resource from this skill; fixes are delivered as Bicep changes in issues.
- **Bicep in `infra/` is the source of truth.** If no Bicep exists, stop and tell the user.
- Budget context: R0 expects about **$50–100/month** for dev + prod (Implementation Plan). Flag anything that puts that at risk.
- Tools: `az` CLI (check `az account show` first; if not logged in, ask the user to run `az login`) and `gh` CLI for issues.

## Step 1: Discover resources

```bash
az account show --query "{sub:id, name:name}" -o table
az group list --query "[?contains(name,'rigroom')].name" -o tsv
az resource list -g <rg> --query "[].{name:name,type:type,sku:sku.name,location:location}" -o table
```

Then per type found:

```bash
az containerapp list -g <rg> --query "[].{name:name,min:properties.template.scale.minReplicas,max:properties.template.scale.maxReplicas,cpu:properties.template.containers[0].resources.cpu,mem:properties.template.containers[0].resources.memory}" -o table
az containerapp job list -g <rg> -o table
az containerapp env show -n <env> -g <rg> --query "properties.workloadProfiles"
az postgres flexible-server list -g <rg> --query "[].{name:name,sku:sku.name,tier:sku.tier,storageGb:storage.storageSizeGb,ha:highAvailability.mode,backupDays:backup.backupRetentionDays}" -o table
az storage account list -g <rg> --query "[].{name:name,sku:sku.name,tier:accessTier}" -o table
az acr list -g <rg> --query "[].{name:name,sku:sku.name}" -o table
az monitor log-analytics workspace list -g <rg> --query "[].{name:name,retention:retentionInDays,cap:workspaceCapping.dailyQuotaGb}" -o table
```

## Step 2: Read the Bicep

Read every `*.bicep` and parameter file under `infra/`. For each resource record the declared SKU/tier/scale settings and compare with Step 1. Report drift (deployed ≠ Bicep) separately — drift is a bug, not a cost recommendation.

## Step 3: Collect usage evidence (last 7–30 days)

```bash
# PostgreSQL CPU and storage
az monitor metrics list --resource <pg-id> --metric cpu_percent storage_percent --interval PT1H --aggregation Average Maximum
# Container App replicas and CPU
az monitor metrics list --resource <app-id> --metric Replicas UsageNanoCores --interval PT1H --aggregation Average Maximum
# Log Analytics ingestion by table
az monitor log-analytics query -w <workspace-guid> --analytics-query "Usage | where TimeGenerated > ago(30d) | summarize GB=sum(Quantity)/1000 by DataType | order by GB desc"
# Blob capacity
az monitor metrics list --resource <storage-id>/blobServices/default --metric BlobCapacity --aggregation Average
```

Also check actual spend if the user has Cost Management access:

```bash
az costmanagement query --type ActualCost --timeframe MonthToDate --scope /subscriptions/<sub>/resourceGroups/<rg> --dataset-grouping name=ResourceType type=Dimension
```

Look up list prices with the Azure Retail Prices API (no auth), e.g.:
`https://prices.azure.com/api/retail/prices?$filter=serviceName eq 'Azure Database for PostgreSQL' and armRegionName eq '<region>'`

Document: resource → current SKU → estimated monthly cost → pricing source.

## Step 4: Recommend

Patterns that fit RigRoom's stack:

- **Container Apps**: API and Valhalla at `minReplicas: 0` in dev (R0 plan); right-size CPU/memory from metrics; Consumption profile unless a dedicated profile is justified; jobs sized to their actual peak.
- **PostgreSQL Flexible Server**: Burstable tier for dev/prod in R0; stop the dev server outside working hours (scheduled automation, declared in Bicep/workflow); no HA or geo-redundant backup in dev; backup retention at the minimum that is acceptable.
- **Blob Storage**: lifecycle rules to move imagery tiles and old packs to Cool/Cold; delete superseded pack versions after N days; LRS in dev.
- **Log Analytics / App Insights**: daily cap in dev, 30-day retention, sampling if ingestion dominates.
- **ACR**: Basic tier; retention/purge of untagged images.
- **Azure Files** (Valhalla tiles): Standard tier, sized to the tile set.
- Remove orphaned resources (unattached disks, old deployments, unused public IPs).

For each, compute savings = validated current cost − target cost, and a priority:

```
Priority = (Value × MonthlySavings) / (Risk × ImplementationDays)
High > 20 · Medium 5–20 · Low < 5
```

## Step 5: Confirm with the user

Show a summary (resources analyzed, current monthly estimate, potential savings, ranked recommendations with risk/effort) and ask whether to create issues. **Do not create issues without an explicit yes.**

## Step 6: Create issues

Ensure labels exist (`gh label create cost-optimization --color 0E8A16`, `azure` `0366D6`, `epic` `6F42C1`; ignore "already exists"). One issue per recommendation:

- Title: `[COST-OPT] <Resource type> - <brief> - $X/month`
- Body: monthly savings, risk, effort; description; the **Bicep change** (file, property, before → after) plus `az deployment group what-if` command; evidence (config, metrics, pricing source); validation checklist (apply in dev first, check performance, confirm in Cost Management); risks.

Then one epic: `[EPIC] Azure Cost Optimization - $X/month potential`, with an executive summary, a Mermaid diagram of current resources, and task-list links to each issue grouped by priority.

```bash
gh issue create --title "..." --body-file <tmpfile> --label cost-optimization --label azure
```

## Error handling

- Not logged in to Azure → ask the user to run `az login`; don't proceed on guesses.
- No usage data → give configuration-based recommendations and say so.
- `gh` fails → print the issue bodies in the conversation instead.

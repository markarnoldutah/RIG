---
name: appinsights-instrumentation
description: Add or fix Azure Application Insights telemetry (OpenTelemetry) for the BigRig API, Container Apps pipeline jobs, or the Bicep that provisions App Insights. Use when the user asks to add telemetry, tracing, logging to Azure Monitor, App Insights, or observability.
---

# App Insights Instrumentation

Instrument Big-Rig services to send traces, metrics, and logs to Azure Application Insights through the Azure Monitor OpenTelemetry distro.

## Ground rules (from CLAUDE.md)

- Telemetry registers **only** when `APPLICATIONINSIGHTS_CONNECTION_STRING` is present. Absent locally = no telemetry, no failure.
- The connection string is injected by Bicep into each container. Never commit it.
- Precise GPS traces, photos, emails, and tokens are PII — filter them before export.
- Infra changes go through Bicep in `infra/`; never create the resource by hand in the portal.

## Step 1: Identify what is being instrumented

Read the code to determine which of these applies; ask only if it is genuinely unclear.

| Component | Hosting | Approach |
| --- | --- | --- |
| `BigRig.Api` (ASP.NET Core 10) | Azure Container Apps | `Azure.Monitor.OpenTelemetry.AspNetCore` |
| Python pipeline jobs | Container Apps Jobs | `azure-monitor-opentelemetry` |
| `BigRig.Web` (Blazor WASM) | Static hosting | Usually not instrumented directly; rely on API-side telemetry. Ask before adding browser SDKs. |
| `BigRig.Mobile` (MAUI) | Device | App Insights is not a mobile crash/analytics tool. Raise this with the user rather than wiring it in. |

## Step 2: Provision App Insights in Bicep

Use a **workspace-based** component, one per environment, in the same resource group as the Container Apps environment. If a module already exists in `infra/`, extend it rather than adding a second one.

```bicep
param location string = resourceGroup().location
param environmentName string

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-bigrig-${environmentName}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: { dailyQuotaGb: 1 } // cost guard for dev
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-bigrig-${environmentName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

output appInsightsConnectionString string = appInsights.properties.ConnectionString
```

Pass the connection string into each container app / job as a secret-backed environment variable named `APPLICATIONINSIGHTS_CONNECTION_STRING` (or a Key Vault reference). Run `az deployment group what-if` before deploying.

## Step 3: Instrument the ASP.NET Core API

```bash
dotnet add src/BigRig.Api package Azure.Monitor.OpenTelemetry.AspNetCore
```

```csharp
// Program.cs — App Insights only when the connection string is injected (staging/prod).
if (!string.IsNullOrWhiteSpace(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
{
    builder.Services.AddOpenTelemetry()
        .UseAzureMonitor()
        .WithTracing(tracing => tracing.AddProcessor<PiiFilterActivityProcessor>());
}
```

- `UseAzureMonitor()` reads `APPLICATIONINSIGHTS_CONNECTION_STRING` itself and enables ASP.NET Core, HttpClient, and `ILogger` export.
- Add EF Core / Npgsql tracing (`Npgsql.OpenTelemetry` → `AddNpgsql()`) when database spans are wanted; make sure SQL parameter values are not recorded.
- Write a `PiiFilterActivityProcessor : BaseProcessor<Activity>` that strips or coarsens tags carrying coordinates, emails, or SAS URLs (query strings) in `OnEnd`. Cover it with a unit test.
- Set `service.name` per component (e.g. `bigrig-api`) via `ConfigureResource` so the Application Map is readable.
- Keep logging via `ILogger` message templates; don't add a second logging pipeline.

## Step 4: Instrument Python pipeline jobs

```bash
pip install azure-monitor-opentelemetry
```

```python
import os
from azure.monitor.opentelemetry import configure_azure_monitor

if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    configure_azure_monitor()  # reads the connection string from the environment
```

- Call it once at job start, before other imports create loggers.
- Set `OTEL_SERVICE_NAME` per job (e.g. `pipeline-ingest`) in the Bicep job definition.
- Log per-run counts (rows ingested, candidates produced, sites classified, tokens spent) as structured fields; they are what you will query later.
- Container Apps Jobs exit quickly — make sure telemetry is flushed before the process ends (the distro flushes on normal exit; avoid `os._exit`).

## Step 5: Verify

1. Run locally without the connection string: the app starts and nothing is exported.
2. Deploy to dev and query Log Analytics:
   ```kql
   AppRequests | where TimeGenerated > ago(30m) | summarize count() by AppRoleName, ResultCode
   ```
3. Confirm no PII appears: search `AppDependencies` / `AppTraces` for coordinates or `sig=` (SAS signatures).

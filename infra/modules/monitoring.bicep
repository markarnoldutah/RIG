// Log Analytics workspace and workspace-based Application Insights.
// The connection string is injected into apps as APPLICATIONINSIGHTS_CONNECTION_STRING.

param location string
param tags object
param logAnalyticsName string
param appInsightsName string
param retentionInDays int

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

output logAnalyticsName string = logAnalytics.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString

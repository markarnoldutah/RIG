// RigRoom: one Azure environment (dev, prod, later staging).
// Deployed at subscription scope so a fresh subscription needs nothing created by hand:
// the resource group is part of the template. Each environment is one .bicepparam file in env/.
targetScope = 'subscription'

import { postgresAdminType, ipRangeType } from 'types.bicep'

@description('Environment name; used in resource names and tags.')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Azure region for every resource in the environment.')
param location string

@description('Short workload name used as the resource name stem.')
@maxLength(8)
param workloadName string = 'rigroom'

@description('PostgreSQL major version.')
param postgresVersion string = '17'

@description('PostgreSQL compute SKU (Burstable tier in R0).')
param postgresSkuName string = 'Standard_B1ms'

@description('PostgreSQL storage size in GiB.')
param postgresStorageSizeGB int = 32

@description('Extra Microsoft Entra administrators for PostgreSQL (for example a developer), on top of the migrator identity.')
param postgresAdditionalAdmins postgresAdminType[] = []

@description('Client IP ranges allowed through the PostgreSQL firewall, for example a developer workstation.')
param postgresClientIpRanges ipRangeType[] = []

@description('Days a deleted Key Vault is recoverable.')
@minValue(7)
@maxValue(90)
param keyVaultSoftDeleteRetentionInDays int = 90

@description('Enable Key Vault purge protection. Cannot be turned off once enabled.')
param keyVaultEnablePurgeProtection bool = true

@description('Log Analytics retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionInDays int = 30

var tags = {
  workload: workloadName
  environment: environmentName
  managedBy: 'bicep'
}

// Globally unique names need a suffix; it is stable per subscription + environment.
var suffix = take(uniqueString(subscription().id, workloadName, environmentName), 6)

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'rg-${workloadName}-${environmentName}'
  location: location
  tags: tags
}

module identity 'modules/identity.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    appIdentityName: 'id-${workloadName}-${environmentName}-app'
    migratorIdentityName: 'id-${workloadName}-${environmentName}-migrator'
  }
}

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: 'log-${workloadName}-${environmentName}'
    appInsightsName: 'appi-${workloadName}-${environmentName}'
    retentionInDays: logRetentionInDays
  }
}

module registry 'modules/registry.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'cr${workloadName}${environmentName}${suffix}'
    pullPrincipals: [
      identity.outputs.appRef
      identity.outputs.migratorRef
    ]
  }
}

module keyVault 'modules/keyvault.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'kv-${workloadName}-${environmentName}-${suffix}'
    softDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
    enablePurgeProtection: keyVaultEnablePurgeProtection
    secretsUserPrincipals: [
      identity.outputs.appRef
      identity.outputs.migratorRef
    ]
  }
}

module storage 'modules/storage.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'st${workloadName}${environmentName}${suffix}'
    blobDataPrincipals: [
      identity.outputs.appRef
    ]
  }
}

module postgres 'modules/postgres.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'psql-${workloadName}-${environmentName}-${suffix}'
    databaseName: workloadName
    version: postgresVersion
    skuName: postgresSkuName
    storageSizeGB: postgresStorageSizeGB
    administrators: concat(
      [
        {
          objectId: identity.outputs.migratorPrincipalId
          principalName: identity.outputs.migratorName
          principalType: 'ServicePrincipal'
        }
      ],
      postgresAdditionalAdmins
    )
    clientIpRanges: postgresClientIpRanges
  }
}

module containerAppsEnvironment 'modules/container-apps-environment.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'cae-${workloadName}-${environmentName}'
    logAnalyticsName: monitoring.outputs.logAnalyticsName
  }
}

output resourceGroupName string = rg.name
output containerAppsEnvironmentId string = containerAppsEnvironment.outputs.id
output containerAppsEnvironmentDefaultDomain string = containerAppsEnvironment.outputs.defaultDomain
output acrLoginServer string = registry.outputs.loginServer
output keyVaultUri string = keyVault.outputs.uri
output storageAccountName string = storage.outputs.name
output storageBlobEndpoint string = storage.outputs.blobEndpoint
output postgresFqdn string = postgres.outputs.fqdn
output postgresDatabaseName string = postgres.outputs.databaseName
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output appIdentityId string = identity.outputs.appId
output appIdentityClientId string = identity.outputs.appClientId
output migratorIdentityId string = identity.outputs.migratorId
output migratorIdentityClientId string = identity.outputs.migratorClientId

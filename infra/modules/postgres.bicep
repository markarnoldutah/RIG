// PostgreSQL Flexible Server (Burstable) with PostGIS allow-listed. Microsoft Entra authentication only:
// no admin password exists. The extension itself is created by an EF migration (CREATE EXTENSION postgis).

import { postgresAdminType, ipRangeType } from '../types.bicep'

param location string
param tags object
param name string
param databaseName string
param version string
param skuName string
param storageSizeGB int

@description('Microsoft Entra administrators. The first entry should be the migrator identity.')
param administrators postgresAdminType[]

@description('Client IP ranges allowed through the firewall in addition to Azure services.')
param clientIpRanges ipRangeType[]

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2025-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    version: version
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: tenant().tenantId
    }
  }
}

// Server-level changes conflict when run in parallel, so configuration, admins, and firewall rules run one at a time.
resource extensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2025-08-01' = {
  parent: server
  name: 'azure.extensions'
  properties: {
    value: 'POSTGIS'
    source: 'user-override'
  }
}

@batchSize(1)
resource admins 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2025-08-01' = [
  for admin in administrators: {
    parent: server
    name: admin.objectId
    properties: {
      principalName: admin.principalName
      principalType: admin.principalType
      tenantId: tenant().tenantId
    }
    dependsOn: [
      extensions
    ]
  }
]

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: server
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
  dependsOn: [
    admins
  ]
}

// 0.0.0.0 is Azure's convention for "allow connections from Azure services" (Container Apps, Actions runners via Azure).
resource allowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-08-01' = {
  parent: server
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    database
  ]
}

@batchSize(1)
resource clientRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-08-01' = [
  for rule in clientIpRanges: {
    parent: server
    name: rule.name
    properties: {
      startIpAddress: rule.startIpAddress
      endIpAddress: rule.endIpAddress
    }
    dependsOn: [
      allowAzure
    ]
  }
]

output fqdn string = server.properties.fullyQualifiedDomainName
output databaseName string = database.name

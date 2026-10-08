// Storage account for corridor packs, imagery tiles, and check-in photos (private Blob containers,
// reached through short-lived user delegation SAS), plus the Azure Files share for Valhalla routing tiles.

import { identityRefType } from '../types.bicep'

param location string
param tags object

@minLength(3)
@maxLength(24)
param name string

@description('Identities granted Storage Blob Data Contributor and Storage Blob Delegator (to sign user delegation SAS).')
param blobDataPrincipals identityRefType[]

var blobContainers = [
  'packs'
  'imagery'
  'photos'
]

var roleIds = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  'db58b8e5-c6ad-4a2a-8342-4190687cbf4a' // Storage Blob Delegator
]

resource account 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    // Container Apps mounts Azure Files (Valhalla tiles) with the account key, so shared key stays on.
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-08-01' = {
  parent: account
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-08-01' = [
  for containerName in blobContainers: {
    parent: blobService
    name: containerName
    properties: {
      publicAccess: 'None'
    }
  }
]

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2025-08-01' = {
  parent: account
  name: 'default'
}

resource valhallaTiles 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-08-01' = {
  parent: fileService
  name: 'valhalla-tiles'
  properties: {
    shareQuota: 100
  }
}

resource blobRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for pair in flatten(map(
    blobDataPrincipals,
    principal =>
      map(roleIds, roleId => {
        principal: principal
        roleId: roleId
      })
  )): {
    name: guid(account.id, pair.principal.resourceId, pair.roleId)
    scope: account
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleId)
      principalId: pair.principal.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

output name string = account.name
output blobEndpoint string = account.properties.primaryEndpoints.blob

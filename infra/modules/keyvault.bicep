// Key Vault with Azure RBAC (no access policies). Apps read secrets with their managed identity
// and load them at startup when KeyVault:VaultUri is set.

import { identityRefType } from '../types.bicep'

param location string
param tags object

@minLength(3)
@maxLength(24)
param name string

param softDeleteRetentionInDays int
param enablePurgeProtection bool

@description('Identities granted Key Vault Secrets User.')
param secretsUserPrincipals identityRefType[]

var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // Purge protection can only be set to true; omit it to leave it off.
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: 'Enabled'
  }
}

resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principal in secretsUserPrincipals: {
    name: guid(vault.id, principal.resourceId, secretsUserRoleId)
    scope: vault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
      principalId: principal.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

output uri string = vault.properties.vaultUri

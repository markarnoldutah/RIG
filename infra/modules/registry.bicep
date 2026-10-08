// Azure Container Registry, Basic tier. Images are pulled by managed identity; the admin user stays off.

import { identityRefType } from '../types.bicep'

param location string
param tags object

@minLength(5)
@maxLength(50)
param name string

@description('Identities granted AcrPull.')
param pullPrincipals identityRefType[]

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principal in pullPrincipals: {
    name: guid(registry.id, principal.resourceId, acrPullRoleId)
    scope: registry
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: principal.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

output loginServer string = registry.properties.loginServer

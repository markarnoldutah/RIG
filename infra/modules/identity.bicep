// User-assigned managed identities. Container Apps and Jobs attach these; no workload uses keys or passwords.
// - app: the API and pipeline jobs (ACR pull, Key Vault secrets, Blob data + SAS delegation).
// - migrator: EF migrations from the deploy pipeline; it is the PostgreSQL Entra admin and grants the app its database roles.

import { identityRefType } from '../types.bicep'

param location string
param tags object
param appIdentityName string
param migratorIdentityName string

resource app 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: appIdentityName
  location: location
  tags: tags
}

resource migrator 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: migratorIdentityName
  location: location
  tags: tags
}

output appRef identityRefType = {
  resourceId: app.id
  principalId: app.properties.principalId
}
output migratorRef identityRefType = {
  resourceId: migrator.id
  principalId: migrator.properties.principalId
}
output appId string = app.id
output appClientId string = app.properties.clientId
output migratorId string = migrator.id
output migratorName string = migrator.name
output migratorClientId string = migrator.properties.clientId
output migratorPrincipalId string = migrator.properties.principalId

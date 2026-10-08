// Shared parameter types for main.bicep and its modules.

@export()
type postgresAdminType = {
  @description('Object id of the Entra principal.')
  objectId: string

  @description('Display name (user principal name for a user, app name for a service principal).')
  principalName: string

  principalType: 'User' | 'Group' | 'ServicePrincipal'
}

@export()
type ipRangeType = {
  @description('Firewall rule name.')
  name: string
  startIpAddress: string
  endIpAddress: string
}

@export()
@description('A managed identity to grant a role to. The resource id keeps role assignment names deterministic, so what-if can preview them.')
type identityRefType = {
  resourceId: string
  principalId: string
}

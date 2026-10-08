using '../main.bicep'

param environmentName = 'dev'
param location = 'westus3'

// Dev is disposable: short soft-delete window and no purge protection, so the vault name can be reused after a teardown.
param keyVaultSoftDeleteRetentionInDays = 7
param keyVaultEnablePurgeProtection = false

param postgresSkuName = 'Standard_B1ms'
param postgresStorageSizeGB = 32

// Add a developer as an extra Entra admin, or a workstation IP, here when needed. Never commit secrets.
param postgresAdditionalAdmins = []
param postgresClientIpRanges = []

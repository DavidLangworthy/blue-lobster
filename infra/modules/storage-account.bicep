@description('Name of the Storage Account')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('SKU for the storage account')
param sku string = 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
  }
}

// Create file shares for OpenClaw persistent state.
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource openclawHomeShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'openclaw-home'
  properties: {
    shareQuota: 5
    accessTier: 'TransactionOptimized'
  }
}

resource openclawWorkspaceShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'openclaw-workspace'
  properties: {
    shareQuota: 10
    accessTier: 'TransactionOptimized'
  }
}

resource openclawMediaShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'openclaw-media'
  properties: {
    shareQuota: 20
    accessTier: 'TransactionOptimized'
  }
}

// Create blob container for optional exported artifacts.
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource artifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'openclaw-artifacts'
  properties: {
    publicAccess: 'None'
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output homeShareName string = openclawHomeShare.name
output workspaceShareName string = openclawWorkspaceShare.name
output mediaShareName string = openclawMediaShare.name

@description('Azure OpenAI account name')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Azure OpenAI account SKU')
param skuName string = 'S0'

@description('Create a default model deployment in the AOAI account')
param deployModel bool = true

@description('AOAI deployment name used by the app')
param deploymentName string = 'gpt-5-2'

@description('AOAI model name for the default deployment')
param deploymentModelName string = 'gpt-4.1'

@description('AOAI model version for the default deployment')
param deploymentModelVersion string = '2025-04-14'

@description('AOAI deployment SKU name')
param deploymentSkuName string = 'Standard'

@description('AOAI deployment SKU capacity')
param deploymentSkuCapacity int = 1

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (deployModel) {
  parent: account
  name: deploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentSkuCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: deploymentModelName
      version: deploymentModelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

output name string = account.name
output endpoint string = account.properties.endpoint

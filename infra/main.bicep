targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Optional existing Azure Container Registry name to reuse (reduces baseline cost when using multiple environments)')
param existingContainerRegistryName string = ''

@description('Azure OpenAI endpoint (for example: https://my-aoai.openai.azure.com)')
param azureOpenAiEndpoint string = ''

@description('Azure OpenAI API key')
@secure()
param azureOpenAiApiKey string = ''

@description('Azure OpenAI deployment name')
param azureOpenAiDeployment string = 'gpt-5-2'

@description('Anthropic API key for optional fallback model routing')
@secure()
param anthropicApiKey string = ''

@description('Gateway token for web UI authentication')
@secure()
param openclawGatewayToken string = ''

@description('OpenClaw persona name')
param openclawPersonaName string = 'Clawd'

@description('Optional explicit primary model (provider/model). If empty, runtime defaults are used.')
param openclawModel string = ''

@description('Comma-separated fallback models (provider/model)')
param openclawModelFallbacks string = 'anthropic/claude-sonnet-4-6'

@description('Comma-separated room slugs used to scaffold persistent canvas rooms')
param openclawRooms string = 'living-room,master-bedroom'

@description('TTS provider for outbound voice replies (edge or elevenlabs)')
param openclawTtsProvider string = 'edge'

@description('Auto TTS mode (off, inbound, always)')
param openclawTtsAuto string = 'inbound'

@description('Comma-separated WhatsApp allowlist numbers in E.164 format')
param whatsappAllowFrom string = ''

@description('WhatsApp DM policy override (allowlist, pairing, disabled). Empty uses runtime default.')
param whatsappDmPolicy string = ''

@description('WhatsApp group policy override (allowlist, pairing, disabled). Empty uses runtime default.')
param whatsappGroupPolicy string = ''

@description('Outlook mailbox address used by the agent for vendor communication')
param outlookEmail string = ''

@description('Outlook app password for IMAP/SMTP auth')
@secure()
param outlookAppPassword string = ''

@description('IMAP host')
param imapHost string = 'outlook.office365.com'

@description('IMAP port')
param imapPort string = '993'

@description('SMTP host')
param smtpHost string = 'smtp.office365.com'

@description('SMTP port')
param smtpPort string = '587'

@description('Azure Speech key for voice note transcription')
@secure()
param azureSpeechKey string = ''

@description('Azure Speech region for voice note transcription')
param azureSpeechRegion string = ''

@description('Azure Speech language for voice note transcription')
param azureSpeechLanguage string = 'en-US'

@description('ElevenLabs API key for premium TTS voice replies (optional)')
@secure()
param elevenLabsApiKey string = ''

@description('Container image tag (default: latest for ACR-built image)')
param imageTag string = 'latest'

@description('Use official GHCR image (requires building from source first)')
param useOfficialImage bool = false

@description('Container CPU cores')
param containerCpu string = '1.0'

@description('Container memory in Gi')
param containerMemory string = '2.0Gi'

@description('Minimum number of replicas (set to 0 for scale-to-zero)')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 2

@description('Cron start expression for periodic wake windows')
param heartbeatCronStart string = '0 8-20 * * *'

@description('Cron end expression for periodic wake windows')
param heartbeatCronEnd string = '5 8-20 * * *'

@description('Timezone for cron wake windows')
param heartbeatCronTimezone string = 'America/Los_Angeles'

@description('IP addresses allowed to access the gateway (comma-separated CIDR blocks). Leave empty for public access.')
param allowedIpRanges string = ''

@description('Enable internal-only ingress (requires VNet-integrated environment)')
param internalOnly bool = false

@description('Enable security and availability alerts')
param enableAlerts bool = false

@description('Email address for alert notifications (leave empty to disable email alerts)')
param alertEmailAddress string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var useExistingContainerRegistry = !empty(existingContainerRegistryName)

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

module containerRegistry './modules/container-registry.bicep' = if (!useExistingContainerRegistry) {
  name: 'container-registry'
  scope: rg
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (useExistingContainerRegistry) {
  scope: rg
  name: existingContainerRegistryName
}

var containerRegistryName = useExistingContainerRegistry ? existingContainerRegistry!.name : containerRegistry!.outputs.name
var containerRegistryLoginServer = useExistingContainerRegistry ? existingContainerRegistry!.properties.loginServer : containerRegistry!.outputs.loginServer

module storageAccount './modules/storage-account.bicep' = {
  name: 'storage-account'
  scope: rg
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
  }
}

module containerAppsEnvironment './modules/container-apps-env.bicep' = {
  name: 'container-apps-env'
  scope: rg
  params: {
    name: '${abbrs.appContainerAppsEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceCustomerId: logAnalytics.outputs.customerId
    logAnalyticsWorkspaceSharedKey: logAnalytics.outputs.primarySharedKey
  }
}

module openclawApp './modules/openclaw-app.bicep' = {
  name: 'openclaw-app'
  scope: rg
  params: {
    name: 'openclaw'
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistryName
    containerRegistryLoginServer: containerRegistryLoginServer
    storageAccountName: storageAccount.outputs.name
    homeShareName: storageAccount.outputs.homeShareName
    workspaceShareName: storageAccount.outputs.workspaceShareName
    mediaShareName: storageAccount.outputs.mediaShareName
    imageTag: imageTag
    useOfficialImage: useOfficialImage
    azureOpenAiEndpoint: azureOpenAiEndpoint
    azureOpenAiApiKey: azureOpenAiApiKey
    azureOpenAiDeployment: azureOpenAiDeployment
    anthropicApiKey: anthropicApiKey
    openclawGatewayToken: openclawGatewayToken
    openclawPersonaName: openclawPersonaName
    openclawModel: openclawModel
    openclawModelFallbacks: openclawModelFallbacks
    openclawRooms: openclawRooms
    openclawTtsProvider: openclawTtsProvider
    openclawTtsAuto: openclawTtsAuto
    whatsappAllowFrom: whatsappAllowFrom
    whatsappDmPolicy: whatsappDmPolicy
    whatsappGroupPolicy: whatsappGroupPolicy
    outlookEmail: outlookEmail
    outlookAppPassword: outlookAppPassword
    imapHost: imapHost
    imapPort: imapPort
    smtpHost: smtpHost
    smtpPort: smtpPort
    azureSpeechKey: azureSpeechKey
    azureSpeechRegion: azureSpeechRegion
    azureSpeechLanguage: azureSpeechLanguage
    elevenLabsApiKey: elevenLabsApiKey
    containerCpu: containerCpu
    containerMemory: containerMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    heartbeatCronStart: heartbeatCronStart
    heartbeatCronEnd: heartbeatCronEnd
    heartbeatCronTimezone: heartbeatCronTimezone
    allowedIpRanges: allowedIpRanges
    internalOnly: internalOnly
  }
}

module alerts './modules/alerts.bicep' = if (enableAlerts) {
  name: 'alerts'
  scope: rg
  params: {
    namePrefix: 'openclaw'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    containerAppName: 'openclaw'
    enableAlerts: enableAlerts
    alertEmailAddress: alertEmailAddress
  }
  dependsOn: [
    openclawApp
  ]
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = subscription().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = rg.name

output CONTAINER_REGISTRY_NAME string = containerRegistryName
output CONTAINER_REGISTRY_LOGIN_SERVER string = containerRegistryLoginServer

output OPENCLAW_APP_NAME string = openclawApp.outputs.name
output OPENCLAW_APP_FQDN string = openclawApp.outputs.fqdn
output OPENCLAW_GATEWAY_URL string = 'https://${openclawApp.outputs.fqdn}'

// Backward-compatible output aliases used by existing scripts.
output CLAWDBOT_APP_NAME string = openclawApp.outputs.name
output CLAWDBOT_APP_FQDN string = openclawApp.outputs.fqdn
output CLAWDBOT_GATEWAY_URL string = 'https://${openclawApp.outputs.fqdn}'

output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.id
output STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name

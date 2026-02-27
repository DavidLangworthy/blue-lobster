@description('Name of the Container App')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Container Apps Environment ID')
param containerAppsEnvironmentId string

@description('Container Apps Environment name')
param containerAppsEnvironmentName string

@description('Container Registry Name')
param containerRegistryName string

@description('Container Registry Login Server')
param containerRegistryLoginServer string

@description('Storage Account Name')
param storageAccountName string

@description('Azure file share mounted at /home/node/.openclaw')
param homeShareName string

@description('Azure file share mounted at /workspace')
param workspaceShareName string

@description('Azure file share mounted at /workspace/media')
param mediaShareName string

@description('Container image tag')
param imageTag string = 'latest'

@description('Use official GHCR image instead of ACR (not recommended - build from source instead)')
param useOfficialImage bool = false

@description('Azure OpenAI endpoint')
param azureOpenAiEndpoint string = ''

@description('Azure OpenAI API key')
@secure()
param azureOpenAiApiKey string = ''

@description('Azure OpenAI deployment name')
param azureOpenAiDeployment string = 'gpt-5-2'

@description('Enable reasoning include for Azure OpenAI responses API (requires model support)')
param azureOpenAiReasoning string = 'false'

@description('Anthropic API key (optional fallback)')
@secure()
param anthropicApiKey string = ''

@description('OpenClaw gateway auth token')
@secure()
param openclawGatewayToken string = ''

@description('OpenClaw persona name')
param openclawPersonaName string = 'Clawd'

@description('Optional explicit primary model (provider/model). Empty uses runtime defaults')
param openclawModel string = ''

@description('Comma-separated fallback models (provider/model)')
param openclawModelFallbacks string = ''

@description('Comma-separated room slugs for per-room agent scaffolding')
param openclawRooms string = 'living-room,master-bedroom'

@description('TTS provider for outbound voice replies')
param openclawTtsProvider string = 'edge'

@description('Auto TTS mode (off, inbound, always)')
param openclawTtsAuto string = 'inbound'

@description('Disable Control UI device-pairing requirement to keep web dashboard websocket connected')
param openclawControlUiDisableDeviceAuth string = 'true'

@description('Comma-separated WhatsApp allowlist numbers in E.164 format')
param whatsappAllowFrom string = ''

@description('WhatsApp DM policy override (allowlist, pairing, disabled)')
param whatsappDmPolicy string = ''

@description('WhatsApp group policy override (allowlist, pairing, disabled)')
param whatsappGroupPolicy string = ''

@description('Outlook mailbox address used by the agent')
param outlookEmail string = ''

@description('Outlook app password for IMAP/SMTP')
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

@description('ElevenLabs API key for premium TTS voice replies')
@secure()
param elevenLabsApiKey string = ''

@description('Container CPU cores')
param containerCpu string = '1.0'

@description('Container memory in Gi')
param containerMemory string = '2.0Gi'

@description('Minimum number of replicas')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 2

@description('Scale polling interval in seconds')
param scalePollingIntervalSeconds int = 30

@description('Scale cooldown period in seconds before scaling to zero after idle')
param scaleCooldownSeconds int = 3600

@description('Cron start expression for periodic wake windows')
param heartbeatCronStart string = '0 8-20 * * *'

@description('Cron end expression for periodic wake windows')
param heartbeatCronEnd string = '5 8-20 * * *'

@description('Timezone for cron wake windows')
param heartbeatCronTimezone string = 'America/Los_Angeles'

@description('IP addresses allowed to access the gateway (comma-separated CIDR blocks, e.g., "1.2.3.4/32,10.0.0.0/8"). Leave empty for public access.')
param allowedIpRanges string = ''

@description('Enable internal-only ingress (requires VNet integration)')
param internalOnly bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironmentName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-identity'
  location: location
  tags: tags
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useOfficialImage) {
  name: guid(containerRegistry.id, managedIdentity.id, 'acrpull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, 'storagefile')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource openclawHomeStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'openclaw-home'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
      shareName: homeShareName
    }
  }
}

resource openclawWorkspaceStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'openclaw-workspace'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
      shareName: workspaceShareName
    }
  }
}

resource openclawMediaStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'openclaw-media'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
      shareName: mediaShareName
    }
  }
}

var ipRangesArray = !empty(allowedIpRanges) ? split(allowedIpRanges, ',') : []
var ipSecurityRestrictions = [for (ipRange, i) in ipRangesArray: {
  name: 'allow-ip-${i}'
  action: 'Allow'
  ipAddressRange: trim(ipRange)
}]

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: !internalOnly
        targetPort: 18789
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        ipSecurityRestrictions: ipSecurityRestrictions
      }
      registries: useOfficialImage ? [] : [
        {
          server: containerRegistryLoginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'azure-openai-api-key'
          value: !empty(azureOpenAiApiKey) ? azureOpenAiApiKey : 'not-set'
        }
        {
          name: 'anthropic-api-key'
          value: !empty(anthropicApiKey) ? anthropicApiKey : 'not-set'
        }
        {
          name: 'gateway-token'
          value: !empty(openclawGatewayToken) ? openclawGatewayToken : 'not-set'
        }
        {
          name: 'outlook-app-password'
          value: !empty(outlookAppPassword) ? outlookAppPassword : 'not-set'
        }
        {
          name: 'azure-speech-key'
          value: !empty(azureSpeechKey) ? azureSpeechKey : 'not-set'
        }
        {
          name: 'elevenlabs-api-key'
          value: !empty(elevenLabsApiKey) ? elevenLabsApiKey : 'not-set'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'openclaw'
          image: useOfficialImage ? 'ghcr.io/openclaw/openclaw:${imageTag}' : '${containerRegistryLoginServer}/clawdbot:${imageTag}'
          resources: {
            cpu: json(containerCpu)
            memory: containerMemory
          }
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAiEndpoint
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
              value: azureOpenAiDeployment
            }
            {
              name: 'AZURE_OPENAI_REASONING'
              value: azureOpenAiReasoning
            }
            {
              name: 'ANTHROPIC_API_KEY'
              secretRef: 'anthropic-api-key'
            }
            {
              name: 'OPENCLAW_GATEWAY_TOKEN'
              secretRef: 'gateway-token'
            }
            {
              name: 'OPENCLAW_PERSONA_NAME'
              value: openclawPersonaName
            }
            {
              name: 'OPENCLAW_MODEL'
              value: openclawModel
            }
            {
              name: 'OPENCLAW_MODEL_FALLBACKS'
              value: openclawModelFallbacks
            }
            {
              name: 'OPENCLAW_ROOMS'
              value: openclawRooms
            }
            {
              name: 'OPENCLAW_TTS_PROVIDER'
              value: openclawTtsProvider
            }
            {
              name: 'OPENCLAW_TTS_AUTO'
              value: openclawTtsAuto
            }
            {
              name: 'OPENCLAW_CONTROLUI_DISABLE_DEVICE_AUTH'
              value: openclawControlUiDisableDeviceAuth
            }
            {
              name: 'WHATSAPP_ALLOW_FROM'
              value: whatsappAllowFrom
            }
            {
              name: 'WHATSAPP_DM_POLICY'
              value: whatsappDmPolicy
            }
            {
              name: 'WHATSAPP_GROUP_POLICY'
              value: whatsappGroupPolicy
            }
            {
              name: 'OUTLOOK_EMAIL'
              value: outlookEmail
            }
            {
              name: 'OUTLOOK_APP_PASSWORD'
              secretRef: 'outlook-app-password'
            }
            {
              name: 'IMAP_HOST'
              value: imapHost
            }
            {
              name: 'IMAP_PORT'
              value: imapPort
            }
            {
              name: 'SMTP_HOST'
              value: smtpHost
            }
            {
              name: 'SMTP_PORT'
              value: smtpPort
            }
            {
              name: 'AZURE_SPEECH_KEY'
              secretRef: 'azure-speech-key'
            }
            {
              name: 'AZURE_SPEECH_REGION'
              value: azureSpeechRegion
            }
            {
              name: 'AZURE_SPEECH_LANGUAGE'
              value: azureSpeechLanguage
            }
            {
              name: 'ELEVENLABS_API_KEY'
              secretRef: 'elevenlabs-api-key'
            }
            {
              name: 'OPENCLAW_WORKSPACE'
              value: '/workspace'
            }
            {
              name: 'GATEWAY_PORT'
              value: '18789'
            }
            {
              name: 'GATEWAY_BIND'
              value: '0.0.0.0'
            }
            {
              name: 'NODE_ENV'
              value: 'production'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'openclaw-home'
              mountPath: '/home/node/.openclaw'
            }
            {
              volumeName: 'openclaw-workspace'
              mountPath: '/workspace'
            }
            {
              volumeName: 'openclaw-media'
              mountPath: '/workspace/media'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 18789
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 18789
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'openclaw-home'
          storageType: 'AzureFile'
          storageName: openclawHomeStorage.name
        }
        {
          name: 'openclaw-workspace'
          storageType: 'AzureFile'
          storageName: openclawWorkspaceStorage.name
        }
        {
          name: 'openclaw-media'
          storageType: 'AzureFile'
          storageName: openclawMediaStorage.name
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        pollingInterval: scalePollingIntervalSeconds
        cooldownPeriod: scaleCooldownSeconds
        rules: [
          {
            name: 'http-concurrency'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
          {
            name: 'heartbeat-wake'
            custom: {
              type: 'cron'
              metadata: {
                timezone: heartbeatCronTimezone
                start: heartbeatCronStart
                end: heartbeatCronEnd
                desiredReplicas: '1'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    acrPullRoleAssignment
    storageRoleAssignment
  ]
}

output id string = containerApp.id
output name string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output identityPrincipalId string = managedIdentity.properties.principalId

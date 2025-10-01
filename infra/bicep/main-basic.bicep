// --------------------------------------------------------------------------------------------------------------
// Main bicep file that deploys a basic version of the LZ with
//   Public Endpoints, includes EVERYTHING for the application,
//   with optional parameters for existing resources.
// --------------------------------------------------------------------------------------------------------------
// You can test before deploy it with this command (run these commands in the same directory as this bicep file):
//   az deployment group what-if --resource-group rg_mfg-ai-lz --template-file 'main-basic.bicep' --parameters environmentName=dev applicationName=aiapp applicationId=aiapp1 instanceNumber=002 regionCode=US
// You can deploy it with this command:
//   az deployment group create -n "manual-$(Get-Date -Format \'yyyyMMdd-HHmmss\')" --resource-group rg_mfg-ai-lz --template-file 'main-basic.bicep' --parameters environmentName=dev applicationName=aiapp applicationId=aiapp1 instanceNumber=002 regionCode=US
// Or with a parameter file:
//   az deployment group create -n "manual-$(Get-Date -Format \'yyyyMMdd-HHmmss\')" --resource-group rg_mfg-ai-lz --template-file 'main-basic.bicep' --parameters main-basic.your.bicepparam
// --------------------------------------------------------------------------------------------------------------
// 	Services Needed for Chat Agent Programs:
// 		Container Apps
//    Container Registry
// 		CosmosDB
// 		Storage Account
//    Key Vault (APIM Subscription key, certificates)
// 		Azure Foundry (includes Azure Open AI)
//    APIM (may already have existing instance)
//
//  Optional Services:
//    Azure AI Search (?)
//    Bing Grounding (?)
//    Document Intelligence (?)
//
// --------------------------------------------------------------------------------------------------------------

targetScope = 'resourceGroup'

// you can supply a full application name, or you don't it will append resource tokens to a default suffix
@description('Full Application Name (supply this or use default of prefix+token)')
param applicationName string = ''
@description('If you do not supply Application Name, this prefix will be combined with a token to create a unique applicationName')
param applicationPrefix string = ''

@description('The environment code (i.e. dev, qa, prod)')
param environmentName string = ''
// @description('Environment name used by the azd command (optional)')
// param azdEnvName string = ''

@description('Primary location for all resources')
param location string = resourceGroup().location

// --------------------------------------------------------------------------------------------------------------
// Personal info
// --------------------------------------------------------------------------------------------------------------
@description('My IP address for network access')
param myIpAddress string = ''
@description('Id of the user executing the deployment')
param principalId string = ''

// --------------------------------------------------------------------------------------------------------------
// Container App Environment
// --------------------------------------------------------------------------------------------------------------
@description('Name of the Container Apps Environment workload profile to use for the app')
param appContainerAppEnvironmentWorkloadProfileName string = containerAppEnvironmentWorkloadProfiles[0].name
@description('Workload profiles for the Container Apps environment')
param containerAppEnvironmentWorkloadProfiles array = [
  {
    name: 'app'
    workloadProfileType: 'D4'
    minimumCount: 1
    maximumCount: 10
  }
]

// --------------------------------------------------------------------------------------------------------------
// Container App Entra Parameters
// -------------------------------------------------------------------------------------------------------------`
param entraTenantId string = tenant().tenantId
param entraApiAudience string = ''
param entraScopes string = ''
@description('Entra Redirect URI for the application. Only required for custom domains. Should end with /auth/callback')
param entraRedirectUri string?
@secure()
param entraClientId string = ''
@secure()
param entraClientSecret string = ''

// --------------------------------------------------------------------------------------------------------------
// Foundry Parameters
// --------------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------------
// AI Models
// --------------------------------------------------------------------------------------------------------------
@description('The default GPT 4o model deployment name for the AI Agent')
param gpt40_DeploymentName string = 'gpt-4o'
@description('The GPT 4o model version to use')
param gpt40_ModelVersion string = '2024-11-20'
@description('The GPT 4o model deployment capacity')
param gpt40_DeploymentCapacity int = 500

@description('The default GPT 4.1 model deployment name for the AI Agent')
param gpt41_DeploymentName string = 'gpt-4.1'
@description('The GPT 4.1 model version to use')
param gpt41_ModelVersion string = '2025-04-14'
@description('The GPT 4.1 model deployment capacity')
param gpt41_DeploymentCapacity int = 500

// --------------------------------------------------------------------------------------------------------------
// APIM Parameters
// --------------------------------------------------------------------------------------------------------------
@description('Should we deploy an APIM?')
param deployAPIM bool = false
@description('Name of the APIM Subscription. Defaults to aiagent-subscription')
param apimSubscriptionName string = 'aiagent-subscription'
@description('Email of the APIM Publisher')
param apimPublisherEmail string = 'somebody@somewhere.com'
@description('Name of the APIM Publisher')
param adminPublisherName string = 'AI Agent Admin'

// --------------------------------------------------------------------------------------------------------------
// External APIM Parameters
// --------------------------------------------------------------------------------------------------------------
@description('Base URL to facade API')
param apimBaseUrl string = ''
param apimAccessUrl string = ''
@secure()
param apimAccessKey string = ''
// @description('When set to true, UPN received from the authentication will be mocked to a fixed value')
// param mockUserUpn bool = false

// --------------------------------------------------------------------------------------------------------------
// Existing images
// --------------------------------------------------------------------------------------------------------------
param apiImageName string?
param uiImageName string?

// --------------------------------------------------------------------------------------------------------------
// Other deployment switches
// --------------------------------------------------------------------------------------------------------------
@description('Should resources be created with public access?')
param publicAccessEnabled bool = true
@description('Should we make Web Apps Public?')
param makeWebAppsPublic bool = false
@description('Add Role Assignments for the user assigned identity?')
param addRoleAssignments bool = true
@description('Should we run a script to dedupe the KeyVault secrets? (this fails on private networks right now)')
param deduplicateKeyVaultSecrets bool = false
@description('Set this if you want to append all the resource names with a unique token')
param appendResourceTokens bool = false

@description('Should API container app be deployed?')
param deployAPIApp bool = false
@description('Should UI container app be deployed?')
param deployUIApp bool = false
@description('Should we deploy a Document Intelligence?')
param deployDocumentIntelligence bool = false

@description('Add scripts to put a delay before the CAP Host deploy steps')
param addCapHostDelayScripts bool = true

@description('Name of existing Cosmos account to reuse?')
param existingCosmosAccountName string = ''

@description('Global Region where the resources will be deployed, e.g. AM (America), EM (EMEA), AP (APAC), CH (China)')
param regionCode string = 'US'

@description('Instance number for the application, e.g. 001, 002, etc. This is used to differentiate multiple instances of the same application in the same environment.')
param instanceNumber string = '001' // used to differentiate multiple instances of the same application in the same environment

@description('Number of days to retain logs in Log Analytics workspace')
param logRetentionInDays int = 365

// --------------------------------------------------------------------------------------------------------------
// Additional Tags that may be included or not
// --------------------------------------------------------------------------------------------------------------
param createdByTag string = 'UNKNOWN'
// param businessOwnerTag string = 'UNKNOWN'
// param applicationOwnerTag string = 'UNKNOWN'
// param costCenterTag string = 'UNKNOWN'

// --------------------------------------------------------------------------------------------------------------
// A variable masquerading as a parameter to allow for dynamic value assignment in Bicep
// --------------------------------------------------------------------------------------------------------------
param runDateTime string = utcNow()

// --------------------------------------------------------------------------------------------------------------
// -- Variables -------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
var resourceToken = toLower(uniqueString(resourceGroup().id, location))
var resourceGroupName = resourceGroup().name

// if user supplied a full application name, use that, otherwise use default prefix and a unique token
var appName = applicationName != '' ? applicationName : '${applicationPrefix}_${resourceToken}'

var deploymentSuffix = '-${resourceToken}'

var tags = {
  'creation-date': take(runDateTime, 8)
  'created-by': createdByTag
  'application-name': applicationName
  'environment-name': environmentName
  // 'application-owner': applicationOwnerTag
  // 'business-owner': businessOwnerTag
  // 'cost-center': costCenterTag
}

// Run a script to dedupe the KeyVault secrets -- this fails on private networks right now so turn if off for them
var deduplicateKVSecrets = publicAccessEnabled ? deduplicateKeyVaultSecrets : false

// if either of these are empty or the value is set to string 'null', then we will not deploy the Entra client secrets
var deployEntraClientSecrets = !(empty(entraClientId) || empty(entraClientSecret) || toLower(entraClientId) == 'null' || toLower(entraClientSecret) == 'null')

var deployContainerRegistry = deployAPIApp || deployUIApp
var deployCAEnvironment = deployAPIApp || deployUIApp

// Should we deploy a Cosmos or reuse existing?
var deployCosmos = !empty(existingCosmosAccountName) ? false : true

// --------------------------------------------------------------------------------------------------------------
// -- Generate Resource Names -----------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module resourceNames 'resourcenames.bicep' = {
  name: 'resource-names${deploymentSuffix}'
  params: {
    applicationName: appName
    environmentName: environmentName
    resourceToken: appendResourceTokens ? resourceToken : ''
    regionCode: regionCode
    instance: instanceNumber
    numberOfProjects: 1
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Container Registry ----------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module containerRegistry './modules/app/containerregistry.bicep' = if (deployContainerRegistry) {
  name: 'containerregistry${deploymentSuffix}'
  params: {
    newRegistryName: resourceNames.outputs.ACR_Name
    location: location
    acrSku: 'Premium'
    tags: tags
    publicAccessEnabled: publicAccessEnabled
    myIpAddress: myIpAddress
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Log Analytics Workspace and App Insights ------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module logAnalytics './modules/monitor/loganalytics.bicep' = {
  name: 'law${deploymentSuffix}'
  params: {
    newLogAnalyticsName: resourceNames.outputs.logAnalyticsWorkspaceName
    newApplicationInsightsName: resourceNames.outputs.appInsightsName
    location: location
    retentionInDays: logRetentionInDays
    tags: tags
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Storage Resources ---------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module storage './modules/storage/storage-account.bicep' = {
  name: 'storage${deploymentSuffix}'
  params: {
    name: resourceNames.outputs.storageAccountName
    location: location
    tags: tags
    myIpAddress: myIpAddress
    containers: ['data', 'batch-input', 'batch-output']
    allowSharedKeyAccess: false
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Identity and Access Resources -----------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module identity './modules/iam/identity.bicep' = {
  name: 'app-identity${deploymentSuffix}'
  params: {
    identityName: resourceNames.outputs.userAssignedIdentityName
    location: location
  }
}

module appIdentityRoleAssignments './modules/iam/role-assignments.bicep' = if (addRoleAssignments) {
  name: 'identity-roles${deploymentSuffix}'
  dependsOn: [cosmos]
  params: {
    identityPrincipalId: identity.outputs.managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    registryName: deployContainerRegistry ? containerRegistry!.outputs.name : ''
    storageAccountName: storage.outputs.name
    aiSearchName: searchService.outputs.name
    aiServicesName: aiFoundry.outputs.name
    cosmosName: cosmos.outputs.name
    keyVaultName: keyVault.outputs.name
    apimName: deployAPIM ? apim!.outputs.name : ''
  }
}

module adminUserRoleAssignments './modules/iam/role-assignments.bicep' = if (addRoleAssignments && !empty(principalId)) {
  name: 'user-roles${deploymentSuffix}'
  dependsOn: [cosmos]
  params: {
    identityPrincipalId: principalId
    principalType: 'User'
    registryName: deployContainerRegistry ? containerRegistry!.outputs.name : ''
    storageAccountName: storage.outputs.name
    aiSearchName: searchService.outputs.name
    aiServicesName: aiFoundry.outputs.name
    cosmosName: cosmos.outputs.name
    keyVaultName: keyVault.outputs.name
    apimName: deployAPIM ? apim!.outputs.name : ''
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Key Vault Resources ---------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module keyVault './modules/security/keyvault.bicep' = {
  name: 'keyvault${deploymentSuffix}'
  params: {
    location: location
    commonTags: tags
    keyVaultName: resourceNames.outputs.keyVaultName
    keyVaultOwnerUserId: principalId
    adminUserObjectIds: [identity.outputs.managedIdentityPrincipalId]
    publicNetworkAccess: publicAccessEnabled ? 'Enabled' : 'Disabled'
    keyVaultOwnerIpAddress: myIpAddress
    createUserAssignedIdentity: false
  }
}
module keyVaultSecretList './modules/security/keyvault-list-secret-names.bicep' = if (deduplicateKVSecrets) {
  name: 'keyVault-Secret-List-Names${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    location: location
    userManagedIdentityId: identity.outputs.managedIdentityId
  }
}

var apiKeyValue = uniqueString(resourceGroup().id, location, 'api-key', resourceToken)
module apiKeySecret './modules/security/keyvault-secret.bicep' = {
  name: 'secret-api-key${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'api-key'
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
    secretValue: apiKeyValue
  }
}

module apimSecret './modules/security/keyvault-secret.bicep' = if (deployAPIM) {
  name: 'secret-apim${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'apimkey'
    secretValue: apimAccessKey
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
  }
  dependsOn: [apim]
}
module appiSecret './modules/security/keyvault-secret.bicep' = if (deployAPIM) {
  name: 'secret-appi${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'appInsightsConnectingString'
    secretValue: logAnalytics.outputs.appInsightsConnectionString
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
  }
}
module userIdSecret './modules/security/keyvault-secret.bicep' = if (deployAPIM) {
  name: 'secret-userId${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'managed-identity-id'
    secretValue: identity.outputs.managedIdentityId
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
  }
}

module entraClientIdSecret './modules/security/keyvault-secret.bicep' = if (deployEntraClientSecrets) {
  name: 'secret-entraClientId${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'entraclientid'
    secretValue: entraClientId
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
  }
}
module entraClientSecretSecret './modules/security/keyvault-secret.bicep' = if (deployEntraClientSecrets) {
  name: 'secret-entraClientSecret${deploymentSuffix}'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'entraclientsecret'
    secretValue: entraClientSecret
    existingSecretNames: deduplicateKVSecrets ? keyVaultSecretList!.outputs.secretNameList : ''
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Cosmos Resources ------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
var uiDatabaseName = 'ChatHistory'
var sessionsDatabaseName = 'sessions'
var uiChatContainerName = 'ChatTurn'
var uiChatContainerName2 = 'ChatHistory'
var apiSessionsContainerName = 'apisessions'
var uiSessionsContainerName = 'uisessions'
var cosmosContainerArray = [
  { name: 'AgentLog', partitionKey: '/requestId' }
  { name: 'UserDocuments', partitionKey: '/userId' }
  { name: uiChatContainerName, partitionKey: '/chatId' }
  { name: uiChatContainerName2, partitionKey: '/chatId' }
]
var sessionsContainerArray = [
  { name: apiSessionsContainerName, partitionKey: '/id' }
  { name: uiSessionsContainerName, partitionKey: '/id' }
]
module cosmos './modules/database/cosmosdb.bicep' = {
  name: 'cosmos${deploymentSuffix}'
  params: {
    accountName: deployCosmos ? resourceNames.outputs.cosmosName : ''
    existingAccountName: deployCosmos ? '' : existingCosmosAccountName
    databaseName: uiDatabaseName
    sessionsDatabaseName: sessionsDatabaseName
    sessionContainerArray: sessionsContainerArray
    containerArray: cosmosContainerArray
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.managedIdentityPrincipalId
    userPrincipalId: principalId
    publicNetworkAccess: publicAccessEnabled ? 'enabled' : 'disabled'
    myIpAddress: myIpAddress
    disableKeys: true
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Search Service Resource ------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module searchService './modules/search/search-services.bicep' = {
  name: 'search${deploymentSuffix}'
  params: {
    disableLocalAuth: true
    location: location
    name: resourceNames.outputs.searchServiceName
    publicNetworkAccess: makeWebAppsPublic ? 'enabled' : 'disabled'
    // before 08/15: publicNetworkAccess: publicAccessEnabled ? 'enabled' : 'disabled'
    myIpAddress: myIpAddress
    managedIdentityId: identity.outputs.managedIdentityId
    sku: {
      name: 'basic'
    }
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Azure OpenAI/Foundry Resources ------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module aiFoundry './modules/ai/cognitive-services.bicep' = {
  name: 'aiFoundry${deploymentSuffix}'
  params: {
    managedIdentityId: identity.outputs.managedIdentityId
    name: resourceNames.outputs.cogServiceName
    location: location
    appInsightsName: logAnalytics.outputs.applicationInsightsName
    disableLocalAuth: true
    tags: tags
    deployments: [
      {
        name: 'text-embedding'
        properties: {
          model: {
            format: 'OpenAI'
            name: 'text-embedding-ada-002'
            version: '2'
          }
        }
      }
      {
        name: 'gpt-35-turbo'
        properties: {
          model: {
            format: 'OpenAI'
            name: 'gpt-35-turbo'
            version: '0125'
          }
        }
      }
      {
        name: gpt40_DeploymentName
        properties: {
          model: {
            format: 'OpenAI'
            name: gpt40_DeploymentName
            version: gpt40_ModelVersion
          }
        }
        sku: {
          name: 'Standard'
          capacity: gpt40_DeploymentCapacity
        }
      }
      {
        name: gpt41_DeploymentName
        properties: {
          model: {
            format: 'OpenAI'
            name: gpt41_DeploymentName
            version: gpt41_ModelVersion
          }
        }
        sku: {
          name: 'GlobalStandard'
          capacity: gpt41_DeploymentCapacity
        }
      }
    ]
    publicNetworkAccess: makeWebAppsPublic ? 'enabled' : 'disabled'
    // before 08/15: publicNetworkAccess: publicAccessEnabled ? 'enabled' : 'disabled'
    myIpAddress: myIpAddress
  }
  dependsOn: [
    searchService
  ]
}

module documentIntelligence './modules/ai/document-intelligence.bicep' = if (deployDocumentIntelligence) {
  name: 'doc-intelligence${deploymentSuffix}'
  params: {
    disableLocalAuth: true
    name: resourceNames.outputs.documentIntelligenceName
    location: location // this may be different than the other resources
    tags: tags
    publicNetworkAccess: makeWebAppsPublic ? 'enabled' : 'disabled'
    // before 08/15: publicNetworkAccess: publicAccessEnabled ? 'enabled' : 'disabled'
    myIpAddress: myIpAddress
    managedIdentityId: identity.outputs.managedIdentityId
  }
  dependsOn: [
    searchService
  ]
}

// --------------------------------------------------------------------------------------------------------------
// AI Foundry Hub and Project V2
// Imported from https://github.com/adamhockemeyer/ai-agent-experience
// --------------------------------------------------------------------------------------------------------------
// AI Project
var numberOfProjects int = 1 // This is the number of AI Projects to create
// deploying AI projects in sequence
var aiDependencies = {
  aiSearch: {
    name: searchService.outputs.name
    resourceId: searchService.outputs.id
    resourceGroupName: searchService.outputs.resourceGroupName
    subscriptionId: searchService.outputs.subscriptionId
  }
  azureStorage: {
    name: storage.outputs.name
    resourceId: storage.outputs.id
    resourceGroupName: storage.outputs.resourceGroupName
    subscriptionId: storage.outputs.subscriptionId
  } 
  cosmosDB: {
    name: cosmos.outputs.name
    resourceId: cosmos.outputs.id
    resourceGroupName: cosmos.outputs.resourceGroupName
    subscriptionId: cosmos.outputs.subscriptionId
  }
}

module aiProject './modules/ai/ai-project-with-caphost.bicep' = {
  name: 'aiProject${deploymentSuffix}'
  params: {
    foundryName: aiFoundry.outputs.name
    location: location
    projectNo: 1
    createHubCapabilityHost: true   // this is required for non-vnet injected
    aiDependencies: aiDependencies
    managedIdentityId: identity.outputs.managedIdentityId
    addCapHostDelayScripts: addCapHostDelayScripts
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- APIM ------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module apim './modules/api-management/apim.bicep' = if (deployAPIM) {
  name: 'apim${deploymentSuffix}'
  params: {
    location: location
    name: resourceNames.outputs.apimName
    commonTags: tags
    publisherEmail: apimPublisherEmail
    publisherName: adminPublisherName
    appInsightsName: logAnalytics.outputs.applicationInsightsName
    subscriptionName: apimSubscriptionName
  }
}

module apimConfiguration './modules/api-management/apim-oai-config.bicep' = if (deployAPIM) {
  name: 'apimConfig${deploymentSuffix}'
  params: {
    apimName: apim!.outputs.name
    apimLoggerName: apim!.outputs.loggerName
    cognitiveServicesName: aiFoundry.outputs.name
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Container App Environment ---------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module managedEnvironment './modules/app/managedEnvironment.bicep' = if (deployCAEnvironment) {
  name: 'caenv${deploymentSuffix}'
  params: {
    newEnvironmentName: resourceNames.outputs.caManagedEnvName
    location: location
    logAnalyticsWorkspaceName: logAnalytics.outputs.logAnalyticsWorkspaceName
    logAnalyticsRgName: resourceGroupName
    appInsightsName: logAnalytics.outputs.applicationInsightsName
    tags: tags
    publicAccessEnabled: makeWebAppsPublic // before 08/15: publicAccessEnabled
    containerAppEnvironmentWorkloadProfiles: containerAppEnvironmentWorkloadProfiles
  }
}

var containerAppSettings = [
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: logAnalytics.outputs.appInsightsConnectionString }

  { name: 'AppSettings__AppAgentEndpoint', value: aiProject.outputs.aiConnectionUrl }
  { name: 'AppSettings__AppAgentId', value: 'TBD' }

  { name: 'AZURE_CLIENT_ID', value: identity.outputs.managedIdentityClientId }
  { name: 'AZURE_SDK_TRACING_IMPLEMENTATION', value: 'opentelemetry' }
  { name: 'AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED', value: 'true' }

  { name: 'SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS', value: 'true' }
  { name: 'SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS_SENSITIVE', value: 'true' }
]
// { name: 'API_KEY', secretRef: 'apikey' }
var apiUrlSettings = deployAPIApp ? [ 
  {
    name: 'API_URL'
    value: deployCAEnvironment
      ? 'https://${resourceNames.outputs.containerAppAPIName}.${managedEnvironment!.outputs.defaultDomain}/agent'
      : ''
  }
] : []

var cosmosSettings = [
  { name: 'COSMOS_DB_ENDPOINT', value: cosmos.outputs.endpoint }
  { name: 'COSMOS_DB_API_SESSIONS_DATABASE_NAME', value: sessionsDatabaseName }
  { name: 'COSMOS_DB_API_SESSIONS_CONTAINER_NAME', value: sessionsContainerArray[0].name }
  ]
var apimSettings = deployAPIM ? [
  { name: 'APIM_BASE_URL', value: apimBaseUrl }
  { name: 'APIM_ACCESS_URL', value: apimAccessUrl }
  { name: 'APIM_KEY', secretRef: 'apimkey' }
  { name: 'API_MANAGEMENT_NAME', value: apim!.outputs.name }
  { name: 'API_MANAGEMENT_ID', value: apim!.outputs.id }
  { name: 'API_MANAGEMENT_ENDPOINT', value: apim!.outputs.gatewayUrl }
  ] : []
var entraSecuritySettings = deployEntraClientSecrets
  ? [
  { name: 'ENTRA_TENANT_ID', value: entraTenantId }
  { name: 'ENTRA_API_AUDIENCE', value: entraApiAudience }
  { name: 'ENTRA_SCOPES', value: entraScopes }
  { name: 'ENTRA_REDIRECT_URI', value: entraRedirectUri ?? 'https://${resourceNames.outputs.containerAppUIName}.${managedEnvironment!.outputs.defaultDomain}/auth/callback' }
  { name: 'ENTRA_CLIENT_ID', secretRef: 'entraclientid' }
  { name: 'ENTRA_CLIENT_SECRET', secretRef: 'entraclientsecret' }
  ] : []
var baseSecretSet = { }  // { apikey: apiKeySecret.outputs.secretUri }
var apimSecretSet = empty(apimAccessKey)
  ? {}
  : {
  apimkey: apimSecret!.outputs.secretUri
}
var entraSecretSet = deployEntraClientSecrets
  ? {
  entraclientid: entraClientIdSecret!.outputs.secretUri
  entraclientsecret: entraClientSecretSecret!.outputs.secretUri
    }
  : {}

var apiTargetPort = 8000
module containerAppAPI './modules/app/containerappstub.bicep' = if (deployAPIApp) {
  name: 'ca-api-stub${deploymentSuffix}'
  params: {
    appName: resourceNames.outputs.containerAppAPIName
    managedEnvironmentName: managedEnvironment!.outputs.name
    managedEnvironmentRg: managedEnvironment!.outputs.resourceGroupName
    workloadProfileName: appContainerAppEnvironmentWorkloadProfileName
    registryName: resourceNames.outputs.ACR_Name
    targetPort: apiTargetPort
    userAssignedIdentityName: identity.outputs.managedIdentityName
    location: location
    imageName: apiImageName

    tags: union(tags, { 'azd-service-name': 'api' })
    secrets: union(baseSecretSet, apimSecretSet, entraSecretSet) 
    env: union(containerAppSettings, apiUrlSettings, cosmosSettings, apimSettings, entraSecuritySettings)
  }
  dependsOn: deployAPIM ? [containerRegistry, apim] : [containerRegistry]
}

var UITargetPort = 8001
module containerAppUI './modules/app/containerappstub.bicep' = if (deployUIApp) {
  name: 'ca-UI-stub${deploymentSuffix}'
  params: {
    appName: resourceNames.outputs.containerAppUIName
    managedEnvironmentName: managedEnvironment!.outputs.name
    managedEnvironmentRg: managedEnvironment!.outputs.resourceGroupName
    workloadProfileName: appContainerAppEnvironmentWorkloadProfileName
    registryName: resourceNames.outputs.ACR_Name
    targetPort: UITargetPort
    userAssignedIdentityName: identity.outputs.managedIdentityName
    location: location
    imageName: uiImageName
    tags: union(tags, { 'azd-service-name': 'UI' })
    secrets: union(baseSecretSet, apimSecretSet, entraSecretSet)
    env: union(containerAppSettings, apiUrlSettings, apimSettings, entraSecuritySettings)
  }
  dependsOn: deployAPIM ? [containerRegistry, apim] : [containerRegistry]
}

// --------------------------------------------------------------------------------------------------------------
// -- Outputs ---------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
output SUBSCRIPTION_ID string = subscription().subscriptionId
output ACR_NAME string = deployContainerRegistry ? containerRegistry!.outputs.name : ''
output ACR_URL string = deployContainerRegistry ? containerRegistry!.outputs.loginServer : ''
output AI_ENDPOINT string = aiFoundry.outputs.endpoint
output AI_FOUNDRY_PROJECT_ID string = aiProject.outputs.projectId
output AI_FOUNDRY_PROJECT_NAME string = aiProject.outputs.projectName
output AI_PROJECT_NAME string = resourceNames.outputs.aiHubProjectName
output AI_SEARCH_ENDPOINT string = searchService.outputs.endpoint
output API_CONTAINER_APP_FQDN string = deployAPIApp ? containerAppAPI!.outputs.fqdn : ''
output API_CONTAINER_APP_NAME string = deployAPIApp ? containerAppAPI!.outputs.name : ''
output UI_CONTAINER_APP_FQDN string = deployUIApp ? containerAppUI!.outputs.fqdn : ''
output UI_CONTAINER_APP_NAME string = deployUIApp ? containerAppUI!.outputs.name : ''
output API_KEY string = apiKeyValue
output API_MANAGEMENT_ID string = deployAPIM ? apim!.outputs.id : ''
output API_MANAGEMENT_NAME string = deployAPIM ? apim!.outputs.name : ''
output AZURE_CONTAINER_ENVIRONMENT_NAME string = deployCAEnvironment ? managedEnvironment!.outputs.name : ''
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = deployContainerRegistry ? containerRegistry!.outputs.loginServer : ''
output AZURE_CONTAINER_REGISTRY_NAME string = deployContainerRegistry ? containerRegistry!.outputs.name : ''
output AZURE_RESOURCE_GROUP string = resourceGroupName
output COSMOS_CONTAINER_NAME string = uiChatContainerName
output COSMOS_DATABASE_NAME string = cosmos.outputs.databaseName
output COSMOS_ENDPOINT string = cosmos.outputs.endpoint
output DOCUMENT_INTELLIGENCE_ENDPOINT string = deployDocumentIntelligence ? documentIntelligence!.outputs.endpoint : ''
output MANAGED_ENVIRONMENT_ID string = deployCAEnvironment ? managedEnvironment!.outputs.id : ''
output MANAGED_ENVIRONMENT_NAME string = deployCAEnvironment ? managedEnvironment!.outputs.name : ''
output RESOURCE_TOKEN string = resourceToken
output STORAGE_ACCOUNT_BATCH_IN_CONTAINER string = storage.outputs.containerNames[1].name
output STORAGE_ACCOUNT_BATCH_OUT_CONTAINER string = storage.outputs.containerNames[2].name
output STORAGE_ACCOUNT_CONTAINER string = storage.outputs.containerNames[0].name
output STORAGE_ACCOUNT_NAME string = storage.outputs.name

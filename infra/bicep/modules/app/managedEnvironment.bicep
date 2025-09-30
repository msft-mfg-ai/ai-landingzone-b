param newEnvironmentName string = ''
param existingEnvironmentName string = ''
// param existingEnvironmentResourceGroup string = ''
param location string = resourceGroup().location
param tags object = {}

// Reference Resource params
param logAnalyticsWorkspaceName string
param logAnalyticsRgName string
param appInsightsName string = ''
param appSubnetId string = ''
param publicAccessEnabled bool = true
param containerAppEnvironmentWorkloadProfiles array
param privateEndpointSubnetId string = ''
param privateEndpointName string = ''

// --------------------------------------------------------------------------------------------------------------
var useExistingEnvironment = !empty(existingEnvironmentName)
var cleanAppEnvName = replace(newEnvironmentName, '_', '-')
var resourceGroupName = resourceGroup().name

// --------------------------------------------------------------------------------------------------------------
// Reference Resource
resource logAnalyticsResource 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsRgName)
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

//var logAnalyticsKey = logAnalyticsResource.listKeys().primarySharedKey
var logAnalyticsCustomerId = logAnalyticsResource.properties.customerId
var appInsightsConnectionString = appInsights.properties.ConnectionString


// App Environment
resource existingAppEnvironmentResource 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = if (useExistingEnvironment) {
  name: existingEnvironmentName
  scope: resourceGroup(resourceGroupName)
}

// this key is internal to this file only, so security risk in  exposing it
#disable-next-line secure-secrets-in-params // Secret is not passed in or out of this module
resource newAppEnvironmentResource 'Microsoft.App/managedEnvironments@2025-02-02-preview' = if (!useExistingEnvironment) {
  name: cleanAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        #disable-next-line secure-secrets-in-params // Secret is not passed in or out of this module
        sharedKey: logAnalyticsResource.listKeys().primarySharedKey
        //sharedKey: logAnalyticsKey
      }
    }
    openTelemetryConfiguration: {
      tracesConfiguration: {
        includeDapr: false
        destinations: [
          'appInsights'
        ]
      }
      logsConfiguration: {
        destinations: [
          'appInsights'
        ]
      }
    }
    appInsightsConfiguration: {
      connectionString: appInsightsConnectionString
    }
    vnetConfiguration: !empty(appSubnetId) ? {
      infrastructureSubnetId: appSubnetId
      internal: !publicAccessEnabled
    } : {}
    workloadProfiles: containerAppEnvironmentWorkloadProfiles
  }
}

// --------------------------------------------------------------------------------------------------------------
// Private Endpoints
module privateEndpoint '../networking/private-endpoint.bicep' = if (!useExistingEnvironment && !empty(privateEndpointSubnetId) && !empty(privateEndpointName)) {
  name: '${cleanAppEnvName}-private-endpoint'
  params: {
    tags: tags
    location: location
    privateEndpointName: privateEndpointName
    groupIds: ['managedEnvironments']
    targetResourceId: newAppEnvironmentResource.id
    subnetId: privateEndpointSubnetId
  }
}

output id string = useExistingEnvironment ? existingAppEnvironmentResource.id : newAppEnvironmentResource.id
output name string = useExistingEnvironment ? existingAppEnvironmentResource.name : newAppEnvironmentResource.name
output resourceGroupName string = resourceGroupName
output defaultDomain string = useExistingEnvironment ? existingAppEnvironmentResource!.properties.defaultDomain : newAppEnvironmentResource!.properties.defaultDomain
output staticIp string = useExistingEnvironment ? existingAppEnvironmentResource!.properties.staticIp : newAppEnvironmentResource!.properties.staticIp
output privateEndpointName string = privateEndpointName

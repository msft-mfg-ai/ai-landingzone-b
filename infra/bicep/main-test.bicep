// --------------------------------------------------------------------------------------------------------------
// Main test bicep file that deploys a loganalytics account and nothing else
// --------------------------------------------------------------------------------------------------------------

targetScope = 'resourceGroup'

@description('Full Application Name (supply this or use default of prefix+token)')
param applicationName string = ''
@description('If you do not supply Application Name, this prefix will be combined with a token to create a unique applicationName')
param applicationPrefix string = ''
@description('The environment code (i.e. dev, qa, prod)')
param environmentName string = ''
@description('Primary location for all resources')
param location string = resourceGroup().location

// --------------------------------------------------------------------------------------------------------------
// Additional Tags that may be included or not
// --------------------------------------------------------------------------------------------------------------
param businessOwnerTag string = 'UNKNOWN'
param applicationOwnerTag string = 'UNKNOWN'
param createdByTag string = 'UNKNOWN'
param costCenterTag string = 'UNKNOWN'

// --------------------------------------------------------------------------------------------------------------
// A variable masquerading as a parameter to allow for dynamic value assignment in Bicep
// --------------------------------------------------------------------------------------------------------------
param runDateTime string = utcNow()

// --------------------------------------------------------------------------------------------------------------
// -- Variables -------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
var resourceToken = toLower(uniqueString(resourceGroup().id, location))

// if user supplied a full application name, use that, otherwise use default prefix and a unique token
var appName = applicationName != '' ? applicationName : '${applicationPrefix}_${resourceToken}'

var deploymentSuffix = '-${resourceToken}'

var tags = {
  'creation-date': take(runDateTime, 8)
  'created-by': createdByTag
  'application-name': applicationName
  'environment-name': environmentName
  'application-owner': applicationOwnerTag
  'business-owner': businessOwnerTag
  'cost-center': costCenterTag
}

// --------------------------------------------------------------------------------------------------------------
// -- Generate Resource Names -----------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module resourceNames 'resourcenames.bicep' = {
  name: 'resource-names${deploymentSuffix}'
  params: {
    applicationName: appName
    environmentName: environmentName
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
    tags: tags
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Outputs ---------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
output SUBSCRIPTION_ID string = subscription().subscriptionId
output LOGANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.logAnalyticsWorkspaceId

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Bicep file that builds all the resource names used by other Bicep templates
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
@description('Application name unique to this application, typically 5-8 characters.')
param applicationName string = ''

@description('Root Application Name that this is based on')
param rootApplication string = ''

@description('Environment name for the application, e.g. azd, dev, demo, qa, stg, ct, prod. This is used to differentiate resources in different environments.')
param environmentName string = 'dev'

@description('Global Region where the resources will be deployed, e.g. AM (America), EM (EMEA), AP (APAC), CH (China)')
//@allowed(['AM', 'EM', 'AP', 'CH', 'US'])
param regionCode string = 'US'

@description('Instance number for the application, e.g. 001, 002, etc. This is used to differentiate multiple instances of the same application in the same environment.')
@maxLength(3)
@minLength(3)
param instance string = '000'

@description('Optional resource token to ensure uniqueness - leave blank if desired')
param resourceToken string = ''

@description('Number of projects to create, used for AI Hub projects')
@minValue(1)
param numberOfProjects int = projectNumber+1

@description('Project number to use for AI Hub project names, must be less than or equal to numberOfProjects')
@minValue(1)
param projectNumber int=1

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Scrub inputs and create repeatable variables
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
var sanitizedEnvironment = toLower(environmentName)
var sanitizedAppNameWithDashes = replace(replace(toLower(applicationName), ' ', ''), '_', '')
var sanitizedAppName = replace(replace(replace(toLower(applicationName), ' ', ''), '-', ''), '_', '')
var sanitizedRootApplication = replace(replace(replace(toLower(rootApplication), ' ', ''), '-', ''), '_', '')

var resourceTokenWithDash = resourceToken == '' ? '' : '-${resourceToken}'
var resourceTokenWithoutDash = resourceToken == '' ? '' : '${resourceToken}'

var dashInstance = instance == '' ? '' : toLower('-${instance}')
var dashProject = instance == '' ? '' : toLower('-${projectNumber}')
var partialInstance = substring(instance, 2, 1) // get last digit of a three digit code
var partialRegion = substring(regionCode, 0, 1) // get first digit of a two digit code

// pull resource abbreviations from a common JSON file
var resourceAbbreviations = loadJsonContent('./data/abbreviation.json')

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
output webSiteName string                  = toLower('${resourceAbbreviations.webSitesAppService}-${sanitizedAppNameWithDashes}-${sanitizedEnvironment}${resourceTokenWithDash}')
output webSiteAppServicePlanName string    = toLower('${resourceAbbreviations.webServerFarms}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output appInsightsName string              = toLower('${resourceAbbreviations.insightsComponents}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output logAnalyticsWorkspaceName string    = toLower('${resourceAbbreviations.operationalInsightsWorkspaces}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

output cosmosName string                   = toLower('${resourceAbbreviations.documentDBDatabaseAccounts}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

output apimName string                     = toLower('${resourceAbbreviations.apiManagementService}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

output searchServiceName string            = toLower('${resourceAbbreviations.searchSearchServices}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output cogServiceName string               = toLower('${resourceAbbreviations.cognitiveServicesFoundry}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output documentIntelligenceName string     = toLower('${resourceAbbreviations.documentIntelligence}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output rootCogServiceName string           = toLower('${resourceAbbreviations.cognitiveServicesFoundry}-${sanitizedRootApplication}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

output aiHubName string                    = toLower('${resourceAbbreviations.cognitiveServicesAIHub}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
// AI Hub Project name must be alpha numeric characters or '-', length must be <= 32
func getProjectName(no int) string => take(toLower('${resourceAbbreviations.cognitiveServicesFoundryProject}-${sanitizedAppName}-${no}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}'), 32)
var aiProjectNames = [for i in range(1, numberOfProjects + 1): getProjectName(i)]

output aiHubProjectNames array             = aiProjectNames
output aiHubProjectName string             = getProjectName(projectNumber) // Use the first project name as the AI Hub Project name
output aiHubFoundryProjectName string      = take(toLower('${resourceAbbreviations.cognitiveServicesFoundryProject}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}'), 32)

output caManagedEnvName string             = toLower('${resourceAbbreviations.appManagedEnvironments}-${sanitizedAppName}-${sanitizedEnvironment}${resourceToken}${dashInstance}')
// CA name must be lower case alpha or '-', must start and end with alpha, cannot have '--', length must be <= 32
output containerAppAPIName string          = take(toLower('${resourceAbbreviations.appContainerApps}-api-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}'), 32)
output containerAppUIName string           = take(toLower('${resourceAbbreviations.appContainerApps}-ui-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}'), 32)
output containerAppBatchName string        = take(toLower('${resourceAbbreviations.appContainerApps}-bat-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}'), 32)

output caManagedIdentityName string        = toLower('${resourceAbbreviations.managedIdentityUserAssignedIdentities}-${sanitizedAppName}-${resourceAbbreviations.appManagedEnvironments}-${sanitizedEnvironment}${dashInstance}')
output kvManagedIdentityName string        = toLower('${resourceAbbreviations.managedIdentityUserAssignedIdentities}-${sanitizedAppName}-${resourceAbbreviations.keyVaultVaults}-${sanitizedEnvironment}${dashInstance}')
output userAssignedIdentityName string     = toLower('${resourceAbbreviations.managedIdentityUserAssignedIdentities}-${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
output rootUserAssignedIdentityName string = toLower('${resourceAbbreviations.managedIdentityUserAssignedIdentities}-${sanitizedRootApplication}-${sanitizedEnvironment}${dashInstance}')

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Container Registry, Key Vaults and Storage Account names are only alpha numeric characters limited length
output ACR_Name string                     = take('${resourceAbbreviations.containerRegistryRegistries}${sanitizedAppName}${sanitizedEnvironment}${resourceTokenWithoutDash}${instance}', 50)
output keyVaultName string                 = take('${resourceAbbreviations.keyVaultVaults}${sanitizedAppName}${sanitizedEnvironment}${resourceTokenWithoutDash}${instance}', 24)
output storageAccountName string           = take('${resourceAbbreviations.storageStorageAccounts}${sanitizedAppName}${sanitizedEnvironment}${resourceTokenWithoutDash}${instance}', 24)

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Network resource names
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
output vnet_Name string                    = toLower('${resourceAbbreviations.networkVirtualNetworks}-${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
output root_vnet_Name string               = toLower('${resourceAbbreviations.networkVirtualNetworks}-${sanitizedRootApplication}-${sanitizedEnvironment}${dashInstance}')
output vnetNsgName string                  = toLower('${resourceAbbreviations.networkNetworkSecurityGroups}-${sanitizedAppName}-${sanitizedEnvironment}-001')
                               
output subnet object = {
  appGwName:                                 toLower('snet-app-gateway')
  appSeName:                                 toLower('snet-app-services')
  peName:                                    toLower('snet-private-endpoint')
  agentName:                                 toLower('snet-agent')
  bastionName:                               'AzureBastionSubnet' // Must be exactly this name for Azure Bastion
  jumpboxName:                               toLower('snet-jumpbox')  
  trainingName:                              toLower('snet-training')
  scoringName:                               toLower('snet-scoring')
}

output vm object = {
  name:                                      toLower('${resourceAbbreviations.computeVirtualMachines}oaz${sanitizedAppName}${sanitizedEnvironment}${instance}')
  name_15:                                   take(toLower('${resourceAbbreviations.computeVirtualMachines}oaz${sanitizedAppName}${sanitizedEnvironment}${partialRegion}${partialInstance}'),15)
  nic_name:                                  toLower('${resourceAbbreviations.networkNetworkInterfaces}${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
  pip_name:                                  toLower('${resourceAbbreviations.networkPublicIPAddresses}${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
  os_disk_name:                              toLower('${resourceAbbreviations.computeDisks}-${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
  nsg_name:                                  toLower('${resourceAbbreviations.networkNetworkSecurityGroups}-${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
}

output bastion object = {
  host_name:                                 toLower('${resourceAbbreviations.networkBastionHosts}${sanitizedAppName}-${sanitizedEnvironment}${dashInstance}')
  pip_name:                                  toLower('${resourceAbbreviations.networkPublicIPAddresses}${sanitizedAppName}-${resourceAbbreviations.bastionPip}-${sanitizedEnvironment}${dashInstance}')
}
output project_vm object = {
  vm_name:                                   toLower('${resourceAbbreviations.computeVirtualMachines}oaz${sanitizedAppName}${sanitizedEnvironment}${projectNumber}')
  vm_name_15:                                take(toLower('${resourceAbbreviations.computeVirtualMachines}oaz${sanitizedAppName}${sanitizedEnvironment}${projectNumber}'),15)
  vm_nic_name:                               toLower('${resourceAbbreviations.networkNetworkInterfaces}${sanitizedAppName}-${sanitizedEnvironment}${dashProject}')
  vm_pip_name:                               toLower('${resourceAbbreviations.networkPublicIPAddresses}${sanitizedAppName}-${sanitizedEnvironment}${dashProject}')
  vm_os_disk_name:                           toLower('${resourceAbbreviations.computeDisks}-${sanitizedAppName}-${sanitizedEnvironment}${dashProject}')
  vm_nsg_name:                               toLower('${resourceAbbreviations.networkNetworkSecurityGroups}-${sanitizedAppName}-${sanitizedEnvironment}${dashProject}')
  bastion_host_name:                         toLower('${resourceAbbreviations.networkBastionHosts}${sanitizedAppName}-${sanitizedEnvironment}${dashProject}')
  bastion_pip_name:                          toLower('${resourceAbbreviations.networkPublicIPAddresses}${sanitizedAppName}-${resourceAbbreviations.bastionPip}-${sanitizedEnvironment}${dashProject}')
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Private Endpoint Names (sequential) -- created for the customer need
output pe object = {
  storageAccountBlobName:                    toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-001')
  storageAccountTableName:                   toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-002')
  storageAccountQueueName:                   toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-003')
  cosmosDbName:                              toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-004')
  keyVaultName:                              toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-005')
  acrName:                                   toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-006')
  searchServiceName:                         toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-007')
  openAIName:                                toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-008')
  containerAppsName:                         toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-009')
  documentIntelligenceName:                  toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-010')
  openAIServiceConnection:                   toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-011')
  aIHubName:                                 toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-012')
  appInsightsName:                           toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-013')
  monitorName:                               toLower('pep-${sanitizedAppName}-${sanitizedEnvironment}-014')
}

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// Application Gateway resource names
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
output appGatewayName string               = toLower('${resourceAbbreviations.networkApplicationGateways}${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output appGatewayWafPolicyName string      = toLower('${resourceAbbreviations.networkFirewallPoliciesWebApplication}-${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output appGatewayPublicIpName string       = toLower('${resourceAbbreviations.networkPublicIPAddresses}${sanitizedAppName}-agw-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

// Monitoring and Alerting resource names
output actionGroupName string              = toLower('${resourceAbbreviations.insightsActionGroups}${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')
output smartDetectorAlertRuleName string   = toLower('${resourceAbbreviations.insightsSmartDetectorAlertRules}${sanitizedAppName}-${sanitizedEnvironment}${resourceTokenWithDash}${dashInstance}')

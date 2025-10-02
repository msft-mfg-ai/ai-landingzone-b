
import * as types from '../types/types.bicep'

param aiDependencies types.aiDependenciesType
param location string
param foundryName string
param createHubCapabilityHost bool = false
param managedIdentityId string = ''
param addCapHostDelayScripts bool = true

@description('The number of the AI project to create')
@minValue(1)
param projectNo int

resource foundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: foundryName
}

module aiProject './ai-project.bicep' = {
  name: 'ai-project-${projectNo}'
  params: {
    foundryName: foundryName
    createHubCapabilityHost: createHubCapabilityHost
    location: location
    projectName: 'ai-project-${projectNo}'
    projectDescription: 'AI Project ${projectNo}'
    displayName: 'AI Project ${projectNo}'
    managedIdentityId: null // Use System Assigned Identity

    aiSearchName: aiDependencies.aiSearch.name
    aiSearchServiceResourceGroupName: aiDependencies.aiSearch.resourceGroupName
    aiSearchServiceSubscriptionId: aiDependencies.aiSearch.subscriptionId

    azureStorageName: aiDependencies.azureStorage.name
    azureStorageResourceGroupName: aiDependencies.azureStorage.resourceGroupName
    azureStorageSubscriptionId: aiDependencies.azureStorage.subscriptionId

    cosmosDBName: aiDependencies.cosmosDB.name
    cosmosDBResourceGroupName: aiDependencies.cosmosDB.resourceGroupName
    cosmosDBSubscriptionId: aiDependencies.cosmosDB.subscriptionId
  }
}

// NOTE: using a wait script to ensure the project is fully deployed before proceeding with role assignments and connections
// // this br/public:deployment-scripts/wait module has been deprecated...
// module waitForProjectScript 'br/public:deployment-scripts/wait:1.1.1' = {
//   name: 'waitForProjectScript-${projectNo}'
//   dependsOn: [aiProject]
//   params: {
//     waitSeconds: 90
//     location: resourceGroup().location
//   }
// }
// fails because it's trying to use key based access to the storage account
module waitForProjectScript 'waitDeploymentScript.bicep' = {
  name: 'waitForProjectScript-${projectNo}'
  dependsOn: [aiProject]
  params: {
    name: 'script-wait-proj-${projectNo}'
    location: location
    seconds: 90
    userManagedIdentityId: managedIdentityId
    addCapHostDelayScripts: addCapHostDelayScripts
    storageAccountName: toLower('stwaitproj${uniqueString(resourceGroup().id)}1')  
  }
}


module formatProjectWorkspaceId './format-project-workspace-id.bicep' = {
  name: 'format-project-${projectNo}-workspace-id-deployment'
  params: {
    projectWorkspaceId: aiProject.outputs.projectWorkspaceId
  }
}

//Assigns the project SMI the storage blob data contributor role on the storage account
module storageAccountRoleAssignment '../iam/azure-storage-account-role-assignment.bicep' = {
  name: 'storage-role-assignment-deployment-${projectNo}'
  scope: resourceGroup(aiDependencies.azureStorage.resourceGroupName)
  dependsOn: [waitForProjectScript]
  params: {
    azureStorageName: aiDependencies.azureStorage.name
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
}

// The Cosmos DB Operator role must be assigned before the caphost is created
module cosmosAccountRoleAssignments '../iam/cosmosdb-account-role-assignment.bicep' = {
  name: 'cosmos-account-ra-project-deployment-${projectNo}'
  dependsOn: [waitForProjectScript]
  scope: resourceGroup(aiDependencies.cosmosDB.resourceGroupName)
  params: {
    cosmosDBName: aiDependencies.cosmosDB.name
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
}

// This role can be assigned before or after the caphost is created
module aiSearchRoleAssignments '../iam/ai-search-role-assignments.bicep' = {
  name: 'ai-search-ra-project-deployment-${projectNo}'
  dependsOn: [waitForProjectScript]  
  scope: resourceGroup(aiDependencies.aiSearch.resourceGroupName)
  params: {
    aiSearchName: aiDependencies.aiSearch.name
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
}

// This module creates the capability host for the project and account
module addProjectCapabilityHost 'add-project-capability-host.bicep' = {
  name: 'capabilityHost-configuration-deployment-${projectNo}'
  dependsOn: [waitForProjectScript, cosmosAccountRoleAssignments, storageAccountRoleAssignment, aiSearchRoleAssignments]
  params: {
    accountName: foundryName
    projectName: aiProject.outputs.projectName
    cosmosDBConnection: aiProject.outputs.cosmosDBConnection
    azureStorageConnection: aiProject.outputs.azureStorageConnection
    aiSearchConnection: aiProject.outputs.aiSearchConnection
    aiFoundryConnectionName: aiProject.outputs.aiFoundryConnectionName
  }
}

// NOTE: using a wait script to ensure all connections are established before finishing the capability host
// this br/public:deployment-scripts/wait module has been deprecated...
// module waitForConnectionsScript 'br/public:deployment-scripts/wait:1.1.1' = {
//   name:  'waitForConnectionsScript-${projectNo}'
//   dependsOn: [addProjectCapabilityHost]
//   params: {
//     waitSeconds: 90
//     location: resourceGroup().location
//   }
// }
// but this fails because it's trying to use key based access to the storage account
module waitForConnectionsScript 'waitDeploymentScript.bicep' = {
  name: 'waitForConnectionsScript-${projectNo}'
  dependsOn: [addProjectCapabilityHost]
  params: {
    name: 'script-wait-connections-${projectNo}'
    location: location
    seconds: 90
    userManagedIdentityId: managedIdentityId
    addCapHostDelayScripts: addCapHostDelayScripts
    storageAccountName: toLower('stwaitconn${uniqueString(resourceGroup().id)}2')
  }
}

// The Storage Blob Data Owner role must be assigned after the caphost is created
module storageContainersRoleAssignment '../iam/blob-storage-container-role-assignments.bicep' = {
  name: 'storage-containers-deployment-${projectNo}'
  dependsOn: [waitForConnectionsScript, addProjectCapabilityHost]
  scope: resourceGroup(aiDependencies.azureStorage.resourceGroupName)
  params: {
    aiProjectPrincipalId: aiProject.outputs.projectPrincipalId
    storageName: aiDependencies.azureStorage.name
    workspaceId: formatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
}

// The Cosmos Built-In Data Contributor role must be assigned after the caphost is created
module cosmosContainerRoleAssignments '../iam/cosmos-container-role-assignments.bicep' = {
  name: 'cosmos-ra-deployment-${projectNo}'
  dependsOn: [waitForConnectionsScript, addProjectCapabilityHost]
  scope: resourceGroup(aiDependencies.cosmosDB.resourceGroupName)
  params: {
    cosmosAccountName: aiDependencies.cosmosDB.name
    projectWorkspaceId: formatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
}

output capabilityHostUrl string = 'https://portal.azure.com/#/resource/${aiProject.outputs.projectId}/capabilityHosts/${addProjectCapabilityHost.outputs.capabilityHostName}/overview'
output aiConnectionUrl string = 'https://portal.azure.com/#/resource/${foundry.id}/connections/${aiProject.outputs.aiFoundryConnectionName}/overview'
output foundry_connection_string string = aiProject.outputs.projectConnectionString
output projectId string = aiProject.outputs.projectId
output projectName string = aiProject.outputs.projectName

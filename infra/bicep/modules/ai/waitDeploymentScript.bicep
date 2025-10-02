@description('Required. Name of the deployment script.')
param name string

@description('Required. Location for the deployment script.')
param location string

@description('Required. Sleep/wait time for the deployment script in seconds.')
param seconds int

// param utcValue string = utcNow()

param userManagedIdentityId string = ''
param addCapHostDelayScripts bool = true
param storageAccountName string

module storageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = if (addCapHostDelayScripts) {
  name: 'storageAccount-${storageAccountName}'
  params: {
    name: storageAccountName
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    tags: {
      SecurityControl: 'Ignore'
      'hidden-title': 'For deployment script'
    }
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    roleAssignments: [
      {
        principalId: userManagedIdentityId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage File Data Privileged Contributor'
      }
    ]
  }
}

module deploymentScript 'br/public:avm/res/resources/deployment-script:0.5.1' = if (addCapHostDelayScripts) {
  name: name
  params: {
    // Required parameters
    kind: 'AzureCLI'
    name: name
    // Non-required parameters
    azCliVersion: '2.75.0'
    cleanupPreference: 'Always'
    location: location
    managedIdentities: { userAssignedResourceIds: [userManagedIdentityId] }
    tags: { 'hidden-title': 'For deployment script' }
    retentionInterval: 'PT1H'
    runOnce: true
    scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
    storageAccountResourceId: storageAccount.outputs.resourceId
    timeout: 'PT5M'
  }
}

// resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (addCapHostDelayScripts) {
//   name: name
//   location: location
//   kind: 'AzurePowerShell'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: { '${ userManagedIdentityId }': {} }
//   }
//   properties: {
//     // storageAccountSettings: { storageAccountName: storageAccountName, storageAccountAccessKey: storageAccountAccessKey }  Note: this doesn't work without the access key...
//     azPowerShellVersion: '11.0'
//     forceUpdateTag: utcValue
//     retentionInterval: 'PT1H'
//     timeout: 'P1D'
//     cleanupPreference: 'Always' // cleanupPreference: 'OnSuccess' or 'Always'
//     scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
//   }
// }

// --------------------------------------------------------------------------------------------------------------
// Wait a minute...  and this needs a storage account with key access for the deployment script to work
// --------------------------------------------------------------------------------------------------------------
@description('Required. Name of the deployment script.')
param name string
@description('Required. Location for the deployment script.')
param location string
@description('Required. Sleep/wait time for the deployment script in seconds.')
param seconds int
param utcValue string = utcNow()
param userManagedIdentityResourceId string = ''
param userManagedIdentityId string = ''
param addCapHostDelayScripts bool = true
param storageAccountName string

// This creates a storage account for the deployment script with key access to use if addCapHostDelayScripts is true
module storageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = if (addCapHostDelayScripts) {
  name: 'storageAccount-${storageAccountName}'
  params: {
    name: storageAccountName
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    tags: {
      SecurityControl: 'Ignore'
      'hidden-title': 'For deployment scripts'
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

resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (addCapHostDelayScripts) {
  name: name
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${ userManagedIdentityResourceId }': {} }
  }
  properties: {
    storageAccountSettings: { storageAccountName: storageAccountName, storageAccountKey: storageAccount.outputs.primaryAccessKey } // Note: this doesn't work without the access key...
    azPowerShellVersion: '11.0'
    forceUpdateTag: utcValue
    retentionInterval: 'PT1H'
    timeout: 'P1D'
    cleanupPreference: 'Always' // cleanupPreference: 'OnSuccess' or 'Always'
    scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
  }
}

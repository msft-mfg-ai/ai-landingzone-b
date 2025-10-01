@description('Required. Name of the deployment script.')
param name string

@description('Required. Location for the deployment script.')
param location string

@description('Required. Sleep/wait time for the deployment script in seconds.')
param seconds int

param utcValue string = utcNow()

param userManagedIdentityId string = ''
param addCapHostDelayScripts bool = true
// param storageAccountName string = ''
// param storageAccountAccessKey string = ''

resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (addCapHostDelayScripts) {
  name: name
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${ userManagedIdentityId }': {} }
  }
  properties: {
    // storageAccountSettings: { storageAccountName: storageAccountName, storageAccountAccessKey: storageAccountAccessKey }  Note: this doesn't work without the access key...
    azPowerShellVersion: '11.0'
    forceUpdateTag: utcValue
    retentionInterval: 'PT1H'
    timeout: 'P1D'
    cleanupPreference: 'Always' // cleanupPreference: 'OnSuccess' or 'Always'
    scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
  }
}

@description('Required. Name of the deployment script.')
param name string

@description('Required. Location for the deployment script.')
param location string

@description('Required. Sleep/wait time for the deployment script in seconds.')
param seconds int

param utcValue string = utcNow()

//param userManagedIdentityId string = ''

resource waitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: name
  location: location
  kind: 'AzurePowerShell'
  // identity: {
  //   type: 'UserAssigned'
  //   userAssignedIdentities: { '${ userManagedIdentityId }': {} }
  // }
  properties: {
    azPowerShellVersion: '11.0'
    forceUpdateTag: utcValue
    retentionInterval: 'PT1H'
    timeout: 'P1D'
    cleanupPreference: 'Always' // cleanupPreference: 'OnSuccess' or 'Always'
    scriptContent: 'Write-Host "Waiting for ${seconds} seconds..." ; Start-Sleep -Seconds ${seconds}; Write-Host "Wait complete."'
  }
}

# Azure DevOps Deployment Notes

## Azure DevOps Pipeline Definitions

Base Pipeline Definitions:

- **[1-deploy-infra-pipeline.yml](1-deploy-infra-pipeline.yml):** Creates all of the Azure resources by deploying the [main-advanced.bicep](../../infra/bicep/main-advanced.bicep) template or  [main-basic.bicep](../../infra/bicep/main-basic.bicep) template.
- **[2-build-deploy-apps-pipeline.yml](2-build-deploy-apps-pipeline.yml):** Pipeline to build all apps in the app code folder, store the resulting images in the Azure Container Registry, then deploy to the Azure Container Apps environments.
  > Note: This pipeline pushes into the ACR created by the first pipeline. The service principal used to run this pipeline must have `acrpush` rights to the ACR, which will need to be added manually after the ACR is created in the Access Control page of the Container Registry.
- **[3-deploy-aif-project-pipeline.yml](3-deploy-aif-project-pipeline.yml):** Creates an AI Foundry Project in an existing AI Foundry by deploying the [main-project.bicep](../../infra/bicep/main-project.bicep) template.
- **[4-pr-pipeline.yml](3-build-pr-pipeline.yml):** Runs each time a Pull Request is submitted and includes results in the PR
- **[5-scan-pipeline.yml](4-scan-pipeline.yml):** Runs a periodic scan of the app for security vulnerabilities

Testing and Development Pipelines

- **[testing-az-import-container-pipeline.yml](testing-az-import-container-pipeline.yml):** Imports a container image into Azure Container Registry from an external source, then deploys it to Azure Container Apps.
  - Note: This import is needed until a build agent can be deployed in the same VNET as the container registry.
  - After that, it can be changed to build locally and deploy to the Container Registry and to Azure locally.
- **[testing-az-cleanup-pipeline.yml](testing-az-cleanup-pipeline.yml):** Development Cleanup task to remove items from the resource group that were created in error
- **[testing-az-call-api-pipeline.yml](testing-az-call-api-pipeline.yml):** Development test to call an API like the application would do

---

## Deploy Environments

These Azure DevOps YML files were designed to run as multi-stage environment deploys (i.e. DEV/QA/PROD). Each Azure DevOps environments can have permissions and approvals defined. For example, DEV can be published upon change, and QA/PROD environments can require an approval before any changes are made. These will be created automatically when the pipelines are run, but if you want to add approvals, you can do so in the Azure DevOps portal.

---

## Create the variable group "AI.LZ.Secrets"

This project needs a variable group with at least one variable in it that uniquely identifies your resources.

To create this variable groups, customize and run this command in the Azure Cloud Shell, or you can go into the Azure DevOps portal and create it manually.

> Alternatively, you could define these variables in the Azure DevOps Portal on each pipeline, but a variable group is a more repeatable and maintainable way to do it.

> Note: The `MY_IP_ADDRESS` and `USER_PRINCIPAL_ID` variables are optional and can be skipped.  If you enter those values, the `MY_IP_ADDRESS` will be added to the allowed IP addresses for the resources being created, and the `USER_PRINCIPAL_ID` will be given rights to resources being created. This is very useful for testing and development, but should not be used in production.

```bash
   # Get your public IP address from a site like https://whatismyipaddress.com/
   curl ifconfig.me
```

```bash
   # Get your User Principal Id from the Azure Portal in the Azure Active Directory > Users > (your user) > Object ID
   az ad user show --id <yourEmailAddress> --query objectId --output tsv
```

```bash
   az login

   az pipelines variable-group create `
     --organization=https://dev.azure.com/<yourAzDOOrg>/ `
     --project='<yourAzDOProject>' `
     --name AI.LZ.Secrets `
     --variables `
         APP_NAME='myailz' `
         RESOURCEGROUP_PREFIX='rg-ailz' `
         INSTANCE_NUMBER='001' `
         MY_IP_ADDRESS='<yourPublicIpAddress>' `
         USER_PRINCIPAL_ID='<yourAdminPrincipalId>' `
```

## Resource Group Name

The Resource Group created will be `<resourceGroupPrefix>-<env>` and will be created in the `<location>` Azure region.  The `location` variable is defined in the [vars/var-common.yml](./vars/var-common.yml) file.  The `resourceGroupPrefix` variable could be defined in either the variable group or in the [var-common.yml](./vars/var-common.yml)  file.  

If you want to use an existing Resource Group Name or change the format of the `generatedResourceGroupName` variable in the [create-infra-template.yml](./pipes/templates/create-infra-template.yml) file and also in the three aca-*template.yml files in the templates folder.

Change the following line in those files to whatever you need it to be:

```bash
$resourceGroupName="$(RESOURCEGROUP_PREFIX)-$environmentCodeLower-$(INSTANCE_NUMBER)".ToLower()
```

## Create Service Connections and update the Service Connection Variable File

The pipelines use unique Service Connection names for each environment (dev/qa/prod), and can be configured to be any name of your choosing. By default, they are set up to be a simple format of `<env> Service Connection`. Edit the [vars/var-service-connections.yml](./vars/var-service-connections.yml) file to match what you have set up as your service connections.

See [Azure DevOps Service Connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure) for more info on how to set up service connections.

```yml
- name: serviceConnectionName
  value: 'DV Service Connection'
- name: serviceConnectionDV
  value: 'DV Service Connection'
- name: serviceConnectionTS
  value: 'TS Service Connection'
- name: serviceConnectionPD
  value: 'PD Service Connection'
```

## Update the Common Variables File with your settings

Customize your deploy by editing the [vars/var-common.yml](./vars/var-common.yml) file. This file contains the following variables which you can change:

```bash
  - name: GLOBAL_REGION_CODE
    value: 'US'
```

## Update the Environment Specific Variables File with your settings

Customize your deploy by editing the [vars/var-dv.yml](./vars/var-dv.yml) file. This file contains the following variables which you can change:

```bash
  - name:   RESOURCEGROUP_LOCATION
    value: 'eastus2'
  - name:   AIFOUNDRY_DEPLOY_LOCATION
    value: 'eastus2'
  - name:   OPENAI_DEPLOY_LOCATION
    value: 'eastus2'
  - name:   AI_MODEL_CAPACITY
    value: '20'
```

## Set up the Deploy Pipelines

The Azure DevOps pipeline files exist in your repository and are defined in the `.azdo/pipelines` folder. However, in order to actually run them, you need to configure each of them using the Azure DevOps portal.

Set up each of the desired pipelines using [these steps](../../docs/CreateNewPipeline.md).

---

## Chat Application Configuration

After your landing zone is deployed and you want to deploy the Chat UI App, there are some additional configurations to be added before you deploy the Chat UI App.  Create the agent in the AI foundry, then make note of the Foundry project endpoint and the agent Id.  In addition, make note of the Application Insights connection string and the User Assigned Managed Identity Client Id created for the app.

In the AI.LZ.Secrets variable group, add the following variables with the appropriate values:

```bash
APP_AGENT_ENDPOINT='<url>' `
APP_AGENT_ID='<string>'
APP_APPINSIGHTS_CONNECTION_STRING='<string>'
APP_IDENTITY_CLIENT_ID='<string>'
```

## Chat Application Deploy

When the Container app is first deployed by the landing zone, it is deployed as a stub application.  To deploy the actual application, run the [2-build-deploy-apps-pipeline.yml](2-build-deploy-apps-pipeline.yml) pipeline in the Azure DevOps portal.  This will build the application, push it to the ACR, then deploy it to the Container App environment.

When you choose the `create-build-deploy` option, it will find the variables created above and set up the container app with those values and deploy a new revision of the application.

When you choose the `build-deploy` option, it simply builds the new container image and deploys it and it will not change the container app configuration or settings.

---

You should be all set to go now!

---

[Home Page](../../README.md)

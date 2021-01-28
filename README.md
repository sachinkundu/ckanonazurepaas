# Introduction

This repository contains deployment configs and settings to run [CKAN](https://ckan.org/) on Azure using native Azure PaaS servies.

## CKAN components and chosen stack

CKAN has three basic components

* Python WSGI fronend - This will be deployed to Azure Container Instances.
* PostgreSQL - We use Azure Database for Postgres.
* Solr - We deploy Solr as a Java webapp on Azure App Services.

Besides that the automation creates supporting components such as a container registry, virtual network and subnets and Azure File storage etc.

## Getting started

First of all create a resource group where CKAN components will be deployed.

You can create a resource group using portal or you can also run

```bash
az group create -l westeurope -g <<resource_group_name>>
```

Next we need to enable Azure DevOps to be able to create resources in this resouce group. For that we will create a service connection to this resource group from the portal as explained [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml)

Update [dev.yaml](pipelines/templates/variables/dev.yml) with your desired values. Remember to change all entries listed in **Must change** category.

Commit these changes back to the Azure DevOps repo(for example by creating a new branch)

Use the [pipeline spec](pipelines/create-base-infra.yml) to create a new pipline for creating base infrastructure needed for CKAN.

Use the branch created earlier with your changes to dev.yml file and trigger the base infra pipeline. This will create many resources in the resource group which you can track from Azure portal. Once the deployment is complete head over to Azure DevOps to create a docker registry service connection to the newly created Azure Container Registry.

You can use the information [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-docreg) to create the service connection to ACR.

Use the pipeline [spec](frontend-ui/pipelines/build-and-push-container.yaml) to create a new pipeline to generate a custom ckan image which is pushed to ACR created above. The ACR service connection created above is used as a parameter for this pipeline.

Note the version tag generated in the build and push logs during pipeline run or you can go to the ACR/Repositories/ckan and get the version tag from there.

Create the following secrets in KeyVault in the ckan resource group

* POSTGRESPASSWORD
* POSTGRESADMINPASSWORD
* SOLRPASSWORD
* CKANSYSADMINEMAIL
* CKANSYSADMINPASSWORD
* CKANSYSADMINUSERNAME

> **NOTE** Before you create the secrets you might have to add yourself to the access policy of the key vault first.

Use the pipeline [spec](pipelines/create-public-catalog.yml) to create a pipeline for creating CKAN components. Remember to use your branch when initiating the pipeline run.

This will use the base infrastructure components created earlier to create CKAN components.

Once the deployment is complete you should be able to navigate to CKAN frontend by using the url

``
frontendname.westeurope.azurecontainer.io
``

>**NOTE:** It is possible that the CKAN deployment fails due to not being able to find a folder under Azure Files which was created in an earlier pipeline step. This is temporary and if it happens rerun the pipeline failed jobs and it should recover.

## Create users and tokens

By running the standalone [pipeline](pipelines/create-users-and-tokens.yml), organizations and further specific users can be created for the system. Each created user is authorized to only one specified organization with *Editor* role (one user is created for each organization configured in the *NAMES* pipeline parameter) and also an API token is generated for them. These users are provided to be able to invoke authorized API calls.

> **IMPORTANT!** Organizations and users passed in the parameters are created/updated by invoking API calls implemented in [this script file](scripts/environment/new-ckanorganduser.ps1). These API requests are authorized with the token of the provisioned sysadmin user Therefore, before running this pipeline it has to make sure that API token is generated for this sysadmin user and stored in Azure Key Vault (name of this secret will be passed to the *apiToken* parameter).

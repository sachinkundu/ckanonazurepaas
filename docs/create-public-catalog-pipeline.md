# Create Public Catalog pipeline

Master pipeline: [`pipelines/create-public-catalog.yml`](../pipelines/create-public-catalog.yml)

## Prerequisites

The following resources are required and presumed to exist:

* Resource Group
* KeyVault
  * Secrets with name SOLRPASSWORD, POSTGRESPASSWORD, CKANSYSADMINUSERNAME, CKANSYSADMINPASSWORD and CKANSYSADMINEMAIL
  * All secret should have appropriate value to set upfront as the pipeline only retrieves their value
* Virtual Network
* Subnet in Virtual Network
* Container Registry
  * Containing CKAN docker image to deploy
* Azure DevOps Service Connection to Azure with rights to deploy in the ResourceGroup

## Deployment

The following resources are created by the pipeline

* Postgres for Azure:
  * Creates User and database to be used by CKAN.
  * Allows connections from the specified Subnet and all of Azure.
* Solr webapp in an AppService:
  * Creates a single Solr core for CKAN
  * Changes administrator password to the one stored in KeyVault.
* CKAN website in a container, configured utilize the previous two services.
* Storage account for attaching Azure File volumes to CKAN container to preserve stored state.
* Storage account for supporting files to dataset publish.
Properties
* The deployments are idempotent, if executed multiple times with the same parameters no changes are made.
* If some parameters are changed, it is **not** guaranteed that the configuration of the services is updated correctly (e.g. if resource name is changed, the older version is not deleted and data not migrated)!

## Parameters

* Environment specific parameters (resource names) are injected as variables from variable templates under $\whdh-public-catalog\pipelines\templates\variables\
* Other parameters can be specified on the Run pipeline dialog.
* All parameters have sensible defaults, the pipeline can be executed without changing the parameters.

|Name       |Description| Default  |
|-----------|-----------|----------|
|solrVersion|Version    |     6.5.1|
...

## Environments

All deployment environments have a corresponding stage in the pipeline and there is a certain dependency between them. By creating a new release, DEV environment is provisioned first and after that it can be run to TEST and at last to PROD stages. To provision TEST and PROD environments an approval is needed upfront. Users also can differ from this chain deployment process and select only some of these stages to run (on the pipeline paramets window, under Advanced Options section). Pending approvals for a certain release are not cancelled automatically after a newer release has been run.

|Name       |Approval?            | Triggers?  |
|-----------|---------------------|------------|
|CKANDEV    |None                 |            |
|CKANTEST   |Manual (SRHD Team)   |            |
|CKANPROD   |Manual (SRHD Team)   |            |

### Creating new environments

1. Create a new yaml file under $\whdh-public-catalog\pipelines\templates\variables\ by copying an existing environment description file
2. Edit  $\pipelines\create-public-catalog.yml:  
   1. Copy an existing stage
   2. In the variables template line change the file path to the new file created in step 1.
   3. In the environment line change the environment name to a new name
3. In Azure DevOps under Environments:
   1. Create a new environment with the same name (optional, the pipeline creates it on first run if it does not exist).
   2. Set up the required checks and approvals.

## Known Issues

* There are empty 'error messages' showing up in the run results, these can be ignored.

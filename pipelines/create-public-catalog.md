# Create Public Catalog pipeline

## Prerequisites

The following resources are required and presumed to exist:

* Resource Group
* KeyVault
  * Secret with name SOLRPASSWORD  
  * Secret with name POSTGRESPASSWORD
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

All deployment environments have a corresponding stage in the pipeline. When selecting multiple stages, there will be a dependency between them so before deploying to TEST, the same release has to be deployed to DEV first. This can be avoided by selecting the TEST stage only. On stages with manual approval obsolete runs do not get cancelled automatically.
|Name       |Approval?            | Triggers?  |
|-----------|---------------------|------------|
|CKANDEV    |None                 |            |
|CKANTEST   |Manual (SRHD Team)   |            |

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

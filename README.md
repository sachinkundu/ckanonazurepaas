# Public catalog

This repository contains deployment configs and settings to run CKAN on Azure.

## Frontend UI

The frontend UI is deployed as a custom container based on ckan/ckan base container. We need a custom container to be able to use Azure Postgresql.

Dockerfile to build the container can be found at [`frontend-ui/Dockerfile`](./frontend-ui/dockerfile)

To make a container locally use:

```plaintext
cd frontend-ui
docker build -t ckan:<<version_number>> .
```

There is a [`docker-compose.yaml` file](./frontend-ui/docker-compose.yaml) which can be used to then start the container along with it's dependencies. CKAN needs access to Solr, Redis and Postgresql to work.

We are using Solr deployed on Azure App Service and Azure Postgresql here. Redis is deployed along side the frontend container and is available as redis within the container (no configs needed)

In `docker-compose.yaml` you need to edit the environment variables and provide connection specific information to the front end.

You can bring the stack up using:

```plaintext
docker compose build
docker compose up
```

CKAN frontend UI is now available on localhost:80 using port forwarding to the frontend container.

### Deploying to Azure Container Instances

You can use the following two methods to deploy the container stack

### Using YAML specification

You can use [`frontend-ui/aci.yaml`](./frontend-ui/aci.yaml) to deploy the whole stack to Azure Container Instances.

Assuming you have a resource group called `ckan` you use

```plaintext
az container create --resource-group ckan --file aci.yaml
```

Make sure to edit `frontend-ui/aci.yaml` with your environment specific configs before running the above command.

### Using ARM templates

You can use [`frontend-ui/arm-templates/aci-template.json`](./frontend-ui/arm-templates/aci-template.json) to deploy the whole stack to Azure Container Instances using ARM templates

Assuming you have a resource group called `ckan` you can use

```ps
templateFile=frontend-ui/arm-templates/aci-template.json
parametersFile=frontend-ui/arm-templates/aci-parameters.json

az deployment group create --name ckan-arm --resource-group ckan --template-file $templateFile --parameters $parametersFile
```

Make sure to edit `parametersFile` with with your environment specific configs before running the above command.

## Azure DevOps Pipeline for deploying CKAN stack

There is a master pipeline spec [`pipelines/create-public-catalog.yml`](./pipelines/create-public-catalog.yml) which can deploy all components to make CKAN stack in a fully automated manner.

It calls template jobs for frontend, solr and postgres which are stored in `pipelines/templates/jobs`. Solr and Postgres are independent pipelines while the frontend job will wait for both to finish before launching as it needs both of the services to be up to boot properly.

Parameters for jobs come from either ARM parameters file if present, default parameters within the template jobs itself or then from environment specific files in `pipelines/templates/variables` folder. Together they comprise all definitions needed to start a CKAN stack.

The stack deployed expects certain infrastructure to be present which is created using the core infra pipeline. In particular it expects a VNET and a subnet within it where to deploy. Also container registry from where to pick ckan frontend container and keyvault from where to store and retrieve password for solr and postgres.

Learn more: [Create Public Catalog pipeline documentation](./docs/create-public-catalog-pipeline.md)

## User and organization management

A dataset in CKAN by design is created under an organization and can be configured to be accessible publicly without a need to authenticate with a user or set to private - in this case, only those users can view/edit an existing dataset or create a new dataset who are authorized to its organization. In each organization a user can have member, editor or admin role. Also sysadmin users can access and manage any datasets and users in the system.

Learn more: [Organizations and authorization in CKAN](https://docs.ckan.org/en/2.9/maintaining/authorization.html)

### Users and organizations managed by pipelines

During running the `pipelines/create-public-catalog.yml` pipeline to [provision an environment](#azure-devops-pipeline-for-deploying-ckan-stack), a sysadmin user is being created/updated. It's implemented as part of [`frontend-ui/ckan-entrypoint.sh` script](./frontend-ui/ckan-entrypoint.sh). All information needed for creating the sysadmin user is pulled from the Key Vault, the secret names are [detailed here](./docs/create-public-catalog-pipeline.md#prerequisites). It's need to be ensured that these secrets are set prior to running the provisioning pipeline.

Organizations and users also can be created by running the standalone [`pipelines/create-users-and-tokens.yml` pipeline](./docs/create-users-and-tokens-pipeline.md). Each of the created users are authorized only one organization to restrict their access and provided to be able to invoke authorized API calls, see in use under [Automated dataset publish](#automated-dataset-publish) section.

**NOTE:** Although organizations can be created by any sysadmin user through the Public Catalog Portal, it's recommended to use this pipeline instead of manual process as it also creates and configures the user for using API calls.

### Manage other registered users

New users registered on Public Catalog Portal can be authorized to any organization by a sysadmin user. It can be managed on the `/organization/members/{organization_name}` page after authenticating with the sysadmin user.

## Automated dataset publish

Example dataflow to publish dataset to the Public Catalog Portal is implemented in DDI Azure Data Factory. For invoking API calls the `ddi_api` user is used which is only authorized to the DDI organization, so it should be created by pipeline for each environment upfront.

Learn more:

* [RefMart Country dataflow design](https://dev.azure.com/WHOHQ/SRHD/_wiki/wikis/General%20Wiki/211/RefMart-Country)
* [RefMart Country Silver To Public pipeline](https://dev.azure.com/WHOHQ/SRHD/_git/DDI-dev-dataflows?path=%2Fpipeline%2FRC_SilverToPublic.json&version=GBdevelopment&_a=contents)

## Provisioning summary

To provision an environment, the below detailed steps should be executed. Prerequisites are detailed in the [pipeline documentation](./docs/create-public-catalog-pipeline.md#prerequisites).

### Provision a new environment

If the desired stage is not defined yet, follow the required steps in [pipeline documentation](./docs/create-public-catalog-pipeline.md#creating-new-environments) first.

If the stage is defined:

1. Run the [`create-public-catalog.yml` pipeline](#azure-devops-pipeline-for-deploying-ckan-stack) for the new environment.
2. After the environment is provisioned, create authorization token for the sysadmin user and store the token value in Key Vault (secret name: *CKANSYSADMINUSERTOKEN*).
3. Run the `create-users-and-tokens.yml` pipeline on the new environment with setting proper parameters. It will creates the desired organizations and their users for using API calls.

### Reprovision existing environment

For an existing environment it's enough to run the [`create-public-catalog.yml` pipeline](#azure-devops-pipeline-for-deploying-ckan-stack) on the desired stage.

If for any reason the resources should be purged upfront, additional steps should be followed detailed under [Backup and restore database](#backup-and-restore-database) section.

## Backup and restore database

If an environment should be reprovsioned with purging all resources, database backup should be created first. Currently there is no automated process for this, backup and restore can be managed by following the steps detailed below. Proper backup and restore plan should be designed and implemented to exchange this manual process.

Prerequisites:

* PostgreSQL binaries are downloaded from [this link](https://www.postgresql.org/download)
* Allow access to client IP adress on PostgreSQL resource (Connection security blade)

The following scripts can be run to create and restore a database dump file using PostgreSQL binaries:

* Backup script: `pg_dump -h {postgres_hostname} -U {postgres_admin}@{postgres_db} --format=custom -d ckan_default > {dump_file}`
* Restore script: `pg_restore -h {postgres_hostname} -U {postgres_admin}@{postgres_db} --clean --if-exists -d ckan_default > {dump_file}`

**IMPORTANT!** After restoring database, Solr index always should be rebuilt by this CKAN CLI command (it can be run on the container CLI):
`ckan -c $CKAN_CONFIG/production.ini search-index rebuild`
It's also recommended to implement a feature for scheduled index rebuild - if the index is written frequently, it might become corrupted. The Solr index contains metadata for all datasets created and these are pulled by UI on datasets page and by APIs as well, so it should be kept clean. To maintain index, need to consider and design either a [background job](https://docs.ckan.org/en/2.9/maintaining/background-tasks.html) or a cron job.

## Monitoring CKAN resources

All CKAN resources are connected to Log Analytics workspace, therefore they can be pinned and visualized on custom Azure Dashboard. Solr App Service is also configured to store logs on the File System.

Solr application has its own logging feature as well, log stream can be accessed trough Solr Admin Dashboard after authentication - `https://{solr_hostname}.azurewebsites.net/solr/#/~logging`
Underneath level of logging can be changed for each category. Solr log files are stored under path `/wwwroot/server/logs` on the App Service.

## See also

* [CKAN source](https://github.com/ckan/ckan/tree/ckan-2.9.0)
* [CKAN documentation](https://docs.ckan.org/en/2.9/)
* [CKAN API documentation](https://docs.ckan.org/en/2.9/api/)
* [CKAN CLI documentation](https://docs.ckan.org/en/2.9/maintaining/cli.html)
* [CKAN database management](https://docs.ckan.org/en/2.9/maintaining/database-management.html)

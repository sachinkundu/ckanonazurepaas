# Public catalog

This repository contains deployment configs and settings to run CKAN on Azure.

## Frontend UI

The frontend UI is deployed as a custom container based on ckan/ckan base container. We need a custom container to be able to use Azure Postgresql.

Dockerfile to build the container can be found at ``frontend-ui/Dockerfile``

To make a container locally use:

```plaintext
cd frontend-ui
docker build -t ckan:<<version_number>> .
```

There is `docker-compose.yaml` file which can be used to then start the container along with it's dependencies. CKAN needs access to Solr, Redis and Postgresql to work.

We are using Solr deployed on Azure App Service and Azure Postgresql here. Redis is deployed along side the frontend container and is available as redis within the container(No configs needed)

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

You can use `frontend-ui/aci.yaml` to deploy the whole stack to Azure Container Instances.

Assuming you have a resource group called `ckan` you use

```plaintext
az container create --resource-group ckan --file aci.yaml
```

Make sure to edit `frontend-ui/aci.yaml` with your environment specific configs before running the above command.

### Using ARM templates

You can use `frontend-ui/arm-templates/aci-template.json` to deploy the whole stack to Azure Container Instances using ARM templates

Assuming you have a resource group called `ckan` you can use

```ps
templateFile=frontend-ui/arm-templates/aci-template.json
parametersFile=frontend-ui/arm-templates/aci-parameters.json

az deployment group create --name ckan-arm --resource-group ckan --template-file $templateFile --parameters $parametersFile
```

Make sure to edit `parametersFile` with with your environment specific configs before running the above command.

## Azure DevOps Pipeline for deploying CKAN stack

There is a master pipeline spec `pipelines/create-public-catalog.yml` which can deploy all components to make CKAN stack in a fully automated manner.

It calls template jobs for frontend, solr and postgres which are stored in `pipelines/templates/jobs`. Solr and Postgres are independent pipelines while the frontend job will wait for both to finish before launching as it needs both of the services to be up to boot properly.

Parameters for jobs come from either ARM parameters file if present, default parameters within the template jobs itself or then from environment specific files in `pipelines/templates/variables` folder. Together they comprise all definitions needed to start a CKAN stack.

The stack deployed expects certain infrastructure to be present which is created using the core infra pipeline. In particular it expects a VNET and a subnet within it where to deploy. Also container registry from where to pick ckan frontend container and keyvault from where to store and retrieve password for solr and postgres.

## Monitoring CKAN resources

All CKAN resources are connected to Log Analytics workspace, therefore they can be pinned and visualized on custom Azure Dashboard. Solr App Service is also configured to store logs on the File System.

Solr application has its own logging feature as well, log stream can be accessed trough Solr Admin Dashboard after authentication - `https://{solr_hostname}.azurewebsites.net/solr/#/~logging`
Underneath level of logging can be changed for each category. Solr log files are stored under path `/wwwroot/server/logs` on the App Service.

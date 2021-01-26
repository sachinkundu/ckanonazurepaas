# Introduction

This repository contains deployment configs and settings to run CKAN on Azure.

## Frontend UI

The frontend UI is deployed as a custom container based on ckan/ckan base container. We need a custom container to be able to use native Azure services like Azure Postgresql and Azure files etc.

To build the container you can use this [Dockerfile](frontend-ui/Dockerfile)

To make a container locally run

```bash
cd frontend-ui
docker build -t ckan:<<version_number>> .
```

To build it using a pipeline on Azure DevOps use [pipleine spec](frontend-ui/pipelines/build-and-push-container.yaml). This spec requires a service connection to ACR/Docker registry which must be made beforehand in Azure DevOps by a project admin.

There is ``docker-compose.yaml`` file which can be used to start the container along with it's dependencies. CKAN needs access to Solr, Redis and Postgresql to work.

We are using Solr deployed on Azure App Service and Azure Postgresql here. Redis is deployed along side the frontend container and is available as redis within the container(No configs needed)

In ``docker-compose.yaml`` you need to edit the environment variables and provide connection specific information to the front end.

You can bring the stack up using

```bash
docker compose build
docker compose up
```

CKAN frontend UI is now available on localhost:5000 using port forwarding to the frontend container.

### Deploying to Azure Container Instances

You can use the following two methods to deploy the container stack

### Using YAML specification

You can use ``frontend-ui/aci.yaml`` to deploy the whole stack to Azure Container Instances.

Assuming you have a resource group called ``ckan`` you use

```bash
az container create --resource-group ckan --file aci.yaml
```

Make sure to edit ``frontend-ui/aci.yaml`` with your environment specific configs before running the above command.

### Using ARM templates

You can use ``frontend-ui/arm-templates/aci-template.json`` to deploy the whole stack to Azure Container Instances using ARM templates

Assuming you have a resource group called ``ckan`` you can use

```bash
templateFile=frontend-ui/arm-templates/aci-template.json
parametersFile=frontend-ui/arm-templates/aci-parameters.json
az deployment group create --name ckan-arm --resource-group ckan --template-file $templateFile --parameters $parametersFile
```

Make sure to edit ``parametersFile`` with with your environment specific configs before running the above command.

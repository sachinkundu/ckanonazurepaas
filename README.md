# Introduction
This repository contains deployment configs and settings to run CKAN on Azure.

## Frontend UI

The frontend UI is deployed as a custom container based on ckan/ckan base container. We need a custom container to be able to use Azure Postgresql.

Dockerfile to build the container can be found at ``frontend-ui/Dockerfile``

To make a container locally use

```
cd frontend-ui
docker build -t ckan:<<version_number>> .
```

There is ``docker-compose.yaml`` file which can be used to then start the container along with it's dependencies. CKAN needs access to Solr, Redis and Postgresql to work.

We are using Solr deployed on Azure App Service and Azure Postgresql here. Redis is deployed along side the frontend container and is available as redis within the container(No configs needed)

In ``docker-compose.yaml`` you need to edit the environment variables and provide connection specific information to the front end.

You can bring the stack up using

```
docker compose build
docker compose up
```

CKAN frontend UI is now available on localhost:5000 using port forwarding to the frontend container.

### Deploying to Azure Container Instances

You can use ``frontend-ui/aci.yaml`` to deploy the whole stack to Azure Container Instances.

Assuming you have a resource group called ``ckan`` you use

```
az container create --resource-group ckan --file aci.yaml
```
Make sure to edit the file ``frontend-ui/aci.yaml`` with your environment specific configs before running the above command.



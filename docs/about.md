# CKAN on Azure PaaS

Comprehensive Knowledge Archive Network (CKAN) is an open-source open data portal for the storage and distribution of open data. It is the defacto data portal used by governments, non governmental organizations and companies to make data available to general public.

We recently worked with World Health Organization(WHO) on their data platform. This platform makes it easy to share and consume data within different teams in WHO as well as make it possible to release high quality datasets to the general public through CKAN.

## Motivation

While there are already [packaged solutions](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/bitnami.ckan-multitier?tab=Overview) to deploy CKAN on Azure using Azure infrastructure services, we wanted to leverage Azure'd Platform as a Service offering as much as possible. This was done to reduce the maintenance burden for WHO IT as well as to utilize Azure to its fullest. 

## Architecture

CKAN can be broadly divided into three components

* Python WSGI frontend
* PostgreSQL database
* Solr for search indexes

We chose to run the frontend as a containerized application on top of Azure Container Instances. We start dependent services like Redis and Datapusher inside a container group along with wsgi python frontend.

For PostgreSQL we use fully managed service [Azure Database for Postgres](https://azure.microsoft.com/en-us/services/postgresql/). Using this service you can scale workloads quickly with ease. Enjoy high availability with up to 99.99% SLA, AI–powered performance optimization, and advanced security.

We deployed Solr as a Java app on top of Azure App Services.

Besides that CKAN settings are persisted in Azure files which are mounted as volumes within ACI. Azure Data Lake Storage is used as the file store backend where datasets are published when they are ready.

## What has been done

Using the configurations and automation in this repo you should be able to spin up a functional cluster with the three components listed above(as well as supporting components) in no time.

There is a Dockerfile to build frontend container with production settings enabled. This involves using nginx as reverse proxy and running multiple processes behind supervisord.

We had to patch CKAN source files while building the container to be able to talk to Azure Postgres. Username convention on Azure Postgres was in conflict with how the database ORM used within CKAN(sqlalchemy) handled the username. Specifically we had to

``
RUN sed -i '269s/.*/          "sqlalchemy.url", str(self.metadata.bind.url).replace("%40","@")/' /usr/lib/ckan/venv/src/ckan/ckan/model/__init__.py
``

There are ARM templates and Azure DevOps pipeline specs to deploy both Postges as well as Solr.

## What has not been done

We must make it clear that this is day 1 work for a production level CKAN environment on Azure. Specifically we note the following features which must be implemented before opening the portal to general public

* Move all components within a VNET and enable an Azure App GW for SSL termination. Use private link endpoint whenever possible.
* Connect ACI, Postgres and Solr App Service to send diagnostic logs to a centralized log analytics backed. This is partly done but end to end log capturing and correlation ability needs to be verified. Also dashboards and alerts need to be implemented.
* Postgres DB backups and restore automation. Azure service for Postgres makes this easy but there is some work around policy needed.

## Conclusion

We hope that using this repo will enable you to bootstrap a functional CKAN instance on Azure faster than it took us. We also hope that you would enjoy the benefits of using Azure native services namely ease of maintenance and high SLA guarantees.

### How to use this stuff

If you want to deploy the automation head over to [README](../README.md) and follow the steps as listed there.

If you find any discrepancies please file an issue or better still submit a PR. We would be delighted!
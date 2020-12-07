# Create users and tokens pipeline

## Overview

By running the standalone [`pipelines/create-users-and-tokens.yml` pipeline](../pipelines/create-users-and-tokens.yml) organizations and further specific users can be created for the system. Each created user is authorized to only one specified organization with *Editor* role (one user is created for each organization configured in the *technicalUnit* pipeline parameter) and also an API token is generated for them. These users are provided to be able to invoke authorized API calls.

## Parameters

* *azureResourceManagerConnection* - name of the environment specific Azure Resource Manager Connection
* *ckanURL* - URL of Public Catalog instance
* *technicalUnit* - name of technical units, comma separated. CKAN organizations are created from its value. Title and display name of each organization will be set from the given technical unit name and its name will be set as the lowercase version of belonging technical unit name.
* *technicalUnitEmails* - email address of users to create for each organization, comma separated. Should have the same number of email addresses defined as technical unit names, they are associated to each other in the same order. Multiple users can't be created with the same email address, so each user should have unique email address to set.
* *apiToken* - name of sysadmin's API token secret stored in Key Vault, default value: *CKANSYSADMINAPITOKEN*

**IMPORTANT!** Organizations and users passed in the parameters are created/updated by invoking API calls implemented in [this script file](../scripts/environment/new-ckanorganduser.ps1). These API requests are authorized with the token of the provisioned sysadmin user Therefore, before running this pipeline it has to make sure that API token is generated for this sysadmin user and stored in Azure Key Vault (name of this secret will be passed to the *apiToken* parameter). Because of this dependency, this pipeline is currently not part of the [provisioning master pipeline](./create-public-catalog-pipeline.md) and can be run separately.

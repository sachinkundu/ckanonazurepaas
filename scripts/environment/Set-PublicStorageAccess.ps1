#!/usr/bin/env pwsh

# Get the managed identity for the ADF
$managedIdentity = (az datafactory factory show --name $env:FACTORYNAME --resource-group $env:RESOURCEGROUP |  ConvertFrom-Json).identity.principalId

# Set Storage Blob Reader permissions for Tech Unit ADF to ADL
az role assignment create `
    --assignee-object-id $managedIdentity `
    --role "Storage Blob Data Contributor" `
    --scope "/subscriptions/$env:SUBSCRIPTIONID/resourceGroups/$env:RESOURCEGROUP/providers/Microsoft.Storage/storageAccounts/$env:STORAGEACCOUNTNAME"

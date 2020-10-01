#!/usr/bin/env pwsh

# Set the Subscription ID to an task variable
$id = (az account show | ConvertFrom-Json).id;
Write-Output "##vso[task.setvariable variable=subscriptionId]$id"

# Convert RG name to environment designation
 switch -wildcard ($env:AZURERESOURCEMANAGERCONNECTION)
    {
        "*-D-*" {$environment="dev"}
        "*-T-*" {$environment="test"}
        "*-S-*" {$environment="stage"}
        "*-P-*" {$environment="prod"}
    }

Write-Output "##vso[task.setvariable variable=environment]$environment"

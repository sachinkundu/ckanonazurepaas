#!/usr/bin/env pwsh

# Added module check and install because of the git pre-commit hooks
if (Get-Module -ListAvailable -Name PSScriptAnalyzer)
{
  Install-Module -Name PSScriptAnalyzer
}

$lintErrors = Invoke-ScriptAnalyzer -Path . -Recurse

if ($lintErrors)
{
  Write-Output $lintErrors
  Exit 1
}

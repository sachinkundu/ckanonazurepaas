#!/usr/bin/env pwsh

$lintErrors = Invoke-ScriptAnalyzer -Path . -Recurse
if ($lintErrors)
{
  Write-Output $lintErrors
  Exit 1
}

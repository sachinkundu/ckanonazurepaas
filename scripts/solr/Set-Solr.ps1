param(
  $keyVaultName,
  $webAppUrl,
  $solrPasswordKeyName,
  $coreName
)
Write-Output "webAppUrl=" + $webAppUrl
Write-Output "coreName=" + $coreName

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Header = 
@{
    "Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("solr:SolrRocks"))
}

Write-Output "Wait for the web app to come online..."
$waitTimeoutSec = 5
$waitMaxRetries = 150
for($i=1; $i -le $waitMaxRetries; $i++) {
  try {
    $resp = try { 
      (Invoke-WebRequest  -SkipCertificateCheck -uri "$webAppUrl/solr/#/" -TimeoutSec $waitTimeoutSec).BaseResponse
    } catch [System.Net.WebException], [Microsoft.PowerShell.Commands.HttpResponseException] { 
      Write-Verbose "An exception was caught: $($_.Exception.Message)"
      $_.Exception.Response 
    } 
    if ($resp.StatusCode -lt 400 -or $resp.StatusCode -eq 401 -or $resp.StatusCode -eq 402) { 
      break
    } 
  }
  catch [System.Threading.Tasks.TaskCanceledException] {
    Write-Warning $_.Exception.Message
    if ($i -eq $waitMaxRetries) {
      throw
    }  
  }
  catch [System.Net.WebException] {
    if (_.Exception.Message -like "*timeout*") {
      Write-Warning $_.Exception.Message
      if ($i -eq $waitMaxRetries) {
        throw
      }  
    }
    else {
      throw
    }
  } 
}

Write-Output "Create core for CKAN"
Invoke-RestMethod -Method GET -Header $Header -SkipCertificateCheck -TimeoutSec 600 -uri "$webAppUrl/solr/admin/cores?action=CREATE&name=$coreName&instanceDir=$coreName&config=solrconfig.xml&dataDir=data"

Write-Output "Generate new password for Solr user"
$password = ""
$rand = New-Object System.Random
0..14 | ForEach-Object {$password += [char]$rand.Next(33,126)}

Write-Output "Store the new password in Key Vault"
az keyvault secret set --vault-name $keyVaultName --name $solrPasswordKeyName --value $password

#if ($LastExitCode -ne 0){
#    Write-Error "Could not store password in Key Vault"
#    exit $LastExitCode
#}
# TODO: Pipeline should fail if Key Vault operations fail, but as a workaround currently we can get the password from pipeline log
Write-Output "Password: " + $password 

Write-Output "Change password for admin user"
$Body = 
@{
    "set-user" =
      @{
        "solr" = $password
       }
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Header $Header -ContentType "application/json" -SkipCertificateCheck -uri "$webAppUrl/solr/admin/authentication" -Body $Body
param(
  $solrUrl,
  $solrPassword,
  $coreName
)
Write-Output "solrUrl=" + $solrUrl
Write-Output "coreName=" + $coreName

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Header = 
@{
    "Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("solr:SolrRocks"))
}

Write-Output "Wait for the web app to come online..."
$waitTimeoutSec = 15
$waitMaxRetries = 50
for($i=1; $i -le $waitMaxRetries; $i++) {
  try {
    $resp = try { 
      (Invoke-WebRequest -Headers $Header -SkipCertificateCheck -uri "$solrUrl" -TimeoutSec $waitTimeoutSec).BaseResponse
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

Write-Output "Checking core data directory..."
for ($i=1; $i -le 15; $i++) {
  $response = Invoke-RestMethod -Method GET -Header $Header -SkipCertificateCheck -TimeoutSec 10 -uri "$solrUrl/admin/cores?action=STATUS&core=$coreName"
  $content = ([xml]$response)
  $indexNodeExist = (($content.response.lst | Where-Object {$_.name -eq 'status'}).lst | Where-Object {$_.name -eq $coreName}).lst | Where-Object {$_.name -eq 'index'}
  Write-Output $indexNodeExist
  
  if ($indexNodeExist) {
    Write-Output "The core already exists!"
    break
  }
}

if (!$indexNodeExist) {
  Write-Output "Create core for CKAN"
  Invoke-RestMethod -Method GET -Header $Header -SkipCertificateCheck -TimeoutSec 600 -uri "$solrUrl/admin/cores?action=CREATE&name=$coreName&instanceDir=$coreName&config=solrconfig.xml&dataDir=data"
}

Write-Output "Change password for admin user"
$Body = 
@{
    "set-user" =
      @{
        "solr" = $solrPassword
       }
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Header $Header -ContentType "application/json" -SkipCertificateCheck -uri "$solrUrl/admin/authentication" -Body $Body
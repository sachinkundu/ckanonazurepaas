param(
  $solrUrl,
  $solrPwd,
  $coreName
)

Write-Output "solrUrl = $solrUrl"
Write-Output "coreName = $coreName"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Header =
@{
    "Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("solr:SolrRocks"))
}

$waitTimeoutSec = 15
$waitMaxRetries = 50

Write-Output "Wait for the web app to come online..."

for($i=1; $i -le $waitMaxRetries; $i++) {
  try {
    $resp = try {
      (Invoke-WebRequest -Headers $Header -SkipCertificateCheck -uri "$solrUrl" -TimeoutSec $waitTimeoutSec).BaseResponse
    } catch [System.Net.WebException], [Microsoft.PowerShell.Commands.HttpResponseException] {
      Write-Verbose "An exception was caught: $($_.Exception.Message)"
      $_.Exception.Response
    }

    $statusCode = [int]$resp.StatusCode
    if ($statusCode -lt 400 -or $statusCode -eq 401 -or $statusCode -eq 402) {
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

$waitMaxRetries = 15
$isCoreExists = $false

for ($i=1; $i -le $waitMaxRetries; $i++) {
  Write-Output "Attempt to get core information..."

  try {
    $resp = Invoke-WebRequest -Method GET -Headers $Header -SkipCertificateCheck -TimeoutSec $waitTimeoutSec -uri "$solrUrl/admin/cores?action=STATUS&core=$coreName"
    $statusCode = [int]$resp.StatusCode
    $content = ([xml]$resp.Content)
    $indexNode = (($content.response.lst | Where-Object {$_.name -eq 'status'}).lst | Where-Object {$_.name -eq $coreName}).lst | Where-Object {$_.name -eq 'index'}

    if ($indexNode) {
      $isCoreExists = $true
    }
  }
  catch {
    $statusCode = [int]$_.Exception.Response.StatusCode
    Write-Warning $_.Exception.Message
  }

  Write-Output "Status code: $statusCode"

  if ($statusCode -eq 200 -and $isCoreExists) {
    Write-Output "The core $coreName already exists."
    break
  }

  Write-Output "Unabled to get core information."
}

if (!$isCoreExists) {
  for ($i=1; $i -le $waitMaxRetries; $i++) {
    Write-Output "Attempt to create core for CKAN..."

    try {
      $resp = Invoke-WebRequest -Method GET -Headers $Header -SkipCertificateCheck -TimeoutSec $waitTimeoutSec -uri "$solrUrl/admin/cores?action=CREATE&name=$coreName&instanceDir=$coreName&config=solrconfig.xml&dataDir=data"
      $statusCode = [int]$resp.StatusCode
      Write-Output "The core $coreName has been created."
    }
    catch {
      $statusCode = [int]$_.Exception.Response.StatusCode
      Write-Warning $_.Exception.Message
    }

    Write-Output "Status code: $statusCode"

    if ($statusCode -eq 200) {
      Write-Output "The core $coreName has been created."
      break
    }

    if ($statusCode -eq 500) {
      Write-Output "The core $coreName already exists."
      break
    }
  }
}

Write-Output "Change password for admin user"

$Body =
@{
    "set-user" =
      @{
        "solr" = $solrPwd
       }
} | ConvertTo-Json

for ($i=1; $i -le $waitMaxRetries; $i++) {
  Write-Output "Attempt to change admin password..."

  try {
    $resp = Invoke-WebRequest -Method POST -Headers $Header -ContentType "application/json" -SkipCertificateCheck -TimeoutSec $waitTimeoutSec -uri "$solrUrl/admin/authentication" -Body $Body
    $statusCode = [int]$resp.StatusCode
  }
  catch {
    $statusCode = [int]$_.Exception.Response.StatusCode
    Write-Warning $_.Exception.Message
  }

  Write-Output "Status code: $statusCode"

  if ($statusCode -eq 200) {
    Write-Output "The password has been changed."
    break
  }
}
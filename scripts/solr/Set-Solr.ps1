param(
  $keyVaultName,
  $webAppUrl,
  $solrPasswordKeyName,
  $coreName
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Header = 
@{
    "Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("solr:SolrRocks"))
}

Write-Output "Create core for CKAN"
Invoke-RestMethod -Method GET -Header $Header -SkipCertificateCheck -uri "$webAppUrl/solr/admin/cores?action=CREATE&name=$coreName&instanceDir=$coreName&config=solrconfig.xml&dataDir=data"

Write-Output "Generate new password for Solr user"
$password = ""
$rand = New-Object System.Random
0..8 | ForEach-Object {$password += [char]$rand.Next(33,126)}

Write-Output "Store the new password in Key Vault"
az keyvault secret set --vault-name $keyVaultName --name $solrPasswordKeyName --value $password

Write-Output "Change password for admin user"
$Body = 
@{
    "set-user" =
      @{
        "solr" = $password
       }
} | ConvertTo-Json
Invoke-RestMethod -Method POST -Header $Header -ContentType "application/json" -SkipCertificateCheck -uri "$webAppUrlsolr/admin/authentication" -Body $Body
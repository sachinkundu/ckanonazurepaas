Param(
    $solrVersion,
    $configDir
)

$solrName = "solr-$solrVersion"

Write-Output "Downloading Solr package version $solrVersion"
$solrSourceUrl = "https://archive.apache.org/dist/lucene/solr/$solrVersion/$solrName.zip"
Invoke-WebRequest -Uri $solrSourceUrl -UseBasicParsing -OutFile ".\solr.zip"

Write-Output "Extract Solr package"
Expand-Archive ".\solr.zip" -DestinationPath ".\"

Write-Output "Add web.config to the root"
Copy-Item -Path "$configDir\web.config" -Destination ".\solr-$solrVersion"
Copy-Item -Path "$configDir\security.json" -Destination ".\solr-$solrVersion\server\solr"

Write-Output "Create configuration for new core"
New-Item -Path ".\solr-$solrVersion\server\solr" -Name "ckan" -ItemType "directory"
$corePath = ".\solr-$solrVersion\server\solr\ckan"
Copy-Item -Path ".\solr-$solrVersion\server\solr\configsets\basic_configs\*" -Destination $corePath -Recurse
Copy-Item -Path "$configDir\schema.xml" -Destination "$corePath\conf"
Remove-Item -Path "$corePath\conf\managed-schema" -Force

Write-Output "Create package to deploy"
Compress-Archive -Path ".\solr-$solrVersion\*" -DestinationPath ".\solr_setup_package.zip" -Force

Write-Output "Clean up folder"
Remove-Item -Path ".\solr.zip"
Remove-Item -Path ".\solr-$solrVersion" -Recurse -Force

$packagePath = Resolve-Path ".\solr_setup_package.zip"
Write-Output "Package is ready for deployment - path: $packagePath"

$apiToken = (az keyvault secret show --name $env:APITOKENNAME --vault-name $env:KEYVAULT | ConvertFrom-Json).value

$ckanURL = "$($env:CKANURL)/api/3/action/"

# Create lists for user names, and emails, and check if their lengths matches
$userNames = $env:TECHUNITNAMES.Split(",")
$emails = $env:TECHUNITEMAILS.Split(",")

if ($userNames.Count -ne $emails.Count) {
    Write-Error "The user name and email counts are not matching!" -ErrorAction Stop
}

$headers = @{
    Authorization = "$apiToken"
}

# Get the list of current users
try {
    $response = Invoke-WebRequest `
        -Uri "$($ckanURL)user_list" `
        -Method GET `
        -Headers $headers `
        -ErrorAction Stop

    $statusCode = $response.StatusCode

    $existingUsers = ($response.Content | ConvertFrom-Json).result
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__

    Write-Error "Couldn't retrieve user list!"
    Write-Error $Error[0]
    Break
}

# Setup each user:
# - Create user for TU in CKAN
# - Save their password to Key Vault
# - Create API token and save it to key vault
# - Add them to the TU's CKAN organization
if ($statusCode -eq 200) {
    for ($i = 0; $i -lt $userNames.Count; $i++) {
        # Have to use join, because for values larger then 48 it returns a multi-line result
        $password = (openssl rand -base64 64) -join ("\n")

        $tuName = $userNames[$i].ToLower()
        $userName = "$($tuName)_api"

        $user = @{
            name = $userName;
            email = $emails[$i];
            password = $password
        }

        # Check if user already exist
        $id = ($existingUsers | Where-Object {$_.name -eq $userName}).id

        try {
            if ($id) {
                $user | Add-Member -MemberType NoteProperty -Name 'id' -Value $id
                $user = $user | ConvertTo-Json

                $response = Invoke-WebRequest `
                    -Uri "$($ckanURL)user_update" `
                    -Method POST `
                    -Body $user `
                    -Headers $headers `
                    -ContentType 'application/json' `
                    -ErrorAction Stop

                $statusCode = $response.StatusCode

                Write-Output "$($userName) updated"
            } else {
                $user = $user | ConvertTo-Json

                $response = Invoke-WebRequest `
                    -Uri "$($ckanURL)user_create" `
                    -Method POST `
                    -Body $user `
                    -Headers $headers `
                    -ContentType 'application/json' `
                    -ErrorAction Stop

                $statusCode = $response.StatusCode

                Write-Output "$($userName) created"
            }

            # If successful, save user name and password to Key Vault
            $keyVaultVaule = az keyvault secret set --name "ckan-$($tuName)-api-user-name" --vault-name $env:KEYVAULT --value $userName --query "name"
            Write-Output "$($keyVaultVaule) created in Key Vault"

            $keyVaultVaule = az keyvault secret set --name "ckan-$($tuName)-api-user-password" --vault-name $env:KEYVAULT --value $password --query "name"
            Write-Output "$($keyVaultVaule) created in Key Vault"

        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            Write-Error "Couldn't create/update user!"
            Write-Error $Error[0]
            Break
        }

        if ($statusCode -eq 200) {
            try {
                $tokenName = "$($userName)_api_token"
                $userToken = @{
                    user = $userName;
                    name = $tokenName
                } | ConvertTo-Json

                # Check if there is already a Token with this name created
                $currentTokens = Invoke-WebRequest `
                    -Uri "$($ckanURL)api_token_list?user=$($userName)" `
                    -Method GET `
                    -Headers $headers `
                    -ContentType 'application/json' `
                    -ErrorAction Stop

                $currentTokensList = ($currentTokens.Content | ConvertFrom-Json).result
                $currentTokenId = ($currentTokensList | Where-Object {$_.name -eq $tokenName}).id

                if ($currentTokenId) {
                    # Revoke current API Token, if exists
                    $tokenId = @{
                        jti = $currentTokenId
                    } | ConvertTo-Json

                    $response = Invoke-WebRequest `
                        -Uri "$($ckanURL)api_token_revoke" `
                        -Method POST `
                        -Body $tokenId `
                        -Headers $headers `
                        -ContentType 'application/json' `
                        -ErrorAction Stop

                    Write-Output "Old token revoked"
                }

                # Create API token for user
                $response = Invoke-WebRequest `
                    -Uri "$($ckanURL)api_token_create" `
                    -Method POST `
                    -Body $userToken `
                    -Headers $headers `
                    -ContentType 'application/json' `
                    -ErrorAction Stop

                $token = ($response | ConvertFrom-Json).result.token
                $statusCode = $response.StatusCode

                Write-Output "New token created"

                # If successful, save token and token name to Key Vault
                $keyVaultVaule = az keyvault secret set --name "ckan-$($tuName)-api-user-token-name" --vault-name $env:KEYVAULT --value $tokenName --query "name"
                Write-Output "$($keyVaultVaule) created in Key Vault"

                $keyVaultVaule = az keyvault secret set --name "ckan-$($tuName)-api-user-token" --vault-name $env:KEYVAULT --value $token --query "name"
                Write-Output "$($keyVaultVaule) created in Key Vault"
            }
            catch {
                $statusCode = $_.Exception.Response.StatusCode.value__

                Write-Error "Couldn't create API Token!"
                Write-Error $Error[0]
                Break
            }

            try {
                # Add user to organization
                $member = @{
                    id = $tuName;
                    object = $userName;
                    object_type = "user";
                    capacity = "editor"
                } | ConvertTo-Json

                $response = Invoke-WebRequest `
                    -Uri "$($ckanURL)member_create" `
                    -Method POST `
                    -Body $member `
                    -Headers $headers `
                    -ContentType 'application/json' `
                    -ErrorAction Stop

                $statusCode = $response.StatusCode

                Write-Output "$($userName) added to $($tuName) organization"
            }
            catch {
                $statusCode = $_.Exception.Response.StatusCode.value__

                Write-Error "Couldn't add user to organization!"
                Write-Error $Error[0]
                Break
            }
        }
    }
}

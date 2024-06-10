$ErrorActionPreference = 'Break'

$apiVersion = "2020-06-01"
$resource = "https://management.azure.com/"
$endpoint = "{0}?resource={1}&api-version={2}" -f $env:IDENTITY_ENDPOINT, $resource, $apiVersion
$secretFile = ""

(Invoke-WebRequest -Method GET -Uri http://localhost:40342/metadata/instance?api-version=2020-06-01 -Headers @{Metadata = 'True' } -UseBasicParsing).Content > output1.ConvertFrom-Json
code .\output1.json

try {
    Invoke-WebRequest -Method GET -Uri $endpoint -Headers @{Metadata = 'True' }
}
catch {
    $wwwAuthHeader = $_.Exception.Response.Headers.WwwAuthenticate.Parameter
    $wwwAuthHeader
    if ($wwwAuthHeader -match "realm=.+") {
        $secretFile = ($wwwAuthHeader -split "realm=")[1]
    }
}
Write-Host "Secret file path: " $secretFile
$secret = Get-Content -Raw $secretFile
$secret

$response = Invoke-WebRequest -Method GET -Uri $endpoint -Headers @{Metadata = 'True'; Authorization = "Basic $secret" } -UseBasicParsing
if ($response) {
    $token = (ConvertFrom-Json -InputObject $response.Content).access_token
    Write-Host "Access token: " $token
    $token | clip
}

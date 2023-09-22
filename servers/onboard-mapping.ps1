$csv = Import-Csv -Path .\onboard-mapping.csv -Delimiter ';'
$computerConfig = $csv | Where-Object -Property Name -Value $env:COMPUTERNAME -EQ
$computerConfig

if ($null -eq $computerConfig) {
    Write-Information "No configuration found for computer $env:COMPUTERNAME. Using default configuration."
}
else {
    Write-Information "Using configuration for computer $env:COMPUTERNAME."
    $env:SUBSCRIPTION_ID = $computerConfig.SubscriptionId;
    $env:RESOURCE_GROUP = $computerConfig.ResourceGroup;
    $env:TAGS = $computerConfig.Tags;
    # ...
}

# Run connect command
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$servicePrincipalClientId" --service-principal-secret "$servicePrincipalSecret" --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --tags "$env:TAGS" --correlation-id "$env:CORRELATION_ID";
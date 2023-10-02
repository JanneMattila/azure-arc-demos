# Arc-enabled servers

## Onboarding by mapping

Typical onboarding process contains script like this:

```powershell
try {
    # Add the service principal application ID and secret here
    $servicePrincipalClientId="<ENTER ID HERE>";
    $servicePrincipalSecret="<ENTER SECRET HERE>";

    $env:SUBSCRIPTION_ID = "6eccf8a5-bc2d-448b-bf79-8d5df172c56a";
    $env:RESOURCE_GROUP = "rg-target";
    # ...

    # Run connect command
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id `
      "$servicePrincipalClientId" --service-principal-secret "$servicePrincipalSecret" `
      --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" `
      --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" `
      --cloud "$env:CLOUD" --tags "Datacenter=DC,City=Espoo" --correlation-id "$env:CORRELATION_ID";
# ...
```

Above is quite static and would onboard all Arc-enabled servers to same resource group and subscription with same tags.

Alternative to that, you could have simple mapping CSV file like this:

```csv
Name;ResourceGroup;SubscriptionId;Tags
fihesrv00010;rg-south;3ca5f54c-9e15-45e3-9be8-e922be122c24;Datacenter=DC1,City=Helsinki
fihesrv00011;rg-south;3ca5f54c-9e15-45e3-9be8-e922be122c24;Datacenter=DC1,City=Helsinki
fiousrv00050;rg-north;938ba7df-b539-4b68-ba55-cf37c5048d32;Datacenter=DC1,City=Oulu
```

You can use Excel to edit that file content:

![Use Excel to edit mapping file](https://github.com/JanneMattila/azure-arc-demos/assets/2357647/186505c9-15f8-45b7-b377-545ec7ccb7ab)

If no mapping is found for current computer, then default configuration is used.

Above configuration would mean this in practise:

![Arc-enabled servers mapping to Azure subscriptions and resource groups](https://github.com/JanneMattila/azure-arc-demos/assets/2357647/9f6af770-7071-482c-befe-8a32aff9371e)

You should place that mapping file to location which servers can access during the provisioning e.g., network fileshare.

And then you could use PowerShell to onboard them using the mapping file:

```powershell
try {
    # Add the service principal application ID and secret here
    $servicePrincipalClientId="<ENTER ID HERE>";
    $servicePrincipalSecret="<ENTER SECRET HERE>";

    $env:SUBSCRIPTION_ID = "6eccf8a5-bc2d-448b-bf79-8d5df172c56a";
    $env:RESOURCE_GROUP = "rg-target";
    # ...

    ######################
    # This part is new-->
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
    # <--This part is new
    ######################

    # Run connect command
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id `
      "$servicePrincipalClientId" --service-principal-secret "$servicePrincipalSecret" `
      --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" `
      --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" `
      --cloud "$env:CLOUD" --tags "$env:TAGS" --correlation-id "$env:CORRELATION_ID";
# ...
```

## Resource move

Resource mover enables you to move Arc-enabled servers resources between resource groups and subscriptions.

However, you might get following error messages if they have related resources:

Error code: `ResourceMovePolicyValidationFailed`

Message: `Resource move policy validation failed. Please see details. Diagnostic information: subscription id 'f9054d67-06ae-43ae-ab57-b2ecc30e1a97', request correlation id '49e7a9bf-719e-428c-815e-35b8b4372f91'.`

Details: 

Code: `ResourceReadFailed`
Target: `Microsoft.HybridCompute/Microsoft.HybridCompute/machines/extensions`

```json
{
  "error": {
    "code": "HCRP404",
    "message": "The requested resource was not found.",
    "target": "f9054d67-06ae-43ae-ab57-b2ecc30e1a97/rg-arc-vm/myarcvm/WindowsOpenSSH"
  }
}
```

You might get these per each extension:

- `MDE.Windows`
- `WindowsOpenSSH`

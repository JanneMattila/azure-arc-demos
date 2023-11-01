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
    # NOTE: This part is new-->
    $csv = Import-Csv -Path .\onboard-mapping.csv -Delimiter ';'
    $computerConfig = $csv | Where-Object -Property Name -Value $env:COMPUTERNAME -EQ
    $computerConfig

    if ($null -eq $computerConfig) {
        Write-Host "No configuration found for computer $env:COMPUTERNAME. Using default configuration."
    }
    else {
        Write-Host "Using configuration for computer $env:COMPUTERNAME."
        $env:SUBSCRIPTION_ID = $computerConfig.SubscriptionId;
        $env:RESOURCE_GROUP = $computerConfig.ResourceGroup;
        $env:TAGS = $computerConfig.Tags;
        # ...
    }
    # <--This part is new
    ######################

    # Run connect command
    # NOTE: Add additional deployment parameters to the command->
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

## AzureConnectedMachineAgent examples

To invoke AzureConnectedMachineAgent, you can use following command:

`& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"`

```powershell
# Allow only AMA deployment
azcmagent config set extensions.allowlist "Microsoft.Azure.Monitor/AzureMonitorWindowsAgent"

# Disable guest configuration (evaluating Azure Policies on the server)
azcmagent config set guestconfiguration.enabled false

# Disable incoming connections
azcmagent config set incomingconnections.enabled false

# List current configuration
azcmagent config list
```

Extensions are installed to following location:

`C:\Packages\Plugins`

Azure Monitor Agent is installed to following location:

`C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent`

## Onboarding to monitoring with policy

Initiative: [Enable Azure Monitor for Hybrid VMs with AMA](https://www.azadvertizer.net/azpolicyinitiativesadvertizer/2b00397d-c309-49c4-aa5a-f0b2c5bc6321.html)

Policy: [Configure Windows Arc-enabled machines to run Azure Monitor Agent](https://www.azadvertizer.net/azpolicyadvertizer/94f686d6-9a24-4e19-91f1-de937dc171a4.html)

Key points from the policy:

- Extension `Microsoft.Azure.Monitor/AzureMonitorWindowsAgent` will be deployed

```json
{
  // clipped
  "variables": {
    "extensionName": "AzureMonitorWindowsAgent",
    "extensionPublisher": "Microsoft.Azure.Monitor",
    "extensionType": "AzureMonitorWindowsAgent"
  },
  "resources": [
    {
      "name": "[concat(parameters('vmName'), '/', variables('extensionName'))]",
      "type": "Microsoft.HybridCompute/machines/extensions",
      "location": "[parameters('location')]",
      "apiVersion": "2021-05-20",
      "properties": {
        "publisher": "[variables('extensionPublisher')]",
        "type": "[variables('extensionType')]",
        "autoUpgradeMinorVersion": true,
        "enableAutomaticUpgrade": true
      }
    }
  ]
  // clipped
}
```

Policy: [Configure Dependency agent on Azure Arc enabled Windows servers with Azure Monitoring Agent settings](https://www.azadvertizer.net/azpolicyadvertizer/84cfed75-dfd4-421b-93df-725b479d356a.html)

Key points from the policy:

- Extension `Microsoft.Azure.Monitoring.DependencyAgent/DependencyAgentWindows` will be deployed

```json
{
  // clipped
  "variables": {
    "DaExtensionName": "DependencyAgentWindows",
    "DaExtensionType": "DependencyAgentWindows"
  },
  "resources": [
    {
      "type": "Microsoft.HybridCompute/machines/extensions",
      "apiVersion": "2020-03-11-preview",
      "name": "[concat(parameters('vmName'), '/', variables('DaExtensionName'))]",
      "location": "[parameters('location')]",
      "properties": {
        "publisher": "Microsoft.Azure.Monitoring.DependencyAgent",
        "type": "[variables('DaExtensionType')]",
        "autoUpgradeMinorVersion": true,
        "settings": {
          "enableAMA": "true"
        }
      }
    }
  ],
  // clipped
}
```

Policy: [Configure Windows Machines to be associated with a Data Collection Rule or a Data Collection Endpoint](https://www.azadvertizer.net/azpolicyadvertizer/eab1f514-22e3-42e3-9a1f-e1dc9199355c.html)

Key points from the policy:

- [Data Collection Rule](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
  association will be done either to data collection rule or data collection endpoint

```json
{
  // clipped
  "resources": [
    // clipped
    {
        "condition": "[and(equals(toLower(parameters('type')), 'microsoft.hybridcompute/machines'), equals(parameters('resourceType'), variables('dcrResourceType')))]",
        "name": "[variables('dcrAssociationName')]",
        "type": "Microsoft.Insights/dataCollectionRuleAssociations",
        "apiVersion": "2021-04-01",
        "properties": {
            "dataCollectionRuleId": "[parameters('dcrResourceId')]"
        },
        "scope": "[concat('Microsoft.HybridCompute/machines/', parameters('resourceName'))]"
    },
    {
        "condition": "[and(equals(toLower(parameters('type')), 'microsoft.hybridcompute/machines'), equals(parameters('resourceType'), variables('dceResourceType')))]",
        "name": "[variables('dceAssociationName')]",
        "type": "Microsoft.Insights/dataCollectionRuleAssociations",
        "apiVersion": "2021-04-01",
        "properties": {
            "dataCollectionEndpointId": "[parameters('dcrResourceId')]"
        },
        "scope": "[concat('Microsoft.HybridCompute/machines/', parameters('resourceName'))]"
    }
  ]
  // clipped
}
```
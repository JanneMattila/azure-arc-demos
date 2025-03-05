# Use deployment folder
Set-Location agora

############################################### 
#  ____
# |  _ \ _   _ _ __     ___  _ __   ___ ___
# | |_) | | | | '_ \   / _ \| '_ \ / __/ _ \
# |  _ <| |_| | | | | | (_) | | | | (_|  __/
# |_| \_\\__,_|_| |_|  \___/|_| |_|\___\___|
# to create deployment service principal
############################################### 
#region Create deployment service principal
Connect-AzAccount

# *Explicitly* select your working context
Select-AzSubscription -Subscription "<YourSubscriptionName>"

$context = Get-AzContext
$subscription = $context.Subscription.Id

# Key Vault API "user_impersonation" Permissions
$keyVaultApp = Get-AzADServicePrincipal -ApplicationId "cfa8b339-82a2-471a-a3c9-0fc0be7a4093"
$keyVaultermissions = $keyVaultApp | Select-Object -ExpandProperty Oauth2PermissionScope
$permission = $keyVaultermissions | Where-Object { $_.Value -eq "user_impersonation" }

$newSPN = New-AzADServicePrincipal `
    -DisplayName "AgoraBoxSPN" `
    -Role "Owner" `
    -Scope "/subscriptions/$($subscription)"

# Get application
$app = Get-AzADApplication -ApplicationId $newSPN.AppId

$requiredResourceAccessJson = [ordered]@{
    requiredResourceAccess = @(
        @{
            resourceAppId = $keyVaultApp.AppId  # Key Vault API
            resourceAccess = @(
                @{
                    id = $permission.Id  # user_impersonation permission ID
                    type = "Scope"  # Delegated permission type
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-AzRestMethod `
    -Method PATCH `
    -Uri "https://graph.microsoft.com/v1.0/myorganization/applications/$($app.Id)" `
    -Payload $requiredResourceAccessJson

# Save the service principal to a JSON file
$newSPN | ConvertTo-Json > spn.json

# Create SSH key pair
ssh-keygen -t ed25519 -C $spn.DisplayName -f id_rsa -N ""

#endregion

###############################################
#  ____             _
# |  _ \  ___ _ __ | | ___  _   _
# | | | |/ _ \ '_ \| |/ _ \| | | |
# | |_| |  __/ |_) | | (_) | |_| |
# |____/ \___| .__/|_|\___/ \__, |
#            |_|            |___/
# Agora demo environment
###############################################

# Now you restore the service principal from the JSON file
$spn = Get-Content spn.json | ConvertFrom-Json

# Get the SSH public key
$sshRSAPublicKey = Get-Content id_rsa.pub

$customLocationRP = Get-AzADServicePrincipal -DisplayName "Custom Locations RP"

# Download deployment scripts
Invoke-WebRequest -Uri "https://github.com/microsoft/azure_arc/archive/main.zip" -OutFile azure_arc.zip
Expand-Archive azure_arc.zip -DestinationPath azure_arc -Force

Set-Location azure_arc/azure_arc-main/azure_jumpstart_ag/contoso_motors/bicep

# Create copy of original parameters file
Copy-Item main.parameters.json main.parameters.json.bak

# Update deployment parameters
$configuration = Get-Content main.parameters.json | ConvertFrom-Json
$configuration.parameters.spnClientId.value = $spn.AppId
$configuration.parameters.spnObjectId.value = $spn.Id
$configuration.parameters.spnClientSecret.value = $spn.PasswordCredentials.SecretText
$configuration.parameters.spnTenantId.value = $spn.AppOwnerOrganizationId
$configuration.parameters.windowsAdminUsername.value = "azureuser"
$configuration.parameters.windowsAdminPassword.value = $spn.PasswordCredentials.SecretText
$configuration.parameters.customLocationRPOID.value = $customLocationRP.Id
$configuration | ConvertTo-Json > main.parameters.json

$configuration.parameters

$clientPassword = ConvertTo-SecureString $spn.PasswordCredentials.SecretText -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($spn.AppId, $clientPassword)
Connect-AzAccount -Credential $credentials -ServicePrincipal -TenantId $spn.AppOwnerOrganizationId

# Ensure context
Get-AzContext

$resourceGroupName = "rg-agorabox"
$location = "northeurope"

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

$result = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile main.bicep `
    -TemplateParameterFile main.parameters.json `
    -sshRSAPublicKey $sshRSAPublicKey `
    -Mode Complete -Force `
    -Verbose

$result

# Enable access to RDP from this machine
$myIP = Invoke-RestMethod https://myip.jannemattila.com

$nsg = Get-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroupName `
    -Name "Ag-NSG-Prod"

$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP" `
    -Description "Allow from developer machine" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceAddressPrefix $myIP/32 `
    -SourcePortRange * `
    -DestinationAddressPrefix VirtualNetwork `
    -DestinationPortRange 3389

# Update the network security group
$nsg | Set-AzNetworkSecurityGroup

# Connect to the VM
$pip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "Ag-VM-Client-PIP"
$pip.IpAddress

$configuration.parameters.windowsAdminUsername.value
$configuration.parameters.windowsAdminPassword.value
$configuration.parameters.windowsAdminPassword.value | clip

mstsc /v:$($pip.IpAddress)

# To save costs, you can shutdown the VM
Stop-AzVM -ResourceGroupName $resourceGroupName -Name "Ag-VM-Client" -Force

# Resume demo environment
Start-AzVM -ResourceGroupName $resourceGroupName -Name "Ag-VM-Client"

# Remove the resource group
Remove-AzResourceGroup -Name $resourceGroupName -Force

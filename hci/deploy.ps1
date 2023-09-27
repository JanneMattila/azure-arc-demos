# Use deployment folder
Set-Location hci

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

$newSPN = New-AzADServicePrincipal -DisplayName "HCIBoxSPN" -Role "Owner" -Scope "/subscriptions/$($subscription)"

# Save the service principal to a JSON file
$newSPN | ConvertTo-Json > spn.json

#endregion

###############################################
#  ____             _
# |  _ \  ___ _ __ | | ___  _   _
# | | | |/ _ \ '_ \| |/ _ \| | | |
# | |_| |  __/ |_) | | (_) | |_| |
# |____/ \___| .__/|_|\___/ \__, |
#            |_|            |___/
# HCIBox demo environment
###############################################

# Now you restore the service principal from the JSON file
$spn = Get-Content spn.json | ConvertFrom-Json

# Download deployment scripts
Invoke-WebRequest -Uri "https://github.com/microsoft/azure_arc/archive/main.zip" -OutFile azure_arc.zip
Expand-Archive azure_arc.zip -DestinationPath azure_arc -Force

Set-Location azure_arc/azure_arc-main/azure_jumpstart_hcibox/bicep

# Create copy of original parameters file
Copy-Item main.parameters.json main.parameters.json.bak

# Update deployment parameters
$configuration = Get-Content main.parameters.json | ConvertFrom-Json
$configuration.parameters.spnClientId.value = $spn.AppId
$configuration.parameters.spnClientSecret.value = $spn.PasswordCredentials.SecretText
$configuration.parameters.spnTenantId.value = $spn.AppOwnerOrganizationId
$configuration | ConvertTo-Json > main.parameters.json

$configuration.parameters

$clientPassword = ConvertTo-SecureString $spn.PasswordCredentials.SecretText -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($spn.AppId, $clientPassword)
Connect-AzAccount -Credential $credentials -ServicePrincipal -TenantId $spn.AppOwnerOrganizationId

# Ensure context
Get-AzContext

$resourceGroupName = "rg-hcibox"
$location = "northeurope"

New-AzResourceGroup -Name $ResourceGroupName -Location $location -Verbose

$result = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile main.bicep `
    -TemplateParameterFile main.parameters.json `
    -Mode Complete -Force `
    -Verbose

$result

# Enable access to RDP from this machine
$myIP = Invoke-RestMethod https://myip.jannemattila.com

$nsg = Get-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroupName `
    -Name "HCIBox-NSG"

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
$pip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "HCIBox-Client-PIP"
$pip.IpAddress

$configuration.parameters.windowsAdminUsername.value
$configuration.parameters.windowsAdminPassword.value
$configuration.parameters.windowsAdminPassword.value | clip

mstsc /v:$($pip.IpAddress)

# To save costs, you can shutdown the VM
Stop-AzVM -ResourceGroupName $resourceGroupName -Name "HCIBox-Client" -Force

# Resume demo environment
Start-AzVM -ResourceGroupName $resourceGroupName -Name "HCIBox-Client"

# Remove the resource group
Remove-AzResourceGroup -Name $resourceGroupName -Force

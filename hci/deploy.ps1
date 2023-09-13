Set-Location hci

# Download deployment scripts
Invoke-WebRequest -Uri "https://github.com/microsoft/azure_arc/archive/main.zip" -OutFile azure_arc.zip
Expand-Archive azure_arc.zip -DestinationPath azure_arc -Force

Set-Location azure_arc/azure_arc-main/azure_jumpstart_hcibox/bicep

# Edit parameters
code main.parameters.json

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

$configuration = Get-Content main.parameters.json | ConvertFrom-Json

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

# Remove the resource group
Remove-AzResourceGroup -Name $resourceGroupName -Force

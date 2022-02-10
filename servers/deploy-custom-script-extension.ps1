Param (
    [Parameter(HelpMessage = "Resource group to deploy custom script extension.")]
    [string] $ResourceGroup = "rg-arc-vms"
)

$ErrorActionPreference = "Stop"

class VMInstallationStatus {
    [string] $VirtualMachine
    [string] $Status
}

$installedModule = Get-Module -Name "Az.ConnectedMachine" -ListAvailable
if ($null -eq $installedModule) {
    Install-Module "Az.ConnectedMachine" -Scope CurrentUser
}
else {
    # Should be imported automatically but if not then you need this
    # Import-Module "Az.ConnectedMachine"
}

# You can check parameters from here:
# https://github.com/Azure/custom-script-extension-linux
$publicSettings = @{ 
    "commandToExecute" = "./install.sh"
}

$protectedSettings = @{ 
    "fileUris" = @(
        "https://github.com/JanneMattila/azure-arc-demos/blob/main/servers/install.sh"
    )
}

$list = New-Object Collections.Generic.List[VMInstallationStatus]

$linuxArcVMs = Get-AzConnectedMachine -ResourceGroupName $ResourceGroup
$linuxArcVMs | Format-Table
$forceRerun = (Get-Date).ToString("yyyyMMddHHmmss")

foreach ($linuxArcVM in $linuxArcVMs) {
    if ($linuxArcVM.OSName -eq "linux") {

        $vmInstallationStatus = New-Object VMInstallationStatus
        $vmInstallationStatus.VirtualMachine = $linuxArcVM.Name
        $vmInstallationStatus.Status = "Not started"

        # https://docs.microsoft.com/en-us/azure/azure-arc/servers/manage-vm-extensions-powershell#enable-extension
        # https://docs.microsoft.com/en-us/powershell/module/az.connectedmachine/new-azconnectedmachineextension?view=azps-7.2.0

        try {
            $extension = New-AzConnectedMachineExtension -Name "custom" `
                -ResourceGroupName $ResourceGroup `
                -MachineName $linuxArcVM.Name `
                -Location $linuxArcVM.Location `
                -Publisher "Microsoft.Compute" `
                -Settings $publicSettings `
                -ProtectedSetting $protectedSettings `
                -ForceRerun $forceRerun `
                -ExtensionType CustomScriptExtension
            $vmInstallationStatus.Status = $extension.StatusDisplayStatus
        }
        catch {
            $vmInstallationStatus.Status = $_
        }
        $list.Add($vmInstallationStatus)
    }
}

$list | Export-Csv -Path "DeployedExtensions.csv" -NoTypeInformation
$list | Format-Table

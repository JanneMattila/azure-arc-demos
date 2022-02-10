Param (
    [Parameter(HelpMessage = "Resource group to deploy custom script extension.")]
    [string] $ResourceGroup = "rg-arc-vms"
)

$ErrorActionPreference = "Stop"

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
        "https://raw.githubusercontent.com/JanneMattila/azure-arc-demos/main/servers/install.sh"
    )
}

$jobs = @()

$linuxArcVMs = Get-AzConnectedMachine -ResourceGroupName $ResourceGroup
$linuxArcVMs | Format-Table
$forceRerun = (Get-Date).ToString("yyyyMMddHHmmss")

foreach ($linuxArcVM in $linuxArcVMs) {
    if ($linuxArcVM.OSName -eq "linux") {
        Write-Host "Starting deployment for $($linuxArcVM.Name)"

        # https://docs.microsoft.com/en-us/azure/azure-arc/servers/manage-vm-extensions-powershell#enable-extension
        # https://docs.microsoft.com/en-us/powershell/module/az.connectedmachine/new-azconnectedmachineextension?view=azps-7.2.0

        # For troubleshooting:
        # https://docs.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-vm-extensions
        # Logs:
        # /var/opt/azcmagent
        # /var/lib/GuestConfig

        $jobs += New-AzConnectedMachineExtension -Name "customDeployment" `
            -ResourceGroupName $ResourceGroup `
            -MachineName $linuxArcVM.Name `
            -Location $linuxArcVM.Location `
            -Publisher "Microsoft.Azure.Extensions" `
            -Settings $publicSettings `
            -ProtectedSetting $protectedSettings `
            -ForceRerun $forceRerun `
            -ExtensionType CustomScript `
            -AutoUpgradeMinorVersion `
            -NoWait `
            -AsJob
    }
}

Write-Host "Waiting for all deployment jobs to complete."

$jobs
$outputs = $jobs | Get-Job | Wait-Job | Receive-Job 
$outputs | Format-Table -AutoSize
$outputs | Export-Csv -Path "ExtensionOutputs.csv" -NoTypeInformation

# If you need to clean up jobs, here's example command:
# Get-Job | Remove-Job -Force

# Networking

```powershell
# Get the current proxy settings
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent" config get proxy.url

# Set the proxy settings for external proxy
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent" config set proxy.url "http://192.168.100.100:8080"

# Set the proxy to use local Fiddler proxy
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent" config set proxy.url "http://localhost:8888"

# Do connectivity check
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent" check --location "westeurope"
```

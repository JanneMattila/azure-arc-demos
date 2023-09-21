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

Example connectivity check output:

```powershell
PS C:\Users\azureuser> & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent" check --location "westus3"
time="2023-09-21T07:15:57Z" level=info msg="Testing connectivity to endpoints that are needed to connect to Azure... This might take a few minutes."
time="2023-09-21T07:16:10Z" level=error msg="Regional Service Discovery" Error="Get \"https://gbl.his.arc.azure.com/discovery?location=westus3&api-version=2.1\": proxyconnect tcp: dial tcp [::1]:8888: connectex: No connection could be made because the target
 machine actively refused it." Proxy Status="proxy set via config command" Request URL="https://gbl.his.arc.azure.com/discovery?location=westus3&api-version=2.1"
ENDPOINT                                              |REACHABLE  |PRIVATE  |TLS      |PROXY
https://agentserviceapi.guestconfiguration.azure.com  |false      |unknown  |unknown  |set
https://gbl.his.arc.azure.com                         |false      |unknown  |unknown  |set
https://login.microsoftonline.com                     |false      |unknown  |unknown  |set
https://login.windows.net                             |false      |unknown  |unknown  |set
https://management.azure.com                          |false      |unknown  |unknown  |set
https://pas.windows.net                               |false      |unknown  |unknown  |set
https://westus3-gas.guestconfiguration.azure.com      |false      |unknown  |unknown  |set

PS C:\Users\azureuser> 
```

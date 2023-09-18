RESOURCE_GROUP="rg-aci-proxy"
ACI_NAME="ci-proxy"
STORAGE_NAME="ciproxy0000010"
LOCATION="northeurope"

az account set --subscription "development"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the storage account
az storage account create \
    --resource-group $RESOURCE_GROUP \
    --name $STORAGE_NAME \
    --allow-blob-public-access true \
    --sku Standard_LRS

# Create the file share
az storage share create \
  --name share \
  --account-name $STORAGE_NAME \
  --quota 100

STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_NAME --query "[0].value" --output tsv)
echo $STORAGE_KEY

COMMAND_LINE="mitmweb --web-host 0.0.0.0 --save-stream +/home/mitmproxy/%Y/%m/%d/%H-%M-proxy.log"
COMMAND_LINE="mitmdump --w +/home/mitmproxy/proxy.log --flow-detail 3 --set stream_websocket=true"

aci_json=$(az container create \
  --resource-group $RESOURCE_GROUP \
  --name $ACI_NAME \
  --image mitmproxy/mitmproxy:10.0.0 \
  --command-line "$COMMAND_LINE" \
  --cpu 1 \
  --memory 1 \
  --ports 8080 8081 \
  --ip-address public \
  --restart-policy Always \
  --azure-file-volume-account-name $STORAGE_NAME \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name share \
  --azure-file-volume-mount-path "/home/mitmproxy/" \
  -o json)

az container attach --name $ACI_NAME --resource-group $RESOURCE_GROUP
az container logs --name $ACI_NAME --resource-group $RESOURCE_GROUP --follow

echo $aci_json | jq .

# Get the IP address of the container group
ip_address=$(echo $aci_json | jq -r '.ipAddress.ip')
echo $ip_address

curl http://$ip_address:8080
curl http://$ip_address:8081

# Open the web UI
echo http://$ip_address:8081

http_proxy=http://$ip_address:8080/ curl http://echo.jannemattila.com/pages/echo
https_proxy=http://$ip_address:8080/ curl -k https://echo.jannemattila.com/pages/echo

# Cleanup ACI
az container delete --name $ACI_NAME --resource-group $RESOURCE_GROUP --yes
# Cleanup all resources
az group delete --name $RESOURCE_GROUP --yes

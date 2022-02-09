#!/bin/bash

# All the variables for the deployment
subscriptionName="AzureDev"

arcName="myarckube"
workspaceName="myarckube"
resourceGroupName="rg-myarckube"
location="westeurope"

# Login and set correct context
az login -o table
az account set --subscription $subscriptionName -o table

subscriptionID=$(az account show -o tsv --query id)
az group create -l $location -n $resourceGroupName -o table

# Prepare extensions and providers
az extension add --upgrade --yes --name connectedk8s

# Enable feature
az provider register --namespace "Microsoft.Kubernetes"
az provider register --namespace "Microsoft.KubernetesConfiguration"
az provider register --namespace "Microsoft.ExtendedLocation"

az provider show -n "Microsoft.Kubernetes" -o table
az provider show -n "Microsoft.KubernetesConfiguration" -o table
az provider show -n "Microsoft.ExtendedLocation" -o table

# Use Docker desktop
kubectl config use-context docker-desktop

az connectedk8s connect --name $arcName --resource-group $resourceGroupName

workspaceid=$(az monitor log-analytics workspace create -g $resourceGroupName -n $workspaceName --query id -o tsv)
echo $workspaceid

kubectl get nodes
kubectl get deployments,pods -n azure-arc

monitorExtensionId = $(az k8s-extension create `
  --name azuremonitor-containers `
  --cluster-name $arcName `
  --resource-group $resourceGroupName `
  --cluster-type connectedClusters `
  --extension-type Microsoft.AzureMonitor.Containers `
  --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceid)

az resource wait --ids $monitorExtensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

# Apply log and prometheus data collection settings 
kubectl apply -f container-azm-ms-agentconfig.yaml

# Create namespace
kubectl apply -f namespace.yaml

# Create deployment & service
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

kubectl get deployment -n demos
kubectl describe deployment -n demos

kubectl get pod -n demos
pod1=$(kubectl get pod -n demos -o name | head -n 1)
echo $pod1

kubectl describe $pod1 -n demos

kubectl get service -n demos

ingressip=$(kubectl get service -n demos -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
echo $ingressip

curl $ingressip
curl $ingressip/home/privacy
curl $ingressip/notfound
curl $ingressip/metrics

# Query prometheus logs from our test app
workspaceCustomerId=$(az monitor log-analytics workspace create --resource-group $resourceGroupName --workspace-name $workspaceName --query customerId -o tsv)
echo $workspaceCustomerId

az monitor log-analytics query \
  --workspace $workspaceCustomerId \
  --analytics-query "InsightsMetrics | where Namespace == 'prometheus' | summarize by Name" \
  --out table

az monitor log-analytics query \
  --workspace $workspaceCustomerId \
  --analytics-query "InsightsMetrics | where Namespace == 'prometheus' and parse_json(Tags).app == 'webapp-monitoring-demo' and Name == 'http_request_duration_seconds_bucket'" \
  --out table

# Wipe out the resources
az connectedk8s delete --name $arcName --resource-group $resourceGroupName
az group delete --name $resourceGroupName -y

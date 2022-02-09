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
#
# NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/cluster-metadata-operator   1/1     1            1           6m31s
# deployment.apps/clusterconnect-agent        1/1     1            1           6m31s
# deployment.apps/clusteridentityoperator     1/1     1            1           6m31s
# deployment.apps/config-agent                1/1     1            1           6m31s
# deployment.apps/controller-manager          1/1     1            1           6m31s
# deployment.apps/extension-manager           1/1     1            1           6m31s
# deployment.apps/flux-logs-agent             1/1     1            1           6m31s
# deployment.apps/kube-aad-proxy              1/1     1            1           6m31s
# deployment.apps/metrics-agent               1/1     1            1           6m31s
# deployment.apps/resource-sync-agent         1/1     1            1           6m31s
# 
# NAME                                             READY   STATUS    RESTARTS   AGE
# pod/cluster-metadata-operator-7d9b465454-tsqc4   2/2     Running   0          6m31s
# pod/clusterconnect-agent-b65cbd6b5-nbl6p         3/3     Running   0          6m31s
# pod/clusteridentityoperator-657fd75459-vk76l     2/2     Running   0          6m31s
# pod/config-agent-b6547d575-mkhtz                 2/2     Running   0          6m31s
# pod/controller-manager-66d56c9bf-9qzbn           2/2     Running   0          6m31s
# pod/extension-manager-cf49d5cbd-rqvn8            2/2     Running   0          6m31s
# pod/flux-logs-agent-6cbd59f69d-js7pd             1/1     Running   0          6m31s
# pod/kube-aad-proxy-65bf446c-hzwz5                2/2     Running   0          6m31s
# pod/metrics-agent-667587f7bd-h6jtv               2/2     Running   0          6m31s
# pod/resource-sync-agent-54b8f8c755-5gl28         2/2     Running   0          6m31s
# 

# Note: After above you can already see "Standard" Metrics
# at the portal e.g., Total number of cpu cores in a connected cluster
# but not yet Insights or Logs.

monitorExtensionId=$(az k8s-extension create \
  --name azuremonitor-containers \
  --cluster-name $arcName \
  --resource-group $resourceGroupName \
  --cluster-type connectedClusters \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceid)

az k8s-extension show \
  --name azuremonitor-containers \
  --cluster-name $arcName \
  --resource-group $resourceGroupName \
  --cluster-type connectedClusters \
  -n azuremonitor-containers

kubectl get deployments -n kube-system
# NAME          READY   UP-TO-DATE   AVAILABLE   AGE
# coredns       2/2     2            2           9d
# omsagent-rs   1/1     1            1           8m37s

# Apply log and prometheus data collection settings 
kubectl apply -f k8s/container-azm-ms-agentconfig.yaml

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create deployment & service
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

kubectl get deployment -n demos
kubectl describe deployment -n demos

kubectl get pod -n demos
pod1=$(kubectl get pod -n demos -o name | head -n 1)
echo $pod1

kubectl describe $pod1 -n demos

kubectl get service -n demos

# 1. You can use port forwarding
kubectl port-forward service/webapp-monitoring-demo -n demos 1080:80
# Navigate:
# http://localhost:1080/
# http://localhost:1080/metrics

# 2. You can use exposed node port
svc=localhost:30080
echo $svc

curl $svc
curl $svc/home/privacy
curl $svc/notfound
curl $svc/metrics

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

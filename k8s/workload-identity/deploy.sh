subscription_name="Production"
resource_group_name="rg-arc-k8s"
app_identity_name="id-arc-k8s"
storage_name="arck8s0000000010"
container_name="oidc"
location="swedencentral"

az account set --subscription $subscription_id

az group create --name $resource_group_name --location $location

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create identity
identity_json=$(az identity create --name $app_identity_name --resource-group $resource_group_name -o json)
client_id=$(echo $identity_json | jq -r .clientId)
principal_id=$(echo $identity_json | jq -r .principalId)
echo $client_id
echo $principal_id

subscription_id=$(az account show --query id -o tsv)

# Grant reader access to identity to subscription
az role assignment create \
 --assignee-object-id $principal_id \
 --assignee-principal-type ServicePrincipal \
 --scope /subscriptions/$subscription_id \
 --role "Reader"

# Prepare cluster
# https://azure.github.io/azure-workload-identity/docs/installation/self-managed-clusters.html
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub

# Generate storage account
az storage account create --resource-group $resource_group_name --name $storage_name --allow-blob-public-access true
az storage container create --account-name $storage_name --name $container_name --public-access blob

cat <<EOF > openid-configuration.json
{
  "issuer": "https://${storage_name}.blob.core.windows.net/${container_name}/",
  "jwks_uri": "https://${storage_name}.blob.core.windows.net/${container_name}/openid/v1/jwks",
  "response_types_supported": [
    "id_token"
  ],
  "subject_types_supported": [
    "public"
  ],
  "id_token_signing_alg_values_supported": [
    "RS256"
  ]
}
EOF

cat openid-configuration.json

# Upload the discovery document
az storage blob upload \
   --account-name $storage_name \
  --container-name $container_name \
  --file openid-configuration.json \
  --name .well-known/openid-configuration

# Verify that the discovery document is publicly accessible
curl -s "https://${storage_name}.blob.core.windows.net/${container_name}/.well-known/openid-configuration"

# Download azwi from GitHub Releases
download=$(curl -sL https://api.github.com/repos/Azure/azure-workload-identity/releases/latest | jq -r '.assets[].browser_download_url' | grep linux-amd64)
wget $download -O azwi.zip
tar -xf azwi.zip --exclude=*.md --exclude=LICENSE
./azwi --help
./azwi version

# Generate the JWKS document
./azwi jwks --public-keys sa.pub --output-file jwks.json
cat jwks.json

# Upload the JWKS document
az storage blob upload \
  --account-name $storage_name \
  --container-name $container_name \
  --file jwks.json \
  --name openid/v1/jwks

# Verify that the JWKS document is publicly accessible
curl -s "https://${storage_name}.blob.core.windows.net/${container_name}/openid/v1/jwks"

# Install Mutating Admission Webhook
tenant_id=$(az account show --query tenantId -o tsv)
echo $tenant_id

# Create a Kubernetes service account
service_account_oidc_issuer=$(echo "https://${storage_name}.blob.core.windows.net/${container_name}/.well-known/openid-configuration")
service_account_key_file="$(pwd)/sa.pub"
service_account_signing_file="$(pwd)/sa.key"
service_account_name="workload-identity-sa"

# https://kind.sigs.k8s.io/docs/user/quick-start/
# https://hub.docker.com/r/kindest/node/tags
cat <<EOF | kind create cluster --name azure-workload-identity --image kindest/node:v1.22.4 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
    - hostPath: ${service_account_key_file}
      containerPath: /etc/kubernetes/pki/sa.pub
    - hostPath: ${service_account_signing_file}
      containerPath: /etc/kubernetes/pki/sa.key
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        service-account-issuer: ${service_account_oidc_issuer}
        service-account-key-file: /etc/kubernetes/pki/sa.pub
        service-account-signing-key-file: /etc/kubernetes/pki/sa.key
    controllerManager:
      extraArgs:
        service-account-private-key-file: /etc/kubernetes/pki/sa.key
EOF

kubectl cluster-info --context kind-azure-workload-identity

# Create connected cluster
az connectedk8s connect \
  --name "mylaptop" \
  --resource-group $resource_group_name \
  --location $location \
  --tags "Datacenter=Garage City=Espoo StateOrDistrict CountryOrRegion=Finland"

kubectl get nodes

helm repo add azure-workload-identity https://azure.github.io/azure-workload-identity/charts
helm repo update
helm install workload-identity-webhook azure-workload-identity/workload-identity-webhook \
   --namespace azure-workload-identity-system \
   --create-namespace \
   --set azureTenantID="${tenant_id}"

kubectl create ns network-app

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${client_id}
    azure.workload.identity/tenant-id: ${tenant_id}
  name: ${service_account_name}
  namespace: network-app
EOF

az identity federated-credential create \
 --name "app-identity" \
 --identity-name $app_identity_name \
 --resource-group $resource_group_name \
 --issuer $service_account_oidc_issuer \
 --subject "system:serviceaccount:secrets-app:$service_account_name"

kubectl get serviceaccount -n network-app
kubectl describe serviceaccount -n network-app

kubectl apply -f network-app.yaml

network_app_pod1=$(kubectl get pod -n network-app -o name | head -n 1)
echo $network_app_pod1

network_app_uri="http://localhost:30080"
curl $network_app_uri

curl $network_app_uri/api/commands
curl -X POST --data "INFO ENV" "$network_app_uri/api/commands"
curl -X POST --data "INFO ENV AZURE_CLIENT_ID" "$network_app_uri/api/commands"
curl -X POST --data "INFO ENV AZURE_TENANT_ID" "$network_app_uri/api/commands"
curl -X POST --data "INFO ENV AZURE_FEDERATED_TOKEN_FILE" "$network_app_uri/api/commands"
curl -X POST --data "INFO ENV AZURE_AUTHORITY_HOST" "$network_app_uri/api/commands"
curl -X POST --data "FILE READ /var/run/secrets/azure/tokens/azure-identity-token" "$network_app_uri/api/commands"

# Deploy Azure PowerShell Job
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: network-app-configmap
  namespace: network-app
data:
  app.config: |-
    Write-Output "This is example run.ps1 (from configmap)"

    Get-AzResourceGroup | Format-Table
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: azure-powershell-job
  namespace: network-app
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: "${service_account_name}"
      restartPolicy: Never
      containers:
        - name: azure-powershell-job
          image: azure-powershell-job:latest
          imagePullPolicy: IfNotPresent
        #   image: jannemattila/azure-powershell-job:1.0.4
        #   command: ["pwsh", "-Command", "{ Start-Sleep -Seconds 1000 }"]
          env:
            # - name: AZURE_CLIENT_ID
            #   value: "${client_id}"
            - name: SCRIPT_FILE
              value: /mnt/run.ps1
          volumeMounts:
            - name: configmap
              mountPath: /mnt
      volumes:
        - name: configmap
          configMap:
            name: network-app-configmap
            defaultMode: 0744
EOF

kubectl get pods -n network-app
kubectl get jobs -n network-app
kubectl delete job azure-powershell-job -n network-app

kubectl logs azure-powershell-job-ff66k -n network-app
kubectl exec --stdin --tty azure-powershell-job-px64b -n network-app -- /bin/sh

kubectl delete ns network-app

kind delete cluster --name azure-workload-identity
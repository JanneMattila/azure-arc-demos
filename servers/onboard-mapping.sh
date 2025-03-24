# Default values used if no mapping in CSV file
# Set these values to match your own environment
export tenantId="6d5a790e-8cd2-4ff2-8e1b-8ebcbd887e4a";
export subscriptionId="30fa2e75-859f-407a-9e18-f803e300b67f";
export resourceGroup="rg-arc-servers";
export tenantId="f9631ab9-69a0-4608-9ef7-dfe474720d2f";
export location="swedencentral";
export tags="Datacenter=DC1,City=Espoo,Country=FI,Environment=Production,Department=IT";

# Mount the NFS share
export nfsServer="your-nfs-server";
export nfsSharePath="/path/to/nfs/share";
export localMountPoint="/mnt/nfs";

export correlationId="f5d7868b-6f65-4aa2-9118-df1c9522e322";
export cloud="AzureCloud";

export mappingFile="onboard-mapping.csv";

# Create the mount point if it doesn't exist
sudo mkdir -p $localMountPoint

# Mount the NFS share
sudo mount -t nfs $nfsServer:$nfsSharePath $localMountPoint

# Check if mount was successful
if [ $? -ne 0 ]; then
    echo "Failed to mount NFS share. Exiting."
    exit 1
fi

# Update the path to your mapping file
export mappingFile="$localMountPoint/onboard-mapping.csv"

# Get hostname and convert to lowercase
export current_hostname=$(hostname | tr '[:upper:]' '[:lower:]')

skip_headers=1
while IFS=\; read -r col1 col2 col3 col4
do
    if ((skip_headers))
    then
        ((skip_headers--))
    else
        # Does the hostname match the first column?
        col1_lower=$(echo "$col1" | tr '[:upper:]' '[:lower:]')
        if [[ "$current_hostname" == "$col1_lower" ]]; then
            # Hostname matches the first column value, set the variables
            echo "Found matching hostname: $current_hostname and overriding variables:"
            # Display the values
            echo "resourceGroup: $col2"
            echo "subscriptionId: $col3"
            echo "tags: $col4"

            export resourceGroup="$col2"
            export subscriptionId="$col3"
            export tags="$col4"
            break
        fi
    fi
done < $mappingFile

# Print the values
echo "Final values for onboarding:"
echo "----------------------------"
echo "tenantId: $tenantId"
echo "subscriptionId: $subscriptionId"
echo "resourceGroup: $resourceGroup"
echo "location: $location"
echo "tags: $tags"

# Unmount the NFS share
sudo umount $localMountPoint

LINUX_INSTALL_SCRIPT="/tmp/install_linux_azcmagent.sh"

if [ -f "$LINUX_INSTALL_SCRIPT" ]; then rm -f "$LINUX_INSTALL_SCRIPT"; fi;

output=$(wget https://gbl.his.arc.azure.com/azcmagent-linux -O "$LINUX_INSTALL_SCRIPT" 2>&1);

if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"correlationId\":\"$correlationId\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;

echo "$output";
bash "$LINUX_INSTALL_SCRIPT";
sudo azcmagent connect --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --tags "$tags" --correlation-id "$correlationId";

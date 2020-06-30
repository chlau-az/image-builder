# Required variables:
# - AZURE_TENANT_ID - tenant ID
# - AZURE_CLIENT_ID - Service principal ID
# - AZURE_CLIENT_SECRET - Service principal secret
# - AZURE_SUBSCRIPTION_ID - Subscription ID used by the pipeline
# - KUBERNETES_VERSION - version of Kubernetes to build the image with, e.g. `1.16.2`

#Write configuration files
# KUBERNETES_RELEASE=$(echo ${KUBERNETES_VERSION} | cut -d "." -f -2)
# sed -i "s/.*kubernetes_series.*/  \"kubernetes_series\": \"v${KUBERNETES_RELEASE}\",/g" kubernetes.json
# sed -i "s/.*kubernetes_semver.*/  \"kubernetes_semver\": \"v${KUBERNETES_VERSION}\",/g" kubernetes.json
# if [[ "${KUBERNETES_VERSION:-}" == "1.16.11" || "${KUBERNETES_VERSION:-}" == "1.17.7" || "${KUBERNETES_VERSION:-}" == "1.18.4" ]]; then
# sed -i "s/.*kubernetes_rpm_version.*/  \"kubernetes_rpm_version\": \"${KUBERNETES_VERSION}-1\",/g" kubernetes.json
# sed -i "s/.*kubernetes_deb_version.*/  \"kubernetes_deb_version\": \"${KUBERNETES_VERSION}-01\",/g" kubernetes.json
# else
# sed -i "s/.*kubernetes_rpm_version.*/  \"kubernetes_rpm_version\": \"${KUBERNETES_VERSION}-0\",/g" kubernetes.json
# sed -i "s/.*kubernetes_deb_version.*/  \"kubernetes_deb_version\": \"${KUBERNETES_VERSION}-00\",/g" kubernetes.json
# fi
# cat kubernetes.json

#Building VHD
make build-azure-vhd-ubuntu-1804 |& tee packer/azure/packer.out

#Getting OS VHD URL
#directory: images/capi/packer/azure
#condition: eq(variables.CLEANUP, 'False')
RESOURCE_GROUP_NAME="$(cat packer/azure/packer.out | grep "resource group name:" | cut -d " " -f 4)"
STORAGE_ACCOUNT_NAME=$(cat packer/azure/packer.out | grep "storage name:" | cut -d " " -f 3)
OS_DISK_URI=$(cat packer/azure/packer.out | grep "OSDiskUri:" | cut -d " " -f 2)
echo ${OS_DISK_URI} | tee packer/azure/vhd-url.out
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}
ACCOUNT_KEY=$(az storage account keys list -g ${RESOURCE_GROUP_NAME} --subscription ${AZURE_SUBSCRIPTION_ID} --account-name ${STORAGE_ACCOUNT_NAME} --query '[0].value')
start_date=$(date +"%Y-%m-%dT00:00Z" -d "-1 day")
expiry_date=$(date +"%Y-%m-%dT00:00Z" -d "+1 year")
az storage container generate-sas --name system --permissions lr --account-name ${STORAGE_ACCOUNT_NAME} --account-key ${ACCOUNT_KEY} --start $start_date --expiry $expiry_date | tr -d '\"' | tee -a packer/azure/vhd-url.out

#cleanup - chown all files in work directory 
chown -R $USER:$USER .
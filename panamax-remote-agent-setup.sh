#!/bin/bash
SEP='|'
KEY_NAME="pmx_remote_agent"
WORK_DIR="/home/core/pmx_agent"
CERT_DIR="${WORK_DIR}/certs"
CONFIG_DIR="${WORK_DIR}/config"
CERT_IMAGE="centurylink/openssl:latest"

ADAPTER_IMAGE_NAME_FLEET="centurylink/panamax-fleet-adapter"
ADAPTER_IMAGE_NAME_KUBER="centurylink/panamax-kubernetes-adapter"
ADAPTER_CONTAINER_NAME="pmx_adapter"

AGENT_IMAGE_NAME="centurylink/panamax-remote-agent"
AGENT_CONTAINER_NAME="pmx_agent"

HOST_PORT=3001

docker rm -f ${AGENT_CONTAINER_NAME} > /dev/null 2>&1
docker rm -f ${ADAPTER_CONTAINER_NAME} > /dev/null 2>&1

mkdir -p ${CERT_DIR}
mkdir -p ${CONFIG_DIR}


function displayLogo {
    tput clear
    echo ""
    echo -e "\033[0;31;32m███████╗ ██████╗  █████████╗ ██████╗ \033[0m\033[31;37m ██████████╗ ██████╗  ██╗  ██╗\033[0m"
    echo -e "\033[0;31;32m██╔══██║  ╚═══██╗ ███╗  ███║  ╚═══██╗\033[0m\033[31;37m ██║ ██╔ ██║  ╚═══██╗ ╚██╗██╔╝\033[0m"
    echo -e "\033[0;31;32m██   ██║ ███████║ ███║  ███║ ███████║\033[0m\033[31;37m ██║╚██║ ██║ ███████║  ╚███╔╝ \033[0m"
    echo -e "\033[0;31;32m███████╝ ███████║ ███║  ███║ ███████║\033[0m\033[31;37m ██║╚██║ ██║ ███████║  ██╔██╗ \033[0m"
    echo -e "\033[0;31;32m██║      ███████║ ███║  ███║ ███████║\033[0m\033[31;37m ██║╚██║ ██║ ███████║ ██╔╝ ██╗\033[0m"
    echo -e "\033[0;31;32m╚═╝      ╚══════╝ ╚══╝  ╚══╝ ╚══════╝\033[0m\033[31;37m ╚═╝ ╚═╝ ╚═╝ ╚══════╝ ╚═╝  ╚═╝\033[0m"
    echo ""
    echo "CenturyLink Labs - http://www.centurylinklabs.com/"
}

displayLogo

common_name=""
while [[ "${common_name}" == "" ]]; do
  read -p "Enter the public hostname (dev.example.com) or IP Address (10.3.4.5) of the agent: " common_name
done

read -p "Enter the port you wish the agent to run on (${HOST_PORT}): " host_port
host_port=${HOST_PORT:host_port}

echo -e "\nSelect the ochestrator you want to use: "
select operation in "Kubernetes" "CoreOS Fleet"; do
case $operation in
    "Kubernetes") cluster_type=0; break;;
    "CoreOS Fleet") cluster_type=1; break;;
esac
done

adapter_name="Kubernetes"
if [[ ${cluster_type} == 1 ]]; then
    adapter_name="Fleet"
fi

echo -e "\n\n"
while [[ "${cluster_url}" == "" ]]; do
  read -p "Enter the API endpoint to access the ${adapter_name} cluster (e.g: https://10.187.241.100:8080/): " cluster_url
done

echo -e "\nGenerating SSL Key"
`docker run --rm  -e COMMON_NAME=${common_name} -e KEY_NAME=${KEY_NAME} -v ${CERT_DIR}:/certs ${CERT_IMAGE} > /dev/null 2>&1`&
PID=$!
while $(kill -n 0 $PID 2> /dev/null)
do
  echo -n '.'
  sleep 2
done
echo ""

url='${common_name}'
PUBLIC_CERT="$(<${CERT_DIR}/${KEY_NAME}.crt)"

if [[ ! -f ${CERT_DIR}/.env ]]; then
  PMX_AGENT_ID="`uuidgen`"
  PMX_AGENT_PASSWORD="`uuidgen | base64`"
  echo "PMX_AGENT_ID=\"${PMX_AGENT_ID}\"
  PMX_AGENT_PASSWORD=\"${PMX_AGENT_PASSWORD}\"" > .env
  sudo mv .env ${WORK_DIR}
else
  source ${WORK_DIR}/.env
fi

adapter_image_name=${ADAPTER_IMAGE_NAME_KUBER}
adapter_env_var_name="KUBERNETES_ENDPOINT"
if [[ ${cluster_type} == 1 ]]; then
    adapter_image_name=${ADAPTER_IMAGE_NAME_FLEET}
    adapter_env_var_name="FLEETCTL_ENDPOINT"
fi

echo -e "\nStarting Panamax remote agent and adapter"
docker run -d --name ${ADAPTER_CONTAINER_NAME} -e "${adapter_env_var_name}=${cluster_url}" -v ${CONFIG_DIR}:/usr/local/share/config --restart=always ${adapter_image_name}:latest
docker run -d --name ${AGENT_CONTAINER_NAME} --link ${ADAPTER_CONTAINER_NAME}:adapter -e REMOTE_AGENT_ID=${PMX_AGENT_ID} -e REMOTE_AGENT_API_KEY=${PMX_AGENT_PASSWORD}  --restart=always -v ${CERT_DIR}:/usr/local/share/certs -p ${host_port}:3000 ${AGENT_IMAGE_NAME}:latest

echo ""
echo "============================== START =============================="
echo "https://${common_name}:${host_port}${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT}" | base64
echo "============================== END =============================="
echo -e "\n\nCopy and paste the above to your local panamax client to connect to this remote agent."
echo -e "\n\n*** Add any additional configuration settings needed for the ${adapter_name} adapter to the following file: ${CONFIG_DIR}/.config"
echo -e "\nRemote Agent installation complete!\n\n"

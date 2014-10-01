#!/bin/bash
SEP='|'
KEY_NAME="pmx_remote_agent"
WORK_DIR="/home/core/pmx_agent"
CERT_DIR="${WORK_DIR}/certs"
CERT_IMAGE="centurylink/openssl:latest"
HOST_PORT=3001

ADAPTER_IMAGE_NAME="centurylink/panamax-fleet-adapter"
ADAPTER_CONTAINER_NAME="pmx_adapter"

AGENT_IMAGE_NAME="centurylink/panamax-remote-agent"
AGENT_CONTAINER_NAME="pmx_agent"

docker rm -f ${AGENT_CONTAINER_NAME} > /dev/null 2>&1
docker rm -f ${ADAPTER_CONTAINER_NAME} > /dev/null 2>&1

mkdir -p ${CERT_DIR}

common_name=""
while [[ "${common_name}" == "" ]]; do
  read -p "Please enter the public hostname (dev.example.com) or IP Address (10.3.4.5): " common_name
done

read -p "Please enter the port you wish the agent to run on (${HOST_PORT}): " host_port
host_port=${host_port:-$HOST_PORT}

docker run --rm  -e COMMON_NAME=${common_name} -e KEY_NAME=${KEY_NAME} -v ${CERT_DIR}:/certs ${CERT_IMAGE}

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


echo ""
echo ""
echo "Copy and paste the following to your local panamax instance to connect to this remote instance:"
echo "============================== START =============================="
echo "https://${common_name}:${host_port}${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT}" | base64
echo "============================== END =============================="

echo "Below are the conainer ids for the adapter and agent"
docker run -d --name ${ADAPTER_CONTAINER_NAME} -v /var/run/docker.sock:/run/docker.sock --expose 4567 ${ADAPTER_IMAGE_NAME}:latest
docker run -d --name ${AGENT_CONTAINER_NAME} --link ${ADAPTER_CONTAINER_NAME}:adapter -e REMOTE_AGENT_ID=${PMX_AGENT_ID} -e REMOTE_AGENT_API_KEY=${PMX_AGENT_PASSWORD}  -v ${CERT_DIR}:/usr/local/share/certs -p ${host_port}:3000 ${AGENT_IMAGE_NAME}:latest

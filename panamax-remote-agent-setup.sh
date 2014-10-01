#!/bin/bash
SEP='|'
KEY_NAME="pmx_remote_agent"
WORK_DIR="/home/core/pmx_agent"
CERT_DIR="${WORK_DIR}/certs"
CERT_IMAGE="centurylink/openssl:latest"
HOST_PORT=3001

mkdir -p ${CERT_DIR}

common_name=""
while [[ "${common_name}" == "" ]]; do
    read -p "Please enter CN (common name) for SSL Cert: " common_name
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
echo "Copy and paste the following to your panamax to connect to this remote instance:"
echo "============================== START =============================="
echo "https://${common_name}:${host_port}${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT}" | base64
echo "============================== END =============================="

adapter_dir="adapter"
adapter_name="centurylink/panamax-fleet-adapter"
adapter_container_name="pmx_adapter"

agent_dir="panamax-remote-agent"
agent_name="centurylink/panamax-remote-agent"
agent_container_name="pmx_agent"

docker run -d --name ${adapter_container_name} -v /var/run/docker.sock:/run/docker.sock --expose 4567 ${adapter_name}:latest
docker run -d --name ${agent_container_name} --link ${adapter_container_name}:adapter -e REMOTE_AGENT_ID=${PMX_AGENT_ID} -e REMOTE_AGENT_API_KEY=${PMX_AGENT_PASSWORD}  -v ${CERT_DIR}:/usr/local/share/certs -p ${host_port}:3000 ${agent_name}:latest


#1. Gen the Cert
#2. Start the containers (adapter & agent)
#3. Update adapter & agent images
#4. Restart adapter & agent
#5. Self update?

#!/bin/bash
SEP='|'
KEY_NAME="pmx_remote_agent"
CERT_DIR="/home/core/pmx_agent/certs"
CERT_IMAGE="panamax/pmx_cert_generator"

mkdir -p ${CERT_DIR}
common_name=""
while [[ "${common_name}" == "" ]]; do
    read -p "Please enter CN (common name) for SSL Cert: " common_name
done

docker run --rm  -e COMMON_NAME=${common_name} -e KEY_NAME=${KEY_NAME} -v ${CERT_DIR}:/certs ${CERT_IMAGE}

url='${common_name}'
PUBLIC_CERT="$(<${CERT_DIR}/${KEY_NAME}.crt)"

echo "${PUBLIC_CERT}"

if [[ ! -f ${CERT_DIR}/.env ]]; then
    PMX_AGENT_ID="`uuidgen`"
    PMX_AGENT_PASSWORD="`uuidgen | base64`"
    echo "export PMX_AGENT_ID=\"${PMX_AGENT_ID}\"
    export PMX_AGENT_PASSWORD=\"${PMX_AGENT_PASSWORD}\"" > .env
    sudo mv .env ${CERT_DIR}
else
    source ${CERT_DIR}/.env
fi


echo ""
echo ""
echo "Copy and paste the following to your panamax to connect to this remote instance:"
echo "============================== START =============================="
echo $common_name${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT} | base64
echo "============================== END =============================="

#
#rm -Rf panamax-remote-agent
#git clone https://github.com/CenturyLinkLabs/panamax-remote-agent.git
#cd panamax-remote-agent
#docker build -t panamax/panamax-remote-agent .
#
adapter_dir="adapter"
adapter_name="panamax/panamax-fleet-adapter"
adapter_container_name="pmx_adapter"
#rm -rf ${adapter_dir}
#git clone https://github.com/CenturyLinkLabs/fleet-adapter.git ${adapter_dir}
#cd ${adapter_dir} && docker build -t ${adapter_name} .

agent_dir="panamax-remote-agent"
agent_name="panamax/panamax-remote-agent"
agent_container_name="pmx_agent"
#rm -rf ${agent_dir}
#git clone https://github.com/CenturyLinkLabs/panamax-remote-agent.git ${agent_dir}
#cd ${agent_dir} && docker build -t ${agent_name} .

echo docker run -d --name ${adapter_container_name} -v /var/run/docker.sock:/run/docker.sock --expose 4567 ${adapter_name}:latest
echo docker run -d --name ${agent_container_name} --link ${adapter_container_name}:adapter -e REMOTE_AGENT_ID=${PMX_AGENT_ID} -e REMOTE_AGENT_API_KEY=${PMX_AGENT_PASSWORD}  -v ${CERT_DIR}:/usr/local/share -p 3001:3001 ${agent_name}:latest


#1. Gen the Cert
#2. Start the containers (adapter & agent)
#3. Update adapter & agent images
#4. Restart adapter & agent
#5. Self update?

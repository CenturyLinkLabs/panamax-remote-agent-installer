#!/bin/bash

SEP='|'
KEY_NAME="pmx_remote_agent"
WORK_DIR="$(pwd)"
AGENT_CONFIG="${WORK_DIR}/agent"
ADAPTER_CONFIG="${WORK_DIR}/adapter"
ENV="${WORK_DIR}/.env"
CERT_IMAGE="centurylink/openssl:latest"

ADAPTER_IMAGE_FLEET="centurylink/panamax-fleet-adapter:latest"
ADAPTER_IMAGE_KUBER="centurylink/panamax-kubernetes-adapter:latest"
ADAPTER_CONTAINER_NAME="pmx_adapter"

AGENT_IMAGE="centurylink/panamax-remote-agent:latest"
AGENT_CONTAINER_NAME="pmx_agent"

HOST_PORT=3001

echo_install="init:          First time installing Panamax remote agent! - Downloads and installs panamax remote agent."
echo_restart="restart:       Stops and Starts Panamax remote agent/adapter."
echo_reinstall="reinstall:     Deletes your current panamax remote agent/adapter and reinstalls latest version."
echo_update="update:        Updates to latest Panamax agent/adapter."
echo_checkUpdate="check:         Checks for available updates for Panamax agent/adapter."
echo_uninstall="delete:        Uninstalls Panamax remote agent/adapter."
echo_help="help:          Show this help"
echo_debug="debug:         Display your current Panamax settings."

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
    echo -e "CenturyLink Labs - http://www.centurylinklabs.com/\n"

}

function cmd_exists() {
    while [ -n "$1" ]
    do
        command -v "$1" >/dev/null 2>&1 || { echo >&2 " '$1' is required but not installed.  Aborting."; exit 1; }
        shift
    done
}

function uninstall {
    echo -e "\nDeleting panamax remote agent/adapter containers..."
    docker rm -f ${AGENT_CONTAINER_NAME} > /dev/null 2>&1
    docker rm -f ${ADAPTER_CONTAINER_NAME} > /dev/null 2>&1

    echo -e "\nDeleting panamax remote agent/adapter images..."
    docker rmi ${CERT_IMAGE}  > /dev/null 2>&1
    docker rmi "${PMX_ADAPTER_IMAGE_NAME}"  > /dev/null 2>&1
    docker rmi ${AGENT_IMAGE}  > /dev/null 2>&1
}

function downloadImage {
    $(docker pull "${1}" > /dev/null 2>&1)&
    PID=$!
    while $(kill -n 0 "${PID}" 2> /dev/null)
    do
      echo -n '.'
      sleep 2
    done
    echo ""
}

function setEnvVar {
    sed -i "/$1=/d" "$ENV"
    echo export $1=$2 >> "$ENV"
}

function setConfigVar {
    sed -i "/$1=/d" "${ADAPTER_CONFIG}/.config"
    echo export $1=$2 >> "${ADAPTER_CONFIG}/.config"
}

function installAdapter {
    if [[ $(docker ps -a| grep "${ADAPTER_CONTAINER_NAME}\|${AGENT_CONTAINER_NAME}") != "" ]]; then
        echo -e "\nYou already have remote agent/adapter installed. Please reinstall.\n\n"
        exit 1;
    fi

    echo -e "\nInstalling Panamax adapter:"

    mkdir -p ${ADAPTER_CONFIG}

    echo -e "\nSelect the ochestrator you want to use: "
    select operation in "Kubernetes" "CoreOS Fleet"; do
    case $operation in
        "Kubernetes") cluster_type=0; break;;
        "CoreOS Fleet") cluster_type=1; break;;
    esac
    done

    echo -e "\n\n"
    adapter_name="Fleet"
    if [[ ${cluster_type} == 0 ]]; then
        adapter_name="Kubernetes"
        adapter_image_name=${ADAPTER_IMAGE_KUBER}
        adapter_env_var_name="KUBERNETES_API_ENDPOINT"

        while [[ "${api_url}" == "" ]]; do
          read -p "Enter the API endpoint to access the ${adapter_name} cluster (e.g: https://10.187.241.100:8080/): " api_url
        done

        read -p "Enter username for ${adapter_name} API:" api_username
        stty -echo
        read -p "Enter password for ${adapter_name} API:" api_password; echo
        stty echo

        setConfigVar "${adapter_env_var_name}" "${api_url}"
        setConfigVar API_USERNAME "${api_username}"
        setConfigVar API_PASSWORD "${api_password}"
    else
        adapter_image_name=${ADAPTER_IMAGE_FLEET}
        adapter_env_var_name="FLEETCTL_ENDPOINT"

        while [[ "${api_url}" == "" ]]; do
          read -p "Enter the API endpoint to access the ${adapter_name} cluster (e.g: https://10.187.241.100:8080/): " api_url
        done

        setConfigVar "${adapter_env_var_name}" "${api_url}"
    fi

    setEnvVar "PMX_ADAPTER_IMAGE_NAME" \"${adapter_image_name}\"

    echo -e "\nStarting Panamax ${adapter_name} adapter:"
    downloadImage ${adapter_image_name}
    docker run -d --name ${ADAPTER_CONTAINER_NAME} -e ${adapter_env_var_name}="${api_url}" -e API_PASSWORD=${api_password} -e API_USERNAME=${api_username}  -v ${ADAPTER_CONFIG}:/usr/local/share/config --restart=always ${adapter_image_name}
}


function installAgent {
    echo -e "\nInstalling Panamax remote agent:"

    mkdir -p ${AGENT_CONFIG}

    while [[ "${common_name}" == "" ]]; do
      read -p "Enter the public hostname (dev.example.com) or IP Address (10.3.4.5) of the agent: " common_name
    done

    read -p "Enter the port to run the agent on (${HOST_PORT}): " -i ${HOST_PORT} host_port

    echo -e "\nGenerating SSL Key"
    downloadImage ${CERT_IMAGE}
    docker run --rm  -e COMMON_NAME="${common_name}" -e KEY_NAME="${KEY_NAME}" -v "${AGENT_CONFIG}":/certs "${CERT_IMAGE}" > /dev/null 2>&1

    PUBLIC_CERT="$(<${AGENT_CONFIG}/${KEY_NAME}.crt)"
    PMX_AGENT_ID="$(uuidgen)"
    PMX_AGENT_PASSWORD="$(uuidgen | base64)"
    setEnvVar PMX_AGENT_ID \""${PMX_AGENT_ID}"\"
    setEnvVar PMX_AGENT_PASSWORD \""${PMX_AGENT_PASSWORD}"\"

    echo -e "\nStarting Panamax remote agent:"
    downloadImage ${AGENT_IMAGE}
    docker run -d --name ${AGENT_CONTAINER_NAME} --link ${ADAPTER_CONTAINER_NAME}:adapter -e REMOTE_AGENT_ID="${PMX_AGENT_ID}" -e REMOTE_AGENT_API_KEY="${PMX_AGENT_PASSWORD}"  --restart=always -v ${AGENT_CONFIG}:/usr/local/share/certs -p ${host_port}:3000 ${AGENT_IMAGE}

    echo ""
    echo "============================== START =============================="
    echo "https://${common_name}:${host_port}${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT}" | base64
    echo "============================== END =============================="
    echo -e "\n\nCopy and paste the above (Not including start/end tags) to your local panamax client to connect to this remote agent."
    #echo -e "\n\n*** Add any additional configuration settings needed for the ${adapter_name} adapter to the following file: ${ADAPTER_CONFIG}/.config"
    echo -e "\nRemote Agent/Adapter installation complete!\n\n"
}

function install {
    installAdapter
    installAgent
}

function restart {
    echo "Restarting Panamax remote agent/adapter containers..."
    docker restart ${ADAPTER_CONTAINER_NAME}
    docker restart ${AGENT_CONTAINER_NAME}
}

function update {
    echo "Updating Panamax remote agent/adapter images..."
    downloadImage "${PMX_ADAPTER_IMAGE_NAME}"
    downloadImage "${AGENT_IMAGE}"

    restart
}

function reinstall {
    uninstall
    install
}

function readParams {
    for i in "$@"
    do
    case $(echo "$i" | tr '[:upper:]' '[:lower:]') in
        install|init)
        operation=install
        ;;
        uninstall|delete)
        operation=uninstall
        ;;
        restart)
        operation=restart
        ;;
        update)
        operation=update
        ;;
        check)
        operation=check
        ;;
        info|--version|-v)
        operation=info
        ;;
        reinstall)
        operation=reinstall
        ;;
        debug)
        operation=debug
        ;;
        --help|-h|help)
        showLongHelp;
        exit 1;
        ;;
        *)
        showLongHelp;
        exit 1;
        ;;
    esac
    done
}

function main {
    displayLogo

    if [ $UID -ne 0 ] ; then
        echo -e "\nPlease execute the installer as root.\n\n"
        exit 1;
    fi

    cmd_exists curl uuidgen base64 docker

    readParams "$@"

    if [[ ! -f "${ENV}" ]]; then
        source "${ENV}"
    fi

    if [[ $# -gt 0 ]]; then
        case $operation in
            install)   install "$@" || { showHelp; exit 1; } ;;
            reinstall)   reinstall "$@" || { showHelp; exit 1; } ;;
            restart) restart;;
            check) echo "Not Implemented";;
            info) echo "Not Implemented";;
            update) update;;
            uninstall) uninstall;;
            debug) echo "Not Implemented";;
        esac
    else
        PS3="Please select one of the preceding options: "
        select operation in "$echo_install" "$echo_restart" "$echo_reinstall" "$echo_checkUpdate" "$echo_update" "$echo_uninstall" "$echo_help" "$echo_debug" "quit"; do
        case $operation in
            "$echo_install") install; break;;
            "$echo_reinstall") reinstall; break;;
            "$echo_restart") restart; break;;
            "$echo_checkUpdate") echo "Not Implemented"; break;;
            "$echo_info") echo "Not Implemented"; break;;
            "$echo_update")  echo "Not Implemented"; break;;
            "$echo_uninstall") uninstall; break;;
            "$echo_help") echo "Not Implemented"; break;;
            "$echo_debug")  echo "Not Implemented"; break;;
            quit) exit 0;;
        esac
        done
    fi
}

main "$@";

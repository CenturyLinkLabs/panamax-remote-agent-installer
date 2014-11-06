#!/bin/bash

SEP='|'
KEY_NAME="pmx_remote_agent"
WORK_DIR="${HOME}/pmx-agent"
ENV="${WORK_DIR}/.env"
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
echo_info="info:          Displays version of your panamax agent/adapter."
echo_update="update:        Updates to latest Panamax agent/adapter."
echo_checkUpdate="check:         Checks for available updates for Panamax agent/adapter."
echo_uninstall="delete:        Uninstalls Panamax remote agent/adapter."
echo_help="help:          Show this help"
echo_debug="debug:         Display your current Panamax settings."

function display_logo {
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
        if [[ "$1" == "docker" ]]; then
            docker -v | grep -w '1\.[2-9]'  >/dev/null 2>&1 || { echo "docker 1.2 or later is required but not installed. Aborting."; exit 1; }
        else
            command -v "$1" >/dev/null 2>&1 || { echo >&2 " '$1' is required but not installed.  Aborting."; exit 1; }
        fi
        shift
    done
}

function validate_install {
    if [[ $(docker ps -a| grep "${ADAPTER_CONTAINER_NAME}\|${AGENT_CONTAINER_NAME}") == "" ]]; then
        echo -e "\nYou don't have remote agent/adapter installed. Please execute init before using other commands.\n\n"
        exit 1;
    fi
}

function uninstall {
    validate_install
    echo -e "\nDeleting panamax remote agent/adapter containers..."
    docker rm -f ${AGENT_CONTAINER_NAME} ${ADAPTER_CONTAINER_NAME}> /dev/null 2>&1

    echo -e "\nDeleting panamax remote agent/adapter images..."
    #docker rmi "${CERT_IMAGE}" "${PMX_ADAPTER_IMAGE_NAME}" "${AGENT_IMAGE}" > /dev/null 2>&1
}

function download_image {
    echo -e "\nDownloading docker image ${1}"
    $(docker pull "${1}" > /dev/null 2>&1)&
    PID=$!
    while $(kill -n 0 "${PID}" 2> /dev/null)
    do
      echo -n '.'
      sleep 2
    done
    echo ""
}

function set_adapter_config {
    sed -i "/$1=/d" "${ADAPTER_CONFIG}/.config"
    echo $1=$2 >> "${ADAPTER_CONFIG}/.config"
}

function set_agent_config {
    sed -i "/$1=/d" "${AGENT_CONFIG}/.config"
    echo $1=$2 >> "${AGENT_CONFIG}/.config"
}

function install_adapter {
    if [[ $(docker ps -a| grep "${ADAPTER_CONTAINER_NAME}\|${AGENT_CONTAINER_NAME}") != "" ]]; then
        echo -e "\nYou already have remote agent/adapter installed. Please reinstall.\n\n"
        exit 1;
    fi

    echo -e "\nInstalling Panamax adapter:"

    mkdir -p ${ADAPTER_CONFIG}

    echo -e "\nSelect the ochestrator you want to use: \n"
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

        while [[ "${api_url}" == "" ]]; do
          read -p "Enter the API endpoint to access the ${adapter_name} cluster (e.g: https://10.187.241.100:8080/): " api_url
        done

        read -p "Enter username for ${adapter_name} API:" api_username
        stty -echo
        read -p "Enter password for ${adapter_name} API:" api_password; echo
        stty echo

        set_adapter_config PMX_ADAPTER_API_URL "${api_url}"
        set_adapter_config PMX_ADAPTER_API_USERNAME "${api_username}"
        set_adapter_config PMX_ADAPTER_API_PASSWORD "${api_password}"
        adapter_env="-e KUBERNETES_MASTER=${api_url} -e KUBERNETES_USERNAME=${api_username} -e KUBERNETES_PASSWORD=${api_password}"
    else
        adapter_image_name=${ADAPTER_IMAGE_FLEET}

        while [[ "${api_url}" == "" ]]; do
          read -p "Enter the API endpoint to access the ${adapter_name} cluster (e.g: https://10.187.241.100:4001/): " api_url
        done

        adapter_env="-e FLEETCTL_ENDPOINT=${api_url}"
    fi

    set_adapter_config "PMX_ADAPTER_IMAGE_NAME" \"${adapter_image_name}\"

    echo -e "\nStarting Panamax ${adapter_name} adapter:"
    download_image ${adapter_image_name}
    docker run -d --name ${ADAPTER_CONTAINER_NAME} ${adapter_env} --restart=always ${adapter_image_name}
}

function install_agent {
    echo -e "\nInstalling Panamax remote agent:"

    mkdir -p ${AGENT_CONFIG}

    while [[ "${common_name}" == "" ]]; do
      read -p "Enter the public hostname (dev.example.com) or IP Address (10.3.4.5) of the agent: " common_name
    done

    read -p "Enter the port to run the agent on (${HOST_PORT}): " host_port
    host_port=${host_port:-$HOST_PORT}

    echo -e "\nGenerating SSL Key"
    download_image ${CERT_IMAGE}
    docker run --rm  -e COMMON_NAME="${common_name}" -e KEY_NAME="${KEY_NAME}" -v "${AGENT_CONFIG}":/certs "${CERT_IMAGE}" > /dev/null 2>&1

    PUBLIC_CERT="$(<${AGENT_CONFIG}/${KEY_NAME}.crt)"
    set_agent_config PMX_AGENT_COMMON_NAME \""${common_name}"\"
    set_agent_config PMX_AGENT_HOST_PORT \""${host_port}"\"
    set_agent_config PMX_AGENT_AGENT_ID \""$(uuidgen)"\"
    set_agent_config PMX_AGENT_AGENT_PASSWORD \""$(uuidgen | base64)"\"

    echo -e "\nStarting Panamax remote agent:"
    download_image ${AGENT_IMAGE}
    pmx_agent_run_command="docker run -d --name ${AGENT_CONTAINER_NAME} --link ${ADAPTER_CONTAINER_NAME}:adapter -e REMOTE_AGENT_ID=$agent_id -e REMOTE_AGENT_API_KEY=$agent_password  --restart=always -v ${AGENT_CONFIG}:/usr/local/share/certs -v /usr/src/app/db -p ${host_port}:3000 ${AGENT_IMAGE}"
    set_env_var PMX_AGENT_RUN_COMMAND \""$pmx_agent_run_command"\"
    $pmx_agent_run_command

    echo "https://${common_name}:${host_port}${SEP}${PMX_AGENT_ID}${SEP}${PMX_AGENT_PASSWORD}${SEP}${PUBLIC_CERT}" | base64 > ${AGENT_CONFIG}/panamax_agent_key
    print_agent_key
    echo -e "\nRemote Agent/Adapter installation complete!\n\n"
}

function install {
    echo -e "\nInstalling panamax remote agent/adapter..."
    install_adapter
    install_agent
    set_env_var PMX_SETUP_VERSION \"$(<"$WORK_DIR"\.version)\"
}

function stop {
    docker rm -f $AGENT_CONTAINER_NAME $ADAPTER_CONTAINER_NAME
}

function start {
    $PMX_ADAPTER_RUN_COMMAND
    $PMX_AGENT_RUN_COMMAND
}

function restart {
    echo -e "\nRestarting panamax remote agent/adapter..."
    validate_install
    docker restart ${ADAPTER_CONTAINER_NAME} ${AGENT_CONTAINER_NAME}
}

function update {
    echo -e "\nUpdating panamax remote agent/adapter..."
    validate_install
    download_image "${PMX_ADAPTER_IMAGE_NAME}" "${AGENT_IMAGE}"
    restart
}

function reinstall {
    echo -e "\nReinstalling panamax remote agent/adapter..."
    validate_install
    uninstall
    install
}

function print_agent_key {
    echo -e "\n============================== START =============================="
    cat ${AGENT_CONFIG}/panamax_agent_key
    echo "============================== END =============================="
    echo -e "\n\nCopy and paste the above (Not including start/end tags) to your local panamax client to connect to this remote agent.\n"
}

function debug {
    print_agent_key
}

function show_help {
    echo -e "\n$echo_install\n$echo_restart\n$echo_reinstall\n$echo_info\n$echo_checkUpdate\n$echo_update\n$echo_uninstall\n$echo_help\n"
}

function read_params {
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
        show_help;
        exit 1;
        ;;
        *)
        show_help;
        exit 1;
        ;;
    esac
    done
}

function main {
    display_logo
    [[ $UID -eq 0 ]] || { echo -e "\nPlease execute the installer as root.\n\n"; exit 1; }
    cmd_exists curl uuidgen base64 docker sort
    touch "$ENV"
    source "$ENV"
    read_params "$@"

    mkdir -p ${ADAPTER_CONFIG}
    mkdir -p ${AGENT_CONFIG}
    touch "${ENV}"
    touch "${ADAPTER_CONFIG}/.config"
    touch "${AGENT_CONFIG}/.config"

    if [[ $# -gt 0 ]]; then
        case $operation in
            install)   install "$@" || { show_help; exit 1; } ;;
            reinstall)   reinstall "$@" || { show_help; exit 1; } ;;
            restart) restart;;
            check) echo "Not Implemented.";;
            info) echo "Not Implemented.";;
            update) update;;
            uninstall) uninstall;;
            help) show_help;;
            debug) debug;;
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
            "$echo_update")  update; break;;
            "$echo_uninstall") uninstall; break;;
            "$echo_help") show_help; break;;
            "$echo_debug")  debug; break;;
            quit) exit 0; break;;
        esac
        done
    fi
}

main "$@";

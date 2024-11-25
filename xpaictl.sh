#!/bin/bash

# Get the current path
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")

. ${script_dir}/scripts/utils.sh
banner 
check_root
checkCommand

MASTER_NODES=()
NODE_NODES=()
CONFIG_FILE=""


# Parameter Parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --masters)
            IFS=',' read -r -a MASTER_NODES <<< "$2"
            shift 2
            ;;
        --nodes)
            IFS=',' read -r -a NODE_NODES <<< "$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
done

# Check if the required parameters are provided
if [ ${#MASTER_NODES[@]} -eq 0 ]; then
    echo "--master argument is required."
    usage
fi
if [ -z "$CONFIG_FILE" ]; then
    echo "--config argument is required."
    usage
fi
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE does not exist."
    exit 1
fi

for master in "${MASTER_NODES[@]}"; do
    if ! is_valid_ip "$master"; then
        log ERROR validate " Invalid IP address format for master node: $master"
        exit 1
    fi
done

# Parse the configuration file and convert the content into global environment variables
parse_config "$CONFIG_FILE"
checkenvs

masters=$(IFS=','; echo "${MASTER_NODES[*]}")
workers=""
if [ ${#NODE_NODES[@]} -gt 0 ]; then
    workers=$(IFS=','; echo "${NODE_NODES[*]}")
fi


export masters
export workers

log INFO nodes "Master Nodes: $masters"
if [ -n "$workers" ]; then
    log INFO nodes "Worker Nodes: $workers"
else
    log INFO nodes "No worker nodes specified."
fi

check_ssh_status
. ${script_dir}/main.sh
main 
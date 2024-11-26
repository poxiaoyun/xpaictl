function log() {
    local level=$1       # log level(INFO, error, debug)
    local module=$2      # modules 
    local message=$3     # messages
    
    # timestamp
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # ANSI 
    local GREEN="\033[0;32m"  
    local RED="\033[0;31m"    
    local YELLOW="\033[0;33m" 
    local RESET="\033[0m"     

    case "$level" in
        INFO)
            local color=$GREEN
            ;;
        ERROR)
            local color=$RED
            ;;
        DEBUG)
            local color=$YELLOW
            ;;
        *)
            echo -e "${RED}Invalid log level: $level${RESET}"
            return 1
            ;;
    esac

    echo -e "${color}${timestamp} ${level} [${module}]-[$(pwd)]${RESET} ${message}"
}

# Display help INFOrmation
function usage() {
    echo ""
    echo "Usage: $0 --config xpai.yaml --masters <master_ip1,master_ip2,...> --nodes <node_ip1,node_ip2,...>"
    echo ""
    echo "Examples:"
    echo ""
    echo "create a HA cluster to your baremetal server, appoint the iplist:"
    echo "         xpaictl.sh --config xpai.yaml --masters 192.168.0.1,192.168.0.2,192.168.0.3 --nodes 192.168.0.4,192.168.0.5,192.168.0.6"
    echo ""
    echo "create a single master cluster to your baremetal server, appoint the iplist:"
    echo "         xpaictl.sh --config xpai.yaml --masters 192.168.0.1 --nodes 192.168.0.2,192.168.0.3,192.168.0.4"
    echo ""
    exit 1
}

# Parse the configuration file and convert the content to environment variables
function parse_config() {
    local config_file="$1"
    local output_env_file="artifacts/env"
    local product="Environment"

    if [[ ! -f "$config_file" ]]; then
        log ERROR $product "Configuration file $config_file does not exist!"
        return 1
    fi

    > "$output_env_file" || { log ERROR $product "Failed to create or clear $output_env_file"; return 1; }

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comment lines and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Match key-value pairs (key: value format)
        if [[ "$line" =~ ^([^:]+):[[:space:]]*(.+)$ ]]; then
            key=$(echo "${BASH_REMATCH[1]}" | xargs)
            value=$(echo "${BASH_REMATCH[2]}" | xargs)

            # Export as an environment variable
            export "$key=$value"
            log DEBUG $product "Setting environment variable: $key=$value"
            echo "$key=$value" >> "$output_env_file"
        fi
    done < "$config_file"
}

function parse_config_nolog() {
    local config_file="$1"
    local output_env_file="artifacts/env"
    local product="Environment"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    > "$output_env_file" || { return 1; }

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comment lines and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Match key-value pairs (key: value format)
        if [[ "$line" =~ ^([^:]+):[[:space:]]*(.+)$ ]]; then
            key=$(echo "${BASH_REMATCH[1]}" | xargs)
            value=$(echo "${BASH_REMATCH[2]}" | xargs)

            # Export as an environment variable
            export "$key=$value"
            echo "$key=$value" >> "$output_env_file"
        fi
    done < "$config_file"
}

# IP address verification function to check whether it conforms to IPv4 format
function is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        for octet in $(echo $ip | tr "." " "); do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

function check_root() {
    # Check if the current effective user ID is 0 (root user's ID)
    if [ "$EUID" -ne 0 ]; then
        log error check "Error: This script must be run as root."
        log error check "Please run it with sudo or as the root user."
        exit 1
    fi
}

# Verify whether the environment variables sshPassword and sshPort are valid.
function validate_ssh_env() {
    local product="utils"
    if ! [[ "$sshPort" =~ ^[0-9]+$ ]]; then
        log INFO $product "Error: SSH port must be a valid number."
        exit 1
    fi

    if ((sshPort < 1 || sshPort > 65535)); then
        log INFO $product "Error: SSH port must be between 1 and 65535."
        exit 1
    fi
}


function check_ssh_status() {

    IFS=',' read -r -a masters <<< "$masters"
    IFS=',' read -r -a workers <<< "$workers"

    local all_hosts=("${masters[@]}" "${workers[@]}")
    local product=utils

    for host in "${all_hosts[@]}"; do
        if is_valid_ip ${host}; then
            log INFO $product "Checking SSH access for $host..."
           (timeout 5 /bin/bash -c "3<>/dev/tcp/${host}/${sshPort:-22}") >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                log INFO $product "Host $host:${sshPort:-22} Connected ok"
            else
                log ERROR $product "Failed to connect ${host}:${sshPort:-22}, please check your host is alive."
                exit 1
            fi
        else
            log ERROR $product "${host} is not a valid ip."
        fi
    done
    log INFO $product "All machines are accessible via SSH as root!"
}

function wait_until_running() {
    local type=$1         
    local name=$2         
    local namespace=$3    
    local timeout=${4:-300} 
    local product="utils"

    log DEBUG $product "Waiting for $type '$name' in namespace '$namespace' to be running..."

    for ((i = 0; i < timeout; i+=10)); do
        if [ "$type" == "deployment" ]; then
            status=$(kubectl get deployment $name -n $namespace -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
        elif [ "$type" == "statefulset" ]; then
            status=$(kubectl get statefulset $name -n $namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        else
            log ERROR $product "Error: Unsupported resource type '$type'. Use 'deployment' or 'statefulset'. Exiting."
            exit 1
        fi

        if [[ "$status" -ge 1 ]]; then
            log INFO $product "$type '$name' is running."
            return
        fi

        log DEBUG $product "Still waiting for $type '$name' to be running... retrying in 10 seconds."
        sleep 10
    done
    
    log ERROR $product "Timeout reached waiting for $type '$name' to be running. Exiting."
    exit 1
}

function checkCommand(){
    local product="utils"
    if ! command -v envsubst >/dev/null 2>&1; then
        log debug $product "The 'envsubst' command is not found. Please install it before proceeding."
        log debug $product "Installation instructions:"
        log debug $product "For Debian/Ubuntu: sudo apt-get install gettext"
        log debug $product "For CentOS/RHEL: sudo yum install gettext"
        log debug $product "For Fedora: sudo dnf install gettext"
        log debug $product "For Arch: sudo pacman -S gettext"
        exit 1
    fi
}

function checkenvs(){
    local product="environment"

    if [[ "${installMinio}" != "true" && "${installMinio}" != "false" ]]; then
        log ERROR $product "Enviroment 'installMinio=$minioArchitecture', must be 'true' or 'false'."
        exit 1
    fi
    
    if [[ "$minioArchitecture" != "standalone" && "$minioArchitecture" != "distributed" ]]; then
        log ERROR $product "Enviroment 'minioArchitecture=$minioArchitecture', must be 'standalone' or 'distributed'."
        exit 1
    fi

    if [[ "$installNvidiaDriver" != "true" &&  "$installNvidiaDriver" != "false" ]]; then
        log ERROR $product "Enviroment 'installNvidiaDriver=$installNvidiaDriver', must be 'true' or 'false'."
        exit 1
    fi

    if [[ "$enableVgpu" != "true" && "$enableVgpu" != "false" ]]; then
        log ERROR  $product "Enviroment 'enableVgpu=$enableVgpu' must be 'true' or 'true'."
        exit 1
    fi

    # Get the value of the baseHost environment variable
    local value="$baseHost"

    # Check if the baseHost environment variable is set
    if [[ -z "$value" ]]; then
        log error $product "Error: 'baseHost' environment variable is not set or is empty."
        exit 1
    fi

    # Regular expression for validating HTTP resource format
    # This ensures the value is in the format: domain or subdomain, with optional port
    local regex="^([a-zA-Z0-9._-]+\.[a-zA-Z]{2,})(:[0-9]{1,5})?$"

    # Validate the value
    if [[ ! "$value" =~ $regex ]]; then
        log error $product "Error: environment baseHost='$baseHost' is NOT a valid HTTP resource format."
        exit 1
    fi

    validate_ssh_env

}

function get_node_count() {
    local product="utils"
    if ! command -v kubectl >/dev/null 2>&1; then
        log error $product "The 'kubectl' command is not found. Please check the [module][kubernetes] runs well."
        exit 1
    fi

    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

    if [ $? -ne 0 ]; then
        log error $product "Error: Failed to retrieve nodes. Please ensure you have access to a Kubernetes cluster."
        return 1
    fi

    if ! [[ "$node_count" =~ ^[0-9]+$ ]]; then
        elog error $product "Error: Invalid node count retrieved: '$node_count'."
        return 1
    fi

    if (( node_count % 2 == 0 )); then
        minioNums=$node_count
    else
        minioNums=$((node_count - 1))
    fi

    if [[ -n "$minioReplicas" ]] && [[ "$minioReplicas" =~ ^[0-9]+$ ]]; then
        minioNums=$minioReplicas
        log debug $product "Environment variable 'minioReplicas' is set. Using its value: $minioReplicas"
    else
        log INFO $product "The largest even number of nodes in the Kubernetes cluster is: ${minioNums},set to 'minioReplicas'"
    fi

    export minioNums
    return 0
}

wait_for_nodes_ready() {
    local product="utils"
    log INFO $product "Waiting for all Kubernetes nodes to be in 'Ready' state..."
    while true; do
        not_ready_count=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {count++} END {print count+0}')
        if [[ "$not_ready_count" -eq 0 ]]; then
            log INFO $product "All nodes are Ready!"
            break
        fi
        not_ready_nodes=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}')

        log DEBUG $product "Currently $not_ready_count node(s) are not Ready: $not_ready_nodes"
        log DEBUG $product "Retrying in 5 seconds..."

        sleep 10
    done
}

function convert_image_to_tar() {
    local input_image="$1"
    local name_with_tag=$(echo "$input_image" | awk -F/ '{print $NF}')
    local name=$(echo "$name_with_tag" | awk -F: '{print $1}')
    local version=$(echo "$name_with_tag" | awk -F: '{print $2}')
    local output_file="${name}-${version}.tar"
    echo "$output_file"
}

function detect_package_manager() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_id=$(echo "$ID" | tr '[:upper:]' '[:lower:]')

        case $os_id in
            ubuntu|debian|linuxmint|pop|kali|raspbian)
                echo "apt" 
                ;;
            centos|rhel|rocky|almalinux|amazon)
                if command -v dnf &>/dev/null; then
                    echo "dnf" 
                else
                    echo "yum" 
                fi
                ;;
            fedora)
                echo "dnf" 
                ;;
            arch|manjaro|artix|endeavouros|garuda)
                echo "pacman" 
                ;;
            opensuse|suse)
                echo "zypper" 
                ;;
            alpine)
                echo "apk" 
                ;;
            gentoo)
                echo "emerge" 
                ;;
            void)
                echo "xbps-install" 
                ;;
            *)
                echo "unknown" 
                ;;
        esac

    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        os_id=$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')

        case $os_id in
            ubuntu|debian)
                echo "apt"
                ;;
            centos|rhel)
                echo "yum"
                ;;
            *)
                echo "unknown"
                ;;
        esac

    elif [[ -f /etc/issue ]]; then
        os_info=$(cat /etc/issue | head -n 1 | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

        case $os_info in
            ubuntu|debian)
                echo "apt"
                ;;
            centos|redhat)
                echo "yum"
                ;;
            arch)
                echo "pacman"
                ;;
            alpine)
                echo "apk"
                ;;
            suse|opensuse)
                echo "zypper"
                ;;
            *)
                echo "unknown"
                ;;
        esac

    else
        echo "unknown" 
    fi
}

function namespace_exists() {
    local namespace=$1
    if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
        return 0  
    else
        return 1  
    fi
}

function banner(){
    echo '                                  _____                    _____                    _____          ';
    echo '        ______                   /\    \                  /\    \                  /\    \         ';
    echo '       |::|   |                 /::\    \                /::\    \                /::\    \        ';
    echo '       |::|   |                /::::\    \              /::::\    \               \:::\    \       ';
    echo '       |::|   |               /::::::\    \            /::::::\    \               \:::\    \      ';
    echo '       |::|   |              /:::/\:::\    \          /:::/\:::\    \               \:::\    \     ';
    echo '       |::|   |             /:::/__\:::\    \        /:::/__\:::\    \               \:::\    \    ';
    echo '       |::|   |            /::::\   \:::\    \      /::::\   \:::\    \              /::::\    \   ';
    echo '       |::|   |           /::::::\   \:::\    \    /::::::\   \:::\    \    ____    /::::::\    \  ';
    echo ' ______|::|___|___ ____  /:::/\:::\   \:::\____\  /:::/\:::\   \:::\    \  /\   \  /:::/\:::\    \ ';
    echo '|:::::::::::::::::|    |/:::/  \:::\   \:::|    |/:::/  \:::\   \:::\____\/::\   \/:::/  \:::\____\';
    echo '|:::::::::::::::::|____|\::/    \:::\  /:::|____|\::/    \:::\  /:::/    /\:::\  /:::/    \::/    /';
    echo ' ~~~~~~|::|~~~|~~~       \/_____/\:::\/:::/    /  \/____/ \:::\/:::/    /  \:::\/:::/    / \/____/ ';
    echo '       |::|   |                   \::::::/    /            \::::::/    /    \::::::/    /          ';
    echo '       |::|   |                    \::::/    /              \::::/    /      \::::/____/           ';
    echo '       |::|   |                     \::/____/               /:::/    /        \:::\    \           ';
    echo '       |::|   |                      ~~                    /:::/    /          \:::\    \          ';
    echo '       |::|   |                                           /:::/    /            \:::\    \         ';
    echo '       |::|   |                                          /:::/    /              \:::\____\        ';
    echo '       |::|___|                                          \::/    /                \::/    /        ';
    echo '        ~~                                                \/____/                  \/____/         ';
    echo '                                                                                                   ';
    echo '###########################################################################################'
    echo '#                                                                                         #'
    echo '#                            Script by: maqing@xiaoshiai.cn                               #'
    echo '#                           © 2024 Chengdu PoXiaoshi Technology Co. Ltd                   #'
    echo '#                                                                                         #'
    echo '#           This script is proprietary and confidential. Unauthorized copying,            #'
    echo '#           distribution, or use of this script is strictly prohibited.                   #'
    echo '#                                                                                         #'
    echo '###########################################################################################'
    sleep 2
}

function show_access_info() {

    local LIGHT_BLUE='\033[1;36m'
    local RED='\033[1;31m'
    local RED_END='\033[0m'
    local NORMAL='\033[0m' 

    echo ""
    echo ""
    echo -e "  🎉 ${LIGHT_BLUE}Congratulations! XPAI has been successfully deployed! 🎉${NORMAL}"
    echo -e ""
    echo -e "  📦 Version: ${LIGHT_BLUE}${mainVersion}-${xpaiVersion}${NORMAL}"
    echo -e "  🌐 Access Address: ${LIGHT_BLUE}http://console.${baseHost}${NORMAL}"
    echo -e "  👤 Username: ${LIGHT_BLUE}admin${NORMAL}"
    echo -e "  🔒 Password: ${LIGHT_BLUE}demo!@#admin${NORMAL}"
    echo -e""
    echo -e "  🔑 License: ${LIGHT_BLUE}${license}${NORMAL} ${RED}(Inactive)${RED_END}"
    echo -e "  📞 Contact: ${LIGHT_BLUE} support@xiaoshiai.cn${NORMAL}"
    echo -e ""
    echo -e ""

}

function get_gems_token() {
  local host=$1
  local response=$(curl "http://${master}:30000/api/v1/login" \
    -H "Host: ${host}" \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json;charset=UTF-8' \
    --data-raw '{"username":"admin","password":"demo!@#admin","source":"account"}' \
    --insecure -s)
  local token=$(echo $response | grep -o '"token":"[^"]*' | sed 's/"token":"//')
  echo $token
}

function get_gems_license() {
  local host=$1
  local token=$2
  local response=$(curl "http://${master}:30000/api/v1/license" \
    -H "Host: ${host}" \
    -H "Authorization: Bearer $token" \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'X-NoProcess: true' \
    --insecure -s)
  echo $(echo $response | grep -o '"cluster":"[^"]*' | sed 's/"cluster":"//')
}


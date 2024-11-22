function installNvidiaOperator() {
    local timestamp
    local product="nvida"
    local manifestsDir="${script_dir}/manifests/nvida"


    if [ "$installNvidiaDriver" == "true" ]; then
        template=${manifestsDir}/gpu-operator.yaml
    elif [ "$installNvidiaDriver" == "false" ]; then
        template=${manifestsDir}/gpu-operator.nodriver.yaml
    else
        log ERROR $product "Invalid enviroment: installNvidiaDriver "
        exit 1
    fi


    if ! command -v kubectl >/dev/null 2>&1; then
        log ERROR $product "The 'kubectl' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    # Log start of installation
    log INFO $product "Trying to install nvidia operator."

    if [ -e "${template}" ]; then
        if  kubectl apply -f --force ${template} > /dev/null 2>&1; then
            log INFO $product "Manifest ${template} is applied"
        else
            log ERROR $product "Failed to apply ${template}."
        fi
    else
        log ERROR $product "Can't find manifest ${template}."
        exit 1
    fi
}
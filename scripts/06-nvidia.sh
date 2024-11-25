function installNvidiaOperator() {
    local product="nvidia"
    local manifestsDir="${script_dir}/manifests/nvidia"
    local manifest


    if [ "$installNvidiaDriver" == "true" ]; then
        manifest=${manifestsDir}/gpu-operator.yaml
    elif [ "$installNvidiaDriver" == "false" ]; then
        manifest=${manifestsDir}/gpu-operator.nodriver.yaml
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

    if [ -e "${manifest}" ]; then
        if  kubectl apply --force -f ${manifest} > /dev/null 2>&1; then
            log INFO $product "Manifest ${manifest} is applied"
        else
            log ERROR $product "Failed to apply ${manifest}."
        fi
    else
        log ERROR $product "Can't find manifest ${manifest}."
        exit 1
    fi
}
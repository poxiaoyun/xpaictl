function installKubernetes() {
    # Environment Variables
    export SEALOS_RUNTIME_ROOT=/data/.sealos
    export SEALOS_SCP_CHECKSUM=false
    export SEALOS_DATA_ROOT=${defaultDir}/registry
    local criDataDir="${defaultDir}/containerd"
    local ebsDataDir="${defaultDir}/openebs/localpv"
    local product="kubernetes"
    # kernel configurations
    local MAX_USER_WATCHES_VALUE=2099999999
    local MAX_USER_INSTANCES_VALUE=2099999999
    local MAX_QUEUED_EVENTS_VALUE=2099999999

    if [[ "$(declare -p masters 2>/dev/null)" =~ "declare -a" ]]; then
        local masterss=$(IFS=,; echo "${masters[*]}")
    else
        local masterss=${masters}
    fi

    if [[ "$(declare -p workers 2>/dev/null)" =~ "declare -a" ]]; then
        local nodes=$(IFS=,; echo "${workers[*]}")
    else
        local nodes=${workers}
    fi

    # Log start of installation
    log INFO $product "Starting Kubernetes installation..."

    # Install Kubernetes with or without workers
    if [[ -z "$workers" ]]; then
        log INFO $product "Installing Kubernetes masters: $masterss"
        sealos run docker.io/labring/kubernetes:${kubernetesVersion} \
                    docker.io/labring/helm:v3.12.0 \
                    docker.io/labring/calico:3.24.6 \
                    --masters "$masterss" \
                    --port ${sshPort:-22} \
                    --passwd ${sshPassword} \
                    -e criData="${criDataDir}"
    else
        log INFO $product "Installing Kubernetes masters: $masterss and workers: $nodes"
        sealos run docker.io/labring/kubernetes:${kubernetesVersion} \
                    docker.io/labring/helm:v3.12.0 \
                    docker.io/labring/calico:3.24.6 \
                    --masters "$masterss" \
                    --nodes "$nodes" \
                    --port ${sshPort:-22} \
                    --passwd ${sshPassword} \
                    -e criData="${criDataDir}"
    fi

    # Check if Kubernetes installation succeeded
    if [[ $? -ne 0 ]]; then
        log ERROR $product "Kubernetes installation failed."
        return 1
    fi

    # Install OpenEBS
    log INFO $product "Installing OpenEBS with base path: $ebsDataDir"
    sealos run docker.io/labring/openebs:v3.9.0 \
                -e HELM_OPTS="--set localprovisioner.basePath=${ebsDataDir} \
                               --set ndm.enabled=false \
                               --set ndmOperator.enabled=false \
                               --set localprovisioner.deviceClass.enabled=false \
                               --set localprovisioner.hostpathClass.isDefaultClass=true"

    # Check if OpenEBS installation succeeded
    if [[ $? -ne 0 ]]; then
        log ERROR $product "OpenEBS installation failed."
        return 1
    fi

    log INFO $product "Kubernetes and OpenEBS installation completed successfully."


    # Excute some command
    log INFO $product "Optimize system parameters"
    if [[ $(detect_package_manager) == "apt" ]]; then
        if sealos exec -c default "systemctl stop unattended-upgrades" > /dev/null 2>&1; then
            log DEBUG $product "Excute: systemctl stop unattended-upgrades."
        else
            log ERROR $product "Excute failed: systemctl stop unattended-upgrades."
        fi

        if sealos exec -c default "systemctl disable unattended-upgrades" > /dev/null 2>&1; then
            log DEBUG $product "Excute: systemctl disable unattended-upgrades."
        else
            log ERROR $product "Excute failed: systemctl disable unattended-upgrades."
        fi
        # hold kernel version
        if sealos exec -c default "apt-mark hold linux-generic linux-image-generic linux-headers-generic" > /dev/null 2>&1; then
            log DEBUG $product "Excute: apt-mark hold linux-generic linux-image-generic linux-headers-generic."
        else
            log ERROR $product "Excute failed: apt-mark hold linux-generic linux-image-generic linux-headers-generic."
        fi
        if sealos exec -c default "apt-mark unhold linux-generic linux-image-generic linux-headers-generic" > /dev/null 2>&1; then
            log DEBUG $product "Excute: apt-mark unhold linux-generic linux-image-generic linux-headers-generic"
        else
            log ERROR $product "Excute failed: apt-mark unhold linux-generic linux-image-generic linux-headers-generic"
        fi
    fi

    log INFO $product "Applying runtime kernel configuration."
    
    if sealos exec -c default "sysctl -w fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE" > /dev/null 2>&1; then
        log DEBUG $product "Excute: sysctl -w fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE"
    else
        log ERROR $product "Excute failed: sysctl -w fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE"
    fi

    if sealos exec -c default "sysctl -w fs.inotify.max_user_instances=$MAX_USER_INSTANCES_VALUE"  > /dev/null 2>&1; then
        log DEBUG $product "Excute: sysctl -w fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE"
    else 
        log ERROR $product "Excute failed: sysctl -w fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE"
    fi

    if sealos exec -c default "sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"  > /dev/null 2>&1; then
        log DEBUG $product "Excute: sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"
    else 
        log ERROR $product "Excute failed: sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"
    fi

}

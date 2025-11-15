function installKubernetes() {
    # Environment Variables
    export SEALOS_RUNTIME_ROOT=${defaultDir}/.sealos
    export SEALOS_SCP_CHECKSUM=false
    export SEALOS_DATA_ROOT=${defaultDir}/registry
    
    local criDataDir="${defaultDir}/containerd"
    local ebsDataDir="${defaultDir}/openebs/localpv"
    local product="kubernetes"
    # kernel configurations
    local MAX_USER_WATCHES_VALUE=2099999999
    local MAX_USER_INSTANCES_VALUE=2099999999
    local MAX_QUEUED_EVENTS_VALUE=2099999999
    local CacheDir=${cacheDir:-/var/jfsCache}

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
        sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes:${kubernetesVersion} \
                    registry.cn-shanghai.aliyuncs.com/labring/helm:v${helmVersion:-3.12.0} \
                    registry.cn-shanghai.aliyuncs.com/labring/calico:${calicoVersion:-3.24.6} \
                    --masters "$masterss" \
                    --port ${sshPort:-22} \
                    --passwd ${sshPassword} \
                    -e criData="${criDataDir}"
    else
        log INFO $product "Installing Kubernetes masters: $masterss and workers: $nodes"
        sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes:${kubernetesVersion} \
                    registry.cn-shanghai.aliyuncs.com/labring/helm:v${helmVersion:-3.12.0} \
                    registry.cn-shanghai.aliyuncs.com/labring/calico:${calicoVersion:-3.24.6} \
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
    sealos run registry.cn-shanghai.aliyuncs.com/labring/openebs:v${ebsVersion:-3.9.0} \
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
        log DEBUG $product "Excute: sysctl -w fs.inotify.max_user_instances=$MAX_USER_INSTANCES_VALUE"
    else 
        log ERROR $product "Excute failed: sysctl -w fs.inotify.max_user_instances=$MAX_USER_INSTANCES_VALUE"
    fi

    if sealos exec -c default "sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"  > /dev/null 2>&1; then
        log DEBUG $product "Excute: sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"
    else 
        log ERROR $product "Excute failed: sysctl -w fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE"
    fi

    # Persist kernel parameters to /etc/sysctl.conf
    log INFO $product "Persisting kernel parameters to /etc/sysctl.conf"
    if sealos exec -c default "grep -q 'fs.inotify.max_user_watches' /etc/sysctl.conf 2>/dev/null"; then
        log DEBUG $product "fs.inotify.max_user_watches already exists in /etc/sysctl.conf, skipping"
    else
        if sealos exec -c default "echo 'fs.inotify.max_user_watches=$MAX_USER_WATCHES_VALUE' >> /etc/sysctl.conf" > /dev/null 2>&1; then
            log DEBUG $product "Added fs.inotify.max_user_watches to /etc/sysctl.conf"
        else
            log ERROR $product "Failed to add fs.inotify.max_user_watches to /etc/sysctl.conf"
        fi
    fi

    if sealos exec -c default "grep -q 'fs.inotify.max_user_instances' /etc/sysctl.conf 2>/dev/null"; then
        log DEBUG $product "fs.inotify.max_user_instances already exists in /etc/sysctl.conf, skipping"
    else
        if sealos exec -c default "echo 'fs.inotify.max_user_instances=$MAX_USER_INSTANCES_VALUE' >> /etc/sysctl.conf" > /dev/null 2>&1; then
            log DEBUG $product "Added fs.inotify.max_user_instances to /etc/sysctl.conf"
        else
            log ERROR $product "Failed to add fs.inotify.max_user_instances to /etc/sysctl.conf"
        fi
    fi

    if sealos exec -c default "grep -q 'fs.inotify.max_queued_events' /etc/sysctl.conf 2>/dev/null"; then
        log DEBUG $product "fs.inotify.max_queued_events already exists in /etc/sysctl.conf, skipping"
    else
        if sealos exec -c default "echo 'fs.inotify.max_queued_events=$MAX_QUEUED_EVENTS_VALUE' >> /etc/sysctl.conf" > /dev/null 2>&1; then
            log DEBUG $product "Added fs.inotify.max_queued_events to /etc/sysctl.conf"
        else
            log ERROR $product "Failed to add fs.inotify.max_queued_events to /etc/sysctl.conf"
        fi
    fi

    if ${cache}; then
        log INFO $product "IMPORTANR!! XPAI Cache has enabled, The device ${cacheDev} is about to be format!"
        if sealos exec -c default "mkfs.xfs -f $cacheDev"  > /dev/null 2>&1; then
            log INFO $product "$cacheDev has been successfully format as xfs filesystem."
        else
            log ERROR $product "$cacheDev format failed."
        fi

        mkdir -p ${CacheDir}
        if sealos exec -c default "mkdir -p ${CacheDir}" > /dev/null 2>&1; then
            log DEBUG $product "Created directory ${CacheDir}"
        fi
        
        if sealos exec -c default "mount -o allocsize=1g,noatime,nodiratime ${cacheDev} ${CacheDir}"  > /dev/null 2>&1; then
            log INFO $product "${cacheDev} has been mounted to ${CacheDir}."
            
            # Persist mount entry to /etc/fstab
            log INFO $product "Persisting cache device mount to /etc/fstab"
            if sealos exec -c default "grep -q '${cacheDev}.*${CacheDir}' /etc/fstab 2>/dev/null"; then
                log DEBUG $product "Mount entry for ${cacheDev} already exists in /etc/fstab, skipping"
            else
                if sealos exec -c default "echo '${cacheDev} ${CacheDir} xfs allocsize=1g,noatime,nodiratime 0 0' >> /etc/fstab" > /dev/null 2>&1; then
                    log INFO $product "Added mount entry for ${cacheDev} to /etc/fstab"
                else
                    log ERROR $product "Failed to add mount entry for ${cacheDev} to /etc/fstab"
                fi
            fi
        else
            log ERROR $product "${CacheDir} mounted failed."
        fi
    fi

}

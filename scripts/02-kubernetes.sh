function installKubernetes() {
    local timestamp

    # Environment Variables
    export SEALOS_RUNTIME_ROOT=/data/.sealos
    export SEALOS_SCP_CHECKSUM=false
    export SEALOS_DATA_ROOT=${defaultDir}/registry
    local criDataDir="${defaultDir}/containerd"
    local ebsDataDir="${defaultDir}/openebs/localpv"
    local product="kubernetes"

    # Log start of installation
    log INFO $product "Starting Kubernetes installation..."

    # Install Kubernetes with or without workers
    if [[ -z "$workers" ]]; then
        log INFO $product "Installing Kubernetes masters: $masters"
        sealos run docker.io/labring/kubernetes:${kubernetesVersion} \
                    docker.io/labring/helm:v3.12.0 \
                    docker.io/labring/calico:3.24.6 \
                    --masters "$masters" \
                    --port ${sshPort:-22} \
                    --passwd ${sshPassword} \
                    -e criData="${criDataDir}"
    else
        log INFO $product "Installing Kubernetes masters: $masters and workers: $workers"
        sealos run docker.io/labring/kubernetes:${kubernetesVersion} \
                    docker.io/labring/helm:v3.12.0 \
                    docker.io/labring/calico:3.24.6 \
                    --masters "$masters" \
                    --nodes "$workers" \
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

    # Log success
    log INFO $product "Kubernetes and OpenEBS installation completed successfully."
}

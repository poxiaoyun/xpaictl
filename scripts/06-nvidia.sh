function installNvidiaOperator() {
    local product="nvidia"
    local manifestsDir="${script_dir}/manifests/gpu-operator"
    local templatesDir="${script_dir}/artifacts/templates"
    local file
    local manifest

    export installNvidiaDriver=${installNvidiaDriver:-false}
    export nvidiaDriverVersion=${nvidiaDriverVersion:-570.195.03}

    if [ "$installNvidiaOperator" == "true" ]; then
        template="gpu-operator.values.yaml"
    else
        log INFO $product "Nvidia operator installation is disabled."
        return 0
    fi

    if ! command -v helm >/dev/null 2>&1; then
        log ERROR $product "The 'helm' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    cd "${templatesDir}" || {
        log ERROR $product "Failed to change directory to ${templatesDir}."
        exit 1
    }

    # Log start of installation
    log INFO $product "Trying to preparing nvidia operator templates."

    file=${templatesDir}/${template}
    
    if [ -e "${file}.template" ]; then
        log INFO $product "Templating  ${file}.template ."
        if envsubst < ${file}.template > ${manifestsDir}/${template} ; then

            log INFO $product "Templating Success, Manifest ${file} saved in ${manifestsDir}."
        else
            log ERROR $product "Failed to template ${file}.template ."
            exit 1
        fi
    else
        log ERROR $product "Can't find template ${file}.template ."
        exit 1
    fi

    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    log INFO $product "Trying to install Nvidia operator."

    manifest=${manifestsDir}/${template} 
    if [ -e "${manifest}" ]; then
        if ! namespace_exists; then
            if  kubectl create ns gpu-operator > /dev/null 2>&1; then
                log INFO $product "Create namespace/gpu-operator successfully."
            fi
        fi
        if helm install -n gpu-operator gpu-operator -f ${manifest} ${manifestsDir} > /dev/null 2>&1; then
                log INFO $product "Nvidia operator was installed"
        fi
    else
        log ERROR $product "Can't find mainifest ${manifest}/${template}"
        exit 1
    fi
}

function installvGPU() {

    local product="vGPU"
    local manifestsDir="${script_dir}/manifests"
    local file
    local manifest

    manifest=${manifestsDir}/vgpu.yaml

    if ! namespace_exists volcano-system; then
        if  kubectl create ns volcano-system > /dev/null 2>&1; then
            log INFO $product "Create namespace/volcano-system successfully."
        fi
    fi
    if [ -e "${manifest}" ]; then
        if kubectl apply --force -f ${manifest} > /dev/null 2>&1; then
            log INFO $product "Manifest file ${manifestsDir}/${manifest} is applied."
        else
            log ERROR $product "Failed to apply ${manifestsDir}/${manifest}."
            exit 1
        fi
    else
        log ERROR $product "Can't find manifest ${manifestsDir}/${manifest}."
        exit 1
    fi

}

function installHami() {

    local product="hami"
    local manifestsDir="${script_dir}/manifests/hami"
    local file
    local manifest
    template="hami.yaml"

    if ! command -v helm >/dev/null 2>&1; then
        log ERROR $product "The 'helm' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi
    log INFO $product "Trying to install Hami scheduler."

    manifest=${manifestsDir}/${template}
    if [ -e "${manifest}" ]; then
        if helm list -n kube-system | grep -q "hami"; then
            log INFO $product "Hami scheduler already installed. We'll upgrade it."
            helm upgrade -n kube-system hami -f ${manifest} ${manifestsDir} > /dev/null 2>&1;
            log INFO $product "Hami scheduler was upgraded"
        else
            log INFO $product "Hami scheduler was not installed. We'll install it."
            helm install -n kube-system hami -f ${manifest} ${manifestsDir} > /dev/null 2>&1;
            log INFO $product "Hami scheduler was installed"
        fi
    else
        log ERROR $product "Can't find mainifest ${manifest}"
        exit 1
    fi
}

function installNFD() {

    local product="nfd"
    local manifestsDir="${script_dir}/manifests/nfd"
    local file
    local manifest

    if ! command -v helm >/dev/null 2>&1; then
        log ERROR $product "The 'helm' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    if helm list -n kubegems-pai  | grep -q "nfd"; then
        log INFO $product "NFD already installed. We'll upgrade it."
        helm upgrade -n kubegems-pai  nfd ${manifestsDir} > /dev/null 2>&1;
        log INFO $product "NFD was upgraded"
    else
        log INFO $product "NFD was not installed. We'll install it."
        helm install -n kubegems-pai nfd ${manifestsDir} > /dev/null 2>&1;
        log INFO $product "NFD was installed"
    fi

}
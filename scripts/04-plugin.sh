function installGems() {
    #set -x 
    local product="plugins"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local templates=(
        "installer.yaml"
        "monitor.yaml"
    )
    local manifests=(
        "gateway.yaml"
        "metrics-server.yaml"
        "prometheus-node-exporter.yaml"
    )

    local serviceMonitor=(
        "vllm.sm.yaml"
    )

    export baseHostWithoutPort=${baseHost%%:*}

    if ! command -v kubectl >/dev/null 2>&1; then
        log ERROR $product "The 'kubectl' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    # Change directory to the artifacts folder
    cd "${templatesDir}" || {
        log ERROR $product "Failed to change directory to ${templatesDir}."
        exit 1
    }

    if [ -n "${productSuffix}" ]; then
		templates+=( "kubegems.suffix.yaml" )
    else
        templates+=( "kubegems.yaml" ) 
	fi

    # Log start of installation
    log INFO $product "Trying to preparing XPAI base mainitests."

    for template in "${templates[@]}"; do
        if [ -e "${templatesDir}/${template}.template" ]; then
            log INFO $product "Templating: ${templatesDir}/${template}.template."
            #if envsubst < "${templatesDir}/${template}.template" > ${manifestsDir}/${template} > /dev/null 2>&1; then
            if envsubst < "${templatesDir}/${template}.template" > ${manifestsDir}/${template}; then
                log INFO $product "Manifest file ${template} saved in ${manifestsDir}."
            else
                log ERROR $product "Failed to template ${templatesDir}/${template}.template ."
                exit 1
            fi
        else
            log ERROR $product "Can't find template ${templatesDir}/${template}.template."
            exit 1
        fi
    done

    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }
    # Log start of installation
    log INFO $product "Trying to install XPAI base component."

    local files=("${templates[@]}" "${manifests[@]}")

    for file in "${files[@]}"; do
        if [ -e "${file}" ]; then
            if kubectl apply --force -f ${file} > /dev/null 2>&1; then
                log INFO $product "Manifest file ${manifestsDir}/${file} is applied."
                #wait_until_running deployment kubegems-installer kubegems-installer 500
            else
                log ERROR $product "Failed to apply ${manifestsDir}/${file}."
                exit 1
            fi
        else
            log ERROR $product "Can't find manifest ${manifestsDir}/${file}."
            exit 1
        fi
    done

    # 需要等prometheus-operator提交crd后，这里的servicemonitor才能正常提交
    if ! namespace_exists kubegems-pai; then
        if  kubectl create ns kubegems-pai > /dev/null 2>&1; then
            log INFO $product "Create namespace/kubegems-pai successfully."
        fi
    fi

    wait_until_running deployment kube-prometheus-stack-operator kubegems-monitoring 500
    for file in "${serviceMonitor}";do 
        if [ -e "${file}" ]; then
            if kubectl apply --force -f ${file} > /dev/null 2>&1; then
                log INFO $product "Manifest file ${manifestsDir}/${file} is applied." 
            else
                log ERROR $product "Failed to apply ${manifestsDir}/${file}."
                exit 1
            fi
        else
            log ERROR $product "Can't find manifest ${manifestsDir}/${file}."
            exit 1
        fi
    done

}

function installVolcano() {
    local product="volcano"
    local manifestsDir="${script_dir}/manifests/volcano"
    local templatesDir="${script_dir}/artifacts/templates"
    local file
    local manifest
    template="volcano.yaml"

    export volcanoVersion=${volcanoVersion:-1.12.1}

    if ! command -v helm >/dev/null 2>&1; then
        log ERROR $product "The 'helm' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    cd "${templatesDir}" || {
        log ERROR $product "Failed to change directory to ${templatesDir}."
        exit 1
    }
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

    manifest=${manifestsDir}/${template}
    if [ -e "${manifest}" ]; then
        if ! namespace_exists volcano-system; then
            if  kubectl create ns volcano-system > /dev/null 2>&1; then
                log INFO $product "Create namespace/volcano-system successfully."
            fi
        fi

        if helm list -n volcano-system | grep -q "volcano"; then
            log INFO $product "Volcano already installed. We'll upgrade it."
            helm upgrade -n volcano-system volcano -f ${manifest} ${manifestsDir} > /dev/null 2>&1;
            log INFO $product "Volcano was upgraded"
        else
            log INFO $product "Volcano was not installed. We'll install it."
            helm install -n volcano-system volcano -f ${manifest} ${manifestsDir} > /dev/null 2>&1;
            log INFO $product "Volcano was installed"
        fi
    else
        log ERROR $product "Can't find mainifest ${manifest}/${template}"
        exit 1
    fi
}
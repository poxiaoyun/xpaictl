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
    
}
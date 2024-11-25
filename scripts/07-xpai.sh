function installXpai() {
    local product="xpai"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local template="xpai.yaml"
    local manifest=${manifestsDir}/${template}
    local file

    if ! command -v kubectl >/dev/null 2>&1; then
        log ERROR $product "The 'kubectl' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    cd "${templatesDir}" || {
        log ERROR $product "Failed to change directory to ${templatesDir}."
        exit 1
    }

    # Log start of installation
    log INFO $product "Trying to preparing xpai manifests."
    file=${templatesDir}/${template}

    if [ -e "${file}.template" ]; then
        if envsubst < ${file}.template > ${manifest}; then
            log INFO $product "Manifest ${file} is saved in ${manifestsDir}."
        else
            log ERROR $product "Failed to template ${file}.template."
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

    log INFO $product "Trying to install xpai."

    if [ -e "${manifest}" ]; then
        if  kubectl apply --force -f ${manifest} > /dev/null 2>&1; then
            log INFO $product "Manifest ${manifest} is applied."
        else
            log ERROR $product "Failed to apply ${manifest}."
            exit 1
        fi
    else
        log ERROR $product "Can't find manifest ${manifest}"
        exit 1
    fi
}
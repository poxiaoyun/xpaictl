function installXpai() {
    local timestamp
    local product="xpai"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local template="${templatesDir}/xpai.yaml"

    timestamp=$(get_timestamp)
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

    if [ -e "${template}.template" ]; then
        if envsubst < ${template}.template > ${template} > /dev/null 2>&1; then
            log INFO $product "Manifest ${template} is saved in ${manifestsDir}."
        else
            log ERROR $product "Failed to template ${template}.template."
            exit 1
        fi
    else
        log ERROR $product "Can't find template ${template}.template ."
        exit 1


    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    log INFO $product "Trying to install xpai."

    if [ -e "${template}" ]; then
        if  kubectl apply -f --force ${template} > /dev/null 2>&1; then
            log INFO $product "Manifest ${template} is applied."
        else
            log ERROR $product "Failed to apply ${template}."
            exit 1
        fi
    else
        log ERROR $product "Can't find manifest ${template}"
        exit 1
    fi
fi
}
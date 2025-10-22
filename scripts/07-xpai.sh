function installXpai() {
    local product="xpai"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local template="xpai.yaml"
    local templates=(
        "xpai.yaml"
        "kubegems.mapi.yaml"
    )
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
    export baseHostWithoutPort=${baseHost%%:*}

    # Log start of installation
    log INFO $product "Trying to preparing xpai manifests."

    for template in "${templates[@]}"; do
        if [ -e "${templatesDir}/${template}.template" ]; then
            log INFO $product "Templating: ${templatesDir}/${template}.template."
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

    log INFO $product "Trying to install xpai."

    local files=("${templates[@]}")

    for file in "${files[@]}"; do
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
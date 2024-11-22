function installMinio() {
    local timestamp
    local product="minio"
    local manifestsDir="${script_dir}/manifests/minio"
    local templatesDir="${script_dir}/artifacts/templates"

    if [ "$installMinio" == "true" ]; then
        if [ "$minioArchitecture" == "standalone" ];then
            template=${templatesDir}/minio.standalone.values.yaml
        elif [ "$minioArchitecture" == "distributed" ]; then
            template=${templatesDir}/minio.distributed.values.yaml
        else
            log ERROR $product "Invalid enviroment: minioArchitecture"
            exit 1
        fi
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
    log INFO $product "Trying to preparing minio templates."

    if [ -e "${templatesDir}/${template}.template" ]; then
        log INFO $product "Templating  ${templatesDir}/${template}.template ."
        if envsubst < ${template}.template > ${manifestsDir}/${template} > /dev/null 2>&1; then

            log INFO $product "Templating Success, Manifest ${template} saved in ${manifestsDir}/${template} ."
        else
            log ERROR $product "Failed to template ${templatesDir}/${template}.template ."
            exit 1
        fi
    else
        log ERROR $product "Can't find template ${templatesDir}/${template}.template ."
        exit 1
    fi


    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    log INFO $product "Trying to install Minio."

    if [ -e "${template}" ]; then
        if  kubectl create ns kubegems-pai > /dev/null 2>&1; then
            log INFO $product "Create namespace/kubegems-pai successfully."
            if helm install -n kubegems-pai xpai-minio minio -f ${template} . > /dev/null 2>&1; then
                if [[ ${minioArchitecture} == "distributed" ]]; then
                    log INFO $product "Minio ${minioArchitecture} with ${minioNums} was installed"
                else
                    log INFO $product "Minio ${minioArchitecture} was installed"
                fi
            fi
        else
            log ERROR $product "Failed to create namespace/kubegems-pai."
            exit 1
        fi
    else
        log ERROR $product "Can't find mainifest ${manifestsDir}/${template}"
        exit 1
    fi
}
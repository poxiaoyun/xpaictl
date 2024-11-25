function installMinio() {
    local product="minio"
    local manifestsDir="${script_dir}/manifests/minio"
    local templatesDir="${script_dir}/artifacts/templates"
    local file
    local manifest

    if [ "$installMinio" == "true" ]; then
        if [ "$minioArchitecture" == "standalone" ];then
            template="minio.standalone.values.yaml"
        elif [ "$minioArchitecture" == "distributed" ]; then
            template="minio.distributed.values.yaml"
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

    log INFO $product "Trying to install Minio."

    manifest=${manifestsDir}/${template} 
    if [ -e "${manifest}" ]; then
        if ! namespace_exists; then
            if  kubectl create ns kubegems-pai > /dev/null 2>&1; then
                log INFO $product "Create namespace/kubegems-pai successfully."
            fi
        fi
        if helm install -n kubegems-pai xpai-minio -f ${manifest} ${manifestsDir} > /dev/null 2>&1; then
            if [[ "${minioArchitecture}" == "distributed" ]]; then
                log INFO $product "Minio ${minioArchitecture} with ${minioNums} was installed"
            else
                log INFO $product "Minio ${minioArchitecture} was installed"
            fi
        fi
    else
        log ERROR $product "Can't find mainifest ${manifest}/${template}"
        exit 1
    fi
}
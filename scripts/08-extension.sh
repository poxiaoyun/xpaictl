function installXpaiExtension() {
    local files=(
        "xpai-extension-${mainVersion}.tar"
    )
    local images=(
        "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:${mainVersion}"
    )
    local xpaiImageDir="${script_dir}/artifacts/images"
    local product="extension"
    
    export SEALOS_RUNTIME_ROOT=${defaultDir}/.sealos
    export SEALOS_SCP_CHECKSUM=false
    export SEALOS_DATA_ROOT=${defaultDir}/registry

    # Change directory to the artifacts folder
    cd "${xpaiImageDir}" || {
        log ERROR $product "Failed to change directory to ${xpaiImageDir}."
        exit 1
    }

    # Load each image
    log INFO $product "Trying to load images from ${xpaiImageDir}."
    log INFO $product "This process may take a long time, please do not terminate the process."

    for image in "${files[@]}"; do
        if [ -e "${image}" ]; then
            log INFO $product "Loading image: ${xpaiImageDir}/${image}."
            if sealos load -i "${xpaiImageDir}/${image}" > /dev/null 2>&1; then
                log INFO $product "${xpaiImageDir}/${image} loaded successfully."
            else
                log ERROR $product "Failed to load image: ${xpaiImageDir}/${image}."
                exit 1
            fi
        else
            log ERROR $product "Can't find file ${xpaiImageDir}/${image} ."
            exit 1
        fi
    done

    log INFO $product "All images loaded successfully." 


    # Log start of installation
    log INFO $product "Installing XPAI extension images..."
    for image in "${images[@]}"; do
        if sealos ps --notruncate |grep ${image} > /dev/null 2>&1; then
            log INFO $product "Image $image already installed."
        else
            log INFO $product "Installing image: $image..."
            log INFO $product "This process may take a long time, please do not terminate the process."
            if sealos run "$image" > /dev/null 2>&1; then
                log INFO $product "Image $image installed successfully."
            else
                log ERROR $product "Failed to install image: $image."
                exit 1
            fi 
       fi
    done

    log INFO $product "XPAI extension image installed successfully."
}

function installGemsImages() {
    export SEALOS_RUNTIME_ROOT=${defaultDir}/.sealos
    export SEALOS_SCP_CHECKSUM=false
    export SEALOS_DATA_ROOT=${defaultDir}/registry
    
    local timestamp
    local product="gems"
    local images=(
        "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:${mainVersion}"
    )

	if [ -n "${productSuffix}" ]; then
		images+=( "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:${mainVersion}-${productSuffix}" )
	fi
    
    # Log start of installation
    log INFO $product "Installing XPAI images..."
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

    log INFO $product "All XPAI images installed successfully."
}
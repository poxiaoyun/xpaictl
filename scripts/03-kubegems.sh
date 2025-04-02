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
            # 先下载镜像，可以显示下载进度条，也可以直接运行，但是对安装用户无法了解进度
            # 大部分时间消耗在下载镜像
            log INFO $product "Downloading image: $image..."
            if sealos pull "$image" > /dev/null 2>&1; then
                log INFO $product "Image $image downloaded successfully."
            else
                log ERROR $product "Failed to download image: $image."
                exit 1
            fi

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
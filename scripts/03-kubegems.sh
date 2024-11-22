function installGemsImages() {
    local timestamp
    local product="gems"
    local images=(
        "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:${mainVersion}-${productSuffix}"
        "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:${mainVersion}"
    )

    # Log start of installation

    log INFO $product "Installing XPAI images..."
    for image in "${images[@]}"; do
        log INFO $product "Installing image: $image..."
        log INFO $product "This process may take a long time, please do not terminate the process."
        if sealos run "$image" > /dev/null 2>&1; then
            INFO INFO $product "Image $image installed successfully."
        else
            INFO ERROR $product "Failed to install image: $image."
            exit 1
       fi
    done

    INFO INFO $product "All XPAI images installed successfully."
}
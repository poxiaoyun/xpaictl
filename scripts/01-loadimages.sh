function localXpaiImages() {
    local images=(
        "xpai-stack-${mainVersion}.tar"
        "xpai-extension-${mainVersion}.tar"
        "xpai-stack-${mainVersion}-${productSuffix}.tar.gz"
        "kubernetes-${kubernetesVersion}.tar"
        "helm-v3.12.0.tar"
        "calico-3.24.6.tar"
        "openebs-v3.9.0.tar"
    )
    local xpaiImageDir="${script_dir}/artifacts/images"
    local timestamp
    local product="images"

    # Change directory to the artifacts folder
    cd "${xpaiImageDir}" || {
        log ERROR $product "Failed to change directory to ${xpaiImageDir}."
        exit 1
    }

    # Load each image
    log INFO $product "Trying to load images from ${xpaiImageDir}."
    log INFO $product "This process may take a long time, please do not terminate the process."

    for image in "${images[@]}"; do
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
}

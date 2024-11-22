function initSealos() {
    local tarball="sealos_4.3.7_linux_amd64.tar.gz"
    local binary="sealos"
    local dest_dir="/usr/bin"
    local timestamp
    local product="sealos"

    # Navigate to the script directory
    cd "${script_dir}/artifacts/" || { log ERROR $product "Failed to change directory to ${script_dir}/artifacts/."; return 1; }

    # Extract the binary from the tarball
    log INFO sealos "Extract sealos package ${script_dir}/artifacts/${tarball}"
    if tar zxvf "$tarball" "$binary" > /dev/null 2>&1; then
        chmod +x "$binary"
        mv "$binary" "$dest_dir/"
    else
        log ERROR sealos "Extraction failed. Exiting."
        return 1
    fi

    # Verify if the binary is installed successfully
    if command -v "$binary" > /dev/null 2>&1; then
        log INFO sealos "Sealos installed successfully."
    else
        log INFO sealos "Sealos installation failed. Check your config and re-run script"
        return 1
    fi
}

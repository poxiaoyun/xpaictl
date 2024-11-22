function main(){
    local scriptDir=${script_dir}/scripts
    local product="main"

    local installScripts=(
        "00-prepare.sh"
        "01-loadimages.sh"
        "02-kubernetes.sh"
        "03-kubegems.sh"
        "04-plugin.sh"
        "05-minio.sh"
        "06-nvidia.sh"
        "07-xpai.sh"
    )

    for script in "${installScripts[@]}"; do
        if [[ -f "${scriptDir}/${script}" ]]; then 
            log INFO $product "Source ${scriptDir}/${script}."
            . ${scriptDir}/${script}
        else
            log ERROR $product "Cant't find script ${scriptDir}/${script}."
            exit 1
       fi
    done

    initSealos

}
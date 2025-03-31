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
    localXpaiImages
    installKubernetes
    wait_for_nodes_ready
    installGemsImages
    installGems
    wait_until_running deployment kubegems-installer kubegems-installer 300
    wait_until_running statefulset kubegems-mysql kubegems 300
    wait_until_running statefulset kubegems-redis-master kubegems 300
    wait_until_running deployment kubegems-api kubegems 300
    wait_until_running deployment kubegems-dashboard kubegems 300
    wait_until_running deployment kubegems-worker kubegems 300
    wait_until_running deployment kubegems-msgbus kubegems 300
    wait_until_running deployment kubegems-local-agent kubegems-local 300
    wait_until_running deployment kubegems-local-controller kubegems-local 300
    wait_until_running deployment kubegems-local-kubectl kubegems-local 300
    wait_until_running deployment default-gateway kubegems-gateway 300
    wait_until_running deployment kube-prometheus-stack-operator kubegems-monitoring 300
    wait_until_running statefulset prometheus-kube-prometheus-stack-prometheus kubegems-monitoring 300
    wait_until_running deployment default-gateway kubegems-gateway 300
    if [[ "${installMinio}" == "true" ]];then 
        installMinio
        if [[ "${minioArchitecture}" == "standalone" ]]; then
            wait_until_running deployment xpai-minio kubegems-pai 300
        elif [[ "${minioArchitecture}" == "distributed" ]]; then
            wait_until_running statefulset xpai-minio kubegems-pai 300
        fi
    fi
    installNvidiaOperator
    wait_until_running deployment gpu-operator gpu-operator 300
    installXpai
    wait_until_running statefulset kubegems-pai-mysql kubegems-pai 300
    wait_until_running deployment kubegems-pai-api kubegems-pai 300
    wait_until_running deployment kubegems-pai-controller kubegems-pai 300
    wait_until_running deployment volcano-scheduler volcano-system 300
    wait_until_running deployment volcano-controllers volcano-system 300
    wait_until_running statefulset juicefs-csi-controller juicefs-system 300

    host="console.${baseHost}"
    token=$(get_gems_token ${host})
    local TIMEOUT=600

    local START_TIME=$(date +%s)
    while [[ -z "$token" ]]; do
        log DEBUG main "Attempting to fetch token..."
        token=$(get_gems_token ${host})

        if [[ -n "$token" ]]; then
            break
        fi

        local CURRENT_TIME=$(date +%s)
        if [[ $((CURRENT_TIME - START_TIME)) -ge $TIMEOUT ]]; then
            log ERROR main "License fetch operation timed out after 10 minutes."
            break
        fi

        sleep 10
    done

    local START_TIME=$(date +%s)
    cluster=$(get_gems_license ${host} ${token}) 
    while [[ -z "$cluster" ]]; do
        log DEBUG main "Attempting to fetch license..."
        cluster=$(get_gems_license "${baseHost}" "$token")
        
        if [[ -n "$cluster" ]]; then
            break
        fi

        local CURRENT_TIME=$(date +%s)
        if [[ $((CURRENT_TIME - START_TIME)) -ge $TIMEOUT ]]; then
            log ERROR main "License fetch operation timed out after 10 minutes."
            break
        fi
        sleep 10
    done

    export license=${cluster}
    show_access_info
    if [[ "${xpaiExtension}" == "true" ]];then 
        log INFO $product "XPAI Extension Package is enabled, The script will continue to install extensions."
        log INFO $product "This usually takes a long time to install the extension package, but it does not affect your access to the platform."
        installXpaiExtension
    fi
}
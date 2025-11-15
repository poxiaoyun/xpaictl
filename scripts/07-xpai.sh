function installXpai() {
    local product="xpai"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local template="xpai.yaml"
    local templates=(
        "xpai.yaml"
        "kubegems.mapi.yaml"
    )
    local manifest=${manifestsDir}/${template}
    local file

    if ! command -v kubectl >/dev/null 2>&1; then
        log ERROR $product "The 'kubectl' command is not found. Please check the [modules][kubernetes] runs well."
        exit 1
    fi

    cd "${templatesDir}" || {
        log ERROR $product "Failed to change directory to ${templatesDir}."
        exit 1
    }
    export baseHostWithoutPort=${baseHost%%:*}

    # Log start of installation
    log INFO $product "Trying to preparing xpai manifests."

    for template in "${templates[@]}"; do
        if [ -e "${templatesDir}/${template}.template" ]; then
            log INFO $product "Templating: ${templatesDir}/${template}.template."
            if envsubst < "${templatesDir}/${template}.template" > ${manifestsDir}/${template}; then
                log INFO $product "Manifest file ${template} saved in ${manifestsDir}."
            else
                log ERROR $product "Failed to template ${templatesDir}/${template}.template ."
                exit 1
            fi
        else
            log ERROR $product "Can't find template ${templatesDir}/${template}.template."
            exit 1
        fi
    done

    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    log INFO $product "Trying to install xpai."

    local files=("${templates[@]}")

    for file in "${files[@]}"; do
        if [ -e "${file}" ]; then
            if kubectl apply --force -f ${file} > /dev/null 2>&1; then
                log INFO $product "Manifest file ${manifestsDir}/${file} is applied."
            else
                log ERROR $product "Failed to apply ${manifestsDir}/${file}."
                exit 1
            fi
        else
            log ERROR $product "Can't find manifest ${manifestsDir}/${file}."
            exit 1
        fi
    done
}

function installMapi() {

    # 设置命名空间和 Secret 名称
    local namespace="${NAMESPACE:-kubegems-pai}"
    local secretName="${SECRET_NAME:-kubegems-pai-mysql}"
    local mysqlPod="kubegems-pai-mysql-0"
    
    # 等待 MySQL Pod 就绪
    log INFO $product "Waiting for MySQL pod ${mysqlPod} to be ready in namespace ${namespace}."
    local timeout=300
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if kubectl get pod ${mysqlPod} -n ${namespace} >/dev/null 2>&1; then
            podStatus=$(kubectl get pod ${mysqlPod} -n ${namespace} -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "$podStatus" == "Running" ]; then
                # 检查容器是否就绪
                ready=$(kubectl get pod ${mysqlPod} -n ${namespace} -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
                if [ "$ready" == "true" ]; then
                    log INFO $product "MySQL pod ${mysqlPod} is ready."
                    break
                fi
            fi
        fi
        log DEBUG $product "Waiting for MySQL pod to be ready... (${elapsed}s/${timeout}s)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ $elapsed -ge $timeout ]; then
        log ERROR $product "Timeout waiting for MySQL pod ${mysqlPod} to be ready."
        exit 1
    fi
    
    # 获取 MySQL root 密码
    log INFO $product "Retrieving MySQL root password from secret ${secretName}."
    export MYSQL_ROOT_PASSWORD=$(kubectl get secret ${secretName} -n ${namespace} -o jsonpath="{.data.mysql-root-password}" 2>/dev/null | base64 -d)
    
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        log ERROR $product "Failed to retrieve MySQL root password from secret ${secretName} in namespace ${namespace}."
        exit 1
    fi
    
    # 等待 MySQL 服务完全启动（可以接受连接）
    log INFO $product "Waiting for MySQL service to be ready."
    local mysqlReady=false
    for i in {1..30}; do
        # 尝试执行简单的 SQL 命令来检查 MySQL 是否就绪
        if kubectl exec ${mysqlPod} -n ${namespace} -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
            mysqlReady=true
            break
        fi
        log DEBUG $product "MySQL service not ready yet, retrying... (${i}/30)"
        sleep 5
    done
    
    if [ "$mysqlReady" != "true" ]; then
        log ERROR $product "MySQL service is not ready after waiting."
        exit 1
    fi
    
    # 创建 mapi 数据库
    log INFO $product "Creating database 'mapi' in MySQL."
    if kubectl exec ${mysqlPod} -n ${namespace} -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS mapi;" >/dev/null 2>&1; then
        log INFO $product "Database 'mapi' created successfully."
    else
        log ERROR $product "Failed to create database 'mapi'."
        exit 1
    fi

    local product="mapi"
    local manifestsDir="${script_dir}/manifests"
    local templatesDir="${script_dir}/artifacts/templates"
    local templates=(
        "kubegems.mapi.yaml"
    )
    local manifest=${manifestsDir}/${template}
    local file
    export baseHostWithoutPort=${baseHost%%:*}
    # Log start of installation
    log INFO $product "Trying to preparing mapi manifests."

    for template in "${templates[@]}"; do
        if [ -e "${templatesDir}/${template}.template" ]; then
            log INFO $product "Templating: ${templatesDir}/${template}.template."
            if envsubst < "${templatesDir}/${template}.template" > ${manifestsDir}/${template}; then
                log INFO $product "Manifest file ${template} saved in ${manifestsDir}."
            else
                log ERROR $product "Failed to template ${templatesDir}/${template}.template ."
                exit 1
            fi
        else
            log ERROR $product "Can't find template ${templatesDir}/${template}.template."
            exit 1
        fi
    done

    cd "${manifestsDir}" || {
        log ERROR $product "Failed to change directory to ${manifestsDir}."
        exit 1
    }

    log INFO $product "Trying to install mapi."

    local files=("${templates[@]}")

    for file in "${files[@]}"; do
        if [ -e "${file}" ]; then
            if kubectl apply --force -f ${file} > /dev/null 2>&1; then
                log INFO $product "Manifest file ${manifestsDir}/${file} is applied."
            else
                log ERROR $product "Failed to apply ${manifestsDir}/${file}."
                exit 1
            fi
        else
            log ERROR $product "Can't find manifest ${manifestsDir}/${file}."
            exit 1
        fi
    done
}
SHELL := /bin/bash
ARTIFACTS_DIR:= ./artifacts
DOWNLOAD_DIR:= ./artifacts
MANIFESTS_DIR:= ./manifests

HELM_VERSION := v3.12.0
CALICO_VERSION := 3.24.6
EBS_VERSION := v3.9.0

SEALOS_VERSION := v4.3.7
SEALOS_VERSION_FILE:= sealos_$$(echo $(SEALOS_VERSION) | sed 's/^v//')_linux_amd64.tar.gz
SEALOS_FILE_PATH := $(ARTIFACTS_DIR)/$(SEALOS_VERSION_FILE)
SEALOS_IMAGE_PATH := $(ARTIFACTS_DIR)/images

TIDB_VERSION := v7.5.1
TIDB_FILE := tidb-community-server-$(TIDB_VERSION)-linux-amd64.tar.gz
TIDB_TOOL_FILE := tidb-community-toolkit-$(TIDB_VERSION)-linux-amd64.tar.gz
TIDB_FILE_PATH := $(ARTIFACTS_DIR)/$(TIDB_FILE)
TIDB_TOOL_PATH := $(ARTIFACTS_DIR)/$(TIDB_TOOL_FILE)


IMAGES := $(shell bash -c 'source ./scripts/utils.sh && parse_config_nolog xpai.yaml ; \
    function localXpaiImages() { \
		source ./artifacts/env ;\
        local images=( \
			"registry.cn-shanghai.aliyuncs.com/labring/kubernetes:$${kubernetesVersion}" \
			"registry.cn-shanghai.aliyuncs.com/labring/helm:$(HELM_VERSION)" \
			"registry.cn-shanghai.aliyuncs.com/labring/calico:$(CALICO_VERSION)" \
			"registry.cn-shanghai.aliyuncs.com/labring/openebs:$(EBS_VERSION)" \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:$${mainVersion}" \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:$${mainVersion}" \
        ); \
		if [ -n "$${productSuffix}" ]; then \
			images+=( "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:$${mainVersion}-$${productSuffix}" ); \
		fi; \
        echo $${images[@]}; \
    }; \
    localXpaiImages')

tidb:
	@if [ ! -f $(TIDB_FILE_PATH) ]; then \
		echo "File $(TIDB_FILE_PATH) does not exist. Downloading..."; \
		wget -P $(DOWNLOAD_DIR) https://download.pingcap.org/$(TIDB_FILE); \
	else \
		echo "File $(TIDB_FILE_PATH) already exists. Skipping download."; \
	fi
	@if [ ! -f $(TIDB_TOOL_PATH) ]; then \
		echo "File $(TIDB_TOOL_PATH) does not exist. Downloading..."; \
		wget -P $(DOWNLOAD_DIR) https://download.pingcap.org/$(TIDB_TOOL_FILE); \
	else \
		echo "File $(TIDB_FILE_PATH) already exists. Skipping download."; \
	fi

sealos:
	@if [ ! -f $(SEALOS_FILE_PATH) ]; then \
		echo "File $(SEALOS_FILE_PATH) does not exist. Downloading..."; \
		wget -P $(DOWNLOAD_DIR) https://mirror.ghproxy.com/https://github.com/labring/sealos/releases/download/${SEALOS_VERSION}/$(SEALOS_VERSION_FILE); \
	else \
		echo "File $(SEALOS_FILE_PATH) already exists. Skipping download."; \
	fi
	@tar zxvf $(SEALOS_FILE_PATH) sealos && chmod +x sealos && mv sealos /usr/bin

pull:
	@for image in $(IMAGES); do \
		echo "Pulling $$image"; \
		sealos pull $$image; \
	done

save:
	bash -c 'source ./scripts/utils.sh; \
	 mkdir -p ${SEALOS_IMAGE_PATH}; \
	 for image in $(IMAGES); do \
		file=$$(convert_image_to_tar $${image}); \
		if [ ! -f "${SEALOS_IMAGE_PATH}/$${file}" ]; then \
			sealos pull $$image; \
			sealos save -o ${SEALOS_IMAGE_PATH}/$${file} $$image ;\
		fi ;\
	done'

package:
	@$(MAKE) sealos
	@$(MAKE) pull
	@$(MAKE) save

load:
	bash -c 'source ./scripts/utils.sh; \
	 for image in $(IMAGES); do \
	 	sealos images rmi $${image}
		file=$$(convert_image_to_tar $${image}); \
		sealos load -i ${SEALOS_IMAGE_PATH}/$${file};\
	done'

test:
	@NODE_IP=$$(hostname -I | awk '{print $$1}'); \
	./xpaictl.sh --config xpai.yaml --masters $$NODE_IP
#	./xpaictl.sh --config xpai.yaml --masters 172.21.0.4 --nodes 172.21.0.3,172.21.0.2

clean:
	@rm -rf $(MANIFESTS_DIR)/installer.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/minio/minio.standalone.values.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/minio/minio.distributed.values.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/kubegems.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/kubegems.suffix.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/monitor.yaml ;\
	 rm -rf $(MANIFESTS_DIR)/xpai.yaml ;\
	 rm -rf $(ARTIFACTS_DIR)/env

clean_all:
	@$(MAKE) clean
	@rm -rf $(ARTIFACTS_DIR)/*.tar.gz
	@rm -rf $(ARTIFACTS_DIR)/images/*
	@rm -rf $(ARTIFACTS_DIR)/tidb/*
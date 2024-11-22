SHELL := /bin/bash
MANIFESTS_DIR := ./artifacts
SEALOS_VERSION := v4.3.7
SEALOS_VERSION_FILE:= sealos_$$(echo $(SEALOS_VERSION) | sed 's/^v//')_linux_amd64.tar.gz SEALOS_FILE_PATH := $(MANIFESTS_DIR)/$(SEALOS_VERSION_FILE)
SEALOS_IMAGE_PATH := $(MANIFESTS_DIR)/images
HELM_VERSION := v3.12.0
CALICO_VERSION := 3.24.6
EBS_VERSION := v3.9.0


IMAGES := $(shell bash -c 'source ./scripts/utils.sh && parse_config_nolog xpai.yaml ; \
    function localXpaiImages() { \
		source ./artifacts/env ;\
        local images=( \
			"docker.io/labring/kubernetes:$${kubernetesVersion}" \
			"docker.io/labring/helm:$(HELM_VERSION)" \
			"docker.io/labring/calico:$(CALICO_VERSION)" \
			"docker.io/labring/openebs:$(EBS_VERSION)" \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:$${mainVersion}" \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:$${mainVersion}" \
        ); \
		if [ -n "$${productSuffix}" ]; then \
			images+=( "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:$${mainVersion}-$${productSuffix}" ); \
		fi; \
        echo $${images[@]}; \
    }; \
    localXpaiImages')

sealos:
	@if [ ! -f $(SEALOS_FILE_PATH) ]; then \
		echo "File $(SEALOS_FILE_PATH) does not exist. Downloading..."; \
		wget -P $(DOWNLOAD_DIR) https://mirror.ghproxy.com/https://github.com/labring/sealos/releases/download/${SEALOS_VERSION}/$(SEALOS_FILE_NAME); \
	else \
		echo "File $(SEALOS_FILE_PATH) already exists. Skipping download."; \
	fi
	@tar zxvf $(SEALOS_FILE_PATH) sealos && chmod +x sealos && mv sealos /usr/bin

pull:
	@for image in $(IMAGES); do \
		echo "Pulling $$image..."; \
		sealos pull $$image; \
	done

save:
	@source ./scripts/utils.sh; \
	 for image in $(IMAGES); do \
		file=$$(convert_image_to_tar $${image}); \
		sealos pull $$image; \
		sealos save -o ${SEALOS_IMAGE_PATH}/$${file} $$image ;\
	done

load:
	@source ./scripts/utils.sh; \
	 for image in $(IMAGES); do \
	 	sealos images rmi $${image}
		file=$$(convert_image_to_tar $${image}); \
		sealos load -i ${SEALOS_IMAGE_PATH}/$${file};\
	done

test:
	@./xpaictl.sh --config xpai.yaml --masters 127.0.0.1
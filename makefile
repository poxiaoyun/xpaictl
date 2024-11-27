SHELL := /bin/bash
ARTIFACTS_DIR:= ./artifacts
DOWNLOAD_DIR:= ./artifacts
MANIFESTS_DIR:= ./manifests
SEALOS_VERSION := v4.3.7
SEALOS_VERSION_FILE:= sealos_$$(echo $(SEALOS_VERSION) | sed 's/^v//')_linux_amd64.tar.gz
SEALOS_FILE_PATH := $(ARTIFACTS_DIR)/$(SEALOS_VERSION_FILE)
SEALOS_IMAGE_PATH := $(ARTIFACTS_DIR)/images
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
	@source ./scripts/utils.sh; \
	 mkdir -p ${SEALOS_IMAGE_PATH}; \
	 for image in $(IMAGES); do \
		file=$$(convert_image_to_tar $${image}); \
		if [ ! -f "${SEALOS_IMAGE_PATH}/$${file}" ]; then \
			sealos pull $$image; \
			sealos save -o ${SEALOS_IMAGE_PATH}/$${file} $$image ;\
		fi ;\
	done

package:
	@$(MAKE) sealos
	@$(MAKE) pull
	@$(MAKE) save

load:
	@source ./scripts/utils.sh; \
	 for image in $(IMAGES); do \
	 	sealos images rmi $${image}
		file=$$(convert_image_to_tar $${image}); \
		sealos load -i ${SEALOS_IMAGE_PATH}/$${file};\
	done

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
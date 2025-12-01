SHELL := /bin/bash
ARTIFACTS_DIR:= ./artifacts
DOWNLOAD_DIR:= ./artifacts
MANIFESTS_DIR:= ./manifests
ARCH := $(shell uname -m |sed 's/x86_64/amd64/;s/aarch64/arm64/')

HELM_VERSION := v3.12.0
CALICO_VERSION := 3.24.6
EBS_VERSION := v3.9.0

#由于国内网络的特殊原因，访问 GitHub 可能会受限,需要加速请使用代理
#GITHUB_PROXY := https://ghfast.top

NERDCTL_VERSION := 2.1.4
NERDCTL_VERSION_FILE := nerdctl-$(NERDCTL_VERSION)-linux-$(ARCH).tar.gz
NERDCTL_FILE_PATH := $(ARTIFACTS_DIR)/$(NERDCTL_VERSION_FILE)

BUILDKIT_VERSION := v0.24.0
BUILDKIT_VERSION_FILE := buildkit-$(BUILDKIT_VERSION).linux-$(ARCH).tar.gz
BUILDKIT_VERSION_PATH := $(ARTIFACTS_DIR)/$(BUILDKIT_VERSION_FILE)

SEALOS_VERSION := v4.3.7
SEALOS_VERSION_FILE:= sealos_$$(echo $(SEALOS_VERSION) | sed 's/^v//')_linux_${ARCH}.tar.gz
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
        ); \
		if [ -n "$${productSuffix}" ]; then \
			images+=( "registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-stack:$${mainVersion}-$${productSuffix}" ); \
		fi; \
        echo $${images[@]}; \
    }; \
    localXpaiImages')

NVIDIA_EXTENSION_IMAGES := $(shell bash -c 'source ./scripts/utils.sh && parse_config_nolog xpai.yaml ; \
    function localXpaiExtensionImages() { \
		source ./artifacts/env ;\
        local images=( \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:$${mainVersion}-nvidia" \
        ); \
        echo $${images[@]}; \
    }; \
    localXpaiExtensionImages')

ASCEND_EXTENSION_IMAGES := $(shell bash -c 'source ./scripts/utils.sh && parse_config_nolog xpai.yaml ; \
    function localXpaiExtensionImages() { \
		source ./artifacts/env ;\
        local images=( \
			"registry.cn-hangzhou.aliyuncs.com/xiaoshiai/xpai-extension:$${mainVersion}-ascend" \
        ); \
        echo $${images[@]}; \
    }; \
    localXpaiExtensionImages')

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
		if [ -n "$(GITHUB_PROXY)" ]; then \
			wget -P $(DOWNLOAD_DIR) $(GITHUB_PROXY)/https://github.com/labring/sealos/releases/download/$(SEALOS_VERSION)/$(SEALOS_VERSION_FILE); \
		else \
			wget -P $(DOWNLOAD_DIR) https://github.com/labring/sealos/releases/download/$(SEALOS_VERSION)/$(SEALOS_VERSION_FILE); \
		fi; \
	else \
		echo "File $(SEALOS_FILE_PATH) already exists. Skipping download."; \
	fi
	@tar zxvf $(SEALOS_FILE_PATH) sealos && chmod +x sealos && mv sealos /usr/bin

nerdctl:
	@if [ ! -f $(NERDCTL_FILE_PATH) ]; then \
		echo "File $(NERDCTL_FILE_PATH) does not exist. Downloading..."; \
		if [ -n "$(GITHUB_PROXY)" ]; then \
			wget -P $(DOWNLOAD_DIR) $(GITHUB_PROXY)/https://github.com/containerd/nerdctl/releases/download/v$(NERDCTL_VERSION)/$(NERDCTL_VERSION_FILE); \
		else \
			wget -P $(DOWNLOAD_DIR)	https://github.com/containerd/nerdctl/releases/download/v$(NERDCTL_VERSION)/$(NERDCTL_VERSION_FILE); \
		fi; \
	else \
		echo "File $(NERDCTL_FILE_PATH) already exists. Skipping download."; \
	fi
	@tar zxvf $(NERDCTL_FILE_PATH) -C /usr/local/bin
	@if [ ! -f $(BUILDKIT_VERSION_PATH) ]; then \
		echo "File $(BUILDKIT_VERSION_PATH) does not exist. Downloading..."; \
		if [ -n "$(GITHUB_PROXY)" ]; then \
			wget -P $(DOWNLOAD_DIR) $(GITHUB_PROXY)/https://github.com/moby/buildkit/releases/download/$(BUILDKIT_VERSION)/$(BUILDKIT_VERSION_FILE); \
		else \
			wget -P $(DOWNLOAD_DIR) https://github.com/moby/buildkit/releases/download/$(BUILDKIT_VERSION)/$(BUILDKIT_VERSION_FILE); \
		fi; \
	else \
		echo "File $(BUILDKIT_VERSION_PATH) already exists. Skipping download."; \
	fi
	@tar zxvf $(BUILDKIT_VERSION_PATH) -C /usr/local 

pull:
	@for image in $(IMAGES); do \
		echo "Pulling $$image"; \
		sealos pull $$image; \
	done

pull-extension-nvidia:
	@for image in $(NVIDIA_EXTENSION_IMAGES); do \
		echo "Pulling $$image"; \
		sealos pull $$image; \
	done

pull-extension-ascend:
	@for image in $(ASCEND_EXTENSION_IMAGES); do \
		echo "Pulling $$image"; \
		sealos pull $$image; \
	done

save:
	@bash -c 'source ./scripts/utils.sh; \
	 mkdir -p ${SEALOS_IMAGE_PATH}; \
	 for image in $(IMAGES); do \
		file=$$(convert_image_to_tar $${image}); \
		if [ ! -f "${SEALOS_IMAGE_PATH}/$${file}" ]; then \
			sealos pull $$image; \
			sealos save -o ${SEALOS_IMAGE_PATH}/$${file} $$image ;\
		fi ;\
	done'

save-extension-nvidia:
	@bash -c 'source ./scripts/utils.sh; \
	 mkdir -p ${SEALOS_IMAGE_PATH}; \
	 for image in $(NVIDIA_EXTENSION_IMAGES); do \
		file=$$(convert_image_to_tar $${image}); \
		if [ ! -f "${SEALOS_IMAGE_PATH}/$${file}" ]; then \
			sealos pull $$image; \
			sealos save -o ${SEALOS_IMAGE_PATH}/$${file} $$image ;\
		fi ;\
	done'

save-extension-ascend:
	@bash -c 'source ./scripts/utils.sh; \
	 mkdir -p ${SEALOS_IMAGE_PATH}; \
	 for image in $(ASCEND_EXTENSION_IMAGES); do \
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

package-extension-nvidia:
	@$(MAKE) pull-extension-nvidia
	@$(MAKE) save-extension-nvidia

package-extension-ascend:
	@$(MAKE) pull-extension-ascend
	@$(MAKE) save-extension-ascend

reset:
	@bash -c 'source ./scripts/utils.sh; \
		source ./artifacts/env; \
		echo "注意，此操作会删除所有XPAI平台数据,包括 License 信息，请谨慎操作！"; \
		export SEALOS_RUNTIME_ROOT=$${defaultDir}/.sealos; \
		export SEALOS_SCP_CHECKSUM=false; \
		export SEALOS_DATA_ROOT=${defaultDir}/registry; \
		sealos reset; \
		systemctl stop registry image-cri-shim; \
		rm -rf /$${defaultDir}/{openebs,registry,containerd,sealos}; \
		rm -rf /var/lib/registry; \
		sealos images |grep -v TAG  |awk '"'"'{print "sealos rmi " $$1":"$$2}'"'"' |bash -c "bash -s"; \
		echo "XPAI平台数据已清除完毕";'

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
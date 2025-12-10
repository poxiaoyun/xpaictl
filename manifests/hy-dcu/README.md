## 适配DCU

### 基本信息

- 操作系统

```
PRETTY_NAME="Ubuntu 22.04 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04 (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy
```

- 内核版本

```
Linux node1 5.15.0-25-generic #25 SMP Wed Sep 4 16:01:38 CST 2024 x86_64 x86_64 x86_64 GNU/Linux
```

- DCU

```
K100-AI
```

### 安装驱动

1. 下载安装 DCU dtk-25.04.2 驱动

```
https://download.sourcefind.cn:65024/6/main/dtk-25.04.2%E9%A9%B1%E5%8A%A8

chmod +x
./rock-6.3.16-V1.1.0a.run 
```

2. 验证驱动

```
hy-smi 或者 rocm-smi
================================= System Management Interface ==================================
================================================================================================
HCU     Temp     AvgPwr     Perf     PwrCap     VRAM%      HCU%      Mode
0       63.0C    109.0W     auto     400.0W     0%         0.0%      Normal
1       63.0C    112.0W     auto     400.0W     0%         0.0%      Normal
2       61.0C    100.0W     auto     400.0W     0%         0.0%      Normal
3       60.0C    112.0W     auto     400.0W     0%         0.0%      Normal
================================================================================================
======================================== End of SMI Log ========================================

# 重启驱动管理服务
systemctl restart hymgr
```


### 安装 kubernetes 组件

- 提交当前目录下 v2.3.0 下所有 mainifest
- 安装本目录下的 nfd 组件

```
helm install xpai-nfd -n kubegems-pai --create-namesapce nfd
```

## 监控数据

### 可用 labels

- Hostname： 设备所在物理机
- device： DCU 设备名称
- pod： 运行 DCU 的pod 名称
- container： 运行 DCU 的 Pod 中 container的名称
- namespace： 运行 DCU 的 pod 所在 namespace
- monitor_number： 当前 DCU 所在主机的顺序号

### 可用指标
- dcu_utilizationrate: DCU利用率 （百分比 0-100）
- dcu_temp： DCU 温度 （温度）
- dcu_memorycap_bytes： DCU 总显存 （单位 Byte）
- dcu_usedmemory_bytes： DCU 已使用显存  （单位 Byte）
- dcu_power_usage: DCU 功率  （单位 watte）
- dcu_pciebw_mb： PCIe 带宽 （单位 Mi）


- vdcu_utilizationrate： vDCU 利用率
- vdcu_usedmemory_bytes: vDCU 显存使用量
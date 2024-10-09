#!/bin/bash

# 更新后的路径
BASE_DIR="/opt/categraf"

# 配置文件路径
CONFIG_FILE="$BASE_DIR/conf/config.toml"
NVIDIA_SMI_CONFIG_FILE="$BASE_DIR/conf/input.nvidia_smi/nvidia_smi.toml"
EXPORTER_CONFIG_FILE="$BASE_DIR/conf/input.dcgm/exporter.toml"
EXEC_CONFIG_FILE="$BASE_DIR/conf/input.exec/exec.toml"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
  echo "配置文件 $CONFIG_FILE 不存在。"
  exit 1
fi

if [ ! -f "$NVIDIA_SMI_CONFIG_FILE" ]; then
  echo "配置文件 $NVIDIA_SMI_CONFIG_FILE 不存在。"
  exit 1
fi

if [ ! -f "$EXPORTER_CONFIG_FILE" ]; then
  echo "配置文件 $EXPORTER_CONFIG_FILE 不存在。"
  exit 1
fi

if [ ! -f "$EXEC_CONFIG_FILE" ]; then
  echo "配置文件 $EXEC_CONFIG_FILE 不存在。"
  exit 1
fi

# 检查是否安装 dcgmi 命令
if ! command -v dcgmi &> /dev/null; then
  echo "系统中未安装 dcgmi 命令，开始安装..."
  
  # 删除旧的 apt-key
  sudo apt-key del 7fa2af80
  
  # 获取系统版本信息
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
  
  # 下载并安装 CUDA keyring
  wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  
  # 更新 apt 源
  sudo apt-get update
  
  # 安装 datacenter-gpu-manager
  sudo apt-get install -y datacenter-gpu-manager
  
  # 启用和重启 nvidia-dcgm 服务
  sudo systemctl --now enable nvidia-dcgm
  sudo systemctl --now restart nvidia-dcgm
  
  echo "dcgmi 命令安装完成。"
fi

# 更新 config.toml 文件中的参数
sed -i 's|^file_name = "stdout"|file_name = "'"$BASE_DIR"'/logs/categraf.log"|' "$CONFIG_FILE"
sed -i 's|^\(url = \)".*prometheus/v1/write"$|\1"http://10.6.212.9:17000/prometheus/v1/write"|' "$CONFIG_FILE"
sed -i 's|^\(url = \)".*v1/n9e/heartbeat"$|\1"http://10.6.212.9:17000/v1/n9e/heartbeat"|' "$CONFIG_FILE"

echo "配置文件已更新：$CONFIG_FILE"

# 更新 nvidia_smi.toml 文件中的参数
sed -i 's|^nvidia_smi_command = ""|nvidia_smi_command = "nvidia-smi"|' "$NVIDIA_SMI_CONFIG_FILE"
sed -i 's|^# interval = 15|interval = 15|' "$NVIDIA_SMI_CONFIG_FILE"

echo "配置文件已更新：$NVIDIA_SMI_CONFIG_FILE"

# 更新 exporter.toml 文件中的参数
sed -i 's|^#\[\[instances\]\]|\[\[instances\]\]|' "$EXPORTER_CONFIG_FILE"
sed -i 's|^# collectors = "conf/input.dcgm/default-counters.csv"|collectors = "conf/input.dcgm/dcp-metrics-included.csv"|' "$EXPORTER_CONFIG_FILE"

echo "配置文件已更新：$EXPORTER_CONFIG_FILE"

# 更新 exec.toml 文件中的参数
sed -i 's|^# interval = 15|interval = 15|' "$EXEC_CONFIG_FILE"
sed -i 's|^\(commands = \[\)|\1\n    "'"$BASE_DIR"'/scripts/*.py"|' "$EXEC_CONFIG_FILE"
sed -i 's|^# data_format = "influx"|data_format = "prometheus"|' "$EXEC_CONFIG_FILE"

echo "配置文件已更新：$EXEC_CONFIG_FILE"

# # 新建日志目录和脚本目录
# LOGS_DIR="$BASE_DIR/logs"
# SCRIPTS_DIR="$BASE_DIR/scripts"

# mkdir -pv "$LOGS_DIR" "$SCRIPTS_DIR"

# echo "目录已创建：$LOGS_DIR 和 $SCRIPTS_DIR"

# 重启 Categraf 服务
echo "正在重启 Categraf 服务..."
sudo systemctl restart categraf

# 检查服务状态
echo "检查 Categraf 服务状态..."
sudo systemctl status categraf --no-pager

echo "Categraf 配置和重启完成。"

#!/bin/bash

# 定义Categraf安装目录
categraf_dir="/opt/categraf"
# 获取最新版本号
latest_version=$(curl -s https://api.github.com/repos/flashcatcloud/categraf/releases/latest | grep "tag_name" | cut -d '"' -f 4)
# 下载最新版本的Categraf链接
latest_url="https://github.com/flashcatcloud/categraf/releases/download/$latest_version/categraf-$latest_version-linux-amd64.tar.gz"

# 检查Categraf是否已经部署
if [ ! -d "$categraf_dir" ]; then
    echo "Categraf is not deployed. Downloading and deploying latest version..."
    # 创建目标目录并切换到目标目录
    mkdir -p "$categraf_dir" && cd "$categraf_dir" || { echo "Error: Failed to create or change directory." >&2; exit 1; }
    
    # 下载最新版本的Categraf并解压到指定目录
    wget -qO- "$latest_url" | tar xvz --strip-components=1 || { echo "Error: Failed to download or extract Categraf." >&2; exit 1; }
    echo "Categraf deployed successfully."

    # 使用新的 --install 命令安装服务
    sudo ./categraf --install || { echo "Error: Failed to install Categraf service." >&2; exit 1; }
    
    # 启动并设置 Categraf 服务为开机启动
    sudo systemctl start categraf
    sudo systemctl enable categraf
    echo "Categraf service is started and enabled on boot."
else
    echo "Categraf is already deployed. Checking for updates..."
    # 获取当前部署的Categraf版本
    current_version=$("$categraf_dir/categraf" --version | awk '{print $3}')
    
    # 检查是否是最新版本
    if [ "$current_version" != "$latest_version" ]; then
        echo "Updating Categraf from version $current_version to $latest_version..."
        # 使用 categraf --update命令更新到最新版本
        cd $categraf_dir
        ./categraf --update_url "$latest_url" --update || { echo "Error: Failed to update Categraf." >&2; exit 1; }
        echo "Categraf updated successfully."
    else
        echo "Categraf is already up to date."
    fi
fi

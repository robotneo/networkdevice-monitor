#!/bin/bash

# 定义Categraf安装目录
categraf_dir="/opt/categraf"
# 获取最新版本号
latest_version=$(curl -s https://api.github.com/repos/flashcatcloud/categraf/releases/latest | grep "tag_name" | cut -d '"' -f 4)
# 下载最新版本的Categraf链接
# latest_url="https://github.com/flashcatcloud/categraf/releases/download/$latest_version/categraf-$latest_version-linux-amd64.tar.gz"
latest_url="https://download.flashcat.cloud/categraf-$latest_version-linux-amd64.tar.gz"
# 定义下载文件的名称
categraf_archive="categraf-$latest_version-linux-amd64.tar.gz"

# 检查Categraf是否已经部署
if [ ! -d "$categraf_dir" ]; then
    echo "Categraf is not deployed. Downloading and deploying latest version..."
    
    # 创建目标目录
    mkdir -p "$categraf_dir" || { echo "Error: Failed to create directory $categraf_dir." >&2; exit 1; }

    # 下载文件到安装目录
    echo "Downloading Categraf $latest_version..."
    wget --show-progress "$latest_url" -O "$categraf_dir/$categraf_archive" || { echo "Error: Failed to download Categraf." >&2; exit 1; }

    # 切换到安装目录
    cd "$categraf_dir" || { echo "Error: Failed to change to directory $categraf_dir." >&2; exit 1; }

    # 解压下载的文件
    echo "Extracting Categraf..."
    tar -xzf "$categraf_archive" --strip-components=1 || { echo "Error: Failed to extract Categraf." >&2; exit 1; }

    # 清理下载的压缩文件
    rm "$categraf_archive"

    # 使用新的 --install 命令安装服务
    echo "Installing Categraf as a service..."
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

        # 下载新的版本
        wget --show-progress "$latest_url" -O "$categraf_dir/$categraf_archive" || { echo "Error: Failed to download new version." >&2; exit 1; }

        # 切换到安装目录
        cd "$categraf_dir" || { echo "Error: Failed to change to directory $categraf_dir." >&2; exit 1; }

        # 解压并更新
        tar -xzf "$categraf_archive" --strip-components=1 || { echo "Error: Failed to extract new version." >&2; exit 1; }

        # 清理下载的压缩文件
        rm "$categraf_archive"

        # 安装新版本
        sudo ./categraf --install || { echo "Error: Failed to update Categraf service." >&2; exit 1; }

        echo "Categraf updated successfully."
    else
        echo "Categraf is already up to date."
    fi
fi
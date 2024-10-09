#!/bin/bash

# 默认Categraf安装目录
default_dir="/opt/categraf"

# 提示用户输入安装目录
read -p "Please enter the installation directory for Categraf (default is /opt/categraf): " user_input

# 如果用户输入为空，则使用默认目录
categraf_dir="${user_input:-$default_dir}"

# 获取最新版本号
latest_version=$(curl -s https://api.github.com/repos/flashcatcloud/categraf/releases/latest | grep "tag_name" | cut -d '"' -f 4)
# 下载最新版本的Categraf特定包链接
latest_url="https://github.com/flashcatcloud/categraf/releases/download/$latest_version/categraf-$latest_version-linux-amd64-with-cgo-plugin.tar.gz"

# 检查Categraf是否已经部署
if [ ! -d "$categraf_dir" ]; then
    echo "Categraf is not deployed. Downloading and deploying latest version..."
    # 创建目标目录并切换到目标目录
    mkdir -p "$categraf_dir" && cd "$categraf_dir" || { echo "Error: Failed to create or change directory." >&2; exit 1; }
    # 下载最新版本的Categraf并解压到指定目录
    wget -qO- "$latest_url" | tar xvz --strip-components=1
    echo "Categraf deployed successfully in $categraf_dir."
    # 复制 categraf.service 到 /etc/systemd/system/ 并启动服务及设置开机自启动
    if [ -f "${categraf_dir}/conf/categraf.service" ]; then
        mv "${categraf_dir}/conf/categraf.service" /etc/systemd/system/
        systemctl daemon-reload
        systemctl start categraf
        systemctl enable categraf
        echo "Categraf service is started and enabled on boot."
    else
        echo "The categraf.service file does not exist. Please check the installation."
    fi
else
    echo "Categraf is already deployed in $categraf_dir. Checking for updates..."
    # 获取当前部署的Categraf版本
    current_version=$("$categraf_dir/categraf" --version | awk '{print $3}')
    # 检查是否是最新版本
    if [ "$current_version" != "$latest_version" ]; then
        echo "Updating Categraf from version $current_version to $latest_version..."
        # 使用categraf --update命令更新到最新版本
        cd $categraf_dir
        ./categraf --update_url $latest_url --update 
        echo "Categraf updated successfully to version $latest_version in $categraf_dir."
    else
        echo "Categraf is already up to date in $categraf_dir."
    fi
fi
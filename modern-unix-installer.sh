#!/bin/bash

# Complete Modern Unix Tools Installer
# Based on https://github.com/ibraheemdev/modern-unix
# Supports Ubuntu/Debian and CentOS/RHEL

set -e

# Check if running with sudo/root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

# Function to install packages
install_package() {
    local package_name="$1"
    local binary_name="${2:-$package_name}"
    local total="$3"
    local current="$4"
    
    # 添加调试信息
    log "正在处理包: $package_name (二进制名: $binary_name)"
    
    # 检查是否已安装
    check_installed "$package_name" "$binary_name"
    local install_status=$?
    
    if [ $install_status -eq 0 ]; then
        show_progress "跳过已安装的 $package_name" "$current" "$total"
        return 0
    fi
    
    show_progress "安装 $package_name" "$current" "$total"
    
    # 添加错误处理
    set +e  # 暂时禁用错误退出
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        log "使用 apt-get 安装 $package_name"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name" >/dev/null 2>>install.log
        local apt_status=$?
        if [ $apt_status -ne 0 ]; then
            log "警告: 安装 $package_name 失败 (状态码: $apt_status)"
            log "尝试更新包索引..."
            apt-get update >/dev/null 2>>install.log
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name" >/dev/null 2>>install.log
            apt_status=$?
            if [ $apt_status -ne 0 ]; then
                log "错误: 安装 $package_name 失败"
                return 1
            fi
        fi
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        log "使用 yum 安装 $package_name"
        yum install -y "$package_name" >/dev/null 2>>install.log
        local yum_status=$?
        if [ $yum_status -ne 0 ]; then
            log "错误: 安装 $package_name 失败"
            return 1
        fi
    fi
    
    set -e  # 重新启用错误退出
    
    log "成功安装 $package_name"
    return 0
}

# Function to add repository
add_repository() {
    local repo_name="$1"
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        if ! grep -q "^deb.*$repo_name" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            add-apt-repository -y "$repo_name"
        fi
    fi
}

# Add log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> install.log
}

# Add progress display function
show_progress() {
    echo -ne "\r\033[K$1 [$2/$3] "
}

echo "Setting up package managers and repositories..."

# Update package lists
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update
    apt-get install -y software-properties-common curl wget
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    yum check-update || true
    yum install -y epel-release curl wget
fi

# 添加 GitHub 代理支持
GITHUB_PROXY="https://ghproxy.net/"
GITHUB_TEST_URL="https://github.com/readme.md"

# 检查 GitHub 访问性并置代理
check_github_access() {
    log "检查 GitHub 访问情况..."
    if curl --connect-timeout 5 -sf "$GITHUB_TEST_URL" >/dev/null 2>&1; then
        log "GitHub 可以直接访问"
        GITHUB_PREFIX=""
    else
        log "GitHub 访问受限，使用代理"
        GITHUB_PREFIX="$GITHUB_PROXY"
    fi
}

# 检查并安装依赖
check_dependencies() {
    log "检查系统依赖..."
    
    # 只保留最基础的依赖
    local basic_deps="curl wget git tar gzip"
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update >/dev/null 2>&1
        for dep in $basic_deps; do
            if ! dpkg -l | grep -q "^ii  $dep "; then
                log "安装依赖: $dep"
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep" >/dev/null 2>>install.log
            fi
        done
        
        # 只安装必要的系统库
        local extra_deps="software-properties-common apt-transport-https ca-certificates"
        for dep in $extra_deps; do
            if ! dpkg -l | grep -q "^ii  $dep "; then
                log "安装额外依赖: $dep"
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep" >/dev/null 2>>install.log
            fi
        done
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum check-update >/dev/null 2>&1 || true
        for dep in $basic_deps; do
            if ! rpm -q "$dep" >/dev/null 2>&1; then
                log "安装依赖: $dep"
                yum install -y "$dep" >/dev/null 2>>install.log
            fi
        done
    fi
}

# 修改 Go 安装函数
install_go() {
    log "检查 Go 环境..."
    if command -v go >/dev/null 2>&1; then
        local go_version=$(go version | awk '{print $3}' | sed 's/go//')
        local required_version="1.21.7"
        if version_gt "$go_version" "$required_version"; then
            log "已安装的 Go 版本($go_version)满足要求"
            return 0
        fi
    fi
    
    log "安装 Go $required_version..."
    local go_url="${GITHUB_PREFIX}https://go.dev/dl/go${required_version}.linux-amd64.tar.gz"
    wget "$go_url" -O go.tar.gz || {
        log "Go 下载失败"
        return 1
    }
    rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    
    export PATH=$PATH:/usr/local/go/bin
    mkdir -p /usr/local/gobin
    export GOBIN=/usr/local/gobin
    export PATH=$PATH:/usr/local/gobin
}

# 版本比较函数
version_gt() {
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

# 修改 zoxide 安装函数
install_zoxide() {
    log "检查 zoxide..."
    if command -v zoxide >/dev/null 2>&1; then
        log "zoxide 已安装"
        return 0
    fi
    
    log "安装 zoxide..."
    # 方案一：使用预编译二进制
    local version="0.9.2"  # 更新到最新稳定版本
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        local zoxide_url="${GITHUB_PREFIX}https://github.com/ajeetdsouza/zoxide/releases/download/v${version}/zoxide_${version}_amd64.deb"
        curl -L "$zoxide_url" -o zoxide.deb && \
        dpkg -i zoxide.deb || {
            apt-get install -f -y
            dpkg -i zoxide.deb
        }
        rm -f zoxide.deb
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        local zoxide_url="${GITHUB_PREFIX}https://github.com/ajeetdsouza/zoxide/releases/download/v${version}/zoxide-${version}-x86_64.rpm"
        curl -L "$zoxide_url" -o zoxide.rpm && \
        rpm -i zoxide.rpm
        rm -f zoxide.rpm
    fi
    
    # 如果预编译包安装失败，尝试使用 cargo 安装
    if ! command -v zoxide >/dev/null 2>&1; then
        log "尝试通过 cargo 安装 zoxide..."
        if ! command -v cargo >/dev/null 2>&1; then
            log "安装 rust 和 cargo..."
            if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
                apt-get install -y cargo
            elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
                yum install -y cargo
            fi
        fi
        cargo install zoxide --locked
    fi
    
    # 配置 zoxide
    if command -v zoxide >/dev/null 2>&1; then
        log "配置 zoxide..."
        if ! grep -q "eval \"\$(zoxide init bash)\"" ~/.bashrc; then
            echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
        fi
    else
        log "zoxide 安装失败"
        return 1
    fi
}

# 使用预编译二进制安装 bottom
install_bottom() {
    log "检查 bottom..."
    if command -v btm >/dev/null 2>&1; then
        log "bottom 已安装"
        return 0
    fi
    
    log "安装 bottom..."
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        local bottom_url="${GITHUB_PREFIX}https://github.com/ClementTsang/bottom/releases/download/0.9.6/bottom_0.9.6_amd64.deb"
        curl -L "$bottom_url" -o bottom.deb && \
        dpkg -i bottom.deb || apt-get install -f -y
        rm -f bottom.deb
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        local bottom_url="${GITHUB_PREFIX}https://github.com/ClementTsang/bottom/releases/download/0.9.6/bottom-0.9.6-1.x86_64.rpm"
        curl -L "$bottom_url" -o bottom.rpm && \
        rpm -i bottom.rpm
        rm -f bottom.rpm
    fi
}

# 使用官方脚本安装 lazygit
install_lazygit() {
    log "检查 lazygit..."
    if command -v lazygit >/dev/null 2>&1; then
        log "lazygit 已安装"
        return 0
    fi
    
    log "安装 lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "${GITHUB_PREFIX}https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    install lazygit /usr/local/bin
    rm -f lazygit.tar.gz lazygit
}

# 使用预编译二进制安装 delta
install_delta() {
    log "检查 git-delta..."
    if command -v delta >/dev/null 2>&1; then
        log "git-delta 已安装"
        return 0
    fi
    
    log "安装 git-delta..."
    local version="0.16.5"
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        local delta_url="${GITHUB_PREFIX}https://github.com/dandavison/delta/releases/download/${version}/git-delta_${version}_amd64.deb"
        curl -L "$delta_url" -o delta.deb && \
        dpkg -i delta.deb
        rm -f delta.deb
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        local delta_url="${GITHUB_PREFIX}https://github.com/dandavison/delta/releases/download/${version}/git-delta-${version}-x86_64-unknown-linux-gnu.tar.gz"
        curl -L "$delta_url" | tar xz -C /usr/local/bin --strip-components=1 "delta-${version}-x86_64-unknown-linux-gnu/delta"
    fi
}

# 添加 glow 安装函数
install_glow() {
    log "检查 glow..."
    if command -v glow >/dev/null 2>&1; then
        log "glow 已安装"
        return 0
    fi
    
    log "安装 glow..."
    # 使用预编译二进制
    local version="1.5.1"  # 更新到最新稳定版本
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        local glow_url="${GITHUB_PREFIX}https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_amd64.deb"
        curl -L "$glow_url" -o glow.deb && \
        dpkg -i glow.deb || {
            apt-get install -f -y
            dpkg -i glow.deb
        }
        rm -f glow.deb
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        local glow_url="${GITHUB_PREFIX}https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_amd64.rpm"
        curl -L "$glow_url" -o glow.rpm && \
        rpm -i glow.rpm
        rm -f glow.rpm
    fi
    
    # 如果安装失败，尝试使用 Go 安装
    if ! command -v glow >/dev/null 2>&1; then
        log "尝试通过 Go 安装 glow..."
        if ! command -v go >/dev/null 2>&1; then
            install_go
        fi
        export GOPROXY=https://goproxy.cn,direct
        go install github.com/charmbracelet/glow@latest
    fi
}

# 修改主函数
main() {
    log "开始安装现代 Unix 工具..."
    
    # 系统检查
    check_system
    
    # 检查 GitHub 访问
    check_github_access
    
    # 检查并安装依赖
    check_dependencies
    
    # 询问用户是否要检查和修复配置
    read -p "是否检查并修复工具配置？[Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        check_and_configure || log "警告: 配置检查失败"
    fi
    
    # 安装选择的工具
    install_selected_tools || log "警告: 部分工具安装失败"
    
    # 最后再次检查配置
    check_and_configure || log "警告: 最终配置检查失败"
    
    log "安装和配置完成！"
}

# 修改工具安装函数
install_selected_tools() {
    echo "可用工具类别："
    echo "1) 文件操作工具"
    echo "   - bat (better cat)"
    echo "   - exa (better ls)"
    echo "   - fd-find (better find)"
    echo "   - ripgrep (better grep)"
    echo "2) 系统监控工具"
    echo "   - bottom (better top)"
    echo "   - duf (better df)"
    echo "   - ncdu (better du)"
    echo "3) 开发工具"
    echo "   - lazygit (git TUI)"
    echo "   - delta (better git diff)"
    echo "   - jq (JSON processor)"
    echo "   - fzf (fuzzy finder)"
    echo "4) 其他工具"
    echo "   - zoxide (better cd)"
    echo "   - tldr (better man)"
    echo "   - glow (markdown viewer)"
    echo "5) 全部安装"
    
    read -p "请选择要安装的类别 [1-5]: " choice
    
    case $choice in
        1) install_file_tools;;
        2) install_monitor_tools;;
        3) install_dev_tools;;
        4) install_other_tools;;
        5) install_all_tools;;
        *) echo "无效选择"; exit 1;;
    esac
}

# 分类安装函数
install_file_tools() {
    log "安装文件操作工具..."
    
    # 检查包管理器
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        # 确保软件源是最新的
        log "更新软件源..."
        apt-get update >/dev/null 2>>install.log || {
            log "警告: 软件源更新失败，继续安装..."
        }
    fi
    
    local tools="bat:batcat exa:exa fd-find:fdfind ripgrep:rg"
    install_tool_group "$tools"
    
    log "文件操作工具安装完成"
}

install_monitor_tools() {
    log "安装系统监控工具..."
    install_bottom
    local tools="duf:duf ncdu:ncdu"
    install_tool_group "$tools"
}

install_dev_tools() {
    log "安装开发工具..."
    install_lazygit
    install_delta
    local tools="jq:jq fzf:fzf"
    install_tool_group "$tools"
}

install_other_tools() {
    log "安装其他工具..."
    install_zoxide
    install_glow
    local tools="tldr:tldr"  # 移除 glow，因为我们单独安装它
    install_tool_group "$tools"
    log "其他工具安装完成"
}

install_all_tools() {
    log "开始全部安装..."
    install_file_tools
    install_monitor_tools
    install_dev_tools
    install_other_tools
    log "全部安装完成"
}

# 工具组安装函数
install_tool_group() {
    local tools="$1"
    local total=$(echo "$tools" | wc -w)
    local current=0
    
    log "开始安装工具组，共 $total 个工具"
    
    for tool_info in $tools; do
        ((current++))
        local package_name=${tool_info%:*}
        local binary_name=${tool_info#*:}
        
        log "处理第 $current/$total 个工具: $package_name"
        
        # 添加错误处理
        if ! install_package "$package_name" "$binary_name" "$total" "$current"; then
            log "警告: $package_name 安装失败，继续安装其他工具"
            continue
        fi
    done
}

# 添加软件检查函数
check_installed() {
    local package_name="$1"
    local binary_name="${2:-$package_name}"
    
    log "检查 $package_name..."
    
    # 首先检查命令是否可用
    if command -v "$binary_name" >/dev/null 2>&1; then
        log "$package_name 已安装"
        return 0
    fi
    
    # 如果命令不可用，检查包管理器
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        if dpkg -l | grep -q "^ii  $package_name "; then
            log "$package_name 已安装但可能需要配置"
            return 2
        fi
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        if rpm -q "$package_name" >/dev/null 2>&1; then
            log "$package_name 已安装但可能需要配置"
            return 2
        fi
    fi
    
    return 1
}

# 添加配置检查和设置函数
check_and_configure() {
    log "检查工具配置..."
    
    # 检查 bat 配置
    if check_installed "bat" "batcat"; then
        if [ ! -L "/usr/local/bin/bat" ] && [ -f "/usr/bin/batcat" ]; then
            log "配置 bat 命令链接"
            ln -sf /usr/bin/batcat /usr/local/bin/bat
        fi
    fi
    
    # 检查 fd 配置
    if check_installed "fd-find" "fdfind"; then
        if [ ! -L "/usr/local/bin/fd" ] && [ -f "/usr/bin/fdfind" ]; then
            log "配置 fd 命令链接"
            ln -sf /usr/bin/fdfind /usr/local/bin/fd
        fi
    fi
    
    # 检查 zoxide 配置
    if check_installed "zoxide"; then
        if ! grep -q "eval \"\$(zoxide init bash)\"" ~/.bashrc; then
            log "配置 zoxide 自动加载"
            echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
        fi
    fi
    
    # 检查 git-delta 配置
    if check_installed "git-delta" "delta"; then
        if ! git config --global --get-regexp "delta" >/dev/null 2>&1; then
            log "配置 git-delta"
            git config --global core.pager "delta"
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate true
            git config --global delta.line-numbers true
        fi
    fi
}

# Add system check function
check_system() {
    # Check memory
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 1024 ]; then
        log "警告: 系统内存小于1GB (${total_mem}MB)"
        read -p "是否继续安装? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check disk space
    local free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 1024 ]; then
        log "警告: 根分区空间小于1GB (${free_space}MB)"
        read -p "是否继续安装? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 设置错误处理
trap 'echo "安装过程中断，请检查 install.log 文件"; cleanup; exit 1' ERR

# 执行主程序
main

# 如果需要在最后显示安装总结
echo -e "\n已安装的工具:"
echo "- bat (better cat)"
echo "- exa (better ls)"
echo "- fd-find (better find)"
echo "- ripgrep (better grep)"
echo "- htop/btop (better top)"
echo "- duf (better df)"
echo "- ncdu (better du)"
echo "- jq (JSON processor)"
echo "- fzf (fuzzy finder)"
echo "- zoxide (better cd)"
echo "- lazygit (better git)"
echo "- glow (markdown viewer)"
echo "- bottom (better top/htop)"
echo "- git-delta (better git diff)"
echo "- hyperfine (benchmark)"
echo "- tldr (better man)"
echo "- neofetch (system info)"
echo "- shfmt (shell formatter)"

echo -e "\n使用提示:"
echo "1. 登出并重新登录以使所有更改生效"
echo "2. 或者执行: source ~/.bashrc"

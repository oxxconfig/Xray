#!/usr/bin/env bash
# =============================================================================
# Xray 批量静默部署前置脚本
# =============================================================================

# 1. 严格权限断言 (彻底废除无意义的 sudo)
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[31m[错误] 请使用 root 用户或 sudo 运行此脚本！\033[0m"
    exit 1
fi

# 2. 全局环境变量压制（全面禁绝弹窗交互）
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# 3. 备份原始参数，防止 while 消费导致更新功能丢失参数
ORIGINAL_ARGS=("$@")

readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly RED='\033[31m'
readonly NC='\033[0m'

readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
readonly CUR_FILE="$(basename "$0")"

readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json"

declare PROJECT_ROOT=''
declare CORE_DIR=''
declare QUICK_INSTALL=''
declare LANG_PARAM='--lang=zh'
declare FORCE_CHECK_DEPS=0

function _os() {
    if [[ -f "/etc/debian_version" ]]; then
        local os_id
        os_id=$(grep -oP '^ID=\K\w+' /etc/os-release 2>/dev/null || echo "ubuntu")
        printf -- "%s" "${os_id}"
        return
    fi
    [[ -f "/etc/redhat-release" ]] && printf -- "centos" && return
    printf -- "ubuntu"
}

# 优化系统内核与防火墙
function init_env_optimization() {
    echo -e "${GREEN}[基础配置]${NC} 开始优化系统内核与防火墙规则..."
    
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/et.core.default_qdisc/d' /etc/sysctl.conf

    cat << 'EOF' >> /etc/sysctl.conf

# Network Optimization By Xray Deployer
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p >/dev/null 2>&1

    if type iptables >/dev/null 2>&1; then
        if ! iptables -L INPUT -n 2>/dev/null | grep -q "dpt:443"; then
            iptables -I INPUT -p tcp --dport 443 -j ACCEPT
            echo -e "${GREEN}[基础配置]${NC} 防火墙已放行 TCP 443 端口"
            
            # 持久化规则保存
            if type iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables.rules 2>/dev/null || true
            fi
            if type netfilter-persistent >/dev/null 2>&1; then
                netfilter-persistent save >/dev/null 2>&1 || true
            fi
        else
            echo -e "${GREEN}[基础配置]${NC} 防火墙 TCP 443 端口规则已存在，跳过配置"
        fi
    fi
}

function check_dependencies() {
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    local missing=0

    if [[ "$(_os)" == "centos" ]]; then
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        for pkg in "${packages[@]}"; do
            rpm -q "$pkg" &>/dev/null || missing=$((missing+1))
        done
    else
        if apt-cache show bsdextrautils &>/dev/null; then
            packages+=("cron" "bsdextrautils" "iproute2" "procps" "dnsutils")
        else
            packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        fi

        for pkg in "${packages[@]}"; do
            dpkg -s "$pkg" &>/dev/null || missing=$((missing+1))
        done
    fi

    if [ $missing -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

function install_dependencies() {
    if [[ "$(_os)" == "centos" ]]; then
        local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat" "crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        if type dnf >/dev/null 2>&1; then
            dnf update -y && dnf install -y dnf-plugins-core
            for pkg in "${packages[@]}"; do dnf install -y "${pkg}"; done
        else
            yum update -y && yum install -y epel-release yum-utils
            for pkg in "${packages[@]}"; do yum install -y "${pkg}"; done
        fi
    else

        apt-get update -y -o Acquire::Retries=3 -o Acquire::http::Timeout=10
        
        local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat" "cron" "iproute2" "procps" "dnsutils")
        if apt-cache show bsdextrautils &>/dev/null; then
            packages+=("bsdextrautils")
        else
            packages+=("bsdmainutils")
        fi
        
        for pkg in "${packages[@]}"; do
            apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "${pkg}"
        done
    fi
}


function download_github_files() {
    local target_dir="$1"
    local github_api_url="$2"
    
    mkdir -p "${target_dir}"
    cd "${target_dir}" || exit 1
    echo -e "${GREEN}[下载核心]${NC} 正在拉取：${github_api_url}"
    
    rm -f temp_archive.tar.gz
    if ! curl -sLo temp_archive.tar.gz "${github_api_url}"; then
        echo -e "${RED}[错误]${NC} 下载主程序核心失败，请检查 VPS 网络！"
        exit 1
    fi
    
    if ! tar -xzf temp_archive.tar.gz --no-same-owner 2>/dev/null; then
        echo -e "${RED}[错误]${NC} 核心包解压失败，下载的文件可能损坏或不完整！"
        rm -f temp_archive.tar.gz
        exit 1
    fi
    
    local root_dir
    root_dir=$(tar -tzf temp_archive.tar.gz | head -1 | cut -f1 -d'/')
    
    if [[ -n "${root_dir}" && -d "${root_dir}" ]]; then
        cp -r "${root_dir}"/* ./ 2>/dev/null || true
        rm -rf "${root_dir}"
    fi
    rm -f temp_archive.tar.gz
}

function download_xray_script_files() {
    download_github_files "$1" "https://github.com/oxxconfig/Xray/archive/refs/heads/main.tar.gz"
}

function check_xray_script_version() {
    local script_config_github_url="https://raw.githubusercontent.com/oxxconfig/Xray/main/config.json"
    local local_version remote_version
    local_version="$(jq -r '.version' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "0.0.0")"
    remote_version="$(curl -fsSL --connect-timeout 5 "$script_config_github_url" | jq -r '.version' 2>/dev/null || echo "0.0.0")"

    if [[ "${local_version}" != "${remote_version}" && "${remote_version}" != "0.0.0" ]]; then
        echo -e "${GREEN}[更新提示]${NC} 检测到新版本，自动同步中..."
        cd "${HOME}" || exit 1
        local temp_dir="${SCRIPT_CONFIG_DIR}/xray-script-temp"
        mkdir -p "${temp_dir}"
        download_xray_script_files "${temp_dir}"
        
        # 引入安全根目录校验保护
        if [[ -n "${PROJECT_ROOT}" && "${PROJECT_ROOT}" != "/" && "${PROJECT_ROOT}" != "/root" ]]; then
            rm -rf "${PROJECT_ROOT}"
        fi
        
        mv -f "${temp_dir}" "${PROJECT_ROOT}"
        rm -f "${CUR_DIR}/${CUR_FILE}"
        cp -f "${PROJECT_ROOT}/install.sh" "${CUR_DIR}/${CUR_FILE}"
        sed -i "s|${local_version}|${remote_version}|" "${SCRIPT_CONFIG_PATH}" 2>/dev/null
        echo -e "${GREEN}[更新提示]${NC} 更新完成，正在恢复参数重新载入..."
        
        exec bash "${CUR_DIR}/${CUR_FILE}" "${ORIGINAL_ARGS[@]}"
    fi
}

function main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --vision | --xhttp | --fallback) QUICK_INSTALL="${1}" ;;
        -d) shift; PROJECT_ROOT="${1}" ;;
        esac
        shift
    done

    init_env_optimization

    if check_dependencies; then
        echo -e "${GREEN}[基础配置]${NC} 检测到核心环境依赖已完整，跳过安装"
    else
        echo -e "${YELLOW}[基础配置]${NC} 正在补全系统核心环境依赖..."
        install_dependencies
    fi

    if [[ ! -d "${SCRIPT_CONFIG_DIR}" ]]; then mkdir -p "${SCRIPT_CONFIG_DIR}"; fi

    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        wget --timeout=10 -O "${SCRIPT_CONFIG_PATH}" https://raw.githubusercontent.com/oxxconfig/Xray/main/config.json || \
        echo '{"version":"2026.03.17","language":"zh","path":"/usr/local/xray-script"}' > "${SCRIPT_CONFIG_PATH}"
    fi

    local script_path
    script_path="$(jq -r '.path' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "")"
    if [[ -z "${script_path}" && -z "${PROJECT_ROOT}" ]]; then
        PROJECT_ROOT='/usr/local/xray-script'
        local json_payload
        json_payload=$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)
        [[ -n "${json_payload}" ]] && echo "${json_payload}" >"${SCRIPT_CONFIG_PATH}"
    elif [[ -n "${script_path}" ]]; then
        PROJECT_ROOT="${script_path}"
    fi

    if [[ -z "${PROJECT_ROOT}" || "${PROJECT_ROOT}" == "/" || "${PROJECT_ROOT}" == "/usr" || "${PROJECT_ROOT}" == "/root" || "${PROJECT_ROOT}" == "/home" ]]; then
        echo -e "${RED}[核心防御] 安全熔断：PROJECT_ROOT 路径异常 (${PROJECT_ROOT})，拒绝执行 rm -rf！\033[0m"
        exit 1
    fi

    CORE_DIR="${PROJECT_ROOT}/core"

    if [[ -d "${PROJECT_ROOT}" && -f "${CORE_DIR}/main.sh" ]]; then
        check_xray_script_version "${ORIGINAL_ARGS[@]}"
    else
        rm -rf "${PROJECT_ROOT}"
        download_xray_script_files "${PROJECT_ROOT}"
    fi

    local json_lang
    json_lang=$(jq --arg language "zh" '.language = $language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)
    [[ -n "${json_lang}" ]] && echo "${json_lang}" >"${SCRIPT_CONFIG_PATH}"

    if [ -f "${CORE_DIR}/main.sh" ]; then
        local target_rcs=("${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile")
        for rc in "${target_rcs[@]}"; do
            if [[ -f "${rc}" || "${rc}" == "${HOME}/.bashrc" ]]; then
                sed -i '/alias xray=/d' "${rc}" 2>/dev/null || true
                echo "alias xray='bash ${CORE_DIR}/main.sh'" >> "${rc}"
            fi
        done
    fi

    echo -e "${GREEN}[部署完成]${NC} 前置依赖与系统优化已就绪，正在唤起 Xray 主内核业务脚本..."
    echo "--------------------------------------------------------"
    
    exec bash "${CORE_DIR}/main.sh" "${QUICK_INSTALL}"
}

main "${ORIGINAL_ARGS[@]}"

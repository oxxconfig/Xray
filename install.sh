#!/usr/bin/env bash
# =============================================================================
# 脚本名称: deploy.sh (集成一键自动化部署版)
# 融合功能: 1. 基础环境配置 (BBR加速/内核优化/防火墙)
#           2. Xray-script 官方引导与全自动依赖安装 (免交互)
# 适用系统: Ubuntu 16+, Debian 9+, CentOS 7+
# =============================================================================

# 开启严格错误追踪模式
set -euo pipefail

# --- 1. 全局环境变量压制（全面禁绝弹窗交互） ---
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# 常量设置
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly RED='\033[31m'
readonly NC='\033[0m'

readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
readonly CUR_FILE="$(basename "$0")"

readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json"

# 全局变量声明
declare -A I18N_DATA=(
    ['error']='错误'
    ['root']='请使用 root 权限运行该脚本'
    ['supported']='不支持当前系统，请切换到 Ubuntu 16+、Debian 9+、CentOS 7+'
    ['ubuntu']='不支持当前版本，请切换到 Ubuntu 16+ 重试'
    ['debian']='不支持当前版本，请切换到 Debian 9+ 重试'
    ['centos']='不支持当前版本，请切换到 CentOS 7+ 重试'
    ['tip']='更新提示'
    ['new']='发现有新脚本, 是否更新'
    ['now']='是否更新 [Y/n] '
    ['promptly']='请及时更新脚本'
    ['completed']='更新完成'
    ['download']='正在下载'
    ['failed']='下载失败'
    ['downloaded']='文件已下载到'
)
declare PROJECT_ROOT=''
declare I18N_DIR=''
declare CORE_DIR=''
declare SERVICE_DIR=''
declare CONFIG_DIR=''
declare TOOL_DIR=''
declare QUICK_INSTALL=''
declare SCRIPT_CONFIG=''
declare LANG_PARAM='--lang=zh' # 默认锁死中文，拒绝语言选择弹窗交互
declare FORCE_CHECK_DEPS=0

# =============================================================================
# 新增函数: init_env_optimization (融合原脚本前三步)
# =============================================================================
function init_env_optimization() {
    echo -e "${GREEN}[基础配置]${NC} 开始优化系统内核与防火墙规则..."
    
    # 第一步：安装基础组件 (对 Dpkg 强制套用默认配置，不因冲突卡死)
    if [[ "$(_os)" == "ubuntu" || "$(_os)" == "debian" ]]; then
        apt-get update -y
        apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" wget curl
    fi

    # 第二步：开启 TCP BBR 加速与 FQ 队列 (防重复追加)
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        printf "\n# Network Optimization\net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n" >> /etc/sysctl.conf
        sysctl -p >/dev/null
        echo -e "${GREEN}[基础配置]${NC} TCP BBR 拥塞控制算法已成功开启"
    fi

    # 第三步：配置防火墙放行规则 (防重复添加)
    if cmd_exists "iptables"; then
        if ! iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p tcp --dport 443 -j ACCEPT
            echo -e "${GREEN}[基础配置]${NC} 防火墙已放行 TCP 443 端口"
        fi
    fi
}

function _os() {
    local os=""
    if [[ -f "/etc/debian_version" ]]; then
        source /etc/os-release && os="${ID}"
        printf -- "%s" "${os}" && return
    fi
    if [[ -f "/etc/redhat-release" ]]; then
        os="centos"
        printf -- "%s" "${os}" && return
    fi
}

function _os_full() {
    if [[ -f /etc/redhat-release ]]; then
        awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    fi
    if [[ -f /etc/os-release ]]; then
        awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    fi
    if [[ -f /etc/lsb-release ]]; then
        awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
    fi
}

function _os_ver() {
    local main_ver="$(echo $(_os_full) | grep -oE "[0-9.]+")"
    printf -- "%s" "${main_ver%%.*}"
}

function cmd_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
}

function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --lang=*)
            LANG_PARAM="${1}"
            ;;
        --check-deps)
            FORCE_CHECK_DEPS=1
            ;;
        esac
        shift
    done
}

function load_i18n() {
    local lang="${LANG_PARAM#*=}"
    if [[ -z "${lang}" && -f "${SCRIPT_CONFIG_PATH}" ]]; then
        if cmd_exists "jq"; then
            lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)"
        fi
    fi
    if [[ "$lang" == "auto" ]]; then
        lang=$(echo "$LANG" | cut -d'_' -f1)
    fi
    if [[ "$lang" == "en" ]]; then
        I18N_DATA=(
            ['error']='Error' ['root']='This script must be run as root'
            ['supported']='Not supported OS' ['ubuntu']='Not supported OS, please change to Ubuntu 18+.'
            ['debian']='Not supported OS, please change to Debian 9+.' ['centos']='Not supported OS, please change to CentOS 7+.'
            ['tip']='Update Notice' ['new']='A new version is available. Update?'
            ['now']='Update now? [Y/n]' ['promptly']='Please update the script promptly.'
            ['completed']='Update completed' ['download']='Downloading'
            ['failed']='Download failed' ['downloaded']='The file has been downloaded to'
        )
    fi
}

function _error() {
    printf "${RED}[${I18N_DATA['error']}] ${NC}"
    printf -- "%s" "$@"
    printf "\n"
    exit 1
}

function check_os() {
    case "$(_os)" in
    centos)
        if [[ "$(_os_ver)" -lt 7 ]]; then _error "${I18N_DATA['centos']}"; fi
        ;;
    ubuntu)
        if [[ "$(_os_ver)" -lt 16 ]]; then _error "${I18N_DATA['ubuntu']}"; fi
        ;;
    debian)
        if [[ "$(_os_ver)" -lt 9 ]]; then _error "${I18N_DATA['debian']}"; fi
        ;;
    *)
        _error "${I18N_DATA['supported']}"
        ;;
    esac
}

function check_dependencies() {
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    local missing_packages=()
    case "$(_os)" in
    centos)
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then missing_packages+=("$pkg"); fi
        done
        ;;
    debian | ubuntu)
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" &>/dev/null; then missing_packages+=("$pkg"); fi
        done
        ;;
    esac
    [[ ${#missing_packages[@]} -eq 0 ]]
}

function install_dependencies() {
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    case "$(_os)" in
    centos)
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        if cmd_exists "dnf"; then
            dnf update -y
            dnf install -y dnf-plugins-core
            dnf update -y
            for pkg in "${packages[@]}"; do dnf install -y ${pkg}; done
        else
            yum update -y
            yum install -y epel-release yum-utils
            yum update -y
            for pkg in "${packages[@]}"; do yum install -y ${pkg}; done
        fi
        ;;
    ubuntu | debian)
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        apt-get update -y
        for pkg in "${packages[@]}"; do
            apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ${pkg}
        done
        ;;
    esac
}

function download_github_files() {
    local target_dir="$1"
    local github_api_url="$2"
    mkdir -p "${target_dir}"
    cd "${target_dir}"
    echo -e "${GREEN}[${I18N_DATA['download']}]${NC} ${github_api_url}"
    # 全自动非交互下载安装
    if ! curl -sL "${github_api_url}" | tar xz --strip-components=1; then
        _error "${I18N_DATA['failed']}: ${github_api_url}"
    fi
}

function download_xray_script_files() {
    local target_dir="$1"
    local script_github_api="https://api.github.com/repos/zxcvos/xray-script/tarball/main"
    download_github_files "${target_dir}" "${script_github_api}"
}

# =============================================================================
# 优化更新函数: 剥离全自动运行中阻塞的 read 确认弹窗
# =============================================================================
function check_xray_script_version() {
    local script_config_github_url="https://raw.githubusercontent.com/oxxconfig/Xray/main/config.json"
    local local_version
    local_version="$(jq -r '.version' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "0.0.0")"
    
    local remote_version
    remote_version="$(curl -fsSL --connect-timeout 5 "$script_config_github_url" | jq -r '.version' 2>/dev/null || echo "0.0.0")"

    if [[ "${local_version}" != "${remote_version}" && "${remote_version}" != "0.0.0" ]]; then
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} 检测到脚本新版本，一键自动更新中..."
        cd "${HOME}"
        readonly temp_dir="${SCRIPT_CONFIG_DIR}/xray-script-temp"
        mkdir -p "${temp_dir}"
        download_xray_script_files "${temp_dir}"
        rm -rf "${PROJECT_ROOT}"
        mv -f "${temp_dir}" "${PROJECT_ROOT}"
        rm -f "${CUR_DIR}/${CUR_FILE}"
        cp -f "${PROJECT_ROOT}/install.sh" "${CUR_DIR}/${CUR_FILE}"
        sed -i "s|${local_version}|${remote_version}|" "${SCRIPT_CONFIG_PATH}" 2>/dev/null || true
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['completed']}"
        # 重新执行
        bash "${CUR_DIR}/${CUR_FILE}" "$@"
        exit 0
    fi
}

function main() {
    parse_args "$@"
    load_i18n

    # 1. Root 权限断言
    [[ $EUID -ne 0 ]] && _error "${I18N_DATA['root']}"

    # 2. 系统平台检查
    check_os

    # 3. 执行前三步的环境核心优化 (BBR/FQ/防火墙端口放行)
    init_env_optimization

    # 4. 依赖项前置全自动安装
    local is_first_run=0
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then is_first_run=1; fi

    if [[ "${is_first_run}" -eq 1 || "${FORCE_CHECK_DEPS}" -eq 1 ]]; then
        if ! check_dependencies; then install_dependencies; fi
        if ! check_dependencies; then install_dependencies; fi
    fi

    if [[ ! -d "${SCRIPT_CONFIG_DIR}" ]]; then mkdir -p "${SCRIPT_CONFIG_DIR}"; fi
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        wget --timeout=10 -O "${SCRIPT_CONFIG_PATH}" https://raw.githubusercontent.com/zxcvos/Xray-script/main/config.json || echo '{"version":"1.0.0","language":"zh","path":"/usr/local/xray-script"}' > "${SCRIPT_CONFIG_PATH}"
    fi

    # 处理其余自定义参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --vision | --xhttp | --fallback) QUICK_INSTALL="${1}" ;;
        -d) shift; PROJECT_ROOT="${1}" ;;
        esac
        shift
    done

    local script_path
    script_path="$(jq -r '.path' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "")"
    if [[ -z "${script_path}" && -z "${PROJECT_ROOT}" ]]; then
        PROJECT_ROOT='/usr/local/xray-script'
        SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}"
    elif [[ -n "${script_path}" ]]; then
        PROJECT_ROOT="${script_path}"
    elif [[ -n "${PROJECT_ROOT}" ]]; then
        SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}"
    fi

    I18N_DIR="${PROJECT_ROOT}/i18n"
    CORE_DIR="${PROJECT_ROOT}/core"
    SERVICE_DIR="${PROJECT_ROOT}/service"
    CONFIG_DIR="${PROJECT_ROOT}/config"
    TOOL_DIR="${PROJECT_ROOT}/tool"

    # 5. 下载或更新核心框架文件
    if [[ -d "${PROJECT_ROOT}" ]]; then
        check_xray_script_version "$@"
    else
        download_xray_script_files "${PROJECT_ROOT}"
    fi

    # 6. 强制静默写入语言配置 (防止 menu.sh 弹出选择语言交互菜单)
    local lang
    lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "")"
    if [[ -z "${lang}" ]]; then
        LANG_PARAM="zh"
        SCRIPT_CONFIG="$(jq --arg language "${LANG_PARAM}" '.language = $language' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}"
    fi

    echo -e "${GREEN}[部署完成]${NC} 前置依赖与系统优化已就绪，正在唤起 Xray 主内核业务脚本..."
    
    # 7. 启动主业务脚本
    exec bash "${CORE_DIR}/main.sh" "${QUICK_INSTALL}"
}

# 脚本入口执行
main "$@"
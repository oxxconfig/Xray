cat << 'EOF' > install.sh
#!/usr/bin/env bash
# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "[错误] 请使用 root 用户或 sudo 运行此脚本！"
    exit 1
fi

# 全局环境变量压制（全面禁绝弹窗交互）
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly RED='\033[31m'
readonly NC='\033[0m'

readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
readonly CUR_FILE="$(basename "$0")"

readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json"

declare -A I18N_DATA=(
    ['error']='错误' ['root']='请使用 root 权限运行该脚本'
    ['supported']='不支持当前系统' ['ubuntu']='不支持当前版本'
    ['debian']='不支持当前版本' ['centos']='不支持当前版本'
    ['tip']='更新提示' ['new']='发现有新脚本, 是否更新'
    ['now']='是否更新 [Y/n] ' ['promptly']='请及时更新脚本'
    ['completed']='更新完成' ['download']='正在下载'
    ['failed']='下载失败' ['downloaded']='文件已下载到'
)
declare PROJECT_ROOT=''
declare I18N_DIR=''
declare CORE_DIR=''
declare SERVICE_DIR=''
declare CONFIG_DIR=''
declare TOOL_DIR=''
declare QUICK_INSTALL=''
declare SCRIPT_CONFIG=''
declare LANG_PARAM='--lang=zh'
declare FORCE_CHECK_DEPS=0

function init_env_optimization() {
    echo -e "${GREEN}[基础配置]${NC} 开始优化系统内核与防火墙规则..."
    
    if [[ "$(_os)" == "ubuntu" || "$(_os)" == "debian" ]]; then
        apt-get update -y
        apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" wget curl
    fi

    sudo sed -i '/et.core.default_qdisc/d' /etc/sysctl.conf

    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        sudo cat << 'EOF2' >> /etc/sysctl.conf

# Network Optimization
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF2
    fi
    sudo sysctl -p >/dev/null 2>&1

    if type iptables >/dev/null 2>&1; then
        if ! iptables -L INPUT -n 2>/dev/null | grep -q "dpt:443"; then
            iptables -I INPUT -p tcp --dport 443 -j ACCEPT
            echo -e "${GREEN}[基础配置]${NC} 防火墙已放行 TCP 443 端口"
        else
            echo -e "${GREEN}[基础配置]${NC} 防火墙 TCP 443 端口规则已存在，跳过配置"
        fi
    fi
}

function _os() {
    if [[ -f "/etc/debian_version" ]]; then
        local os_id=$(grep -oP '^ID=\K\w+' /etc/os-release 2>/dev/null || echo "ubuntu")
        printf -- "%s" "${os_id}"
        return
    fi
    if [[ -f "/etc/redhat-release" ]]; then
        printf -- "centos"
        return
    fi
    printf -- "ubuntu"
}

function _os_full() {
    if [[ -f /etc/redhat-release ]]; then
        awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    fi
    if [[ -f /etc/os-release ]]; then
        awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    fi
}

function _os_ver() {
    local main_ver="$(echo $(_os_full) | grep -oE "[0-9.]+")"
    printf -- "%s" "${main_ver%%.*}"
}

function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --lang=*) LANG_PARAM="${1}" ;;
        --check-deps) FORCE_CHECK_DEPS=1 ;;
        esac
        shift
    done
}

function check_os() {
    local cur_os="$(_os)"
    if [[ "${cur_os}" != "ubuntu" && "${cur_os}" != "debian" && "${cur_os}" != "centos" ]]; then
         echo -e "${YELLOW}[提示]${NC} 系统识别可能存在偏差，跳过硬性拦截继续执行..."
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
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        for pkg in "${packages[@]}"; do
            dpkg -s "$pkg" &>/dev/null || missing=$((missing+1))
        done
    fi
    return ${missing}
}

function install_dependencies() {
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    if [[ "$(_os)" == "centos" ]]; then
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        if type dnf >/dev/null 2>&1; then
            dnf update -y && dnf install -y dnf-plugins-core
            for pkg in "${packages[@]}"; do dnf install -y ${pkg}; done
        else
            yum update -y && yum install -y epel-release yum-utils
            for pkg in "${packages[@]}"; do yum install -y ${pkg}; done
        fi
    else
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        apt-get update -y
        for pkg in "${packages[@]}"; do
            apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ${pkg}
        done
    fi
}

function download_github_files() {
    local target_dir="$1"
    local github_api_url="$2"
    mkdir -p "${target_dir}"
    cd "${target_dir}"
    echo -e "${GREEN}[${I18N_DATA['download']}]${NC} ${github_api_url}"
    
    rm -f temp_archive.tar.gz
    if ! curl -sLo temp_archive.tar.gz "${github_api_url}"; then
        echo -e "${RED}[错误]${NC} 下载主程序核心失败，请检查网络！"
        exit 1
    fi
    
    tar -xzf temp_archive.tar.gz --no-same-owner >/dev/null 2>&1
    if [ -d "Xray-main" ]; then
        cp -r Xray-main/* ./ 2>/dev/null
        rm -rf Xray-main
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
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} 检测到新版本，自动同步中..."
        cd "${HOME}"
        local temp_dir="${SCRIPT_CONFIG_DIR}/xray-script-temp"
        mkdir -p "${temp_dir}"
        download_xray_script_files "${temp_dir}"
        rm -rf "${PROJECT_ROOT}"
        mv -f "${temp_dir}" "${PROJECT_ROOT}"
        rm -f "${CUR_DIR}/${CUR_FILE}"
        cp -f "${PROJECT_ROOT}/install.sh" "${CUR_DIR}/${CUR_FILE}"
        sed -i "s|${local_version}|${remote_version}|" "${SCRIPT_CONFIG_PATH}" 2>/dev/null
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} 更新完成，重新载入..."
        exec bash "${CUR_DIR}/${CUR_FILE}" "$@"
    fi
}

function main() {
    parse_args "$@"
    check_os
    init_env_optimization

    check_dependencies
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}[基础配置]${NC} 正在补全系统核心环境依赖..."
        install_dependencies
    else
        echo -e "${GREEN}[基础配置]${NC} 检测到核心环境依赖已完整，跳过安装"
    fi

    if [[ ! -d "${SCRIPT_CONFIG_DIR}" ]]; then mkdir -p "${SCRIPT_CONFIG_DIR}"; fi

    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        wget --timeout=10 -O "${SCRIPT_CONFIG_PATH}" https://raw.githubusercontent.com/oxxconfig/Xray/main/config.json || \
        echo '{"version":"2026.03.17","language":"zh","path":"/usr/local/xray-script"}' > "${SCRIPT_CONFIG_PATH}"
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --vision | --xhttp | --fallback) QUICK_INSTALL="${1}" ;;
        -d) shift; PROJECT_ROOT="${1}" ;;
        esac
        shift
    done

    local script_path="$(jq -r '.path' "${SCRIPT_CONFIG_PATH}" 2>/dev/null || echo "")"
    if [[ -z "${script_path}" ]]; then
        PROJECT_ROOT='/usr/local/xray-script'
        local json_payload=$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)
        [[ -n "${json_payload}" ]] && echo "${json_payload}" >"${SCRIPT_CONFIG_PATH}"
    else
        PROJECT_ROOT="${script_path}"
    fi

    CORE_DIR="${PROJECT_ROOT}/core"

    if [[ -d "${PROJECT_ROOT}" && -f "${CORE_DIR}/main.sh" ]]; then
        check_xray_script_version "$@"
    else
        download_xray_script_files "${PROJECT_ROOT}"
    fi

    local json_lang=$(jq --arg language "zh" '.language = $language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)
    [[ -n "${json_lang}" ]] && echo "${json_lang}" >"${SCRIPT_CONFIG_PATH}"

    if [ -f "${CORE_DIR}/main.sh" ]; then
        sed -i '/alias xray=/d' ~/.bashrc
        echo "alias xray='bash ${CORE_DIR}/main.sh'" >> ~/.bashrc
    fi

    echo -e "${GREEN}[部署完成]${NC} 前置依赖与系统优化已就绪，正在唤起 Xray 主内核业务脚本..."
    exec bash "${CORE_DIR}/main.sh" "${QUICK_INSTALL}"
}

main "$@"
EOF
sed -i 's/\r$//' install.sh && rm -rf /usr/local/xray-script && bash install.sh

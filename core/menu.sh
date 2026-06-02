#!/usr/bin/env bash
#
# --- 环境与常量设置 ---
# 将常用路径添加到 PATH 环境变量，确保脚本能在不同环境中找到所需命令
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# 定义颜色代码，用于在终端输出带颜色的信息
readonly GREEN='\033[32m'  # 绿色
readonly YELLOW='\033[33m' # 黄色
readonly RED='\033[31m'    # 红色
readonly NC='\033[0m'      # 无颜色（重置）

# 获取当前脚本的目录、文件名（不含扩展名）和项目根目录的绝对路径
readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)" # 当前脚本所在目录
readonly CUR_FILE="$(basename "$0" | sed 's/\..*//')"         # 当前脚本文件名 (不含扩展名)
readonly PROJECT_ROOT="$(cd -P -- "${CUR_DIR}/.." && pwd -P)" # 项目根目录

# 定义配置文件和相关目录的路径
readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"              # 主配置文件目录
readonly I18N_DIR="${PROJECT_ROOT}/i18n"                       # 国际化文件目录
readonly CONFIG_DIR="${PROJECT_ROOT}/config"                   # 配置文件目录
readonly GENERATE_PATH="${CUR_DIR}/generate.sh"                # 项目中的 generate.sh 脚本路径
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json" # 脚本主要配置文件路径

# --- 全局变量声明 ---
# 声明用于存储语言参数和国际化数据的全局变量
declare LANG_PARAM='' # (未在脚本中实际使用，可能是预留)
declare I18N_DATA=''  # 存储从 i18n JSON 文件中读取的全部数据

# =============================================================================
# 函数名称: load_i18n
# 功能描述: 加载国际化 (i18n) 数据。
#           1. 从 config.json 读取语言设置。
#           2. 如果设置为 "auto"，则尝试从系统环境变量 $LANG 推断语言。
#           3. 根据确定的语言，加载对应的 JSON i18n 文件。
#           4. 将文件内容读入全局变量 I18N_DATA。
# 参数: 无
# 返回值: 无 (直接修改全局变量 I18N_DATA)
# 退出码: 如果 i18n 文件不存在，则输出错误信息并退出脚本 (exit 1)
# =============================================================================
function load_i18n() {
    # 从脚本配置文件中读取语言设置
    local lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}")"

    # 如果语言设置为 "auto"，则使用系统环境变量 LANG 的第一部分作为语言代码
    if [[ "$lang" == "auto" ]]; then
        lang=$(echo "$LANG" | cut -d'_' -f1)
    fi

    # 构造 i18n 文件的完整路径
    local i18n_file="${I18N_DIR}/${lang}.json"

    # 检查 i18n 文件是否存在
    if [[ ! -f "${i18n_file}" ]]; then
        # 文件不存在时，根据语言输出不同的错误信息
        if [[ "$lang" == "zh" ]]; then
            echo -e "${RED}[错误]${NC} 文件不存在: ${i18n_file}" >&2
        else
            echo -e "${RED}[Error]${NC} File Not Found: ${i18n_file}" >&2
        fi
        # 退出脚本，错误码为 1
        exit 1
    fi

    # 读取 i18n 文件的全部内容到全局变量 I18N_DATA
    I18N_DATA="$(jq '.' "${i18n_file}")"
}

# =============================================================================
# 函数名称: menu_language
# 功能描述: 显示语言选择菜单。
# 参数: 无
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_language() {
    # 打印中文选项
    echo -e "${GREEN}1.${NC}中文"
    # 打印英文选项
    echo -e "${GREEN}2.${NC}English"
}

# =============================================================================
# 函数名称: menu_index
# 功能描述: 显示主菜单。
# 参数: 无 (直接使用全局变量 SCRIPT_CONFIG_PATH 和 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_index() {
    # 从配置文件中读取脚本版本号
    local version=$(jq -r '.version' "${SCRIPT_CONFIG_PATH}")

    # 打印主菜单标题和版本信息
    echo -e "--------------- Xray-script ------------------"
    echo -e "Version      : ${GREEN}${version}${NC}"
    # 从 i18n 数据中读取描述信息
    echo -e "Description  : $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.description")"

    # 打印安装选项部分
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.installation") ------------------"
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option1")"
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option2")"
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option3")"

    # 打印操作选项部分
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.operation") ------------------"
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option4")"
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option5")"
    echo -e "${GREEN}6.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option6")"

    # 打印配置选项部分
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.configuration") ------------------"
    echo -e "${GREEN}7.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option7")"
    echo -e "${GREEN}8.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option8")"
    echo -e "${GREEN}9.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option9")"

    # 打印退出选项
    echo -e "------------------------------------------------------"
    echo -e "${RED}0.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.index.option0")"
}

# =============================================================================
# 函数名称: menu_full_installation
# 功能描述: 显示完整安装选项菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_full_installation() {
    # 打印完整安装菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.full_installation.title") ------------------"
    # 打印选项 1 (默认)
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.full_installation.option1")(${GREEN}$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.default")${NC})"
    # 打印选项 2
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.full_installation.option2")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.full_installation.info1")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.full_installation.info2")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_xray
# 功能描述: 显示 Xray 版本选择菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_xray() {
    # 打印 Xray 版本菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.title") ------------------"
    # 打印选项 1
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.option1")"
    # 打印选项 2 (默认)
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.option2")(${GREEN}$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.default")${NC})"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.option3")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.info1")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.info2")"
    # 打印选项 3 的说明信息
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray_version.info3")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_xray_config
# 功能描述: 显示 Xray 协议配置菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_xray_config() {
    # 打印协议配置菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.title") ------------------"
    # 打印选项 1
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option1")"
    # 打印选项 2 (默认)
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option2")(${GREEN}$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.default")${NC})"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option3")"
    # 打印选项 4
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option4")"
    # 打印选项 5
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option5")"
    # 打印选项 6
    echo -e "${GREEN}6.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.option6")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info1")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info2")"
    # 打印选项 3 的说明信息
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info3")"
    # 打印选项 3.1 的说明信息
    echo -e "3.1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info3_1")"
    # 打印选项 3.2 的说明信息
    echo -e "3.2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info3_2")"
    # 打印选项 4 的说明信息
    echo -e "4. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info4")"
    # 打印选项 5 的说明信息
    echo -e "5. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info5")"
    # 打印选项 6 的说明信息
    echo -e "6. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.protocol_config.info6")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_web_config
# 功能描述: 显示 Web 服务器配置菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_web_config() {
    # 打印 Web 配置菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.title") ------------------"
    # 打印选项 1 (默认)
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.option1")(${GREEN}$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.default")${NC})"
    # 打印选项 2
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.option2")"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.option3")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.info1")"
    # 打印选项 3 的说明信息
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.web_config.info2")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

function menu_ca_vendor() {
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.ca_vendor.title") ------------------"
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.ca_vendor.option1")(${GREEN}$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.default")${NC})"
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.ca_vendor.option2")"
    echo -e "------------------------------------------------------"
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.ca_vendor.info1")"
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.ca_vendor.info2")"
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_config
# 功能描述: 显示配置管理菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_config() {
    # 打印配置管理菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.title") ------------------"
    # 打印选项 1
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option1")"
    # 打印选项 2
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option2")"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option3")"
    # 打印选项 4
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option4")"
    # 打印选项 5
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option5")"
    # 打印选项 6
    echo -e "${GREEN}6.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.option6")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.info1")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.info2")"
    # 打印选项 3 的说明信息
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.info3")"
    # 打印选项 4 的说明信息
    echo -e "4. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.info4")"
    # 打印选项 5 的说明信息
    echo -e "5. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.config_management.info5")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_route
# 功能描述: 显示路由规则管理菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_route() {
    # 打印路由管理菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.title") ------------------"
    # 打印选项 1
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option1")"
    # 打印选项 2
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option2")"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option3")"
    # 打印选项 4
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option4")"
    # 打印选项 5
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option5")"
    # 打印选项 6
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.option6")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息 (有重复)
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info1")"
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info2")"
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info3")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info4")"
    # 打印选项 3 的说明信息
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info5")"
    # 打印选项 4 的说明信息
    echo -e "4. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info6")"
    # 打印选项 5 的说明信息
    echo -e "5. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info7")"
    # 打印选项 6 的说明信息
    echo -e "6. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.route_management.info8")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: menu_sni_config
# 功能描述: 显示 SNI 配置菜单。
# 参数: 无 (直接使用全局变量 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function menu_sni_config() {
    # 打印 SNI 配置菜单标题
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.title") ------------------"
    # 打印选项 1
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option1")"
    # 打印选项 2
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option2")"
    # 打印选项 3
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option3")"
    # 打印选项 4
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option4")"
    # 打印选项 5
    echo -e "${GREEN}5.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option5")"
    # 打印选项 6
    echo -e "${GREEN}6.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option6")"
    # 打印选项 7
    echo -e "${GREEN}7.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option7")"
    echo -e "${GREEN}8.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option8")"
    echo -e "${GREEN}9.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.option9")"

    # 打印分隔线
    echo -e "------------------------------------------------------"
    # 打印选项 1 的说明信息
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.info1")"
    # 打印选项 2 的说明信息
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.info2")"
    echo -e "8. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.info3")"
    echo -e "9. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.sni_config.info4")"
    # 打印分隔线
    echo -e "------------------------------------------------------"
}

function menu_custom_sites() {
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.title") ------------------"
    echo -e "${GREEN}1.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.option1")"
    echo -e "${GREEN}2.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.option2")"
    echo -e "${GREEN}3.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.option3")"
    echo -e "${GREEN}4.${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.option4")"

    echo -e "------------------------------------------------------"
    echo -e "1. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.info1")"
    echo -e "2. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.info2")"
    echo -e "3. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.info3")"
    echo -e "4. $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.custom_sites.info4")"
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: print_banner
# 功能描述: 随机打印一个 ASCII 艺术风格的 Banner。
# 参数: 无
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function print_banner() {
    case $(($(bash "${GENERATE_PATH}" '--random' 1 100) % 2)) in
    0)
        local banner_0="G1swOzE7MzU7OTVtXxtbMDsxOzMxOzkxbV8bWzBtICAgG1swOzE7MzI7OTJtX18bWzBtICAbWzA7MTszNDs5NG1fG1swbSAgICAbWzA7MTszMTs5MW1fG1swbSAgIBtbMDsxOzMyOzkybV8bWzA7MTszNjs5Nm1fXxtbMDsxOzQ7OTRtX19bMG0bWzA7MTszNTs5NW1fXxtbMG0gICAbWzA7MTszMzkzbV8bWzA7MTszjs5Mm1fXxtbMDsxOzM2Ozk2bV9fG1swOzE7MzQ7OTRtX19bMG0gICAbWzA7MTszMTs5MW1fG1swOzE7MzMzOTNtX18bWzA7MTszMjs5Mm1fXxtbMG0gIAogG1swOzE7MzE7OTFtXBtbMG0gG1swOzE7MzM7OTNtXBtbMG0gG1swOzE7MzI7OTJtLxtbMG0gG1swOzE7MzY7OTZtLxtbMG0gG1swOzE7MzQ7OTRtXxtbMG0gG1swOzE7MzU7OTVtXxtbMG0gIBtbMDsxOzMzOzkzbXwbWzBtIBtbMDsxOzMyOzkybXwbWzBtIBtbMDsxOzM2Ozk2bXxfG1swOzE7MzQ7OTRtXxtbMG0gICAbWzA7MTszMTs5MW1fXxtbMDsxOzMzOzkzbXwbWzBtIBtbMDsxOzMyOzkybXxfG1swOzE7MzY7OTZtXxtbMG0gICAbWzA7MTszNTs5NW1fXxtbMDsxOzMxOzkxbXwbWzBtIBtbMDsxOzMzOzkzbXwbWzBtICAbWzA7MTszMjs5Mm1fG1swOzE7MzY7OTZtXxtbMG0gG1swOzE7MzQ7OTRtXBtbMG0gCiAgG1swOzE7MzI7OTJtXBtbMG0gG1swOzE7MzY7OTZtVhtbMG0gG1swOzE7MzQ7OTRtLxtbMG0gIBtbMDsxOzM1Ozk1bXwbWzBtIBtbMDsxOzMxOzkxbXwbWzBtG1swOzE7MzM7OTNtX19bMG0bWzA7MTszMjs5Mm1|G1swbSAbWzA7MTszNjs5Nm1|G1swbSAgICAbWzA7MTszNTs5NW1|G1swbSAbWzA7MTszMTs5MW1|G1swbSAgICAgICAbWzA7MTszNDs5NG1|G1swbSAbWzA7MTszNTs5NW1|G1swbSAgICAbWzA7MTszMjs5Mm1|G1swbSAbWzA7MTszNjs5Nm1|XxtbMDsxOzQ7OTRtXykbWzA7MTszNTs5NW1|G1swbQogICAbWzA7MTszNjs5Nm0+G1swbSAbWzA7MTszNDs5NG08G1swbSAgIBtbMDsxOzMxOzkxbXwbWzBtICAbWzA7MTszMjs5Mm1fXxtbMG0gIBtbMDsxOzQ7OTRtdxtbMG0bWzA7MTszNDs5NG1|G1swbSAgICAbWzA7MTszMTs5MW1|G1swbSAbWzA7MTszMzkzbXwbWzBtICAgICAgIBtbMDsxOzU7OTVtX3wbWzBtG1swOzE7MzE7OTFtfBtbMG0gICAgG1swOzE7MzY7OTZtfBtbMG0gIBtbMDsxOzQ7OTRtfFtbMDsxOzM1Ozk1bV9fG1swOzE7MzE7OTFtL1sw0gCiAgG1swOzE7MzQ7OTRtLxtbMG0gG1swOzE7MzU7OTVtLhtbMG0gG1swOzE7MzMxOzkxbVwbWzBtICAbWzA7MTszMzkzbXwbWzBtIBtbMDsxOzMyOzkybXwbWzBtICAbWzA7MTszNDs5NG1|G1swbSAbWzA7MTszNTs5NW1|G1swbSAgICAbWzA7MTszMzkzbXwbWzBtIBtbMDsxOzMyOzkybXwbWzBtICAgICAgIBtbMDsxOzMxOzkxbXwbWzBtIBtbMDsxOzMzOzkzbXwbWzBtICAgIBtbMDsxOzQ7OTRtfBtbMG0gG1swOzE7NTs5NW1fX3wbWzBtG1swbSAgICAgCiAbWzA7MTszNDs5NG0vG1swOzE7MzU7OTVtXy9bMG0gG1swOzE7MzE7OTFtXBtbMDsxOzMzOzkzbV9cG1swbSAbWzA7MTszMjs5Mm1|G1swOzE7MzY7OTZtX3wbWzBtICAbWzA7MTszNTs5NW18XxtbMDsxOzMxOzkxbXwbWzBtICAgIBtbMDsxOzMyOzkybXwbWzBtG1swOzE7MzY7OTZtX3wbWzBtICAgICAgIBtbMDsxOzMzOzkzbXwbWzBtG1swOzE7MzY7OTZtfF9bMG0gICAgG1swOzE7MzU7OTVtfF9bMzA7MTszMTs5MW18bWzBtICAgICAKCkNvcHlyaWdodCAoQykgb3h4Y29uZmlnIHwgaHR0cHM6Ly9naXRodWIuY29tL294eGNvbmZpZy9YcmF5Cgo="
        echo -n "${banner_0}" | tr -d '\r\n ' | base64 --decode | sed 's/G1s/\x1b\[/g'
        ;;
    1)
        local banner_1="G1swOzE7MzQ7OTRtX18bWzBtICAgG1swOzE7MzQ7OTRtX18bWzBtICAbWzA7MTszNDs5NG1fG1swbSAgICAbWzA7MTszNDs5NG1fG1swbSAgIBtbMDszNG1fX19fX19fG1swbSAgIBtbMDszNG1fX19bWzA7MzdtX19fXxtbMG0gICAbWzA7MzdtX19fX19bMG0gIAogG1swOzE7MzQ7OTRtdxtbMG0bWzA7MTszNDs5NG1cG1swbSAbWzA7MTszNDs5NG0vG1swbSAbWzA7MTszNDs5NG0vG1swbSAbWzA7MzRtfBtbMG0gG1swOzM0bXwbWzBtICAbWzA7MzRtfBtbMG0gG1swOzM0bXwbWzBtIBtbMDszNG18X19bMG0gICAbWzA7MzdtX19|G1swbSAbWzA7MzdtfF9fG1swbSAgIBtbMDszN21fX3wbWzBtIBtbMDszN218G1swbSAgG1swOzE7MzA7OTBtX18bWzBtIBtbMDsxOzMwOzkwbVwbWzBtIAogG1swOzM0bVwbWzBtIBtbMDszNG1WG1swbSAbWzA7MzRtLxtbMG0gIBtbMDszNG1|G1swbSAbWzA7MzRtfF9fXxtbMG0bWzA7MzdtfBtbMG0gICAgG1swOzMzOzM3bXwbWzBtIBtbMDszN21|G1swbSAgICAgICAbWzA7MzdtfBtbMG0gG1swOzE7MzA7OTBtfBtbMG0gICAgG1swOzE7MzA7OTBtfBtbMG0gG1swOzE7MzA7OTBtfF9fKRtbMG0gG1swOzE7MzA7OTBtfBtbMG0KICAgG1swOzM0bT4bWzBtIBtbMDszNG08G1swbSAgIBtbMDszN21|G1swbSAbWzA7MzdtX19bMG0gIBtbMDszN21|G1swbSAgICAbWzA7MzdtfBtbMG0gG1swOzMzOzM3bXwbWzBtICAgICAgIBtbMDsxOzMwOzkwbXwbWzBtIBtbMDsxOzMwOzkwbXwbWzBtICAgIBtbMDsxOzMwOzkwbXwbWzBtICAbWzA7MTszNDs5NG1fX18vG1swbSAgCiAgG1swOzMzOzM3bS9fG1swbSAbWzA7MzdtXBtbMG0gG1swOzM3bXwbWzBtICAgICAbWzA7MzdtfBtbMG0gG1swOzM3bXwbWzBtICAgIBtbMDsxOzMwOzkwbXwbWzBtICAgIBtbMDsxOzMwOzkwbXwbWzBtIBtbMDsxOzMwOzkwbXwbWzBtICAgICAgIBtbMDsxOzMwOzkwbXwbWzBtIBtbMDsxOzQ7OTRtfBtbMG0gICAgG1swOzE7MzQ7OTRtfBtbMG0gG1swOzE7MzQ7OTRtfBtbMG0gICAgIAogG1swOzM3bS9fLxtbMG0gG1swOzM3bVxfXBtbMDsxOzMwOzkwbXxffBtbMG0gICAgIBtbMDsxOzMwOzkwbXxffBtbMG0gICAgG1swOzE7MzA7OTBtfF98G1swbSAgICAgICAbWzA7MTszNDs5NG1fX3wbWzBtICAgIBtbMDsxOzQ7MzRtdxtbMG0bWzA7MTszNDs5NG18XxtbMDszNG18XwogCgpDb9B5cmlnaHQgKEMpIG94eGNvbmZpZyB8IGh0dHBzOi8vZ2l0aHViLmNvbS9veHhjb25maWcvWHJheQoK"
        echo -n "${banner_1}" | tr -d '\r\n ' | base64 --decode | sed 's/G1s/\x1b\[/g'
        ;;
    esac
}
# =============================================================================
# 函数名称: print_status
# 功能描述: 打印当前脚本配置的状态信息，包括 Xray 版本、配置标签和 WARP 状态。
# 参数: 无 (直接使用全局变量 SCRIPT_CONFIG_PATH 和 I18N_DATA)
# 返回值: 无 (直接打印到标准错误输出 >&2)
# =============================================================================
function print_status() {
    # 读取脚本配置文件的完整 JSON 内容
    local SCRIPT_CONFIG=$(jq '.' "${SCRIPT_CONFIG_PATH}")

    # 从配置中提取 Xray 版本、配置标签和 WARP 状态
    local XRAY_VERSION=$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.version')
    local CONFIG_TAG=$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.tag')
    local WARP_STATUS=$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.warp')

    # 从 i18n 数据中读取状态描述文本
    local not_installed=$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.not_installed")
    local not_configured=$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.not_configured")
    local enabled=$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.enabled")
    local disabled=$(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.status.disabled")

    # 根据 Xray 版本是否存在，设置显示颜色和文本
    [[ ${XRAY_VERSION} ]] && XRAY_VERSION="${GREEN}${XRAY_VERSION}${NC}" || XRAY_VERSION="${RED}${not_installed}${NC}"
    # 根据配置标签是否存在，设置显示颜色和文本
    [[ ${CONFIG_TAG} ]] && CONFIG_TAG="${GREEN}${CONFIG_TAG}${NC}" || CONFIG_TAG="${RED}${not_configured}${NC}"
    # 根据 WARP 状态 (1 或 0)，设置显示颜色和文本
    [[ ${WARP_STATUS} -eq 1 ]] && WARP_STATUS="${GREEN}${enabled}${NC}" || WARP_STATUS="${RED}${disabled}${NC}"

    # 打印状态信息
    echo -e "------------------------------------------------------"
    echo -e "Xray       : ${XRAY_VERSION}"
    echo -e "CONFIG     : ${CONFIG_TAG}"
    echo -e "WARP Proxy : ${WARP_STATUS}"
    echo -e "------------------------------------------------------"
    echo
}

# =============================================================================
# 函数名称: get_choose
# 功能描述: 提示用户输入选择，并对输入进行基本验证和处理。
# 参数:
#   $1: 用于区分是否是语言选择菜单的标志 (例如 '--language')
# 返回值: 用户输入的选择数字 (通过 return 返回)
# =============================================================================
function get_choose() {
    local i18n="$1" # 获取参数

    # 根据参数决定提示信息
    if [[ "$i18n" == '--language' ]]; then
        printf "请选择你的语言(默认: 中文): " >&2
    else
        # 从 i18n 数据中读取通用提示信息
        printf "${YELLOW}[$(echo "$I18N_DATA" | jq -r '.title.tip')] ${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.choose"): " >&2
    fi

    # 从标准输入读取用户输入
    read -r choose

    # 检查输入是否为纯数字
    if [[ ${choose} =~ ^[0-9]+$ ]]; then
        # 移除前导零 (例如 01 -> 1)
        choose=$(echo "${choose}" | sed 's/^0*//')
        # 如果处理后为空 (原输入为 "0" 或 "00")，则返回 0；否则返回处理后的数字
        return "${choose:-0}"
    else
        # 如果不是纯数字，则返回 0
        return "0"
    fi
}

# =============================================================================
# 函数名称: main
# 功能描述: 脚本的主入口函数。
#           1. 根据传入的第一个参数决定要执行的操作。
#           2. 如果是语言选择，则显示语言菜单；否则加载 i18n 并显示相应菜单。
#           3. 显示指定的菜单或信息。
#           4. 除非是 banner 或 status，否则提示用户输入选择。
# 参数:
#   $@: 所有命令行参数
# 返回值: 无 (协调调用其他函数完成整个流程)
# =============================================================================
function main() {
    # 检查第一个参数是否为 --language，如果是则显示语言菜单
    if [[ "$1" == "--language" ]]; then
        menu_language >&2
    else
        # 否则加载国际化数据
        load_i18n
    fi

    # 使用 case 语句根据第一个参数调用对应的菜单或信息显示函数
    case "$1" in
    --index) menu_index >&2 ;;            # 显示主菜单
    --full) menu_full_installation >&2 ;; # 显示完整安装菜单
    --xray) menu_xray >&2 ;;              # 显示 Xray 版本菜单
    --config) menu_xray_config >&2 ;;     # 显示协议配置菜单
    --web) menu_web_config >&2 ;;         # 显示 Web 配置菜单
    --ca) menu_ca_vendor >&2 ;;
    --management) menu_config >&2 ;;      # 显示配置管理菜单
    --route) menu_route >&2 ;;            # 显示路由管理菜单
    --sni) menu_sni_config >&2 ;;         # 显示 SNI 配置菜单
    --custom-sites) menu_custom_sites >&2 ;;
    --banner) print_banner >&2 ;;         # 显示 Banner
    --status) print_status >&2 ;;         # 显示状态信息
    esac

    # 如果不是显示 banner 或状态信息，则提示用户输入选择
    if [[ "$1" != "--banner" && "$1" != "--status" ]]; then
        get_choose "$1"
    fi
}

# --- 脚本执行入口 ---
# 将脚本接收到的所有参数传递给 main 函数开始执行
main "$@"

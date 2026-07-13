cat << 'EOF' > /usr/local/bin/xray-info
#!/usr/bin/env bash
# 定义颜色
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
RED='\033[31m'
NC='\033[0m'

# 1. 自动确保系统安装了 jq 和 qrencode (生成二维码必备)
if ! command -v qrencode &>/dev/null; then
    apt-get update && apt-get install -y qrencode || yum install -y qrencode
fi

# 获取当前公网 IP
IP=$(curl -sS4 --connect-timeout 3 --retry 1 ip.sb || curl -sS4 --connect-timeout 3 --retry 1 ifconfig.me || echo "见VPS公网IP")

echo -e "\n${BLUE}==================================================${NC}"
echo -e "       ${GREEN}🌟 Xray 全套节点信息一键看板 V4.0 🌟${NC}"
echo -e "${BLUE}==================================================${NC}"

# 定位实际的配置文件
XRAY_CONFIG=""
PATHS=("/usr/local/etc/xray/config.json" "/usr/local/xray-script/config/xray/config.json" "/etc/xray/config.json" "$HOME/.xray-script/config.json")
for p in "${PATHS[@]}"; do [ -f "$p" ] && XRAY_CONFIG="$p" && break; done

if [ -z "$XRAY_CONFIG" ]; then
    XRAY_CONFIG=$(find /usr/local /etc /home -name "config.json" -path "*xray*" type f 2>/dev/null | head -n 1)
fi

if [ -n "$XRAY_CONFIG" ] && [ -f "$XRAY_CONFIG" ] && command -v jq &>/dev/null; then
    
    # 2. 解析并打印 Socks5 配置
    S5_PORT=$(jq -r '.inbounds[] | select(.tag=="SOCKS5-INBOUND") | .port' "$XRAY_CONFIG" 2>/dev/null)
    S5_USER=$(jq -r '.inbounds[] | select(.tag=="SOCKS5-INBOUND") | .settings.accounts[0].user' "$XRAY_CONFIG" 2>/dev/null)
    S5_PASS=$(jq -r '.inbounds[] | select(.tag=="SOCKS5-INBOUND") | .settings.accounts[0].pass' "$XRAY_CONFIG" 2>/dev/null)
    
    if [ -n "$S5_PORT" ] && [ "$S5_PORT" != "null" ]; then
        echo -e "${YELLOW}[ 🌐 浏览器专用 Socks5 配置 ]${NC}"
        echo -e " 🔹 代理类型 : Socks5"
        echo -e " 🔹 代理 IP  : ${GREEN}${IP}${NC}"
        echo -e " 🔹 端口     : ${GREEN}${S5_PORT}${NC}"
        echo -e " 🔹 用户名   : ${GREEN}${S5_USER}${NC}"
        echo -e " 🔹 密码     : ${GREEN}${S5_PASS}${NC}"
    else
        echo -e "${RED}[!] 未在该 VPS 上检测到追加的 Socks5 服务${NC}"
    fi

    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${YELLOW}[ 🚀 核心 VLESS-REALITY 订阅链接 ]${NC}"

    # 3. 现场全手工拼装 VLESS 核心参数 (100% 脱离原脚本，绝不卡回车)
    UUID=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .settings.clients[0].id' "$XRAY_CONFIG" 2>/dev/null)
    PORT=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .port' "$XRAY_CONFIG" 2>/dev/null)
    FLOW=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .settings.clients[0].flow' "$XRAY_CONFIG" 2>/dev/null)
    NET=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .streamSettings.network' "$XRAY_CONFIG" 2>/dev/null)
    SEC=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .streamSettings.security' "$XRAY_CONFIG" 2>/dev/null)
    
    SNI=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .streamSettings.realitySettings.serverNames[0]' "$XRAY_CONFIG" 2>/dev/null)
    SID=$(jq -r '.inbounds[] | select(.tag=="VLESS-Vision-REALITY") | .streamSettings.realitySettings.shortIds[]' "$XRAY_CONFIG" 2>/dev/null | grep -v '^$' | head -n 1)
    
    # 尝试抓取公钥
    PUBKEY=""
    if [ -f "/usr/local/xray-script/config/script_config.json" ]; then
        PUBKEY=$(jq -r '.xray.public_key' /usr/local/xray-script/config/script_config.json 2>/dev/null)
    fi
    if [ -z "$PUBKEY" ] || [ "$PUBKEY" = "null" ]; then
        PUBKEY=$(jq -r '.nginx.public_key' "$HOME/.xray-script/config.json" 2>/dev/null)
    fi

    [ "$SNI" = "null" ] || [ -z "$SNI" ] && SNI="www.leercapitulo.co"
    [ "$SID" = "null" ] || [ -z "$SID" ] && SID="01"
    [ "$FLOW" = "null" ] || [ -z "$FLOW" ] && FLOW="xtls-rprx-vision"
    [ "$NET" = "null" ] || [ -z "$NET" ] && NET="tcp"
    [ "$SEC" = "null" ] || [ -z "$SEC" ] && SEC="reality"

    if [ -n "$UUID" ] && [ "$UUID" != "null" ]; then
        # 组装链接
        VLESS_LINK="vless://${UUID}@${IP}:${PORT}?type=${NET}&security=${SEC}&flow=${FLOW}&sni=${SNI}&sid=${SID}"
        if [ -n "$PUBKEY" ] && [ "$PUBKEY" != "null" ]; then
            VLESS_LINK="${VLESS_LINK}&pbk=${PUBKEY}"
        fi
        VLESS_LINK="${VLESS_LINK}#oxx_VLESS_${IP}"
        
        # 打印明文
        echo -e " 🔗 节点链接 :\n ${GREEN}${VLESS_LINK}${NC}\n"
        
        # 4. 调用本地 qrencode 强行现场渲染终端二维码
        if command -v qrencode &>/dev/null; then
            echo -e "${YELLOW}[ 📱 手机扫码专用二维码 ]${NC}"
            qrencode -t ansiutf8 "${VLESS_LINK}"
        fi
    else
        echo -e "${RED}[!] 配置文件中未提取到 VLESS 核心数据${NC}"
    fi

else
    echo -e "${RED}[严重错误] 环境损坏，无法解析。${NC}"
fi

echo -e "${BLUE}==================================================${NC}\n"
EOF

chmod +x /usr/local/bin/xray-info

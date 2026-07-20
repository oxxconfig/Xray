# 1. 强制安装 jq 依赖，确保环境绝对没问题
if ! command -v jq &>/dev/null; then
    apt-get update && apt-get install -y jq || yum install -y jq
fi

# 2. 正确定义 Socks5 认证参数（修复了引号）
S5_PORT=1080
S5_USER="TC"
S5_PASS="Tcnet@123456"

# 3. 智能自动寻找服务器上真正的 Xray 配置文件
XRAY_CONFIG=""
PATHS=(
    "/usr/local/xray-script/config/xray/config.json"
    "/etc/xray/config.json"
    "/usr/local/etc/xray/config.json"
    "$HOME/.xray-script/config.json"
)

for p in "${PATHS[@]}"; do
    if [ -f "$p" ]; then
        XRAY_CONFIG="$p"
        break
    fi
done

# 如果通过预设路径没找到，用 find 盲搜一波
if [ -z "$XRAY_CONFIG" ]; then
    XRAY_CONFIG=$(find / -name "config.json" -path "*xray*" type f 2>/dev/null | head -n 1)
fi

# 4. 执行注入逻辑
if [ -n "$XRAY_CONFIG" ] && [ -f "$XRAY_CONFIG" ]; then
    echo -e "\033[32m[找到配置] 正在对目标文件注入 Socks5: $XRAY_CONFIG\033[0m"
    
    # 备份原配置
    cp "$XRAY_CONFIG" "${XRAY_CONFIG}.bak"
    
    # 构造并精准追加 Socks5 节点到 inbounds
    NEW_INBOUND=$(jq -n \
      --arg port "$S5_PORT" \
      --arg user "$S5_USER" \
      --arg pass "$S5_PASS" \
      '{tag: "SOCKS5-INBOUND", listen: "0.0.0.0", port: ($port|tonumber), protocol: "socks", settings: {auth: "password", accounts: [{user: $user, pass: $pass}], udp: true}, sniffing: {enabled: true, destOverride: ["http", "tls"]}}')
    
    jq --argjson new "$NEW_INBOUND" '.inbounds += [$new]' "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp" && mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
    
    # 5. 重启服务
    systemctl restart xray && echo -e "\033[32m[成功] Xray 服务已成功重启！\033[0m" || xray restart
    
    # 6. 打印完美账单
    echo -e "\n\033[33m--- 浏览器专用 Socks5 ---\033[0m"
    echo -e "代理类型 : Socks5"
    echo -e "代理IP   : $(curl -sS4 ip.sb || curl -sS4 ifconfig.me || echo '见VPS公网IP')"
    echo -e "端口     : $S5_PORT"
    echo -e "用户名   : $S5_USER"
    echo -e "密码     : $S5_PASS"
    echo -e "\033[33m-----------------------------\033[0m"
else
    echo -e "\033[31m[严重错误] 找遍了全盘也没发现 Xray 的 config.json，请确认该 VPS 是否成功安装了 VLESS 节点！\033[0m"
fi

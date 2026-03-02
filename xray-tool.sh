#!/bin/bash

# ================= 配置区 =================
GH_USER="caojiaxia"
TUNNEL_IMAGE="ghcr.io/$GH_USER/xray-tunnel:latest"
DOCKER_IMAGE="ghcr.io/$GH_USER/xray-docker:latest"
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. 开启 BBR 加速函数 (增强反馈版)
enable_bbr() {
    echo -e "${BLUE}正在检测 BBR 状态...${NC}"
    # 检查当前是否已开启
    local current_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    
    if [ "$current_cc" == "bbr" ]; then
        echo -e "${GREEN}检测到 BBR 已处于开启状态，性能已达最佳！${NC}"
    else
        echo -e "${YELLOW}当前拥塞控制算法为: $current_cc，正在切换至 BBR...${NC}"
        # 写入配置
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        
        # 生效配置
        sysctl -p >/dev/null 2>&1
        
        # 再次检查确认
        local final_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        if [ "$final_cc" == "bbr" ]; then
            echo -e "${GREEN}成功！BBR 加速已生效。${NC}"
            echo -e "${BLUE}当前算法: $(sysctl net.ipv4.tcp_congestion_control)${NC}"
            echo -e "${BLUE}队列算法: $(sysctl net.core.default_qdisc)${NC}"
        else
            echo -e "${RED}失败！无法自动开启 BBR，请检查内核版本是否高于 4.9。${NC}"
        fi
    fi
    sleep 2
}

# 2. 链接生成器 (含伪装域名 Host/SNI)
gen_link() {
    local TYPE=$1      # ws 或 xhttp
    local UUID=$2
    local XPATH=$3
    local ADDR=$4
    local PORT=$5
    local TLS=$6       # tls 或 none
    local HOST=$7      # 伪装域名
    local REMARK=$8
    
    local ENCODED_PATH=$(echo "$XPATH" | sed 's/\//%2F/g')
    local SECURITY=$TLS
    [ "$TLS" == "none" ] && SECURITY="none"

    local LINK="vless://$UUID@$ADDR:$PORT?path=$ENCODED_PATH&security=$SECURITY&encryption=none"

    if [ "$TLS" == "tls" ]; then
        # sni 默认使用节点地址，host 使用用户自定义的伪装域名
        # allowInsecure=0 (严格验证), alpn 优化
        local ADV_PARAMS="&sni=$ADDR&host=$HOST&fp=chrome&allowInsecure=0&alpn=h2,http/1.1"
        if [ "$TYPE" == "xhttp" ]; then
            LINK="${LINK}&type=xhttp&mode=packet${ADV_PARAMS}"
        else
            LINK="${LINK}&type=ws${ADV_PARAMS}"
        fi
    else
        [ "$TYPE" == "xhttp" ] && LINK="${LINK}&type=xhttp&mode=packet" || LINK="${LINK}&type=ws"
    fi

    LINK="$LINK#$REMARK"
    
    echo -e "${YELLOW}================ 终极节点配置 (全参数版) ================${NC}"
    echo -e "${GREEN}协议: VLESS + $TYPE${NC} | ${CYAN}TLS: $TLS${NC}"
    echo -e "伪装域名 (Host): ${BLUE}$HOST${NC}"
    echo -e "SNI (Server Name): ${BLUE}$ADDR${NC}"
    echo -e "ALPN: h2,http/1.1 | 指纹: chrome | 模式: packet"
    echo -e "${YELLOW}-------------------------------------------------------${NC}"
    echo -e "${CYAN}客户端直接导入链接:${NC}"
    echo -e "${BLUE}$LINK${NC}"
    echo -e "${YELLOW}=======================================================${NC}"
}

# 3. 方案 2: NPM + Xray
install_npm() {
    enable_bbr
    local IP=$(curl -s ifconfig.me)
    mkdir -p ~/xray-npm && cd ~/xray-npm
    
    read -p "请输入自定义 UUID 重要：不要使用默认UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 XHTTP 路径 重要：不要使用默认路径 (回车默认 /xhttp): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/xhttp"}
    
    # 新增伪装域名输入
    read -p "请输入伪装域名 (回车默认使用节点域名): " MY_HOST
    
    echo -e "${CYAN}是否准备在 NPM 中配置域名和 SSL 证书？(y/n)${NC}"
    read -p "> " HAS_DOMAIN
    
    if [[ "$HAS_DOMAIN" == "y" || "$HAS_DOMAIN" == "Y" ]]; then
        read -p "请输入你的实际节点域名 (例如 node.abc.com): " MY_DOMAIN
        ADDR=$MY_DOMAIN
        PORT=443
        TLS="tls"
        # 如果用户没填伪装域名，则默认使用实际域名
        MY_HOST=${MY_HOST:-$MY_DOMAIN}
    else
        ADDR=$IP
        PORT=80
        TLS="none"
        MY_HOST=${MY_HOST:-"www.bing.com"}
    fi

    cat <<EOF > docker-compose.yml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: always
    ports: ['80:80', '81:81', '443:443']
    volumes: ['./data:/data', './letsencrypt:/etc/letsencrypt']
    networks: [xray_net]
  xray:
    image: $DOCKER_IMAGE
    container_name: xray
    restart: always
    environment:
      - UUID=${MY_UUID}
      - XPATH=${MY_XPATH}
    networks: [xray_net]
networks:
  xray_net:
    driver: bridge
EOF
    docker compose up -d
    echo -e "${GREEN}Docker 部署成功！${NC}"
    
    gen_link "xhttp" "$MY_UUID" "$MY_XPATH" "$ADDR" "$PORT" "$TLS" "$MY_HOST" "NPM_XHTTP_$ADDR"

# ================= NPM 设置提醒 =================
    echo -e "\n${RED}🚩 重要：请务必完成以下 NPM 后台设置，否则节点无法连接！${NC}"
    echo -e "${YELLOW}1. 访问管理面板:${NC} http://$IP:81 (默认 admin@example.com / changeme)"
    echo -e "${YELLOW}2. 添加 Proxy Host:${NC}"
    echo -e "   - ${CYAN}Domain Names:${NC} $ADDR"
    echo -e "   - ${CYAN}Forward Host:${NC} xray"
    echo -e "   - ${CYAN}Forward Port:${NC} 10000"
    echo -e "   - ${CYAN}Websockets Support:${NC} 开启 (必须开启)"
    echo -e "${YELLOW}3. 配置 SSL:${NC}"
    echo -e "   - 选择 SSL 选项卡，申请 Let's Encrypt 证书"
    echo -e "   - 勾选 ${CYAN}Force SSL${NC} (强制 HTTPS)"
    echo -e "   - 勾选 ${CYAN}HTTP/2 Support${NC}"
    echo -e "${YELLOW}4. 高级设置 (可选):${NC} 若连接不稳定，可在 Advanced 粘贴 proxy_buffering off;"
    echo -e "${RED}======================================================${NC}\n"
}

# 方案 1: Tunnel (WS 方案)
install_tunnel() {
    enable_bbr
    read -p "请输入 Tunnel Token: " TOKEN
    read -p "请输入自定义 UUID 重要：不要使用默认UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 WS 路径 重要：不要使用默认路径 (回车默认 /ws): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/ws"}
    read -p "请输入你在 CF 绑定的实际域名: " MY_DOMAIN
    read -p "请输入伪装域名 (回车默认与实际域名一致): " MY_HOST
    MY_HOST=${MY_HOST:-$MY_DOMAIN}
    
    docker rm -f xray-tunnel 2>/dev/null
    docker run -d --name xray-tunnel --restart always \
      -e TUNNEL_TOKEN="$TOKEN" -e UUID="$MY_UUID" -e XPATH="$MY_XPATH" $TUNNEL_IMAGE
    
    echo -e "${GREEN}Tunnel 部署成功！${NC}"
    gen_link "ws" "$MY_UUID" "$MY_XPATH" "$MY_DOMAIN" "443" "tls" "$MY_HOST" "CF_WS_$MY_DOMAIN"
}

# 菜单列表
show_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}      BoGe VPS Xray Docker工具箱       ${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo "1) 安装 Cloudflare Tunnel 方案 (WS)"
    echo "2) 安装 NPM + Xray 方案 (XHTTP)"
    echo "3) 彻底卸载并清理残留"
    echo "4) 开启 BBR 加速"
    echo "5) 退出"
    echo -e "${BLUE}====================================${NC}"
}

while true; do
    show_menu
    read -p "请选择操作 [1-5]: " choice
    case "$choice" in
        1) install_tunnel ;;
        2) install_npm ;;
        3) docker rm -f xray-tunnel xray npm 2>/dev/null; docker network rm xray_net 2>/dev/null; rm -rf ~/xray-npm; echo -e "${RED}清理完成${NC}"; sleep 2 ;;
        4) enable_bbr; sleep 2 ;;
        5) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done

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

# 1. 开启 BBR 加速函数
enable_bbr() {
    echo -e "${BLUE}正在检查 BBR 状态...${NC}"
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${GREEN}BBR 已经开启，无需重复操作。${NC}"
    else
        echo -e "${YELLOW}正在开启 BBR...${NC}"
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}BBR 加速已成功开启！${NC}"
    fi
    sleep 2
}

# 2. 链接生成器
gen_link() {
    local TYPE=$1  # ws 或 xhttp
    local UUID=$2
    local XPATH=$3
    local ADDR=$4
    local PORT=$5
    local REMARK=$6
    
    local ENCODED_PATH=$(echo "$XPATH" | sed 's/\//%2F/g')
    local LINK=""

    if [ "$TYPE" == "ws" ]; then
        LINK="vless://$UUID@$ADDR:$PORT?path=$ENCODED_PATH&security=none&encryption=none&type=ws#$REMARK"
        local PROTO_DESC="VLESS + WebSocket (WS)"
    else
        LINK="vless://$UUID@$ADDR:$PORT?path=$ENCODED_PATH&security=none&encryption=none&type=xhttp&mode=packet#$REMARK"
        local PROTO_DESC="VLESS + XHTTP (packet)"
    fi
    
    echo -e "${YELLOW}================ 节点配置信息 ================${NC}"
    echo -e "${GREEN}协议类型: $PROTO_DESC${NC}"
    echo -e "${GREEN}UUID:     $UUID${NC}"
    echo -e "${GREEN}路径:     $XPATH${NC}"
    echo -e "${GREEN}地址:     $ADDR${NC}"
    echo -e "${GREEN}端口:     $PORT${NC}"
    echo -e "${YELLOW}----------------------------------------------${NC}"
    echo -e "${CYAN}VLESS 链接 (直接复制到客户端):${NC}"
    echo -e "${BLUE}$LINK${NC}"
    echo -e "${YELLOW}==============================================${NC}"
}

# 方案 1: Cloudflare Tunnel (WS)
install_tunnel() {
    enable_bbr
    read -p "请输入 Tunnel Token: " TOKEN
    read -p "请输入自定义 UUID 重要：不要使用默认UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 WS 路径 重要：不要使用默认路径 (回车默认 /ws): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/ws"}
    read -p "请输入你在 CF 绑定的域名: " MY_DOMAIN
    
    docker rm -f xray-tunnel 2>/dev/null
    docker run -d --name xray-tunnel --restart always \
      -e TUNNEL_TOKEN="$TOKEN" -e UUID="$MY_UUID" -e XPATH="$MY_XPATH" $TUNNEL_IMAGE
    
    echo -e "${GREEN}Tunnel 方案部署成功！${NC}"
    gen_link "ws" "$MY_UUID" "$MY_XPATH" "$MY_DOMAIN" "443" "CF_WS_$MY_DOMAIN"
}

# 方案 2: NPM + Xray (XHTTP)
install_npm() {
    enable_bbr
    local IP=$(curl -s ifconfig.me)
    mkdir -p ~/xray-npm && cd ~/xray-npm
    
    read -p "请输入自定义 UUID 重要：不要使用默认UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 XHTTP 路径 重要：不要使用默认路径 (回车默认 /xhttp): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/xhttp"}
    
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
    echo -e "${GREEN}NPM + Xray 方案部署成功！${NC}"
    gen_link "xhttp" "$MY_UUID" "$MY_XPATH" "$IP" "80" "NPM_XHTTP_$IP"
}

# 菜单列表
show_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}      Claw VPS Xray 终极工具箱       ${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "1) 安装 Cloudflare Tunnel 方案 (WS)"
    echo -e "2) 安装 NPM + Xray 方案 (XHTTP)"
    echo -e "3) 彻底卸载并清理残留"
    echo -e "${YELLOW}4) 开启 BBR 加速 (独立检查/开启)${NC}"
    echo -e "5) 退出"
    echo -e "${BLUE}====================================${NC}"
}

while true; do
    show_menu
    read -p "请选择操作 [1-5]: " choice
    case "$choice" in
        1) install_tunnel ;;
        2) install_npm ;;
        3) 
            docker rm -f xray-tunnel xray npm 2>/dev/null
            docker network rm xray_net 2>/dev/null
            rm -rf ~/xray-npm
            echo -e "${RED}所有容器已清理完毕${NC}" ; sleep 2 ;;
        4) enable_bbr ;;
        5) exit 0 ;;
        *) echo "无效选项" ; sleep 1 ;;
    esac
done

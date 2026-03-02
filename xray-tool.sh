#!/bin/bash

# ================= 配置区 =================
GH_USER="你的GitHub用户名"  # <--- 修改这里！
TUNNEL_IMAGE="ghcr.io/$GH_USER/xray-tunnel:latest"
NPM_XRAY_IMAGE="ghcr.io/$GH_USER/xray-npm:latest"
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}      Claw VPS Xray 终极工具箱       ${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo "1) 安装 Cloudflare Tunnel 方案 (免开端口/最安全)"
    echo "2) 安装 NPM + Xray 方案 (全能反代/适合建站)"
    echo -e "${RED}3) 彻底卸载并清理残留 (一键重置 VPS)${NC}"
    echo "4) 退出"
    echo -e "${BLUE}====================================${NC}"
    read -p "请选择操作 [1-4]: " choice
}

install_tunnel() {
    read -p "请输入 Cloudflare Tunnel Token: " TOKEN
    read -p "请输入 UUID: " UUID
    read -p "请输入 WS 路径 (例: /proxy): " XPATH
    
    docker run -d --name xray-tunnel --restart always \
      -e TUNNEL_TOKEN=$TOKEN -e UUID=$UUID -e XPATH=$XPATH $TUNNEL_IMAGE
    echo -e "${GREEN}Tunnel 方案已启动！请检查 Cloudflare 控制台。${NC}"
    sleep 3
}

install_npm() {
    mkdir -p ~/xray-npm && cd ~/xray-npm
    read -p "请输入 UUID: " UUID
    read -p "请输入 WS 路径: " XPATH
    
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
    image: $NPM_XRAY_IMAGE
    container_name: xray
    restart: always
    environment: [UUID=$UUID, XPATH=$XPATH]
    networks: [xray_net]
networks:
  xray_net:
    driver: bridge
EOF
    docker compose up -d
    echo -e "${GREEN}NPM 方案已启动！管理后台端口: 81${NC}"
    sleep 3
}

uninstall_all() {
    echo -e "${RED}清理中...${NC}"
    docker rm -f xray-tunnel xray npm 2>/dev/null
    docker network rm xray_net 2>/dev/null
    docker rmi -f $TUNNEL_IMAGE $NPM_XRAY_IMAGE 2>/dev/null
    # 清理无用镜像
    docker image prune -f
    echo -e "${GREEN}所有 Xray 相关服务已卸载。${NC}"
    sleep 2
}

while true; do
    show_menu
    case $choice in
        1) install_tunnel ;;
        2) install_npm ;;
        3) uninstall_all ;;
        4) exit 0 ;;
        *) echo "无效选项" ; sleep 1 ;;
    esac
done

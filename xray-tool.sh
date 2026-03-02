#!/bin/bash

# ================= 配置区 =================
# 自动获取 GitHub 用户名并转为小写
GH_USER=$(echo "caojiaxia" | tr '[:upper:]' '[:lower:]')
TUNNEL_IMAGE="ghcr.io/$GH_USER/xray-tunnel:latest"
DOCKER_IMAGE="ghcr.io/$GH_USER/xray-docker:latest"
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 Docker 是否安装
if ! [ -x "$(command -v docker)" ]; then
    echo -e "${BLUE}正在安装 Docker...${NC}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable --now docker
fi

install_tunnel() {
    echo -e "${BLUE}--- Tunnel 方案配置 ---${NC}"
    read -p "请输入 Tunnel Token: " TOKEN
    read -p "请输入 UUID (默认: c67e108d-b135-4acd-b0b4-33f2d18dff44): " UUID
    UUID=${UUID:-c67e108d-b135-4acd-b0b4-33f2d18dff44}
    read -p "请输入 WS 路径 (默认: /GEdhhrQEkzaq): " XPATH
    XPATH=${XPATH:-/GEdhhrQEkzaq}
    
    docker rm -f xray-tunnel 2>/dev/null
    docker pull $TUNNEL_IMAGE
    docker run -d --name xray-tunnel --restart always \
      -e TUNNEL_TOKEN="$TOKEN" -e UUID="$UUID" -e XPATH="$XPATH" $TUNNEL_IMAGE
    echo -e "${GREEN}Tunnel 方案部署完成！请检查 Cloudflare 后台。${NC}"
}

install_npm() {
    echo -e "${BLUE}--- NPM + Xray 方案配置 ---${NC}"
    mkdir -p ~/xray-npm && cd ~/xray-npm
    read -p "请输入 UUID (默认: c67e108d-b135-4acd-b0b4-33f2d18dff44): " UUID
    UUID=${UUID:-c67e108d-b135-4acd-b0b4-33f2d18dff44}
    read -p "请输入 WS 路径 (默认: /GEdhhrQEkzaq): " XPATH
    XPATH=${XPATH:-/GEdhhrQEkzaq}
    
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
    environment: [UUID=$UUID, XPATH=$XPATH]
    networks: [xray_net]
networks:
  xray_net:
    driver: bridge
EOF
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}NPM 方案部署完成！管理后台端口: 81${NC}"
}

uninstall_all() {
    echo -e "${RED}正在深度清理系统...${NC}"
    docker rm -f xray-tunnel xray npm 2>/dev/null
    docker network rm xray_net 2>/dev/null
    docker rmi -f $TUNNEL_IMAGE $DOCKER_IMAGE jc21/nginx-proxy-manager:latest 2>/dev/null
    rm -rf ~/xray-npm
    docker image prune -f
    echo -e "${GREEN}卸载已完成。${NC}"
}

# 菜单逻辑
echo -e "${BLUE}====================================${NC}"
echo -e "${GREEN}      Claw VPS Xray 终极工具箱       ${NC}"
echo -e "${BLUE}====================================${NC}"
echo "1) 安装 Cloudflare Tunnel 方案"
echo "2) 安装 NPM + Xray 方案"
echo "3) 彻底卸载并清理残留"
echo "4) 退出"
echo -e "${BLUE}====================================${NC}"

# 使用更稳健的读取方式
read -r choice

case "$choice" in
    1) install_tunnel ;;
    2) install_npm ;;
    3) uninstall_all ;;
    4) exit 0 ;;
    *) echo -e "${RED}无效选项: [$choice]${NC}" ; exit 1 ;;
esac

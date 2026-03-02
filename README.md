## 使用教程
**一键部署命令：**
```
curl -L -O https://raw.githubusercontent.com/caojiaxia/xray-docker-tool/main/xray-tool.sh && sed -i 's/\r$//' xray-tool.sh && chmod +x xray-tool.sh && ./xray-tool.sh
```

***手动安装流程***

**一：Docker环境部署**
- 1.更新系统软件包
```
apt update && apt upgrade -y
```
- 2.安装必要的工具
```
apt install -y curl nano
```
- 3.安装docker：
```
bash <(curl -sSL https://cdn.jsdelivr.net/gh/SuperManito/LinuxMirrors@main/DockerInstallation.sh)
```
- 4.安装docker-compose
```
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
```
- 加速镜像
```
curl -L "https://hub.gitmirror.com/https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
```

### 二：Cloudflare Tunnel 方案

**Docker-compose配置**


```yml      
services:
  xray-tunnel:
    image: ghcr.io/caojiaxia/xray-ag:latest
    container_name: xray-tunnel
    restart: always
    environment:
      UUID: xxxxxx     #你的UUID
      XPATH: /xxxxxx   #你的路径
      TUNNEL_TOKEN: 你的隧道Token
```

### 启动命令

- 1
```
docker compose pull
```
- 2
```
docker compose up -d
```
- 3
```
 docker logs -f xray-tunnel
```

### cloudflare tunnel创建
| 选项        | 说明                                                                      |
| ----------- | --------------------------------------------------------------------      |
| Type |   HTTP                                                                           |
| URL  | localhost:8080 

**详细步骤：**

<img width="1409" alt="image" src="https://user-images.githubusercontent.com/92626977/218253461-c079cddd-3f4c-4278-a109-95229f1eb299.png">

<img width="1619" alt="image" src="https://user-images.githubusercontent.com/92626977/218253838-aa73b63d-1e8a-430e-b601-0b88730d03b0.png">

<img width="1155" alt="image" src="https://user-images.githubusercontent.com/92626977/218253971-60f11bbf-9de9-4082-9e46-12cd2aad79a1.png">

## 客户端参数配置
**请严格对照以下参数修改你的客户端（如 v2rayN, Clash Meta 等）**

| 选项        | 说明                                                                      |
| ----------- | --------------------------------------------------------------------      |
| 地址 (Address) | tunnel.abc.com (你刚才在 CF 设置的子域名)                                                                           |
| 端口 (Port)| 443 (注意：隧道出口在 CF 边缘，永远是 443)                                  |
| 用户 ID (UUID) | 你的UUID  |
| 传输协议 (Network) | ws (WebSocket)                                                             |
|伪装域名(host)   |tunnel.abc.com (你刚才在 CF 设置的子域名)                                      |
| 伪装路径 (Path) | /你的路径                                                                     |
| 传输安全 (TLS)t | 开启 (ON)                                                                     |
| SNI | tunnel.abc.com (你刚才在 CF 设置的子域名)     |
| 指纹 (Fingerprint) | chrome 或 randomized          |
| ALPN  |   h2, http/1.1    |
| 跳过证书验证(allowlnsecure) |  false      |

### 三：NPM + Xray 方案

**Docker-compose配置**

```yml      
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    restart: always
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - ./npm/data:/data
      - ./npm/letsencrypt:/etc/letsencrypt
    networks:
      - xray_net

  xray:
    image: ghcr.io/caojiaxia/xray-docker:latest
    container_name: xray
    restart: always
    environment:
      UUID: xxxxxx     #你的UUID
      XPATH: /xxxxxx   #你的路径
    networks:
      - xray_net
    depends_on:
      - npm

networks:
  xray_net:
    driver: bridge
```

### 启动命令

- 1
```
docker compose pull
```
- 2
```
docker compose up -d
```

###   NPM设置   
**为了数据安全，请自行去CF做端口转发** 
   - 为你的NPM面板解析一个域名（你的服务器IP）然后把端口转发到 81

| 选项        | 说明                                                                      |
| ----------- | --------------------------------------------------------------------      |
| Domain Names | 解析到你主机的域名（解析到`Cloudflare`的域名请打开小黄云）                   |
| Scheme | http                                                                           |
| Forward Hostname / IP   | 你的xray镜像名称或者直接填xray                                  |
| Forward Port   | 默认10000  也可以自己设置  打开`config.template.json`修改`"port": 10000`  |
| Websockets Support | 必须打开                                                             |
| Force SSL | 必须打开                                                                     |
| HTTP/2 Support | 必须打开                                                                     |

## 客户端参数配置
**请严格对照以下参数修改你的客户端（如 v2rayN, Clash Meta 等）**

- 协议 (Protocol): VLESS
- 地址: 你的域名/优选IP
- 端口: 443
- UUID: 你设置的环境变量 UUID
- 传输协议 (Transport): xhttp
- 路径 (Path): 你设置的环境变量路径 (注意：如果变量是 abc，路径通常填 /abc)
- TLS: 开启 (ON)
- SNI: 你的域名
- ALPN: h2或者h2,http/1.1
- 跳过证书验证(allowlnsecure)：false



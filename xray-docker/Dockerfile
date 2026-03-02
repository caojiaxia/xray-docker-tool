FROM alpine:latest

# 安装依赖
RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    wget \
    unzip \
    gettext

# 下载最新版 Xray
RUN set -eux; \
    latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f 4); \
    wget -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${latest_version}/Xray-linux-64.zip"; \
    mkdir -p /tmp/xray_files; \
    unzip /tmp/xray.zip -d /tmp/xray_files; \
    cp /tmp/xray_files/xray /usr/bin/xray 2>/dev/null || cp /tmp/xray_files/Xray /usr/bin/xray; \
    chmod +x /usr/bin/xray; \
    rm -rf /tmp/xray.zip /tmp/xray_files

# 复制配置文件和启动脚本
COPY config.template.json /etc/xray/config.template.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

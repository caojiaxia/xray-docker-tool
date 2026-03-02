
# 第一阶段：下载与准备 (使用更稳定的环境)
FROM --platform=$BUILDPLATFORM alpine:latest AS fetcher

RUN apk add --no-cache ca-certificates wget unzip

ARG TARGETARCH
WORKDIR /tmp

# 下载 Xray 和 Cloudflared
RUN set -ex && \
    case "${TARGETARCH}" in \
      "amd64") XRAY_ARCH="64"; CF_ARCH="amd64" ;; \
      "arm64") XRAY_ARCH="arm64-v8a"; CF_ARCH="arm64" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    # 下载 Xray
    wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip" && \
    unzip xray.zip && \
    # 兼容处理：有的包里是大写 Xray，有的是小写 xray
    ([ -f xray ] && mv xray /usr/bin/xray || mv Xray /usr/bin/xray) && \
    chmod +x /usr/bin/xray && \
    # 下载 Cloudflared
    wget -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" && \
    chmod +x /usr/bin/cloudflared

# 第二阶段：最终镜像 (保持极简)
FROM alpine:latest

RUN apk add --no-cache ca-certificates bash gettext

COPY --from=fetcher /usr/bin/xray /usr/bin/xray
COPY --from=fetcher /usr/bin/cloudflared /usr/bin/cloudflared
COPY ./xray-tunnel/config.template.json /etc/xray/config.template.json

RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'envsubst < /etc/xray/config.template.json > /etc/xray/config.json' >> /entrypoint.sh && \
    echo '/usr/bin/xray -config /etc/xray/config.json &' >> /entrypoint.sh && \
    echo '/usr/bin/cloudflared tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

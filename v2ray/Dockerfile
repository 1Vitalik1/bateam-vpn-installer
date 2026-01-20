FROM alpine:3.19

LABEL description="V2Ray proxy with WebSocket and TLS support"

ENV V2RAY_VERSION=5.12.1

# Установка зависимостей
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    unzip \
    ca-certificates \
    tzdata

# Скачивание и установка V2Ray
RUN mkdir -p /tmp/v2ray && \
    cd /tmp/v2ray && \
    wget https://github.com/v2fly/v2ray-core/releases/download/v${V2RAY_VERSION}/v2ray-linux-64.zip && \
    unzip v2ray-linux-64.zip && \
    mkdir -p /usr/local/bin /usr/local/share/v2ray && \
    install -m 755 v2ray /usr/local/bin/ && \
    install -m 755 v2ctl /usr/local/bin/ && \
    install -m 644 geoip.dat /usr/local/share/v2ray/ && \
    install -m 644 geosite.dat /usr/local/share/v2ray/ && \
    cd / && \
    rm -rf /tmp/v2ray

# Создание директорий
RUN mkdir -p /etc/v2ray /var/log/v2ray

# Копирование конфигурации
COPY config/config.json /etc/v2ray/
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/generate-uuid.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/*.sh

EXPOSE 10086/tcp 10087/tcp

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pidof v2ray || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["v2ray", "run", "-c", "/etc/v2ray/config.json"]
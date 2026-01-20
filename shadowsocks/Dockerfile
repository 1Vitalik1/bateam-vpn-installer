FROM alpine:3.19

LABEL description="Shadowsocks-libev proxy server"

# Установка shadowsocks-libev
RUN apk add --no-cache \
    shadowsocks-libev \
    bash \
    curl \
    rng-tools \
    pcre \
    libev \
    libsodium \
    c-ares \
    mbedtls

# Создание директорий
RUN mkdir -p /etc/shadowsocks /var/log/shadowsocks

# Копирование конфигурации и скриптов
COPY config/config.json /etc/shadowsocks/
COPY scripts/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8388/tcp 8388/udp

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD ss-server --help > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["ss-server", "-c", "/etc/shadowsocks/config.json"]
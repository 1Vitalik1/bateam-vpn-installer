FROM alpine:3.19

LABEL description="DNSCrypt-proxy for encrypted DNS queries"

# Установка dnscrypt-proxy
RUN apk add --no-cache \
    dnscrypt-proxy \
    bash \
    curl \
    drill

# Создание директорий
RUN mkdir -p /etc/dnscrypt-proxy /var/log/dnscrypt-proxy

# Копирование конфигурации
COPY config/dnscrypt-proxy.toml /etc/dnscrypt-proxy/
COPY scripts/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5353/udp 5353/tcp

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD drill @127.0.0.1 -p 5353 google.com || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["dnscrypt-proxy", "-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]
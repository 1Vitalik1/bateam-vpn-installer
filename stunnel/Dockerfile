FROM alpine:3.19

LABEL description="Stunnel SSL wrapper for OpenVPN obfuscation"

# Установка stunnel и необходимых утилит
RUN apk add --no-cache \
    stunnel \
    openssl \
    bash \
    curl

# Создание директорий
RUN mkdir -p \
    /etc/stunnel/certs \
    /var/run/stunnel \
    /var/log/stunnel

# Копирование конфигурационных файлов
COPY config/stunnel.conf /etc/stunnel/
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/generate-cert.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/*.sh

# Генерация самоподписанного сертификата при первом запуске
RUN /usr/local/bin/generate-cert.sh

EXPOSE 4443

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pidof stunnel || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["stunnel", "/etc/stunnel/stunnel.conf"]
FROM ubuntu:22.04
LABEL description="Stunnel SSL/TLS wrapper"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    stunnel4 \
    openssl \
 && rm -rf /var/lib/apt/lists/*

# Создаём директорию заранее
RUN mkdir -p /etc/stunnel/certs

# Копируем скрипт
COPY scripts/generate-cert.sh /usr/local/bin/generate-cert.sh

# Даём права и конвертируем окончания строк (на случай Windows)
RUN chmod +x /usr/local/bin/generate-cert.sh \
 && sed -i 's/\r$//' /usr/local/bin/generate-cert.sh

# Запускаем через bash явно
RUN /bin/bash /usr/local/bin/generate-cert.sh

# Копируем конфигурацию stunnel
COPY config/stunnel.conf /etc/stunnel/

EXPOSE 4443

CMD ["stunnel", "/etc/stunnel/stunnel.conf"]

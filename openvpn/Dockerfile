FROM ubuntu:22.04

LABEL maintainer="VPN Obfuscation Project"
LABEL description="OpenVPN with scramble/obfuscation support"

# Переменные окружения
ENV DEBIAN_FRONTEND=noninteractive \
    OPENVPN_VERSION=2.6.8 \
    EASY_RSA_VERSION=3.1.7

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    git \
    libssl-dev \
    liblzo2-dev \
    libpam0g-dev \
    libsystemd-dev \
    net-tools \
    iptables \
    iproute2 \
    procps \
    ca-certificates \
    patch \
    python3 \
    python3-pip \
    supervisor \
    nano \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Скачивание и компиляция OpenVPN с патчем scramble
WORKDIR /tmp
RUN wget https://swupdate.openvpn.org/community/releases/openvpn-${OPENVPN_VERSION}.tar.gz && \
    tar xzf openvpn-${OPENVPN_VERSION}.tar.gz && \
    cd openvpn-${OPENVPN_VERSION} && \
    # Применяем scramble патч
    wget -O scramble.patch https://raw.githubusercontent.com/clayface/openvpn_xorpatch/master/openvpn-2.6-xor.patch || \
    wget -O scramble.patch https://gist.githubusercontent.com/wvengen/cbdb8b744960d7bcc6e3/raw/openvpn-2.4.0-scramble.patch && \
    patch -p1 < scramble.patch || true && \
    ./configure \
        --enable-iproute2 \
        --enable-systemd \
        --with-crypto-library=openssl && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf openvpn-${OPENVPN_VERSION}*

# Установка Easy-RSA для управления сертификатами
RUN wget https://github.com/OpenVPN/easy-rsa/releases/download/v${EASY_RSA_VERSION}/EasyRSA-${EASY_RSA_VERSION}.tgz && \
    tar xzf EasyRSA-${EASY_RSA_VERSION}.tgz && \
    mv EasyRSA-${EASY_RSA_VERSION} /usr/local/share/easy-rsa && \
    rm EasyRSA-${EASY_RSA_VERSION}.tgz

# Создание директорий
RUN mkdir -p \
    /etc/openvpn/server \
    /etc/openvpn/client \
    /etc/openvpn/pki \
    /etc/openvpn/ccd \
    /var/log/openvpn \
    /dev/net && \
    mknod /dev/net/tun c 10 200 || true && \
    chmod 600 /dev/net/tun || true

# Копирование скриптов и конфигов
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/generate-client.sh /usr/local/bin/
COPY scripts/init-pki.sh /usr/local/bin/
COPY scripts/healthcheck.sh /usr/local/bin/
COPY config/server.conf /etc/openvpn/server/
COPY config/supervisord.conf /etc/supervisor/conf.d/

# Права на выполнение
RUN chmod +x /usr/local/bin/*.sh

# Expose ports
EXPOSE 1194/udp 1194/tcp 443/tcp 8443/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Точка входа
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
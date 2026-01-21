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
    libssl3 \
    libssl-dev \
    liblzo2-2 \
    liblzo2-dev \
    libpam0g \
    libpam0g-dev \
    libsystemd0 \
    libsystemd-dev \
    libcap-ng0 \
    libcap-ng-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    libnl-route-3-dev \
    liblz4-1 \
    liblz4-dev \
    libmnl-dev \
    net-tools \
    iptables \
    iproute2 \
    procps \
    ca-certificates \
    patch \
    pkg-config \
    python3 \
    python3-pip \
    supervisor \
    nano \
    vim \
 && rm -rf /var/lib/apt/lists/*

# Скачивание и компиляция OpenVPN
WORKDIR /tmp

RUN echo "[+] Downloading OpenVPN ${OPENVPN_VERSION}..." && \
    wget https://swupdate.openvpn.org/community/releases/openvpn-${OPENVPN_VERSION}.tar.gz && \
    tar xzf openvpn-${OPENVPN_VERSION}.tar.gz

WORKDIR /tmp/openvpn-${OPENVPN_VERSION}

# Попытка применить scramble патч (опционально)
RUN echo "[+] Attempting to download and apply scramble patch..." && \
    wget -O scramble.patch https://raw.githubusercontent.com/clayface/openvpn_xorpatch/master/openvpn-2.6-xor.patch || \
    echo "[!] No scramble patch available" && \
    if [ -f scramble.patch ] && [ -s scramble.patch ]; then \
        echo "[+] Testing patch compatibility..." && \
        if patch --dry-run -p1 -f < scramble.patch 2>/dev/null; then \
            echo "[+] Applying patch..." && \
            patch -p1 < scramble.patch || echo "[!] Patch failed"; \
        else \
            echo "[!] Patch not compatible, skipping"; \
        fi \
    fi

# Конфигурация
RUN echo "[+] Configuring OpenVPN..." && \
    ./configure \
        --prefix=/usr \
        --enable-iproute2 \
        --disable-systemd \
        --with-crypto-library=openssl

# Компиляция
RUN echo "[+] Building OpenVPN (this may take a while)..." && \
    make -j$(nproc)

# Остальная часть Dockerfile без изменений...

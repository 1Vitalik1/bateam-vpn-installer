FROM ubuntu:22.04

LABEL description="DPI Bypass using Zapret (GoodbyeDPI alternative for Linux)"

ENV DEBIAN_FRONTEND=noninteractive

# Установка зависимений
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    iptables \
    ipset \
    curl \
    wget \
    gawk \
    libnetfilter-queue-dev \
    libcap2-bin \
    libpcap-dev \
    libssl-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Клонирование и сборка zapret
WORKDIR /opt
RUN git clone --depth 1 https://github.com/bol-van/zapret.git && \
    cd zapret && \
    make -C nfq && \
    make -C tpws && \
    chmod +x init.d/sysv/zapret && \
    chmod +x install_bin.sh && \
    chmod +x blockcheck.sh

WORKDIR /opt/zapret

# Создание необходимых директорий
RUN mkdir -p /opt/zapret/lists && \
    mkdir -p /opt/zapret/config && \
    mkdir -p /var/log/zapret

# Копирование конфигурационных файлов и скриптов
COPY scripts/entrypoint.sh /usr/local/bin/
COPY config/zapret.conf /opt/zapret/config/
COPY lists/ /opt/zapret/lists/ 

# Установка прав
RUN chmod +x /usr/local/bin/entrypoint.sh

# Capabilities для работы без root
RUN setcap cap_net_admin,cap_net_raw=eip /opt/zapret/nfq/nfqws && \
    setcap cap_net_admin,cap_net_raw=eip /opt/zapret/tpws/tpws

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
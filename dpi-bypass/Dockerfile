FROM ubuntu:22.04
LABEL description="DPI bypass using zapret"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    gcc \
    make \
    iptables \
    ipset \
    curl \
    wget \
    gawk \
    libnetfilter-queue-dev \
    libcap2-bin \
    libcap-dev \
    libpcap-dev \
    libssl-dev \
    pkg-config \
    libnfnetlink-dev \
    libmnl-dev \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone --depth 1 https://github.com/bol-van/zapret.git || \
    (echo "Failed to clone zapret repository" && exit 1)

WORKDIR /opt/zapret

RUN echo "[+] Building nfq..." && \
    make -C nfq || (echo "Failed to build nfq" && exit 1)

RUN echo "[+] Building tpws..." && \
    make -C tpws || (echo "Failed to build tpws" && exit 1)

RUN chmod +x init.d/sysv/zapret && \
    chmod +x install_bin.sh && \
    chmod +x blockcheck.sh

# Создаём директорию для конфигурации
RUN mkdir -p /opt/zapret/config

# Копируем конфигурацию (убедитесь что файл существует)
COPY config/zapret.conf /opt/zapret/config/

EXPOSE 8080

CMD ["/bin/bash"]

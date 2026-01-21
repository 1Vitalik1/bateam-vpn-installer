FROM ubuntu:22.04
LABEL description="V2Ray proxy"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    ca-certificates \
    tzdata \
    jq \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/v2ray \
 && cd /tmp/v2ray \
 && LATEST_VERSION=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | jq -r '.tag_name') \
 && echo "Downloading V2Ray version: ${LATEST_VERSION}" \
 && wget https://github.com/v2fly/v2ray-core/releases/download/${LATEST_VERSION}/v2ray-linux-64.zip \
 && unzip v2ray-linux-64.zip \
 && install -m 755 v2ray /usr/local/bin/v2ray \
 && mkdir -p /usr/local/share/v2ray \
 && install -m 644 geoip.dat /usr/local/share/v2ray/ \
 && install -m 644 geosite.dat /usr/local/share/v2ray/ \
 && rm -rf /tmp/v2ray

ENTRYPOINT ["/usr/local/bin/v2ray"]
CMD ["run"]

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    shadowsocks-libev \
    bash \
    curl \
    rng-tools \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 8388


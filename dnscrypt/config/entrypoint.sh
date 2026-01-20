#!/bin/bash
set -e

echo "==================================="
echo "DNSCrypt-Proxy Starting"
echo "==================================="

# Создание необходимых директорий
mkdir -p /var/cache/dnscrypt-proxy
mkdir -p /var/log/dnscrypt-proxy

# Создание пустого файла для блокированных доменов
touch /etc/dnscrypt-proxy/blocked-names.txt

# Проверка конфигурации
if ! dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml -check; then
    echo "DNSCrypt-proxy configuration test failed!"
    exit 1
fi

echo "DNSCrypt-proxy configuration is valid"
echo "Starting DNSCrypt-proxy on port 5353..."

# Запуск dnscrypt-proxy
exec "$@"
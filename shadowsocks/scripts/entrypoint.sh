#!/bin/bash
set -e

echo "==================================="
echo "Shadowsocks Server Starting"
echo "==================================="

# Переменные окружения с значениями по умолчанию
SS_SERVER_ADDR=${SS_SERVER_ADDR:-0.0.0.0}
SS_SERVER_PORT=${SS_SERVER_PORT:-8388}
SS_PASSWORD=${SS_PASSWORD:-YourStrongPassword456}
SS_METHOD=${SS_METHOD:-chacha20-ietf-poly1305}
SS_TIMEOUT=${SS_TIMEOUT:-300}

# Обновление конфигурации на основе переменных окружения
cat > /etc/shadowsocks/config.json <<EOF
{
    "server": "${SS_SERVER_ADDR}",
    "server_port": ${SS_SERVER_PORT},
    "password": "${SS_PASSWORD}",
    "timeout": ${SS_TIMEOUT},
    "method": "${SS_METHOD}",
    "fast_open": true,
    "workers": 4,
    "prefer_ipv6": false,
    "no_delay": true,
    "reuse_port": true,
    "mode": "tcp_and_udp",
    "nameserver": "1.1.1.1"
}
EOF

echo "Configuration:"
echo "  Server: ${SS_SERVER_ADDR}:${SS_SERVER_PORT}"
echo "  Method: ${SS_METHOD}"
echo "  Timeout: ${SS_TIMEOUT}s"

echo ""
echo "Starting Shadowsocks server..."

# Запуск shadowsocks
exec "$@" -v
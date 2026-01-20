#!/bin/bash
set -e

echo "==================================="
echo "V2Ray Proxy Server Starting"
echo "==================================="

# Переменные окружения
V2RAY_UUID=${V2RAY_UUID:-$(cat /proc/sys/kernel/random/uuid)}
V2RAY_VMESS_PORT=${V2RAY_VMESS_PORT:-10086}
V2RAY_WS_PORT=${V2RAY_WS_PORT:-10087}
V2RAY_ALTERID=${V2RAY_ALTERID:-0}

echo "Configuration:"
echo "  VMess Port: ${V2RAY_VMESS_PORT}"
echo "  WebSocket Port: ${V2RAY_WS_PORT}"
echo "  UUID: ${V2RAY_UUID}"
echo "  AlterID: ${V2RAY_ALTERID}"

# Замена UUID в конфигурации
sed -i "s/GENERATED-UUID-HERE/${V2RAY_UUID}/g" /etc/v2ray/config.json

# Обновление портов если нужно
if [ "$V2RAY_VMESS_PORT" != "10086" ] || [ "$V2RAY_WS_PORT" != "10087" ]; then
    sed -i "s/\"port\": 10086/\"port\": ${V2RAY_VMESS_PORT}/" /etc/v2ray/config.json
    sed -i "s/\"port\": 10087/\"port\": ${V2RAY_WS_PORT}/" /etc/v2ray/config.json
fi

# Проверка конфигурации
if ! v2ray test -c /etc/v2ray/config.json; then
    echo "V2Ray configuration test failed!"
    exit 1
fi

echo "V2Ray configuration is valid"
echo ""
echo "Client Configuration Info:"
echo "-----------------------------------"
echo "Protocol: VMess"
echo "Address: YOUR_SERVER_IP"
echo "Port: ${V2RAY_VMESS_PORT} (TCP) or ${V2RAY_WS_PORT} (WebSocket)"
echo "UUID: ${V2RAY_UUID}"
echo "AlterID: ${V2RAY_ALTERID}"
echo "Security: auto"
echo "Network: tcp (port ${V2RAY_VMESS_PORT}) or ws (port ${V2RAY_WS_PORT})"
echo "WebSocket Path: /v2ray"
echo "-----------------------------------"
echo ""
echo "Starting V2Ray..."

# Запуск V2Ray
exec "$@"
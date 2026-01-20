#!/bin/bash

# Health check скрипт для OpenVPN

# Проверка запущен ли процесс OpenVPN
if ! pgrep -x openvpn > /dev/null; then
    echo "OpenVPN process not running"
    exit 1
fi

# Проверка существования TUN интерфейса
if ! ip link show tun0 > /dev/null 2>&1; then
    echo "TUN interface not found"
    exit 1
fi

# Проверка что интерфейс UP
if ! ip link show tun0 | grep -q "UP"; then
    echo "TUN interface is down"
    exit 1
fi

# Проверка логов на критические ошибки
if [ -f /var/log/openvpn/openvpn.log ]; then
    if tail -n 50 /var/log/openvpn/openvpn.log | grep -i "error\|fatal\|failed" | grep -v "Authenticate/Decrypt packet error" > /dev/null; then
        echo "Critical errors found in logs"
        exit 1
    fi
fi

echo "OpenVPN is healthy"
exit 0
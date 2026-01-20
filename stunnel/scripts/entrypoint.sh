#!/bin/bash
set -e

echo "==================================="
echo "Stunnel SSL Wrapper Starting"
echo "==================================="

# Проверка существования сертификата
if [ ! -f /etc/stunnel/certs/stunnel.pem ]; then
    echo "Certificate not found, generating..."
    /usr/local/bin/generate-cert.sh
fi

# Проверка конфигурации
if ! stunnel -test -fd 0 < /etc/stunnel/stunnel.conf; then
    echo "Stunnel configuration test failed!"
    exit 1
fi

echo "Stunnel configuration is valid"
echo "Starting stunnel..."

# Запуск stunnel
exec "$@"
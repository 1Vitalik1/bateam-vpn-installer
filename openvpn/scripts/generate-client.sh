#!/bin/bash

# Скрипт для генерации клиентских конфигураций
# Использование: ./generate-client.sh CLIENT_NAME [SERVER_IP]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 CLIENT_NAME [SERVER_IP]"
    echo "Example: $0 john 192.168.1.100"
    exit 1
fi

CLIENT_NAME=$1
SERVER_IP=${2:-YOUR_SERVER_IP}
OPENVPN_PROTO=${OPENVPN_PROTO:-tcp}
OPENVPN_PORT=${OPENVPN_PORT:-443}
OPENVPN_ENABLE_OBFUSCATION=${OPENVPN_ENABLE_OBFUSCATION:-true}
OPENVPN_SCRAMBLE_PASSWORD=${OPENVPN_SCRAMBLE_PASSWORD:-defaultPassword}

OUTPUT_DIR="/etc/openvpn/client"
mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "Generating client config: $CLIENT_NAME"
echo "========================================="

# Переход в директорию Easy-RSA
cd /usr/local/share/easy-rsa

# Проверка существования PKI
if [ ! -f pki/ca.crt ]; then
    echo "Error: PKI not initialized. Run init-pki.sh first!"
    exit 1
fi

# Генерация клиентского сертификата
echo "Generating client certificate..."
EASYRSA_BATCH=1 ./easyrsa build-client-full "$CLIENT_NAME" nopass

# Чтение сертификатов
CA_CERT=$(cat pki/ca.crt)
CLIENT_CERT=$(openssl x509 -in pki/issued/${CLIENT_NAME}.crt)
CLIENT_KEY=$(cat pki/private/${CLIENT_NAME}.key)
TLS_AUTH=$(cat pki/ta.key)

# Создание .ovpn файла
OVPN_FILE="$OUTPUT_DIR/${CLIENT_NAME}.ovpn"

cat > "$OVPN_FILE" <<EOF
##############################################
# OpenVPN Client Configuration
# Client: $CLIENT_NAME
# Generated: $(date)
##############################################

client
dev tun
proto $OPENVPN_PROTO
remote $SERVER_IP $OPENVPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun

# Безопасность
remote-cert-tls server
cipher AES-256-GCM
auth SHA512
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Производительность
sndbuf 393216
rcvbuf 393216
fast-io

# Сжатие (закомментировать если не используется на сервере)
;compress lz4-v2

# Логирование
verb 3
mute 20

# Keepalive
keepalive 10 120

# Обфускация трафика
EOF

if [ "$OPENVPN_ENABLE_OBFUSCATION" = "true" ]; then
    echo "scramble obfuscate $OPENVPN_SCRAMBLE_PASSWORD" >> "$OVPN_FILE"
fi

# Добавление сертификатов в конфиг
cat >> "$OVPN_FILE" <<EOF

# Встроенные сертификаты и ключи
<ca>
$CA_CERT
</ca>

<cert>
$CLIENT_CERT
</cert>

<key>
$CLIENT_KEY
</key>

<tls-auth>
$TLS_AUTH
</tls-auth>
key-direction 1

# Дополнительные опции безопасности
auth-nocache
EOF

echo ""
echo "✓ Client configuration generated successfully!"
echo "  File: $OVPN_FILE"
echo ""
echo "Configuration details:"
echo "  Server: $SERVER_IP:$OPENVPN_PORT"
echo "  Protocol: $OPENVPN_PROTO"
echo "  Obfuscation: $OPENVPN_ENABLE_OBFUSCATION"
echo ""

# Создание QR кода для мобильных клиентов (если установлен qrencode)
if command -v qrencode &> /dev/null; then
    QR_FILE="$OUTPUT_DIR/${CLIENT_NAME}_qr.png"
    cat "$OVPN_FILE" | qrencode -o "$QR_FILE" -t PNG
    echo "✓ QR code generated: $QR_FILE"
fi

# Создание zip архива с конфигом
if command -v zip &> /dev/null; then
    ZIP_FILE="$OUTPUT_DIR/${CLIENT_NAME}.zip"
    cd "$OUTPUT_DIR"
    zip -q "$ZIP_FILE" "${CLIENT_NAME}.ovpn"
    echo "✓ ZIP archive created: $ZIP_FILE"
fi

echo ""
echo "Next steps:"
echo "1. Copy $OVPN_FILE to your client device"
echo "2. Import it into your OpenVPN client"
echo "3. Connect and verify the connection"
echo ""
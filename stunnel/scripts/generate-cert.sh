#!/bin/bash

# Генерация самоподписанного SSL сертификата для Stunnel

CERT_DIR="/etc/stunnel/certs"
CERT_FILE="$CERT_DIR/stunnel.pem"

mkdir -p "$CERT_DIR"

if [ -f "$CERT_FILE" ]; then
    echo "Certificate already exists: $CERT_FILE"
    exit 0
fi

echo "Generating self-signed SSL certificate..."

openssl req -new -x509 -days 3650 -nodes \
    -out "$CERT_FILE" \
    -keyout "$CERT_FILE" \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=vpn.example.com" \
    2>/dev/null

chmod 600 "$CERT_FILE"

echo "Certificate generated successfully: $CERT_FILE"
echo "Valid for 3650 days (10 years)"
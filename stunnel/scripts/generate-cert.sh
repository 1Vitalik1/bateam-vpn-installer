#!/bin/bash
set -e

CERT_DIR=/etc/stunnel/certs
CERT_FILE=$CERT_DIR/stunnel.pem

echo "[+] Creating certificate directory..."
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_FILE" ]; then
    echo "[+] Generating self-signed certificate..."
    openssl req -x509 -nodes -days 3650 \
        -newkey rsa:4096 \
        -keyout "$CERT_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=stunnel"
    
    chmod 600 "$CERT_FILE"
    echo "[+] Certificate generated successfully at $CERT_FILE"
else
    echo "[+] Certificate already exists at $CERT_FILE"
fi

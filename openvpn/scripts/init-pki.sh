#!/bin/bash
set -e

echo "Initializing PKI (Public Key Infrastructure)..."

cd /usr/local/share/easy-rsa

# Инициализация PKI
./easyrsa init-pki

# Создание CA (Certificate Authority)
echo "Building CA..."
EASYRSA_BATCH=1 ./easyrsa build-ca nopass

# Генерация серверного сертификата
echo "Generating server certificate..."
EASYRSA_BATCH=1 ./easyrsa build-server-full server nopass

# Генерация Diffie-Hellman параметров (может занять время)
echo "Generating DH parameters (this may take a while)..."
./easyrsa gen-dh

# Генерация TLS-auth ключа для дополнительной безопасности
echo "Generating TLS-auth key..."
openvpn --genkey secret pki/ta.key

# Копирование в нужные директории
echo "Copying certificates..."
cp -r pki /etc/openvpn/

# Установка прав
chmod 600 /etc/openvpn/pki/private/*
chmod 644 /etc/openvpn/pki/ca.crt
chmod 644 /etc/openvpn/pki/dh.pem
chmod 600 /etc/openvpn/pki/ta.key

echo "PKI initialization complete!"
echo "CA Certificate: /etc/openvpn/pki/ca.crt"
echo "Server Certificate: /etc/openvpn/pki/issued/server.crt"
echo "Server Key: /etc/openvpn/pki/private/server.key"
echo "DH Parameters: /etc/openvpn/pki/dh.pem"
echo "TLS-Auth Key: /etc/openvpn/pki/ta.key"
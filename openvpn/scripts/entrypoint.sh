#!/bin/bash
set -e

echo "==================================="
echo "OpenVPN Server with Obfuscation"
echo "==================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка переменных окружения
OPENVPN_ENABLE_OBFUSCATION=${OPENVPN_ENABLE_OBFUSCATION:-true}
OPENVPN_SCRAMBLE_PASSWORD=${OPENVPN_SCRAMBLE_PASSWORD:-defaultPassword}
OPENVPN_PROTO=${OPENVPN_PROTO:-tcp}
OPENVPN_PORT=${OPENVPN_PORT:-1194}
SERVER_SUBNET=${SERVER_SUBNET:-10.8.0.0}
DNS_SERVER_1=${DNS_SERVER_1:-8.8.8.8}
DNS_SERVER_2=${DNS_SERVER_2:-8.8.4.4}

log_info "Configuration:"
log_info "  Protocol: $OPENVPN_PROTO"
log_info "  Port: $OPENVPN_PORT"
log_info "  Obfuscation: $OPENVPN_ENABLE_OBFUSCATION"
log_info "  Server Subnet: $SERVER_SUBNET"

# Создание TUN устройства если не существует
if [ ! -c /dev/net/tun ]; then
    log_warn "TUN device not found, creating..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
fi

# Включение IP forwarding
log_info "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0

# Настройка iptables для NAT
log_info "Configuring iptables..."

# Очистка старых правил
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X

# Разрешаем forwarding
iptables -P FORWARD ACCEPT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

# NAT для VPN клиентов
iptables -t nat -A POSTROUTING -s ${SERVER_SUBNET}/24 -o eth0 -j MASQUERADE

# Разрешаем established connections
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s ${SERVER_SUBNET}/24 -j ACCEPT
iptables -A FORWARD -j REJECT

# Защита от некоторых атак
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Логирование (опционально)
# iptables -A INPUT -j LOG --log-prefix "iptables-input: "
# iptables -A FORWARD -j LOG --log-prefix "iptables-forward: "

# Инициализация PKI если еще не создана
if [ ! -f /etc/openvpn/pki/ca.crt ]; then
    log_info "PKI not found, initializing..."
    /usr/local/bin/init-pki.sh
else
    log_info "PKI already exists, skipping initialization"
fi

# Генерация server.conf с учетом переменных окружения
log_info "Generating server configuration..."

cat > /etc/openvpn/server/server.conf <<EOF
# Основные настройки
port ${OPENVPN_PORT}
proto ${OPENVPN_PROTO}
dev tun
topology subnet

# Сертификаты и ключи
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/pki/ta.key 0

# Сетевые настройки
server ${SERVER_SUBNET} 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# DNS серверы для клиентов
push "dhcp-option DNS ${DNS_SERVER_1}"
push "dhcp-option DNS ${DNS_SERVER_2}"

# Маршрутизация всего трафика через VPN
push "redirect-gateway def1 bypass-dhcp"

# Keepalive
keepalive 10 120

# Шифрование
cipher AES-256-GCM
auth SHA512
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Сжатие (опционально, может замедлить)
;compress lz4-v2
;push "compress lz4-v2"

# Максимум клиентов
max-clients 100

# Права
user nobody
group nogroup
persist-key
persist-tun

# Логирование
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
mute 20

# Производительность
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
fast-io

# Клиентская конфигурация
client-config-dir /etc/openvpn/ccd

# Обфускация (scramble patch)
EOF

if [ "$OPENVPN_ENABLE_OBFUSCATION" = "true" ]; then
    log_info "Enabling traffic obfuscation..."
    echo "scramble obfuscate ${OPENVPN_SCRAMBLE_PASSWORD}" >> /etc/openvpn/server/server.conf
fi

# Создание директории для клиентских конфигов
mkdir -p /etc/openvpn/ccd

# Настройка логов
touch /var/log/openvpn/openvpn.log
touch /var/log/openvpn/openvpn-status.log
chmod 644 /var/log/openvpn/*.log

log_info "OpenVPN configuration complete!"
log_info "Starting services..."

# Запуск supervisor или непосредственно OpenVPN
if [ "$1" = "supervisord" ]; then
    exec "$@"
else
    exec /usr/local/sbin/openvpn --config /etc/openvpn/server/server.conf
fi
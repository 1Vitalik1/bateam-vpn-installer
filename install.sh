#!/bin/bash

# VPN Obfuscation Stack - Installation Script
# Автоматическая установка и настройка всех компонентов

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

echo "=========================================="
echo "VPN Obfuscation Stack - Installation"
echo "=========================================="
echo ""

# Шаг 1: Проверка системы
log_step "Checking system requirements..."

# Проверка ОС
if ! grep -q "Ubuntu" /etc/os-release && ! grep -q "Debian" /etc/os-release; then
    log_warn "This script is optimized for Ubuntu/Debian. Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 1
    fi
fi

# Проверка архитектуры
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    log_warn "Architecture $ARCH detected. x86_64 recommended. Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 1
    fi
fi

# Шаг 2: Установка Docker
log_step "Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    log_info "Docker not found. Installing Docker..."
    
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    
    log_info "Docker installed successfully"
else
    log_info "Docker is already installed"
fi

# Шаг 3: Установка Docker Compose
log_step "Checking Docker Compose installation..."

if ! command -v docker-compose &> /dev/null; then
    log_info "Docker Compose not found. Installing..."
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log_info "Docker Compose installed successfully"
else
    log_info "Docker Compose is already installed"
fi

# Шаг 4: Создание структуры директорий
log_step "Creating directory structure..."

BASE_DIR="/opt/vpn-obfuscation-stack"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Создание всех необходимых директорий
mkdir -p openvpn/{config,scripts,certs}
mkdir -p dpi-bypass/{config,scripts,lists}
mkdir -p stunnel/{config,scripts,certs}
mkdir -p dnscrypt/{config,scripts}
mkdir -p shadowsocks/{config,scripts}
mkdir -p v2ray/{config,scripts}
mkdir -p webui/{app,templates,static}
mkdir -p monitoring/{prometheus,grafana}

log_info "Directory structure created"

# Шаг 5: Получение IP адреса сервера
log_step "Detecting server IP address..."

SERVER_IP=$(curl -s ifconfig.me)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s api.ipify.org)
fi

if [ -z "$SERVER_IP" ]; then
    log_warn "Could not detect server IP automatically"
    echo -n "Please enter your server public IP address: "
    read -r SERVER_IP
fi

log_info "Server IP: $SERVER_IP"

# Шаг 6: Генерация паролей
log_step "Generating secure passwords..."

SCRAMBLE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
SS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
SECRET_KEY=$(openssl rand -hex 32)
V2RAY_UUID=$(cat /proc/sys/kernel/random/uuid)

log_info "Passwords generated"

# Шаг 7: Создание .env файла
log_step "Creating environment configuration..."

cat > "$BASE_DIR/.env" <<EOF
# Auto-generated configuration
# Date: $(date)

# Server Configuration
SERVER_IP=${SERVER_IP}

# OpenVPN Settings
OPENVPN_ENABLE_OBFUSCATION=true
OPENVPN_SCRAMBLE_PASSWORD=${SCRAMBLE_PASSWORD}
OPENVPN_PROTO=tcp
OPENVPN_PORT=1194
SERVER_SUBNET=10.8.0.0
DNS_SERVER_1=10.8.0.1
DNS_SERVER_2=1.1.1.1

# Shadowsocks Settings
SS_SERVER_ADDR=0.0.0.0
SS_SERVER_PORT=8388
SS_PASSWORD=${SS_PASSWORD}
SS_METHOD=chacha20-ietf-poly1305
SS_TIMEOUT=300

# V2Ray Settings
V2RAY_VMESS_PORT=10086
V2RAY_WS_PORT=10087
V2RAY_UUID=${V2RAY_UUID}
V2RAY_ALTERID=0

# Web UI Settings
FLASK_ENV=production
SECRET_KEY=${SECRET_KEY}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# DPI Bypass Settings
MODE=tpws
TPWS_ARGS=--split-pos=2 --split-http-req=method --disorder --oob
NFQWS_ARGS=--dpi-desync=split2 --dpi-desync-ttl=5
ENABLE_IPV6=false

# DNSCrypt Settings
DNSCRYPT_LISTEN_ADDRESS=0.0.0.0:5353
DNSCRYPT_SERVER_NAMES=cloudflare,google
EOF

chmod 600 "$BASE_DIR/.env"

log_info "Environment configuration created"

# Шаг 8: Сохранение паролей в отдельный файл
cat > "$BASE_DIR/credentials.txt" <<EOF
========================================
VPN Obfuscation Stack - Credentials
========================================
Generated: $(date)

Server IP: ${SERVER_IP}

OpenVPN:
  Scramble Password: ${SCRAMBLE_PASSWORD}
  Protocol: TCP
  Port: 1194, 443

Shadowsocks:
  Server: ${SERVER_IP}
  Port: 8388
  Password: ${SS_PASSWORD}
  Method: chacha20-ietf-poly1305

V2Ray:
  Server: ${SERVER_IP}
  VMess Port: 10086
  WebSocket Port: 10087
  UUID: ${V2RAY_UUID}
  AlterID: 0

Web UI:
  URL: http://${SERVER_IP}:8080
  Username: admin
  Password: ${ADMIN_PASSWORD}

Grafana:
  URL: http://${SERVER_IP}:3000
  Username: admin
  Password: admin (change on first login)

========================================
IMPORTANT: Keep this file secure!
========================================
EOF

chmod 600 "$BASE_DIR/credentials.txt"

log_info "Credentials saved to: $BASE_DIR/credentials.txt"

# Шаг 9: Настройка системы
log_step "Configuring system..."

# Включение IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

# BBR для лучшей производительности TCP
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

log_info "System configured"

# Шаг 10: Настройка файрвола
log_step "Configuring firewall..."

if command -v ufw &> /dev/null; then
    log_info "Configuring UFW..."
    
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH
    ufw allow 22/tcp
    
    # OpenVPN
    ufw allow 443/tcp
    ufw allow 1194/tcp
    ufw allow 1194/udp
    
    # Stunnel
    ufw allow 4443/tcp
    ufw allow 8443/tcp
    
    # Shadowsocks
    ufw allow 8388/tcp
    ufw allow 8388/udp
    
    # V2Ray
    ufw allow 10086/tcp
    ufw allow 10087/tcp
    
    # Web UI
    ufw allow 8080/tcp
    
    # Grafana
    ufw allow 3000/tcp
    
    ufw reload
    
    log_info "Firewall configured"
else
    log_warn "UFW not found. Please configure your firewall manually."
    log_warn "Required ports: 22, 443, 1194, 4443, 8388, 10086, 10087, 8080, 3000"
fi

# Шаг 11: Информация о завершении
echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
echo ""
log_info "Installation directory: $BASE_DIR"
log_info "Credentials file: $BASE_DIR/credentials.txt"
log_info ""
log_info "Next steps:"
echo "  1. Copy all Dockerfile and configuration files to $BASE_DIR"
echo "  2. cd $BASE_DIR"
echo "  3. docker-compose build"
echo "  4. docker-compose up -d"
echo "  5. Access Web UI at http://${SERVER_IP}:8080"
echo ""
log_warn "IMPORTANT: Save the credentials.txt file in a secure location!"
echo ""
log_info "To create a client configuration:"
echo "  docker exec openvpn-server /usr/local/bin/generate-client.sh client1 ${SERVER_IP}"
echo ""
echo "=========================================="

# Сохранение информации в лог
cat > "$BASE_DIR/install.log" <<EOF
Installation completed: $(date)
Server IP: ${SERVER_IP}
Installation directory: ${BASE_DIR}
Docker version: $(docker --version)
Docker Compose version: $(docker-compose --version)
EOF

log_info "Installation script completed successfully!"
log_info "Review $BASE_DIR/credentials.txt for all access details"

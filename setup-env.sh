#!/bin/bash

# Скрипт для быстрой настройки .env файла
# Автоматически определяет IP и генерирует пароли

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   VPN Obfuscation Stack - Setup Wizard   ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Функции
log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

# Проверка существования .env
if [ -f .env ]; then
    log_warn ".env файл уже существует!"
    read -p "Перезаписать? (yes/no): " overwrite
    if [ "$overwrite" != "yes" ]; then
        log_info "Отменено"
        exit 0
    fi
    cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
    log_info "Создан бэкап: .env.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Определение IP адреса
log_step "Определение IP адреса сервера..."
SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 api.ipify.org 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null)

if [ -z "$SERVER_IP" ]; then
    log_warn "Не удалось автоматически определить IP адрес"
    read -p "Введите публичный IP адрес вашего сервера: " SERVER_IP
fi

log_info "IP адрес: $SERVER_IP"

# Генерация паролей
log_step "Генерация безопасных паролей..."

SCRAMBLE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
SS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
SECRET_KEY=$(openssl rand -hex 32)
V2RAY_UUID=$(cat /proc/sys/kernel/random/uuid)

log_info "Пароли сгенерированы"

# Выбор режима
echo ""
log_step "Выберите режим работы:"
echo "  1) Базовый (только OpenVPN + DPI bypass)"
echo "  2) Расширенный (OpenVPN + Shadowsocks + V2Ray + все остальное)"
echo "  3) Полный (все сервисы включая мониторинг)"
read -p "Ваш выбор (1/2/3): " mode_choice

case $mode_choice in
    1)
        ENABLE_SHADOWSOCKS=false
        ENABLE_V2RAY=false
        ENABLE_MONITORING=false
        ENABLE_STUNNEL=true
        ;;
    2)
        ENABLE_SHADOWSOCKS=true
        ENABLE_V2RAY=true
        ENABLE_MONITORING=false
        ENABLE_STUNNEL=true
        ;;
    3)
        ENABLE_SHADOWSOCKS=true
        ENABLE_V2RAY=true
        ENABLE_MONITORING=true
        ENABLE_STUNNEL=true
        ;;
    *)
        log_warn "Неверный выбор, используется режим 2 (расширенный)"
        ENABLE_SHADOWSOCKS=true
        ENABLE_V2RAY=true
        ENABLE_MONITORING=false
        ENABLE_STUNNEL=true
        ;;
esac

# Выбор протокола OpenVPN
echo ""
log_step "Выберите протокол OpenVPN:"
echo "  1) TCP (более надежный, лучше для обфускации)"
echo "  2) UDP (быстрее, но может блокироваться)"
read -p "Ваш выбор (1/2): " proto_choice

case $proto_choice in
    1)
        OPENVPN_PROTO=tcp
        ;;
    2)
        OPENVPN_PROTO=udp
        ;;
    *)
        OPENVPN_PROTO=tcp
        ;;
esac

# Выбор порта OpenVPN
echo ""
log_step "Выберите порт OpenVPN:"
echo "  1) 443 (маскировка под HTTPS, рекомендуется)"
echo "  2) 1194 (стандартный порт OpenVPN)"
echo "  3) Другой порт"
read -p "Ваш выбор (1/2/3): " port_choice

case $port_choice in
    1)
        OPENVPN_PORT=443
        ;;
    2)
        OPENVPN_PORT=1194
        ;;
    3)
        read -p "Введите порт: " OPENVPN_PORT
        ;;
    *)
        OPENVPN_PORT=443
        ;;
esac

# Выбор режима DPI bypass
echo ""
log_step "Выберите режим DPI bypass:"
echo "  1) TPWS (прозрачный прокси, рекомендуется)"
echo "  2) NFQWS (netfilter queue, более продвинутый)"
read -p "Ваш выбор (1/2): " dpi_choice

case $dpi_choice in
    1)
        MODE=tpws
        ;;
    2)
        MODE=nfqws
        ;;
    *)
        MODE=tpws
        ;;
esac

# Страновой пресет (опционально)
echo ""
log_step "Использовать страновой пресет для DPI bypass? (опционально)"
echo "  1) Нет (универсальные настройки)"
echo "  2) Россия"
echo "  3) Китай"
echo "  4) Иран"
echo "  5) Турция"
read -p "Ваш выбор (1-5): " country_choice

case $country_choice in
    2)
        COUNTRY_PRESET=russia
        ;;
    3)
        COUNTRY_PRESET=china
        ;;
    4)
        COUNTRY_PRESET=iran
        ;;
    5)
        COUNTRY_PRESET=turkey
        ;;
    *)
        COUNTRY_PRESET=""
        ;;
esac

# Создание .env файла
log_step "Создание .env файла..."

cat > .env <<EOF
###############################################
# VPN Obfuscation Stack - Environment Config
# Auto-generated on $(date)
###############################################

###############################################
# Server Configuration
###############################################
SERVER_IP=${SERVER_IP}

###############################################
# OpenVPN Settings
###############################################
OPENVPN_ENABLE_OBFUSCATION=true
OPENVPN_SCRAMBLE_PASSWORD=${SCRAMBLE_PASSWORD}
OPENVPN_PROTO=${OPENVPN_PROTO}
OPENVPN_PORT=${OPENVPN_PORT}
SERVER_SUBNET=10.8.0.0
DNS_SERVER_1=10.8.0.1
DNS_SERVER_2=1.1.1.1

###############################################
# DPI Bypass Settings (Zapret)
###############################################
MODE=${MODE}
TPWS_PORT=988
TPWS_ARGS=--split-pos=2 --split-http-req=method --disorder --oob
NFQWS_QUEUE=200
NFQWS_ARGS=--dpi-desync=split2 --dpi-desync-ttl=5 --dpi-desync-fooling=badseq
ENABLE_IPV6=false
COUNTRY_PRESET=${COUNTRY_PRESET}

###############################################
# Stunnel Settings
###############################################
STUNNEL_PORT_1=4443
STUNNEL_PORT_2=8443

###############################################
# DNSCrypt Settings
###############################################
DNSCRYPT_LISTEN_ADDRESS=0.0.0.0:5353
DNSCRYPT_SERVER_NAMES=cloudflare,google
DNSCRYPT_DOH=true
DNSCRYPT_QUERY_LOG=false

###############################################
# Shadowsocks Settings
###############################################
SS_SERVER_ADDR=0.0.0.0
SS_SERVER_PORT=8388
SS_PASSWORD=${SS_PASSWORD}
SS_METHOD=chacha20-ietf-poly1305
SS_TIMEOUT=300
SS_MODE=tcp_and_udp

###############################################
# V2Ray Settings
###############################################
V2RAY_VMESS_PORT=10086
V2RAY_WS_PORT=10087
V2RAY_UUID=${V2RAY_UUID}
V2RAY_ALTERID=0
V2RAY_WS_PATH=/v2ray

###############################################
# Web UI Settings
###############################################
WEBUI_PORT=8080
FLASK_ENV=production
SECRET_KEY=${SECRET_KEY}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_USERNAME=admin

###############################################
# Redis Settings
###############################################
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0

###############################################
# Monitoring Settings
###############################################
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=15d
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin

###############################################
# Performance Tuning
###############################################
OPENVPN_MAX_CLIENTS=100
OPENVPN_SNDBUF=393216
OPENVPN_RCVBUF=393216
OPENVPN_COMPRESSION=false
SS_WORKERS=4
DPI_WORKERS=4

###############################################
# Security Settings
###############################################
TLS_VERSION_MIN=1.2
OPENVPN_CIPHER=AES-256-GCM
OPENVPN_AUTH=SHA512
OPENVPN_TLS_AUTH=true

###############################################
# Logging Settings
###############################################
OPENVPN_VERB=3
DPI_LOG_LEVEL=1
DNS_QUERY_LOG=false

###############################################
# Advanced Settings
###############################################
OPENVPN_CLIENT_TO_CLIENT=false
OPENVPN_DUPLICATE_CN=false
OPENVPN_KEEPALIVE_INTERVAL=10
OPENVPN_KEEPALIVE_TIMEOUT=120
OPENVPN_TCP_NODELAY=true
OPENVPN_FAST_IO=true

###############################################
# Backup Settings
###############################################
BACKUP_DIR=/opt/vpn-backups
BACKUP_RETENTION_DAYS=30

###############################################
# Feature Flags
###############################################
ENABLE_OPENVPN=true
ENABLE_DPI_BYPASS=true
ENABLE_STUNNEL=${ENABLE_STUNNEL}
ENABLE_DNSCRYPT=true
ENABLE_SHADOWSOCKS=${ENABLE_SHADOWSOCKS}
ENABLE_V2RAY=${ENABLE_V2RAY}
ENABLE_WEBUI=true
ENABLE_MONITORING=${ENABLE_MONITORING}

###############################################
# Development Settings
###############################################
DEBUG=false
RECREATE_CONTAINERS=false
EOF

chmod 600 .env

log_info ".env файл создан успешно!"

# Создание файла с учетными данными
cat > credentials.txt <<EOF
========================================
VPN Obfuscation Stack - Credentials
========================================
Generated: $(date)

Server IP: ${SERVER_IP}

OpenVPN:
  Protocol: ${OPENVPN_PROTO}
  Port: ${OPENVPN_PORT}
  Scramble Password: ${SCRAMBLE_PASSWORD}

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

Grafana (if enabled):
  URL: http://${SERVER_IP}:3000
  Username: admin
  Password: admin

========================================
IMPORTANT: Keep this file secure!
========================================
EOF

chmod 600 credentials.txt

log_info "Файл с учетными данными создан: credentials.txt"

# Итоговая информация
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Настройка завершена успешно!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
log_info "Конфигурация сохранена в .env"
log_info "Учетные данные сохранены в credentials.txt"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "  1. Проверьте конфигурацию: ${BLUE}make check${NC}"
echo "  2. Соберите образы: ${BLUE}make build${NC}"
echo "  3. Запустите сервисы: ${BLUE}make up${NC}"
echo "  4. Создайте клиента: ${BLUE}make client NAME=username${NC}"
echo "  5. Откройте Web UI: ${BLUE}http://${SERVER_IP}:8080${NC}"
echo ""
echo -e "${RED}ВАЖНО: Сохраните файл credentials.txt в безопасном месте!${NC}"
echo ""
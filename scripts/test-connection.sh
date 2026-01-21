#!/bin/bash

# Скрипт для тестирования доступности портов и сервисов

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "VPN Services Connection Test"
echo "=========================================="
echo ""

# Получение SERVER_IP из .env
if [ -f .env ]; then
    SERVER_IP=$(grep SERVER_IP .env | cut -d= -f2)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

echo "Server IP: $SERVER_IP"
echo ""

# Функция проверки порта
check_port() {
    local port=$1
    local service=$2
    local protocol=${3:-tcp}
    
    echo -n "Testing $service (port $port/$protocol)... "
    
    if [ "$protocol" = "tcp" ]; then
        if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$SERVER_IP/$port" 2>/dev/null; then
            echo -e "${GREEN}✓ OPEN${NC}"
            return 0
        else
            echo -e "${RED}✗ CLOSED/FILTERED${NC}"
            return 1
        fi
    else
        # UDP проверка (менее надежная)
        if nc -uzv -w 3 $SERVER_IP $port 2>&1 | grep -q "succeeded"; then
            echo -e "${GREEN}✓ OPEN${NC}"
            return 0
        else
            echo -e "${YELLOW}? UNKNOWN (UDP)${NC}"
            return 2
        fi
    fi
}

# Функция проверки HTTP эндпоинта
check_http() {
    local url=$1
    local service=$2
    
    echo -n "Testing $service ($url)... "
    
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" | grep -q "200\|401\|302"; then
        echo -e "${GREEN}✓ ACCESSIBLE${NC}"
        return 0
    else
        echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
        return 1
    fi
}

# Проверка Docker
echo "=== Docker Status ==="
if docker ps &>/dev/null; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi
echo ""

# Проверка контейнеров
echo "=== Container Status ==="
docker-compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps --format "table {{.Name}}\t{{.Status}}"
echo ""

# Проверка портов
echo "=== Port Availability ==="

check_port 443 "OpenVPN (HTTPS)" tcp
check_port 1194 "OpenVPN (Standard)" tcp
check_port 1194 "OpenVPN (Standard)" udp

check_port 4443 "Stunnel (SSL-1)" tcp
check_port 8443 "Stunnel (SSL-2)" tcp

check_port 8388 "Shadowsocks" tcp
check_port 8388 "Shadowsocks" udp

check_port 10086 "V2Ray (VMess)" tcp
check_port 10087 "V2Ray (WebSocket)" tcp

check_port 8080 "Web UI" tcp

# Опциональные порты
if grep -q "ENABLE_MONITORING=true" .env 2>/dev/null; then
    check_port 3000 "Grafana" tcp
    check_port 9090 "Prometheus" tcp
fi

echo ""

# Проверка HTTP сервисов
echo "=== HTTP Services ==="

check_http "http://$SERVER_IP:8080" "Web UI"

if grep -q "ENABLE_MONITORING=true" .env 2>/dev/null; then
    check_http "http://$SERVER_IP:3000" "Grafana"
    check_http "http://$SERVER_IP:9090" "Prometheus"
fi

echo ""

# Проверка DNS
echo "=== DNS Resolution ==="
echo -n "Testing DNS resolution... "
if nslookup google.com &>/dev/null || dig google.com &>/dev/null; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi

echo ""

# Проверка iptables
echo "=== Firewall Status ==="
if command -v ufw &>/dev/null; then
    echo "UFW Status:"
    sudo ufw status numbered | grep -E "443|1194|8388|10086|8080" || echo "No VPN rules found"
elif command -v iptables &>/dev/null; then
    echo "iptables rules for VPN ports:"
    sudo iptables -L -n | grep -E "443|1194|8388|10086|8080" || echo "No specific rules found"
else
    echo "No firewall detected"
fi

echo ""

# Итоговый отчет
echo "=========================================="
echo "Test Summary"
echo "=========================================="

# Подсчет открытых портов
OPEN_PORTS=$(netstat -tuln 2>/dev/null | grep -E "443|1194|8388|10086|8080" | wc -l)

echo "Server IP: $SERVER_IP"
echo "Listening ports: $OPEN_PORTS"
echo ""

if docker ps | grep -q "openvpn"; then
    echo -e "${GREEN}✓ System appears to be working correctly${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Create a client: make client NAME=test"
    echo "  2. Download config: ./test.ovpn"
    echo "  3. Test connection from client device"
else
    echo -e "${YELLOW}⚠ Some services may not be running${NC}"
    echo ""
    echo "Try:"
    echo "  docker-compose up -d"
    echo "  docker-compose logs"
fi

echo ""
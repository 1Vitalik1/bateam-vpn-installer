#!/bin/bash

# Скрипт для создания полного бэкапа VPN конфигурации

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "VPN Configuration Backup"
echo "=========================================="
echo ""

# Директория для бэкапов
BACKUP_DIR=${BACKUP_DIR:-./backups}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="vpn-backup-${TIMESTAMP}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Создание директории для бэкапов
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}[1/5]${NC} Preparing backup..."

# Временная директория для сбора файлов
TEMP_DIR=$(mktemp -d)
BACKUP_TEMP="$TEMP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_TEMP"

echo -e "${GREEN}[2/5]${NC} Collecting configuration files..."

# Файлы для бэкапа
FILES_TO_BACKUP=(
    ".env"
    "docker-compose.yml"
    "openvpn/config"
    "openvpn/certs"
    "dpi-bypass/config"
    "dpi-bypass/lists"
    "stunnel/config"
    "stunnel/certs"
    "dnscrypt/config"
    "shadowsocks/config"
    "v2ray/config"
)

# Копирование файлов
for item in "${FILES_TO_BACKUP[@]}"; do
    if [ -e "$item" ]; then
        echo "  ✓ Backing up: $item"
        # Создание родительской директории в backup
        parent_dir=$(dirname "$item")
        mkdir -p "$BACKUP_TEMP/$parent_dir"
        cp -r "$item" "$BACKUP_TEMP/$item"
    else
        echo -e "  ${YELLOW}⚠${NC} Skipping (not found): $item"
    fi
done

echo -e "${GREEN}[3/5]${NC} Creating metadata..."

# Создание файла с метаданными
cat > "$BACKUP_TEMP/backup-info.txt" <<EOF
VPN Obfuscation Stack - Backup Information
==========================================

Backup Date: $(date)
Hostname: $(hostname)
Server IP: $(grep SERVER_IP .env 2>/dev/null | cut -d= -f2 || echo "N/A")

Docker Compose Version: $(docker-compose version --short 2>/dev/null || docker compose version --short)
Docker Version: $(docker --version)

Running Containers:
$(docker ps --format "- {{.Names}}: {{.Status}}" 2>/dev/null || echo "N/A")

Backup Contents:
$(find "$BACKUP_TEMP" -type f | sed 's|'$BACKUP_TEMP'/||' | sort)

==========================================
EOF

echo -e "${GREEN}[4/5]${NC} Creating archive..."

# Создание архива
cd "$TEMP_DIR"
tar czf "$BACKUP_FILE" "$BACKUP_NAME"

# Размер архива
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo -e "${GREEN}[5/5]${NC} Cleaning up..."

# Удаление временной директории
rm -rf "$TEMP_DIR"

# Проверка старых бэкапов
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/vpn-backup-*.tar.gz 2>/dev/null | wc -l)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

if [ $BACKUP_COUNT -gt 10 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: $BACKUP_COUNT backups found"
    echo "  Consider cleaning old backups (retention: $RETENTION_DAYS days)"
    echo "  Run: find $BACKUP_DIR -name 'vpn-backup-*.tar.gz' -mtime +$RETENTION_DAYS -delete"
fi

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo ""
echo "Backup file: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo "Total backups: $BACKUP_COUNT"
echo ""
echo -e "${GREEN}✓ Backup created successfully${NC}"
echo ""
echo "To restore this backup:"
echo "  tar xzf $BACKUP_FILE"
echo "  # Review and copy files as needed"
echo ""
echo "Or use:"
echo "  make restore BACKUP=$BACKUP_FILE"
echo ""
#!/bin/bash

# Скрипт для восстановления из бэкапа

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Example:"
    echo "  $0 backups/vpn-backup-20240115-120000.tar.gz"
    echo ""
    echo "Available backups:"
    ls -1 backups/*.tar.gz 2>/dev/null | tail -5 || echo "  No backups found"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "=========================================="
echo "VPN Configuration Restore"
echo "=========================================="
echo ""
echo "Backup file: $BACKUP_FILE"
echo ""

# Предупреждение
echo -e "${YELLOW}WARNING: This will overwrite current configuration!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Создание бэкапа текущей конфигурации
echo ""
echo -e "${GREEN}[1/5]${NC} Creating backup of current configuration..."

CURRENT_BACKUP="backups/pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
mkdir -p backups

if [ -f .env ]; then
    tar czf "$CURRENT_BACKUP" .env docker-compose.yml openvpn dpi-bypass stunnel dnscrypt shadowsocks v2ray 2>/dev/null || true
    echo "  ✓ Current config backed up to: $CURRENT_BACKUP"
else
    echo "  ⚠ No current configuration found"
fi

# Остановка сервисов
echo -e "${GREEN}[2/5]${NC} Stopping services..."

if docker-compose ps &>/dev/null; then
    docker-compose down
    echo "  ✓ Services stopped"
else
    echo "  ⚠ No running services found"
fi

# Извлечение бэкапа
echo -e "${GREEN}[3/5]${NC} Extracting backup..."

TEMP_DIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

BACKUP_DIR=$(ls -1 "$TEMP_DIR" | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Invalid backup file${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Показать информацию о бэкапе
if [ -f "$TEMP_DIR/$BACKUP_DIR/backup-info.txt" ]; then
    echo ""
    echo "Backup Information:"
    echo "-------------------"
    cat "$TEMP_DIR/$BACKUP_DIR/backup-info.txt"
    echo ""
fi

read -p "Continue with restore? (yes/no): " CONFIRM2

if [ "$CONFIRM2" != "yes" ]; then
    echo "Restore cancelled"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Восстановление файлов
echo -e "${GREEN}[4/5]${NC} Restoring files..."

cd "$TEMP_DIR/$BACKUP_DIR"

# Копирование файлов обратно
if [ -f .env ]; then
    cp .env "$OLDPWD/"
    echo "  ✓ Restored: .env"
fi

if [ -f docker-compose.yml ]; then
    cp docker-compose.yml "$OLDPWD/"
    echo "  ✓ Restored: docker-compose.yml"
fi

# Восстановление директорий
for dir in openvpn dpi-bypass stunnel dnscrypt shadowsocks v2ray; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$OLDPWD/"
        echo "  ✓ Restored: $dir/"
    fi
done

cd "$OLDPWD"

# Очистка
echo -e "${GREEN}[5/5]${NC} Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "Restore Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ Configuration restored successfully${NC}"
echo ""
echo "Current backup saved to: $CURRENT_BACKUP"
echo ""
echo "Next steps:"
echo "  1. Review configuration: cat .env"
echo "  2. Start services: make up"
echo "  3. Check status: make status"
echo ""

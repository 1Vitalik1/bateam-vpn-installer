#!/bin/bash

# Скрипт для генерации UUID для V2Ray

set -e

echo "==================================="
echo "V2Ray UUID Generator"
echo "==================================="

# Функция генерации UUID
generate_uuid() {
    # Метод 1: Использовать /proc/sys/kernel/random/uuid (Linux)
    if [ -f /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
        return
    fi
    
    # Метод 2: Использовать uuidgen (если установлен)
    if command -v uuidgen &> /dev/null; then
        uuidgen
        return
    fi
    
    # Метод 3: Генерация через Python (если установлен)
    if command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
        return
    fi
    
    if command -v python &> /dev/null; then
        python -c "import uuid; print(uuid.uuid4())"
        return
    fi
    
    # Метод 4: Генерация вручную через /dev/urandom
    # UUID формат: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    # где x = [0-9a-f], y = [89ab]
    
    local N B T
    
    for (( N=0; N < 16; ++N ))
    do
        B=$(( RANDOM%256 ))
        
        case $N in
            6)
                printf '4%x' $(( B%16 ))
                ;;
            8)
                local C='89ab'
                printf '%c%x' ${C:$(( RANDOM%${#C} )):1} $(( B%16 ))
                ;;
            3 | 5 | 7 | 9)
                printf '%02x-' $B
                ;;
            *)
                printf '%02x' $B
                ;;
        esac
    done
    
    echo
}

# Основная логика
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [count]"
    echo ""
    echo "Generates UUID(s) for V2Ray configuration"
    echo ""
    echo "Arguments:"
    echo "  count    Number of UUIDs to generate (default: 1)"
    echo ""
    echo "Examples:"
    echo "  $0           # Generate 1 UUID"
    echo "  $0 5         # Generate 5 UUIDs"
    echo ""
    exit 0
fi

# Количество UUID для генерации
COUNT=${1:-1}

# Проверка что count - число
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: count must be a number"
    exit 1
fi

# Генерация UUID
echo "Generating $COUNT UUID(s)..."
echo ""

for (( i=1; i<=$COUNT; i++ ))
do
    UUID=$(generate_uuid)
    
    if [ $COUNT -gt 1 ]; then
        echo "UUID $i: $UUID"
    else
        echo "$UUID"
    fi
done

echo ""
echo "Done!"

# Если в интерактивном режиме, предложить обновить .env
if [ -t 0 ] && [ $COUNT -eq 1 ]; then
    read -p "Update V2RAY_UUID in .env file? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f .env ]; then
            # Создание бэкапа
            cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
            
            # Обновление UUID в .env
            sed -i "s/V2RAY_UUID=.*/V2RAY_UUID=$UUID/" .env
            
            echo "✓ V2RAY_UUID updated in .env file"
            echo "✓ Backup created: .env.backup.$(date +%Y%m%d-%H%M%S)"
        else
            echo "✗ .env file not found"
        fi
    fi
fi

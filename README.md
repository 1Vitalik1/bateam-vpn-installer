# VPN Obfuscation Stack - Complete Docker Solution

Комплексное решение для обхода блокировок с использованием нескольких протоколов и методов обфускации.

## 🎯 Возможности

### Основные компоненты:
- **OpenVPN** с scramble/XOR патчем для обфускации трафика
- **Zapret** (аналог GoodbyeDPI для Linux) - обход DPI на уровне пакетов
- **Stunnel** - SSL обертка для дополнительной маскировки
- **DNSCrypt-proxy** - шифрованный DNS
- **Shadowsocks** - легковесный SOCKS5 прокси с шифрованием
- **V2Ray** - продвинутый протокол с WebSocket/TLS
- **Web UI** - веб-интерфейс для управления
- **Monitoring** - Prometheus + Grafana для мониторинга

### Методы обфускации:
- Scramble/XOR патч в OpenVPN
- SSL wrapper через Stunnel
- DPI bypass через Zapret (фрагментация пакетов, подмена TTL)
- HTTP маскировка в V2Ray
- WebSocket транспорт

## 📋 Требования

- Docker 20.10+
- Docker Compose 2.0+
- Linux сервер с публичным IP
- Минимум 1GB RAM, 10GB диск
- Открытые порты: 443, 1194, 4443, 8388, 10086, 10087, 8080, 3000

## 🚀 Быстрый старт

### 1. Клонирование и подготовка

```bash
# Создание структуры директорий
mkdir -p vpn-obfuscation-stack
cd vpn-obfuscation-stack

# Создание всех необходимых директорий
mkdir -p openvpn/{config,scripts,certs}
mkdir -p dpi-bypass/{config,scripts,lists}
mkdir -p stunnel/{config,scripts,certs}
mkdir -p dnscrypt/{config,scripts}
mkdir -p shadowsocks/{config,scripts}
mkdir -p v2ray/{config,scripts}
mkdir -p webui/{app,templates,static}
mkdir -p monitoring/{prometheus,grafana}
```

### 2. Настройка переменных окружения

```bash
# Создание .env файла
cat > .env <<EOF
# OpenVPN Settings
OPENVPN_ENABLE_OBFUSCATION=true
OPENVPN_SCRAMBLE_PASSWORD=YourSecurePassword123
OPENVPN_PROTO=tcp
OPENVPN_PORT=1194
SERVER_SUBNET=10.8.0.0

# Shadowsocks Settings
SS_PASSWORD=YourStrongPassword456
SS_METHOD=chacha20-ietf-poly1305

# V2Ray Settings
V2RAY_UUID=$(cat /proc/sys/kernel/random/uuid)

# Web UI Settings
SECRET_KEY=$(openssl rand -hex 32)
ADMIN_PASSWORD=admin123

# DPI Bypass Mode (tpws или nfqws)
MODE=tpws
EOF

chmod 600 .env
```

### 3. Редактирование конфигурации

Откройте `docker-compose.yml` и измените `YOUR_SERVER_IP` на реальный IP вашего сервера.

### 4. Запуск

```bash
# Сборка образов
docker-compose build

# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f openvpn
```

### 5. Инициализация PKI (при первом запуске)

```bash
# PKI инициализируется автоматически при первом запуске
# Проверка логов:
docker-compose logs openvpn | grep -i "pki"
```

## 👥 Создание клиентов

### Через Web UI (рекомендуется)

1. Откройте http://YOUR_SERVER_IP:8080
2. Войдите (admin / admin123)
3. Перейдите в "Clients"
4. Нажмите "Create New Client"
5. Скачайте конфигурацию или QR-код

### Через командную строку

#### OpenVPN клиент:

```bash
# Создание нового клиента
docker exec openvpn-server /usr/local/bin/generate-client.sh client1 YOUR_SERVER_IP

# Скачивание конфигурации
docker cp openvpn-server:/etc/openvpn/client/client1.ovpn ./

# Конфигурация будет готова для импорта в OpenVPN клиент
```

#### Shadowsocks клиент:

```bash
# Конфигурация для клиента
Server: YOUR_SERVER_IP
Port: 8388
Password: YourStrongPassword456
Method: chacha20-ietf-poly1305
```

#### V2Ray клиент:

```bash
# Получение UUID из логов
docker logs v2ray-server | grep UUID

# Конфигурация для клиента:
Address: YOUR_SERVER_IP
Port: 10086 (VMess) или 10087 (WebSocket)
UUID: [из логов]
AlterID: 0
Security: auto
Network: tcp или ws
```

## 🔧 Конфигурация

### OpenVPN - режимы обфускации

```bash
# В .env файле:

# Включить scramble обфускацию
OPENVPN_ENABLE_OBFUSCATION=true
OPENVPN_SCRAMBLE_PASSWORD=YourPassword

# Использовать TCP (маскировка под HTTPS)
OPENVPN_PROTO=tcp
OPENVPN_PORT=443
```

### DPI Bypass - режимы работы

```bash
# TPWS режим (прозрачный прокси)
MODE=tpws
TPWS_ARGS=--split-pos=2 --split-http-req=method --disorder --oob

# NFQWS режим (netfilter queue)
MODE=nfqws
NFQWS_ARGS=--dpi-desync=split2 --dpi-desync-ttl=5
```

### Stunnel - дополнительная SSL обертка

```bash
# Подключение через Stunnel (порт 4443)
# Клиент сначала подключается к Stunnel, который перенаправляет на OpenVPN

# Пример stunnel.conf для клиента:
client = yes
[openvpn]
accept = 127.0.0.1:1194
connect = YOUR_SERVER_IP:4443
```

## 📊 Мониторинг

### Prometheus

```bash
# Доступ: http://YOUR_SERVER_IP:9090
# Метрики автоматически собираются со всех сервисов
```

### Grafana

```bash
# Доступ: http://YOUR_SERVER_IP:3000
# Login: admin / admin

# Импорт готовых dashboard для VPN мониторинга
```

### Просмотр логов

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f openvpn
docker-compose logs -f dpi-bypass

# Логи OpenVPN
docker exec openvpn-server tail -f /var/log/openvpn/openvpn.log

# Статус подключений
docker exec openvpn-server cat /var/log/openvpn/openvpn-status.log
```

## 🔒 Безопасность

### Рекомендации:

1. **Смените пароли по умолчанию**
```bash
# В .env файле
ADMIN_PASSWORD=your_strong_password
OPENVPN_SCRAMBLE_PASSWORD=your_scramble_password
SS_PASSWORD=your_shadowsocks_password
```

2. **Используйте файрвол**
```bash
# UFW пример
ufw allow 443/tcp
ufw allow 1194/tcp
ufw allow 8388/tcp
ufw allow 10086/tcp
ufw allow 10087/tcp
ufw enable
```

3. **Регулярно обновляйте**
```bash
docker-compose pull
docker-compose up -d
```

4. **Ограничьте доступ к Web UI**
```bash
# Только с определенных IP
# В docker-compose.yml добавьте:
# ports:
#   - "127.0.0.1:8080:8080"

# И используйте SSH туннель:
ssh -L 8080:localhost:8080 user@YOUR_SERVER_IP
```

## 🛠️ Troubleshooting

### OpenVPN не запускается

```bash
# Проверка логов
docker-compose logs openvpn

# Проверка TUN устройства
docker exec openvpn-server ls -la /dev/net/tun

# Пересоздание контейнера
docker-compose down
docker-compose up -d openvpn
```

### Клиенты не могут подключиться

```bash
# Проверка портов
netstat -tulpn | grep -E "443|1194|8388"

# Проверка файрвола
iptables -L -n -v

# Проверка маршрутизации
docker exec openvpn-server ip route
docker exec openvpn-server iptables -t nat -L -n -v
```

### DPI bypass не работает

```bash
# Проверка TUN интерфейса
docker exec openvpn-server ip link show tun0

# Проверка iptables правил
docker exec dpi-bypass iptables -t nat -L -n -v

# Смена режима
# В .env измените MODE с tpws на nfqws или наоборот
```

### Низкая скорость

```bash
# Отключите сжатие в OpenVPN (если включено)
# В openvpn/config/server.conf закомментируйте:
;compress lz4-v2

# Используйте UDP вместо TCP
# В .env:
OPENVPN_PROTO=udp

# Отключите обфускацию для тестирования
OPENVPN_ENABLE_OBFUSCATION=false
```

## 📈 Производительность

### Оптимизация:

1. **BBR congestion control**
```bash
# На хосте
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

2. **Увеличение буферов**
```bash
# Уже настроено в конфигурации OpenVPN
sndbuf 393216
rcvbuf 393216
```

3. **Использование UDP**
```bash
# UDP быстрее TCP, но менее надежен
OPENVPN_PROTO=udp
```

## 🔄 Обновление

```bash
# Обновление образов
docker-compose pull

# Пересоздание контейнеров с сохранением данных
docker-compose up -d --force-recreate

# Backup конфигураций перед обновлением
tar czf backup-$(date +%Y%m%d).tar.gz openvpn/certs openvpn/config
```

## 📦 Структура проекта

```
vpn-obfuscation-stack/
├── docker-compose.yml          # Главный файл оркестрации
├── .env                        # Переменные окружения
├── README.md                   # Эта документация
│
├── openvpn/                    # OpenVPN с обфускацией
│   ├── Dockerfile
│   ├── config/
│   │   ├── server.conf
│   │   └── supervisord.conf
│   ├── scripts/
│   │   ├── entrypoint.sh
│   │   ├── init-pki.sh
│   │   ├── generate-client.sh
│   │   └── healthcheck.sh
│   └── certs/                  # Сертификаты (генерируются автоматически)
│
├── dpi-bypass/                 # DPI обход (Zapret)
│   ├── Dockerfile
│   ├── config/
│   │   └── zapret.conf
│   ├── scripts/
│   │   └── entrypoint.sh
│   └── lists/                  # Списки доменов для обработки
│
├── stunnel/                    # SSL wrapper
│   ├── Dockerfile
│   ├── config/
│   │   └── stunnel.conf
│   ├── scripts/
│   │   ├── entrypoint.sh
│   │   └── generate-cert.sh
│   └── certs/                  # SSL сертификаты
│
├── dnscrypt/                   # Шифрованный DNS
│   ├── Dockerfile
│   ├── config/
│   │   └── dnscrypt-proxy.toml
│   └── scripts/
│       └── entrypoint.sh
│
├── shadowsocks/                # Shadowsocks прокси
│   ├── Dockerfile
│   ├── config/
│   │   └── config.json
│   └── scripts/
│       └── entrypoint.sh
│
├── v2ray/                      # V2Ray протокол
│   ├── Dockerfile
│   ├── config/
│   │   └── config.json
│   └── scripts/
│       └── entrypoint.sh
│
├── webui/                      # Web интерфейс
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── run.py
│       ├── templates/
│       └── static/
│
└── monitoring/                 # Мониторинг
    ├── prometheus/
    │   └── prometheus.yml
    └── grafana/
        └── dashboards/
```

## 🤝 Поддержка

При возникновении проблем:

1. Проверьте логи: `docker-compose logs -f`
2. Проверьте статус: `docker-compose ps`
3. Проверьте порты: `netstat -tulpn`
4. Проверьте файрвол: `iptables -L -n -v`

## 📝 Лицензия

MIT License

## ⚠️ Disclaimer

Этот проект предназначен только для образовательных целей и для использования в странах, где VPN разрешены законом. Используйте на свой страх и риск.

---

**Версия:** 1.0.0  
**Дата:** 2024

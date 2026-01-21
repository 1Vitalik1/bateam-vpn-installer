# Полная инструкция по развертыванию

## 📋 Содержание

1. [Требования](#требования)
2. [Подготовка сервера](#подготовка-сервера)
3. [Установка](#установка)
4. [Настройка](#настройка)
5. [Запуск](#запуск)
6. [Создание клиентов](#создание-клиентов)
7. [Проверка работы](#проверка-работы)
8. [Troubleshooting](#troubleshooting)

---

## Требования

### Минимальные требования к серверу:
- **OS**: Ubuntu 20.04/22.04 или Debian 10/11
- **CPU**: 1 ядро (рекомендуется 2+)
- **RAM**: 1 GB (рекомендуется 2 GB+)
- **Диск**: 10 GB свободного места
- **Сеть**: Публичный IP адрес
- **Порты**: См. список ниже

### Необходимые порты:
```
22    - SSH
443   - OpenVPN (TCP, маскировка под HTTPS)
1194  - OpenVPN (TCP/UDP, стандартный)
4443  - Stunnel (SSL wrapper)
8388  - Shadowsocks
10086 - V2Ray (VMess)
10087 - V2Ray (WebSocket)
8080  - Web UI
3000  - Grafana (опционально)
9090  - Prometheus (опционально)
```

### Программное обеспечение:
- Docker 20.10+
- Docker Compose 2.0+
- curl, wget, git

---

## Подготовка сервера

### 1. Обновление системы

```bash
# Обновление пакетов
sudo apt update && sudo apt upgrade -y

# Установка необходимых утилит
sudo apt install -y curl wget git make openssl
```

### 2. Установка Docker

```bash
# Автоматическая установка Docker
curl -fsSL https://get.docker.com | sh

# Добавление текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниться или выполнить:
newgrp docker

# Проверка установки
docker --version
docker compose version
```

### 3. Настройка системы

```bash
# Включение IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Сохранение настроек
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf

# Включение BBR (опционально, для лучшей производительности)
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf

# Применение настроек
sudo sysctl -p
```

---

## Установка

### Способ 1: Интерактивная установка (рекомендуется)

```bash
# 1. Клонирование репозитория или создание директории
mkdir -p ~/vpn-obfuscation-stack
cd ~/vpn-obfuscation-stack

# 2. Скопируйте все файлы проекта в эту директорию
# (docker-compose.yml, Dockerfile's, скрипты, конфиги)

# 3. Запустите мастер настройки
chmod +x setup-env.sh
./setup-env.sh

# Следуйте инструкциям мастера для:
# - Определения IP адреса
# - Генерации паролей
# - Выбора протоколов
# - Настройки DPI bypass

# 4. Запустите автоматическую установку
chmod +x install.sh
sudo ./install.sh

# 5. Соберите и запустите
make build
make up
```

### Способ 2: Ручная установка

```bash
# 1. Создание структуры директорий
mkdir -p ~/vpn-obfuscation-stack
cd ~/vpn-obfuscation-stack

mkdir -p openvpn/{config,scripts,certs}
mkdir -p dpi-bypass/{config,scripts,lists}
mkdir -p stunnel/{config,scripts,certs}
mkdir -p dnscrypt/{config,scripts}
mkdir -p shadowsocks/{config,scripts}
mkdir -p v2ray/{config,scripts}
mkdir -p webui/{app,templates,static}
mkdir -p monitoring/{prometheus,grafana}

# 2. Скопировать все файлы проекта

# 3. Настроить .env файл вручную
cp .env.example .env
nano .env

# Обязательно измените:
# - SERVER_IP=ваш_ip
# - Все пароли (OPENVPN_SCRAMBLE_PASSWORD, SS_PASSWORD, ADMIN_PASSWORD)
# - V2RAY_UUID (сгенерируйте через: cat /proc/sys/kernel/random/uuid)
# - SECRET_KEY (сгенерируйте через: openssl rand -hex 32)

# 4. Сборка
docker-compose build

# 5. Запуск
docker-compose up -d
```

---

## Настройка

### Настройка файрвола (UFW)

```bash
# Включение UFW
sudo ufw enable

# Разрешение SSH (ВАЖНО!)
sudo ufw allow 22/tcp

# Разрешение VPN портов
sudo ufw allow 443/tcp
sudo ufw allow 1194/tcp
sudo ufw allow 1194/udp
sudo ufw allow 4443/tcp
sudo ufw allow 8388/tcp
sudo ufw allow 8388/udp
sudo ufw allow 10086/tcp
sudo ufw allow 10087/tcp

# Web UI
sudo ufw allow 8080/tcp

# Monitoring (опционально)
sudo ufw allow 3000/tcp
sudo ufw allow 9090/tcp

# Применение правил
sudo ufw reload

# Проверка статуса
sudo ufw status
```

### Альтернатива: iptables

```bash
# Если используете iptables напрямую
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 1194 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
# ... добавьте остальные порты

# Сохранение правил
sudo netfilter-persistent save
```

---

## Запуск

### Проверка конфигурации

```bash
# Проверка docker-compose.yml
make check

# Или вручную
docker-compose config
```

### Сборка образов

```bash
# Через Makefile (рекомендуется)
make build

# Или напрямую
docker-compose build --no-cache
```

### Запуск всех сервисов

```bash
# Через Makefile
make up

# Или напрямую
docker-compose up -d

# Проверка статуса
make status
# или
docker-compose ps
```

### Просмотр логов

```bash
# Все сервисы
make logs

# Конкретный сервис
make logs-openvpn
make logs-dpi
make logs-shadowsocks

# Или напрямую
docker-compose logs -f openvpn
```

---

## Создание клиентов

### OpenVPN клиент

#### Через Makefile (проще):

```bash
# Создание клиента
make client NAME=john

# Файл john.ovpn будет создан в текущей директории
```

#### Вручную:

```bash
# Создание клиента
docker exec openvpn-server /usr/local/bin/generate-client.sh john YOUR_SERVER_IP

# Скачивание конфигурации
docker cp openvpn-server:/etc/openvpn/client/john.ovpn ./

# Отправка файла клиенту
scp john.ovpn user@client-machine:~/
```

### Shadowsocks клиент

**Конфигурация для клиента:**

```json
{
  "server": "YOUR_SERVER_IP",
  "server_port": 8388,
  "password": "ваш_SS_PASSWORD_из_.env",
  "method": "chacha20-ietf-poly1305",
  "timeout": 300
}
```

**Приложения:**
- **Android**: Shadowsocks (Max Lv)
- **iOS**: Shadowrocket
- **Windows**: Shadowsocks-Windows
- **macOS**: ShadowsocksX-NG
- **Linux**: shadowsocks-libev

### V2Ray клиент

**Получение UUID:**

```bash
# Из логов
docker logs v2ray-server | grep UUID

# Из .env
grep V2RAY_UUID .env
```

**Конфигурация для клиента:**

```
Адрес: YOUR_SERVER_IP
Порт: 10086 (VMess) или 10087 (WebSocket)
UUID: [ваш V2RAY_UUID]
AlterID: 0
Шифрование: auto
Сеть: tcp (для 10086) или ws (для 10087)
TLS: none
```

**Приложения:**
- **Android**: v2rayNG
- **iOS**: Shadowrocket, Quantumult X
- **Windows**: v2rayN
- **macOS**: V2RayX

---

## Проверка работы

### 1. Проверка контейнеров

```bash
# Все контейнеры должны быть в статусе "Up"
docker-compose ps

# Или
make status
```

### 2. Проверка логов

```bash
# OpenVPN должен показывать "Initialization Sequence Completed"
docker-compose logs openvpn | grep -i "completed"

# Нет критических ошибок
docker-compose logs | grep -i error
```

### 3. Проверка портов

```bash
# Все порты должны слушаться
sudo netstat -tulpn | grep -E "443|1194|8388|10086"

# Или через ss
sudo ss -tulpn | grep -E "443|1194|8388|10086"
```

### 4. Тест подключения OpenVPN

```bash
# С клиентской машины
openvpn --config john.ovpn

# Успешное подключение показывает:
# "Initialization Sequence Completed"
```

### 5. Web UI

```bash
# Откройте в браузере
http://YOUR_SERVER_IP:8080

# Логин: admin
# Пароль: из .env (ADMIN_PASSWORD)
```

### 6. Проверка доступа в интернет через VPN

```bash
# После подключения к VPN проверьте IP
curl ifconfig.me

# Должен показать IP вашего VPN сервера
```

---

## Troubleshooting

### Контейнер не запускается

```bash
# Просмотр логов
docker-compose logs [service_name]

# Пересоздание контейнера
docker-compose up -d --force-recreate [service_name]

# Полная переустановка контейнера
docker-compose down
docker-compose up -d
```

### OpenVPN не подключается

**Проблема**: "Connection timed out"

```bash
# 1. Проверьте файрвол
sudo ufw status
sudo iptables -L -n

# 2. Проверьте что порт слушается
sudo netstat -tulpn | grep 1194

# 3. Проверьте логи
docker-compose logs openvpn

# 4. Проверьте TUN устройство
docker exec openvpn-server ip link show tun0
```

**Проблема**: "TLS handshake failed"

```bash
# Пересоздайте PKI
docker exec openvpn-server rm -rf /etc/openvpn/pki
docker-compose restart openvpn

# Пересоздайте клиентскую конфигурацию
make client NAME=newclient
```

### DPI все еще блокирует

```bash
# 1. Попробуйте другой режим
# В .env измените MODE=tpws на MODE=nfqws
docker-compose restart dpi-bypass

# 2. Используйте Stunnel порт
# Подключайтесь к порту 4443 вместо 443

# 3. Попробуйте страновой пресет
# В .env установите COUNTRY_PRESET=russia (или china, iran, turkey)
docker-compose restart dpi-bypass

# 4. Используйте альтернативный протокол
# Shadowsocks или V2Ray вместо OpenVPN
```

### Медленная скорость

```bash
# 1. Используйте UDP вместо TCP
# В .env: OPENVPN_PROTO=udp
docker-compose restart openvpn

# 2. Отключите сжатие
# В .env: OPENVPN_COMPRESSION=false
docker-compose restart openvpn

# 3. Отключите обфускацию для теста
# В .env: OPENVPN_ENABLE_OBFUSCATION=false
docker-compose restart openvpn

# 4. Проверьте загрузку сервера
htop
# или
docker stats
```

### Не работает Web UI

```bash
# Проверьте контейнер
docker-compose ps webui

# Проверьте логи
docker-compose logs webui

# Проверьте Redis
docker-compose ps redis

# Перезапуск
docker-compose restart webui redis
```

### Ошибка "Permission denied"

```bash
# Дайте права на выполнение скриптов
chmod +x openvpn/scripts/*.sh
chmod +x dpi-bypass/scripts/*.sh
chmod +x stunnel/scripts/*.sh
chmod +x dnscrypt/scripts/*.sh

# Пересоберите
docker-compose build --no-cache
docker-compose up -d
```

---

## Резервное копирование

### Создание бэкапа

```bash
# Через Makefile
make backup

# Или вручную
tar czf vpn-backup-$(date +%Y%m%d).tar.gz \
  openvpn/certs \
  openvpn/config \
  .env \
  docker-compose.yml
```

### Восстановление

```bash
# Через Makefile
make restore BACKUP=backups/vpn-backup-YYYYMMDD.tar.gz

# Или вручную
tar xzf vpn-backup-YYYYMMDD.tar.gz
docker-compose down
docker-compose up -d
```

---

## Обновление

### Обновление Docker образов

```bash
# Через Makefile
make update

# Или вручную
docker-compose pull
docker-compose up -d --force-recreate
```

### Обновление конфигурации

```bash
# 1. Создайте бэкап
make backup

# 2. Обновите конфигурационные файлы

# 3. Пересоберите образы
make build

# 4. Перезапустите
make restart
```

---

## Полезные команды

```bash
# Информация о конфигурации
make info

# Генерация новых паролей
make passwords

# Список клиентов
make client-list

# Удаление клиента
make client-delete NAME=username

# Статистика подключений
make stats

# Открыть Web UI в браузере
make webui

# Открыть Grafana
make monitor

# Проверка портов
make test-connection

# Помощь по всем командам
make help
```

---

## Дополнительная настройка

### Настройка доменного имени

```bash
# 1. Направьте домен на IP сервера (A запись)
# vpn.example.com -> YOUR_SERVER_IP

# 2. Обновите .env
# SERVER_IP=vpn.example.com

# 3. Перезапустите
docker-compose down
docker-compose up -d

# 4. Пересоздайте клиентские конфиги
make client NAME=newclient
```

### SSL сертификат для Web UI

```bash
# Используйте Nginx как reverse proxy с Let's Encrypt
# Или настройте Caddy для автоматических HTTPS
```

---

## Безопасность

### Рекомендации:

1. **Измените все пароли по умолчанию**
2. **Используйте сильные пароли (20+ символов)**
3. **Регулярно обновляйте систему и Docker**
4. **Создавайте бэкапы**
5. **Ограничьте доступ к Web UI (только с определенных IP)**
6. **Включите fail2ban для защиты SSH**
7. **Используйте ключи SSH вместо паролей**
8. **Мониторьте логи на подозрительную активность**

---

**Готово!** Ваш VPN сервер с обфускацией полностью настроен и работает. 🎉
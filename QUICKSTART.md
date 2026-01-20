# Quick Start Guide - VPN Obfuscation Stack

## 🚀 Установка за 5 минут

### Вариант 1: Автоматическая установка (рекомендуется)

```bash
# 1. Скачайте установочный скрипт
wget https://raw.githubusercontent.com/your-repo/vpn-obfuscation-stack/main/install.sh

# 2. Сделайте его исполняемым
chmod +x install.sh

# 3. Запустите от root
sudo ./install.sh

# 4. Скопируйте все файлы проекта в /opt/vpn-obfuscation-stack/
sudo cp -r * /opt/vpn-obfuscation-stack/

# 5. Перейдите в директорию
cd /opt/vpn-obfuscation-stack

# 6. Запустите
sudo docker-compose up -d

# 7. Создайте первого клиента
sudo docker exec openvpn-server /usr/local/bin/generate-client.sh client1 YOUR_SERVER_IP

# 8. Скачайте конфигурацию
sudo docker cp openvpn-server:/etc/openvpn/client/client1.ovpn ./
```

### Вариант 2: Ручная установка

```bash
# 1. Установите Docker и Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2. Клонируйте/создайте структуру проекта
mkdir -p ~/vpn-obfuscation-stack
cd ~/vpn-obfuscation-stack

# 3. Создайте все необходимые директории
mkdir -p openvpn/{config,scripts,certs}
mkdir -p dpi-bypass/{config,scripts,lists}
mkdir -p stunnel/{config,scripts,certs}
mkdir -p dnscrypt/{config,scripts}
mkdir -p shadowsocks/{config,scripts}
mkdir -p v2ray/{config,scripts}
mkdir -p webui/{app,templates,static}
mkdir -p monitoring/{prometheus,grafana}

# 4. Скопируйте все файлы в соответствующие директории
# (docker-compose.yml, Dockerfile's, конфиги, скрипты)

# 5. Создайте .env файл
cat > .env <<'EOF'
SERVER_IP=YOUR_SERVER_IP_HERE
OPENVPN_ENABLE_OBFUSCATION=true
OPENVPN_SCRAMBLE_PASSWORD=ChangeMe123
OPENVPN_PROTO=tcp
OPENVPN_PORT=1194
SERVER_SUBNET=10.8.0.0
DNS_SERVER_1=10.8.0.1
DNS_SERVER_2=1.1.1.1
SS_PASSWORD=ChangeMe456
SS_METHOD=chacha20-ietf-poly1305
V2RAY_UUID=$(cat /proc/sys/kernel/random/uuid)
ADMIN_PASSWORD=admin123
SECRET_KEY=$(openssl rand -hex 32)
MODE=tpws
EOF

# 6. Замените YOUR_SERVER_IP на реальный IP
sed -i "s/YOUR_SERVER_IP_HERE/$(curl -s ifconfig.me)/" .env

# 7. Соберите образы
docker-compose build

# 8. Запустите все сервисы
docker-compose up -d

# 9. Проверьте статус
docker-compose ps
```

## 📱 Создание клиентских конфигураций

### OpenVPN

```bash
# Создание клиента
docker exec openvpn-server /usr/local/bin/generate-client.sh john YOUR_SERVER_IP

# Скачивание конфигурации
docker cp openvpn-server:/etc/openvpn/client/john.ovpn ./

# Импортируйте john.ovpn в OpenVPN клиент на телефоне или компьютере
```

### Shadowsocks

**Для Android:** Установите приложение Shadowsocks
**Для iOS:** Установите приложение Shadowrocket

**Конфигурация:**
```
Сервер: YOUR_SERVER_IP
Порт: 8388
Пароль: (из .env файла SS_PASSWORD)
Метод шифрования: chacha20-ietf-poly1305
```

### V2Ray

**Для Android:** Установите v2rayNG
**Для iOS:** Установите Shadowrocket

**Получение UUID:**
```bash
docker logs v2ray-server | grep UUID
```

**Конфигурация:**
```
Адрес: YOUR_SERVER_IP
Порт: 10086 (VMess) или 10087 (WebSocket)
UUID: (из логов)
AlterID: 0
Шифрование: auto
Сеть: tcp или ws
```

## 🌐 Веб-интерфейс

```bash
# Откройте в браузере
http://YOUR_SERVER_IP:8080

# Логин
Username: admin
Password: (из .env файла ADMIN_PASSWORD)
```

## 📊 Мониторинг

### Grafana
```bash
URL: http://YOUR_SERVER_IP:3000
Login: admin / admin
```

### Логи
```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f openvpn
docker-compose logs -f dpi-bypass
docker-compose logs -f shadowsocks

# Статус подключений OpenVPN
docker exec openvpn-server cat /var/log/openvpn/openvpn-status.log
```

## ⚙️ Основные команды

```bash
# Запуск всех сервисов
docker-compose up -d

# Остановка
docker-compose down

# Перезапуск конкретного сервиса
docker-compose restart openvpn

# Просмотр логов
docker-compose logs -f openvpn

# Просмотр статуса
docker-compose ps

# Вход в контейнер
docker exec -it openvpn-server bash

# Обновление
docker-compose pull
docker-compose up -d --force-recreate
```

## 🔧 Быстрое решение проблем

### OpenVPN не подключается

```bash
# 1. Проверьте логи
docker-compose logs openvpn

# 2. Проверьте порты
netstat -tulpn | grep -E "443|1194"

# 3. Проверьте файрвол
sudo ufw status

# 4. Перезапустите контейнер
docker-compose restart openvpn
```

### Медленная скорость

```bash
# 1. Попробуйте UDP вместо TCP
# В .env измените:
OPENVPN_PROTO=udp

# 2. Отключите обфускацию для теста
OPENVPN_ENABLE_OBFUSCATION=false

# 3. Перезапустите
docker-compose down && docker-compose up -d
```

### DPI блокирует подключение

```bash
# 1. Смените режим DPI bypass
# В .env измените:
MODE=nfqws  # или tpws

# 2. Используйте Stunnel порт
# Подключайтесь к порту 4443 вместо 443

# 3. Попробуйте другой протокол
# Используйте Shadowsocks или V2Ray вместо OpenVPN
```

## 📋 Чек-лист после установки

- [ ] Все контейнеры запущены (`docker-compose ps`)
- [ ] OpenVPN работает (проверьте логи)
- [ ] Создан хотя бы один клиент
- [ ] Клиентская конфигурация скачана
- [ ] Подключение работает с клиента
- [ ] Web UI доступен
- [ ] Пароли изменены с дефолтных
- [ ] Файрвол настроен
- [ ] Бэкап сертификатов создан

## 🔐 Безопасность

**Обязательно измените:**
```bash
# В .env файле:
ADMIN_PASSWORD=your_strong_password_here
OPENVPN_SCRAMBLE_PASSWORD=your_scramble_password_here
SS_PASSWORD=your_shadowsocks_password_here
```

**Создайте бэкап:**
```bash
tar czf vpn-backup-$(date +%Y%m%d).tar.gz \
  openvpn/certs \
  openvpn/config \
  .env
```

## 🆘 Получение помощи

1. Проверьте логи: `docker-compose logs -f [service]`
2. Проверьте статус: `docker-compose ps`
3. Проверьте порты: `netstat -tulpn`
4. Проверьте файрвол: `sudo ufw status`
5. Читайте полную документацию в README.md

## 📚 Полезные ссылки

- **OpenVPN клиенты:**
  - Windows/Mac/Linux: https://openvpn.net/community-downloads/
  - Android: OpenVPN Connect или OpenVPN for Android
  - iOS: OpenVPN Connect
  
- **Shadowsocks клиенты:**
  - Android: Shadowsocks от Max Lv
  - iOS: Shadowrocket (платный)
  - Windows: Shadowsocks-Windows
  
- **V2Ray клиенты:**
  - Android: v2rayNG
  - iOS: Shadowrocket, Quantumult X
  - Windows: v2rayN
  - Mac: V2RayX

---

**Готово!** Теперь у вас работающий VPN сервер с множественными протоколами и обфускацией. 🎉
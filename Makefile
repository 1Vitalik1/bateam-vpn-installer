# VPN Obfuscation Stack - Makefile
# Удобные команды для управления

.PHONY: help install build up down restart logs status clean backup restore client

# Цвета для вывода
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Показать эту справку
	@echo "$(GREEN)VPN Obfuscation Stack - Доступные команды:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

install: ## Установить зависимости и настроить систему
	@echo "$(GREEN)Запуск установки...$(NC)"
	@chmod +x install.sh
	@sudo ./install.sh

build: ## Собрать все Docker образы
	@echo "$(GREEN)Сборка Docker образов...$(NC)"
	@docker-compose build --no-cache

up: ## Запустить все сервисы
	@echo "$(GREEN)Запуск сервисов...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Сервисы запущены!$(NC)"
	@make status

down: ## Остановить все сервисы
	@echo "$(YELLOW)Остановка сервисов...$(NC)"
	@docker-compose down
	@echo "$(GREEN)Сервисы остановлены$(NC)"

restart: ## Перезапустить все сервисы
	@echo "$(YELLOW)Перезапуск сервисов...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)Сервисы перезапущены$(NC)"

logs: ## Показать логи всех сервисов
	@docker-compose logs -f --tail=100

logs-openvpn: ## Показать логи OpenVPN
	@docker-compose logs -f --tail=100 openvpn

logs-dpi: ## Показать логи DPI bypass
	@docker-compose logs -f --tail=100 dpi-bypass

logs-shadowsocks: ## Показать логи Shadowsocks
	@docker-compose logs -f --tail=100 shadowsocks

logs-v2ray: ## Показать логи V2Ray
	@docker-compose logs -f --tail=100 v2ray

status: ## Показать статус всех сервисов
	@echo "$(GREEN)Статус сервисов:$(NC)"
	@docker-compose ps

shell-openvpn: ## Войти в контейнер OpenVPN
	@docker exec -it openvpn-server bash

shell-dpi: ## Войти в контейнер DPI bypass
	@docker exec -it dpi-bypass bash

clean: ## Очистить все (остановить и удалить контейнеры, сети, volumes)
	@echo "$(RED)ВНИМАНИЕ: Это удалит все контейнеры, сети и volumes!$(NC)"
	@read -p "Вы уверены? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@docker-compose down -v --remove-orphans
	@echo "$(GREEN)Очистка завершена$(NC)"

backup: ## Создать бэкап конфигураций и сертификатов
	@echo "$(GREEN)Создание бэкапа...$(NC)"
	@mkdir -p backups
	@tar czf backups/vpn-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		openvpn/certs \
		openvpn/config \
		.env \
		docker-compose.yml
	@echo "$(GREEN)Бэкап создан в директории backups/$(NC)"

restore: ## Восстановить из бэкапа (укажите файл: make restore BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Ошибка: укажите файл бэкапа$(NC)"; \
		echo "Использование: make restore BACKUP=backups/vpn-backup-YYYYMMDD-HHMMSS.tar.gz"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Восстановление из $(BACKUP)...$(NC)"
	@tar xzf $(BACKUP)
	@echo "$(GREEN)Восстановление завершено$(NC)"

client: ## Создать нового клиента (использование: make client NAME=username)
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Ошибка: укажите имя клиента$(NC)"; \
		echo "Использование: make client NAME=username"; \
		exit 1; \
	fi
	@echo "$(GREEN)Создание клиента $(NAME)...$(NC)"
	@docker exec openvpn-server /usr/local/bin/generate-client.sh $(NAME) $$(grep SERVER_IP .env | cut -d= -f2)
	@docker cp openvpn-server:/etc/openvpn/client/$(NAME).ovpn ./
	@echo "$(GREEN)Клиент создан! Конфигурация: ./$(NAME).ovpn$(NC)"

client-list: ## Показать список всех клиентов
	@echo "$(GREEN)Список клиентов:$(NC)"
	@docker exec openvpn-server ls -1 /etc/openvpn/client/ | grep .ovpn || echo "Нет клиентов"

client-delete: ## Удалить клиента (использование: make client-delete NAME=username)
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Ошибка: укажите имя клиента$(NC)"; \
		echo "Использование: make client-delete NAME=username"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Удаление клиента $(NAME)...$(NC)"
	@docker exec openvpn-server /usr/local/share/easy-rsa/easyrsa revoke $(NAME)
	@docker exec openvpn-server rm -f /etc/openvpn/client/$(NAME).ovpn
	@echo "$(GREEN)Клиент удален$(NC)"

update: ## Обновить все образы
	@echo "$(GREEN)Обновление образов...$(NC)"
	@docker-compose pull
	@docker-compose up -d --force-recreate
	@echo "$(GREEN)Обновление завершено$(NC)"

check: ## Проверить конфигурацию
	@echo "$(GREEN)Проверка конфигурации...$(NC)"
	@docker-compose config -q && echo "$(GREEN)✓ docker-compose.yml валиден$(NC)" || echo "$(RED)✗ Ошибка в docker-compose.yml$(NC)"
	@test -f .env && echo "$(GREEN)✓ .env файл существует$(NC)" || echo "$(RED)✗ .env файл не найден$(NC)"
	@grep -q "YOUR_SERVER_IP_HERE" .env && echo "$(YELLOW)⚠ Замените YOUR_SERVER_IP_HERE в .env$(NC)" || echo "$(GREEN)✓ SERVER_IP настроен$(NC)"
	@grep -q "GENERATE_UUID_HERE" .env && echo "$(YELLOW)⚠ Сгенерируйте UUID для V2Ray$(NC)" || echo "$(GREEN)✓ V2Ray UUID настроен$(NC)"

passwords: ## Сгенерировать новые пароли для .env
	@echo "$(GREEN)Генерация новых паролей:$(NC)"
	@echo ""
	@echo "OPENVPN_SCRAMBLE_PASSWORD=$$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
	@echo "SS_PASSWORD=$$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
	@echo "ADMIN_PASSWORD=$$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)"
	@echo "SECRET_KEY=$$(openssl rand -hex 32)"
	@echo "V2RAY_UUID=$$(cat /proc/sys/kernel/random/uuid)"
	@echo ""
	@echo "$(YELLOW)Скопируйте эти значения в .env файл$(NC)"

stats: ## Показать статистику подключений
	@echo "$(GREEN)Статистика OpenVPN:$(NC)"
	@docker exec openvpn-server cat /var/log/openvpn/openvpn-status.log 2>/dev/null || echo "Логи недоступны"

test-connection: ## Проверить доступность портов
	@echo "$(GREEN)Проверка портов...$(NC)"
	@netstat -tulpn | grep -E "443|1194|8388|10086|10087|8080|3000" || echo "$(YELLOW)Некоторые порты не открыты$(NC)"

firewall: ## Настроить UFW файрвол
	@echo "$(GREEN)Настройка UFW...$(NC)"
	@sudo ufw allow 22/tcp
	@sudo ufw allow 443/tcp
	@sudo ufw allow 1194/tcp
	@sudo ufw allow 1194/udp
	@sudo ufw allow 4443/tcp
	@sudo ufw allow 8388/tcp
	@sudo ufw allow 8388/udp
	@sudo ufw allow 10086/tcp
	@sudo ufw allow 10087/tcp
	@sudo ufw allow 8080/tcp
	@sudo ufw allow 3000/tcp
	@sudo ufw --force enable
	@echo "$(GREEN)Файрвол настроен$(NC)"

monitor: ## Открыть Grafana в браузере
	@echo "$(GREEN)Открытие Grafana...$(NC)"
	@SERVER_IP=$$(grep SERVER_IP .env | cut -d= -f2) && \
	echo "URL: http://$$SERVER_IP:3000" && \
	xdg-open "http://$$SERVER_IP:3000" 2>/dev/null || open "http://$$SERVER_IP:3000" 2>/dev/null || echo "Откройте вручную: http://$$SERVER_IP:3000"

webui: ## Открыть Web UI в браузере
	@echo "$(GREEN)Открытие Web UI...$(NC)"
	@SERVER_IP=$$(grep SERVER_IP .env | cut -d= -f2) && \
	echo "URL: http://$$SERVER_IP:8080" && \
	xdg-open "http://$$SERVER_IP:8080" 2>/dev/null || open "http://$$SERVER_IP:8080" 2>/dev/null || echo "Откройте вручную: http://$$SERVER_IP:8080"

info: ## Показать информацию о конфигурации
	@echo "$(GREEN)Конфигурация сервера:$(NC)"
	@echo ""
	@echo "Server IP: $$(grep SERVER_IP .env | cut -d= -f2)"
	@echo "OpenVPN Port: $$(grep OPENVPN_PORT .env | cut -d= -f2)"
	@echo "Shadowsocks Port: $$(grep SS_SERVER_PORT .env | cut -d= -f2)"
	@echo "V2Ray VMess Port: $$(grep V2RAY_VMESS_PORT .env | cut -d= -f2)"
	@echo "V2Ray WS Port: $$(grep V2RAY_WS_PORT .env | cut -d= -f2)"
	@echo "Web UI Port: $$(grep WEBUI_PORT .env | cut -d= -f2)"
	@echo ""
	@echo "$(GREEN)Сервисы:$(NC)"
	@docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

dev: ## Режим разработки (с живыми логами)
	@docker-compose up

prod: build up ## Production режим (сборка и запуск в фоне)

all: check build up status ## Полная установка (проверка + сборка + запуск)
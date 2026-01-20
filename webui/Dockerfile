FROM python:3.11-slim

LABEL description="Web UI for VPN management"

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    qrencode \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /app

# Копирование requirements
COPY requirements.txt .

# Установка Python пакетов
RUN pip install --no-cache-dir -r requirements.txt

# Копирование приложения
COPY app/ /app/

# Создание директорий
RUN mkdir -p /app/data /app/logs /app/static /app/templates

# Установка прав
RUN chmod +x /app/run.py

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "run.py"]
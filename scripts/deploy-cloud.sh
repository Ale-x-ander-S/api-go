#!/bin/bash

# Скрипт деплоя на облачный сервер
# Использование: ./deploy-cloud.sh [staging|prod] [server_ip]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка аргументов
if [ $# -lt 2 ]; then
    log_error "Использование: $0 [staging|prod] [server_ip]"
    echo "Пример: $0 prod 192.168.1.100"
    exit 1
fi

ENVIRONMENT=$1
SERVER_IP=$2
REMOTE_USER=${3:-root}

# Проверка окружения
case $ENVIRONMENT in
    staging)
        DOCKER_COMPOSE_FILE="docker-compose.staging.yml"
        CONFIG_FILE="config.staging.env"
        ;;
    prod|production)
        DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
        CONFIG_FILE="config.prod.env"
        ;;
    *)
        log_error "Неверное окружение: $ENVIRONMENT"
        echo "Доступные окружения: staging, prod"
        exit 1
        ;;
esac

log_info "🚀 Деплой на облачный сервер"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
echo ""

# Проверка файлов
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    log_error "Файл $DOCKER_COMPOSE_FILE не найден"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Файл $CONFIG_FILE не найден"
    exit 1
fi

# Проверка SSH соединения
log_info "Проверка SSH соединения..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$SERVER_IP" exit 2>/dev/null; then
    log_error "Не удается подключиться к серверу $SERVER_IP"
    log_info "Убедитесь что:"
    log_info "1. SSH ключи настроены"
    log_info "2. Сервер доступен"
    log_info "3. Пользователь $REMOTE_USER существует"
    exit 1
fi
log_success "SSH соединение установлено"

# Создание директории на сервере
log_info "Создание директории на сервере..."
ssh "$REMOTE_USER@$SERVER_IP" "mkdir -p ~/api-go"

# Копирование файлов
log_info "Копирование файлов на сервер..."
scp "$DOCKER_COMPOSE_FILE" "$REMOTE_USER@$SERVER_IP:~/api-go/"
scp "$CONFIG_FILE" "$REMOTE_USER@$SERVER_IP:~/api-go/"
scp "Dockerfile" "$REMOTE_USER@$SERVER_IP:~/api-go/"
scp "init.sql" "$REMOTE_USER@$SERVER_IP:~/api-go/"
scp -r "nginx" "$REMOTE_USER@$SERVER_IP:~/api-go/" 2>/dev/null || log_warning "Nginx конфигурация не найдена"

# Деплой на сервере
log_info "Запуск деплоя на сервере..."
ssh "$REMOTE_USER@$SERVER_IP" "cd ~/api-go && \
    docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans && \
    docker-compose -f $DOCKER_COMPOSE_FILE build --no-cache && \
    docker-compose -f $DOCKER_COMPOSE_FILE up -d"

# Проверка статуса
log_info "Проверка статуса сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "cd ~/api-go && docker-compose -f $DOCKER_COMPOSE_FILE ps"

log_success "✅ Деплой завершен успешно!"
log_info "🌐 API доступен по адресу: http://$SERVER_IP:8080"
if [ "$ENVIRONMENT" = "prod" ]; then
    log_info "🌐 Nginx доступен по адресу: http://$SERVER_IP"
fi

# Показываем логи
log_info "Показать логи? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd ~/api-go && docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
fi 
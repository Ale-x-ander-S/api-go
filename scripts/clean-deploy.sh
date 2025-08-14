#!/bin/bash

# Скрипт полной очистки сервера и нового деплоя
# Использование: ./clean-deploy.sh [staging|prod] [server_ip] [user]

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
    log_error "Использование: $0 [staging|prod] [server_ip] [user]"
    echo "Пример: $0 prod 45.12.229.112 root"
    exit 1
fi

ENVIRONMENT=$1
SERVER_IP=$2
REMOTE_USER=${3:-root}
REMOTE_DIR="/opt/api-go"

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

log_info "🧹 Полная очистка и передеплой на сервер"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
log_info "Директория: $REMOTE_DIR"
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

# Остановка и удаление всех контейнеров
log_info "🛑 Остановка всех контейнеров..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans --volumes 2>/dev/null || true
    docker-compose down --remove-orphans --volumes 2>/dev/null || true
    docker stop \$(docker ps -aq) 2>/dev/null || true
    docker rm \$(docker ps -aq) 2>/dev/null || true
"

# Удаление всех образов
log_info "🗑️  Удаление Docker образов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker rmi \$(docker images -q) 2>/dev/null || true
    docker system prune -af --volumes 2>/dev/null || true
"

# Полная очистка директории
log_info "🧹 Полная очистка директории $REMOTE_DIR..."
ssh "$REMOTE_USER@$SERVER_IP" "
    sudo rm -rf $REMOTE_DIR
    sudo mkdir -p $REMOTE_DIR
    sudo chown $REMOTE_USER:$REMOTE_USER $REMOTE_DIR
"

# Копирование файлов
log_info "📁 Копирование файлов на сервер..."
scp "$DOCKER_COMPOSE_FILE" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "$CONFIG_FILE" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "Dockerfile" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "init.sql" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "nginx" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/" 2>/dev/null || log_warning "Nginx конфигурация не найдена"

# Копирование исходного кода (если нужно)
log_info "📦 Копирование исходного кода..."
scp -r "handlers" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "models" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "routes" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "middleware" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "utils" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "config" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "cache" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp -r "database" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "main.go" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "go.mod" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
scp "go.sum" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"

# Установка Go на сервере (если нужно)
log_info "🔧 Проверка Go на сервере..."
ssh "$REMOTE_USER@$SERVER_IP" "
    if ! command -v go &> /dev/null; then
        echo 'Установка Go...'
        wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        echo 'export PATH=\$PATH:/usr/local/go/bin' >> ~/.bashrc
        export PATH=\$PATH:/usr/local/go/bin
        rm go1.21.0.linux-amd64.tar.gz
    fi
    go version
"

# Сборка и запуск
log_info "🚀 Сборка и запуск приложения..."
ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && \
    docker-compose -f $DOCKER_COMPOSE_FILE build --no-cache && \
    docker-compose -f $DOCKER_COMPOSE_FILE up -d"

# Ожидание запуска
log_info "⏳ Ожидание запуска сервисов..."
sleep 30

# Проверка статуса
log_info "🔍 Проверка статуса сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE ps"

# Проверка доступности API
log_info "🌐 Проверка доступности API..."
if [ "$ENVIRONMENT" = "prod" ]; then
    API_PORT="8082"
else
    API_PORT="8081"
fi

if curl -s --connect-timeout 10 "http://$SERVER_IP:$API_PORT/health" > /dev/null; then
    log_success "✅ API доступен по адресу: http://$SERVER_IP:$API_PORT"
else
    log_warning "⚠️  API пока недоступен, проверьте логи"
fi

log_success "🎉 Очистка и передеплой завершены!"
log_info "📊 Для мониторинга используйте:"
echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f'"
echo ""

# Показываем логи
log_info "Показать логи? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
fi 
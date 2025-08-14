#!/bin/bash

# Скрипт диагностики и исправления проблем с Redis
# Использование: ./fix-redis.sh [staging|prod] [server_ip] [user]

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
        REDIS_PORT="6380"
        ;;
    prod|production)
        DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
        CONFIG_FILE="config.prod.env"
        REDIS_PORT="6381"
        ;;
    *)
        log_error "Неверное окружение: $ENVIRONMENT"
        echo "Доступные окружения: staging, prod"
        exit 1
        ;;
esac

log_info "🔧 Диагностика и исправление проблем с Redis"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
log_info "Redis порт: $REDIS_PORT"
echo ""

# Проверка SSH соединения
log_info "Проверка SSH соединения..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$SERVER_IP" exit 2>/dev/null; then
    log_error "Не удается подключиться к серверу $SERVER_IP"
    exit 1
fi
log_success "SSH соединение установлено"

# Диагностика Redis
log_info "🔍 Диагностика Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус контейнеров ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps
    
    echo ''
    echo '=== Логи Redis ==='
    docker-compose -f $DOCKER_COMPOSE_FILE logs redis 2>/dev/null || echo 'Redis контейнер не найден'
    
    echo ''
    echo '=== Docker процессы ==='
    docker ps -a | grep redis || echo 'Redis контейнеры не найдены'
    
    echo ''
    echo '=== Проверка портов ==='
    netstat -tlnp | grep $REDIS_PORT || echo 'Порт $REDIS_PORT не прослушивается'
    
    echo ''
    echo '=== Проверка volumes ==='
    docker volume ls | grep redis || echo 'Redis volumes не найдены'
"

# Исправление проблем
log_info "🛠️  Исправление проблем с Redis..."

# Остановка Redis
log_info "Остановка Redis контейнера..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE stop redis 2>/dev/null || true
    docker-compose -f $DOCKER_COMPOSE_FILE rm -f redis 2>/dev/null || true
"

# Очистка Redis данных (если нужно)
log_info "Очистка Redis данных..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker volume rm \$(docker volume ls -q | grep redis) 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
"

# Перезапуск Redis
log_info "Перезапуск Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE up -d redis
"

# Ожидание запуска
log_info "⏳ Ожидание запуска Redis..."
sleep 45

# Проверка статуса
log_info "🔍 Проверка статуса Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус Redis ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps redis
    
    echo ''
    echo '=== Health check Redis ==='
    docker inspect \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q redis) | grep -A 10 Health || echo 'Health check недоступен'
    
    echo ''
    echo '=== Тест подключения к Redis ==='
    docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q redis) redis-cli -a \$(grep REDIS_PASSWORD $CONFIG_FILE | cut -d'=' -f2) ping 2>/dev/null || echo 'Подключение к Redis не удалось'
"

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
    log_warning "⚠️  API пока недоступен"
fi

log_success "🎉 Диагностика и исправление Redis завершены!"
echo ""

# Показываем логи
log_info "Показать логи Redis? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f redis"
fi 
#!/bin/bash

# Универсальный скрипт исправления проблем с базами данных
# Использование: ./fix-databases.sh [staging|prod] [server_ip] [user]

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

log_info "🔧 Исправление проблем с базами данных"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
echo ""

# Проверка SSH соединения
log_info "Проверка SSH соединения..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$SERVER_IP" exit 2>/dev/null; then
    log_error "Не удается подключиться к серверу $SERVER_IP"
    exit 1
fi
log_success "SSH соединение установлено"

# Полная диагностика
log_info "🔍 Полная диагностика системы..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Общий статус ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps
    
    echo ''
    echo '=== Docker info ==='
    docker info 2>/dev/null | head -20 || echo 'Docker недоступен'
    
    echo ''
    echo '=== Дисковое пространство ==='
    df -h
    
    echo ''
    echo '=== Память ==='
    free -h
    
    echo ''
    echo '=== Сетевые порты ==='
    netstat -tlnp | grep -E '(543|637|808)' || echo 'Нет активных портов'
"

# Остановка всех сервисов
log_info "🛑 Остановка всех сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans --volumes
"

# Очистка Docker
log_info "🧹 Очистка Docker..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker system prune -af --volumes
    docker volume prune -f
    docker network prune -f
"

# Проверка и исправление прав
log_info "🔐 Проверка прав доступа..."
ssh "$REMOTE_USER@$SERVER_IP" "
    if [ -d $REMOTE_DIR ]; then
        echo 'Права на директорию:'
        ls -la $REMOTE_DIR/
        echo ''
        echo 'Права пользователя:'
        whoami && id
        echo ''
        echo 'Исправление прав...'
        sudo chown -R $REMOTE_USER:$REMOTE_USER $REMOTE_DIR/
        sudo chmod -R 755 $REMOTE_DIR/
    fi
"

# Перезапуск сервисов
log_info "🚀 Перезапуск сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
"

# Ожидание запуска
log_info "⏳ Ожидание запуска сервисов..."
sleep 60

# Проверка статуса
log_info "🔍 Проверка статуса сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус всех сервисов ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps
    
    echo ''
    echo '=== Health checks ==='
    echo 'PostgreSQL:'
    docker inspect \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) | grep -A 5 Health || echo 'Health check недоступен'
    echo ''
    echo 'Redis:'
    docker inspect \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q redis) | grep -A 5 Health || echo 'Health check недоступен'
    echo ''
    echo 'API:'
    docker inspect \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q api) | grep -A 5 Health || echo 'Health check недоступен'
"

# Тестирование подключений
log_info "🧪 Тестирование подключений..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Тест PostgreSQL ==='
    if docker-compose -f $DOCKER_COMPOSE_FILE ps postgres | grep -q 'Up'; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) pg_isready -U postgres || echo 'PostgreSQL не готов'
    else
        echo 'PostgreSQL не запущен'
    fi
    
    echo ''
    echo '=== Тест Redis ==='
    if docker-compose -f $DOCKER_COMPOSE_FILE ps redis | grep -q 'Up'; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q redis) redis-cli -a \$(grep REDIS_PASSWORD $CONFIG_FILE | cut -d'=' -f2) ping || echo 'Redis не отвечает'
    else
        echo 'Redis не запущен'
    fi
    
    echo ''
    echo '=== Тест API ==='
    if docker-compose -f $DOCKER_COMPOSE_FILE ps api | grep -q 'Up'; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/health || echo 'API не отвечает'
    else
        echo 'API не запущен'
    fi
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

log_success "🎉 Исправление проблем с базами данных завершено!"
echo ""

# Показываем логи
log_info "Показать логи всех сервисов? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
fi 
#!/bin/bash

# Скрипт запуска только Redis без healthcheck
# Использование: ./start-redis-only.sh [staging|prod] [server_ip] [user]

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

log_info "🚀 Запуск только Redis без healthcheck"
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

# Остановка Redis
log_info "🛑 Остановка Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE stop redis 2>/dev/null || true
    docker-compose -f $DOCKER_COMPOSE_FILE rm -f redis 2>/dev/null || true
"

# Создание временного docker-compose файла без healthcheck
log_info "📝 Создание временной конфигурации Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Создаем временный файл без healthcheck
    cat > redis-only.yml << 'EOF'
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    container_name: products_redis_prod
    env_file:
      - config.prod.env
    ports:
      - '6381:6379'
    volumes:
      - redis_data_prod:/data
    command: redis-server --appendonly yes --requirepass \${REDIS_PASSWORD:-}
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true

volumes:
  redis_data_prod:
EOF
"

# Запуск Redis без healthcheck
log_info "🚀 Запуск Redis без healthcheck..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f redis-only.yml up -d redis
"

# Ожидание запуска
log_info "⏳ Ожидание запуска Redis..."
sleep 30

# Проверка статуса
log_info "🔍 Проверка статуса Redis..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус Redis ==='
    docker-compose -f redis-only.yml ps redis
    
    echo ''
    echo '=== Тест подключения к Redis ==='
    docker exec \$(docker-compose -f redis-only.yml ps -q redis) redis-cli -a \$(grep REDIS_PASSWORD $CONFIG_FILE | cut -d'=' -f2) ping 2>/dev/null || echo 'Подключение к Redis не удалось'
    
    echo ''
    echo '=== Логи Redis ==='
    docker-compose -f redis-only.yml logs redis
"

# Теперь запускаем основной docker-compose
log_info "🔄 Запуск основного docker-compose..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Останавливаем временный Redis
    docker-compose -f redis-only.yml down
    
    # Запускаем основной docker-compose
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
"

# Ожидание запуска всех сервисов
log_info "⏳ Ожидание запуска всех сервисов..."
sleep 60

# Проверка статуса всех сервисов
log_info "🔍 Проверка статуса всех сервисов..."
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
"

# Очистка временного файла
log_info "🧹 Очистка временных файлов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    rm -f redis-only.yml
"

log_success "🎉 Redis запущен и все сервисы работают!"
echo ""

# Показываем логи
log_info "Показать логи всех сервисов? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
fi 
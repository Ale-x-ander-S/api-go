#!/bin/bash

# Скрипт диагностики и исправления проблем с PostgreSQL
# Использование: ./fix-postgres.sh [staging|prod] [server_ip] [user]

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
        DB_PORT="5433"
        DB_NAME="products_db_staging"
        ;;
    prod|production)
        DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
        CONFIG_FILE="config.prod.env"
        DB_PORT="5434"
        DB_NAME="products_db_prod"
        ;;
    *)
        log_error "Неверное окружение: $ENVIRONMENT"
        echo "Доступные окружения: staging, prod"
        exit 1
        ;;
esac

log_info "🔧 Диагностика и исправление проблем с PostgreSQL"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
log_info "База данных: $DB_NAME"
log_info "Порт: $DB_PORT"
echo ""

# Проверка SSH соединения
log_info "Проверка SSH соединения..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$SERVER_IP" exit 2>/dev/null; then
    log_error "Не удается подключиться к серверу $SERVER_IP"
    exit 1
fi
log_success "SSH соединение установлено"

# Диагностика PostgreSQL
log_info "🔍 Диагностика PostgreSQL..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус контейнеров ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps
    
    echo ''
    echo '=== Логи PostgreSQL ==='
    docker-compose -f $DOCKER_COMPOSE_FILE logs postgres 2>/dev/null || echo 'PostgreSQL контейнер не найден'
    
    echo ''
    echo '=== Docker процессы ==='
    docker ps -a | grep postgres || echo 'PostgreSQL контейнеры не найдены'
    
    echo ''
    echo '=== Проверка портов ==='
    netstat -tlnp | grep $DB_PORT || echo 'Порт $DB_PORT не прослушивается'
    
    echo ''
    echo '=== Проверка volumes ==='
    docker volume ls | grep postgres || echo 'PostgreSQL volumes не найдены'
    
    echo ''
    echo '=== Проверка диска ==='
    df -h | grep -E '(postgres|docker)' || echo 'Информация о диске недоступна'
"

# Исправление проблем
log_info "🛠️  Исправление проблем с PostgreSQL..."

# Остановка PostgreSQL
log_info "Остановка PostgreSQL контейнера..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE stop postgres 2>/dev/null || true
    docker-compose -f $DOCKER_COMPOSE_FILE rm -f postgres 2>/dev/null || true
"

# Очистка PostgreSQL данных (если нужно)
log_info "Очистка PostgreSQL данных..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker volume rm \$(docker volume ls -q | grep postgres) 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
"

# Проверка и исправление прав на директорию
log_info "Проверка прав доступа..."
ssh "$REMOTE_USER@$SERVER_IP" "
    if [ -d $REMOTE_DIR ]; then
        echo 'Права на директорию:'
        ls -la $REMOTE_DIR/
        echo ''
        echo 'Права пользователя:'
        whoami && id
    fi
"

# Перезапуск PostgreSQL
log_info "Перезапуск PostgreSQL..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE up -d postgres
"

# Ожидание запуска
log_info "⏳ Ожидание запуска PostgreSQL..."
sleep 45

# Проверка статуса
log_info "🔍 Проверка статуса PostgreSQL..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус PostgreSQL ==='
    docker-compose -f $DOCKER_COMPOSE_FILE ps postgres
    
    echo ''
    echo '=== Health check PostgreSQL ==='
    docker inspect \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) | grep -A 10 Health || echo 'Health check недоступен'
    
    echo ''
    echo '=== Тест подключения к PostgreSQL ==='
    docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) pg_isready -U postgres -d $DB_NAME 2>/dev/null || echo 'Подключение к PostgreSQL не удалось'
    
    echo ''
    echo '=== Проверка базы данных ==='
    docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) psql -U postgres -d $DB_NAME -c 'SELECT version();' 2>/dev/null || echo 'Запрос к базе данных не удался'
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

log_success "🎉 Диагностика и исправление PostgreSQL завершены!"
echo ""

# Показываем логи
log_info "Показать логи PostgreSQL? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f postgres"
fi 
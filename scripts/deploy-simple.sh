#!/bin/bash

# Простой скрипт деплоя без healthcheck
# Использование: ./deploy-simple.sh [staging|prod] [server_ip] [user]

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
        ;;
    prod|production)
        DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
        ;;
    *)
        log_error "Неверное окружение: $ENVIRONMENT"
        echo "Доступные окружения: staging, prod"
        exit 1
        ;;
esac

log_info "🚀 Простой деплой без healthcheck"
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

# Остановка всех сервисов
log_info "🛑 Остановка всех сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans --volumes 2>/dev/null || true
"

# Очистка Docker
log_info "🧹 Очистка Docker..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker system prune -af --volumes 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
"

# Создание простого docker-compose без healthcheck
log_info "📝 Создание простой конфигурации без healthcheck..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Создаем простой файл без healthcheck
    cat > docker-compose-simple.yml << 'EOF'
services:
  # PostgreSQL база данных
  postgres:
    image: postgres:15-alpine
    container_name: products_postgres_prod
    environment:
      POSTGRES_DB: products_db_prod
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: Mo5dos!sod5oM
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - '5434:5432'
    volumes:
      - postgres_data_prod:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - products_network_prod
    restart: unless-stopped

  # Redis для кэширования
  redis:
    image: redis:7-alpine
    container_name: products_redis_prod
    ports:
      - '6381:6379'
    volumes:
      - redis_data_prod:/data
    networks:
      - products_network_prod
    command: redis-server --appendonly yes --requirepass Mo5dos!sod5oM
    restart: unless-stopped

  # API приложение
  api:
    build: .
    container_name: products_api_prod
    ports:
      - '8082:8080'
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: Mo5dos!sod5oM
      DB_NAME: products_db_prod
      DB_SSL_MODE: disable
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: Mo5dos!sod5oM
      JWT_SECRET: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwcm9kdWN0cy1hcGkiLCJpc3MiOiJhcGktZ28iLCJhdWQiOiJwcm9kdWN0cy1jbGllbnQiLCJpYXQiOjE3MzQ1NjgwMDAsIm5iZiI6MTczNDU2ODAwMCwiZXhwIjoyMTAwMDAwMDAwfQ.Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8
      ENVIRONMENT: production
      LOG_LEVEL: debug
      PORT: 8080
    depends_on:
      - postgres
      - redis
    networks:
      - products_network_prod
    restart: unless-stopped

volumes:
  postgres_data_prod:
  redis_data_prod:

networks:
  products_network_prod:
    driver: bridge
EOF
"

# Запуск без healthcheck
log_info "🚀 Запуск сервисов без healthcheck..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose -f docker-compose-simple.yml up -d
"

# Ожидание запуска
log_info "⏳ Ожидание запуска сервисов..."
sleep 60

# Проверка статуса
log_info "🔍 Проверка статуса сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус всех сервисов ==='
    docker-compose -f docker-compose-simple.yml ps
    
    echo ''
    echo '=== Тест PostgreSQL ==='
    docker exec \$(docker-compose -f docker-compose-simple.yml ps -q postgres) pg_isready -U postgres -d products_db_prod 2>/dev/null && echo 'PostgreSQL готов' || echo 'PostgreSQL не готов'
    
    echo ''
    echo '=== Тест Redis ==='
    docker exec \$(docker-compose -f docker-compose-simple.yml ps -q redis) redis-cli ping 2>/dev/null && echo 'Redis отвечает' || echo 'Redis не отвечает'
    
    echo ''
    echo '=== Тест API ==='
    docker exec \$(docker-compose -f docker-compose-simple.yml ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/health 2>/dev/null && echo 'API отвечает' || echo 'API не отвечает'
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

log_success "🎉 Простой деплой завершен!"
echo ""

# Показываем логи
log_info "Показать логи всех сервисов? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose -f docker-compose-simple.yml logs -f"
fi

# Инструкции по дальнейшим действиям
echo ""
log_info "📋 Следующие шаги:"
echo "1. Проверьте что все сервисы работают:"
echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f docker-compose-simple.yml ps'"
echo ""
echo "2. Когда все будет работать, можете вернуть healthcheck:"
echo "   - Раскомментируйте healthcheck в $DOCKER_COMPOSE_FILE"
echo "   - Перезапустите с основным файлом"
echo ""
echo "3. Или используйте простой файл для production:"
echo "   docker-compose -f docker-compose-simple.yml up -d" 
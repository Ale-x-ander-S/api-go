#!/bin/bash

# Деплой на облачный сервер с локальной конфигурацией (как make deploy-local)
# Использование: ./deploy-cloud-local.sh [staging|prod] [server_ip] [user]

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

log_info "☁️  Деплой на облачный сервер с локальной конфигурацией"
log_info "Окружение: $ENVIRONMENT"
log_info "Сервер: $SERVER_IP"
log_info "Пользователь: $REMOTE_USER"
log_info "Конфигурация: $CONFIG_FILE"
echo ""

# Проверка SSH соединения
log_info "Проверка SSH соединения..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$SERVER_IP" exit 2>/dev/null; then
    log_error "Не удается подключиться к серверу $SERVER_IP"
    exit 1
fi
log_success "SSH соединение установлено"

# Создание директории на сервере
log_info "📁 Создание директории на сервере..."
ssh "$REMOTE_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

# Копирование всех файлов проекта на сервер
log_info "📤 Копирование файлов проекта на сервер..."
scp -r . "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/" 2>/dev/null || {
    log_warning "Не удалось скопировать все файлы, копируем по частям..."
    scp -r "migrations" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "Dockerfile" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "init.sql" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "main.go" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "go.mod" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "go.sum" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "handlers" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "models" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "routes" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "middleware" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "utils" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "config" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "cache" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp -r "database" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "docker-compose.yml" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    scp "$CONFIG_FILE" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
}
log_success "Файлы скопированы на сервер"

# Остановка всех сервисов
log_info "🛑 Остановка всех сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    docker-compose down --remove-orphans --volumes 2>/dev/null || true
    docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans --volumes 2>/dev/null || true
"

# Очистка Docker
log_info "🧹 Очистка Docker..."
ssh "$REMOTE_USER@$SERVER_IP" "
    docker system prune -af 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
"

# Запуск через docker-compose (как в make deploy-local)
log_info "🚀 Запуск сервисов через docker-compose..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Используем основной docker-compose файл
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        echo 'Запуск через $DOCKER_COMPOSE_FILE...'
        docker-compose -f $DOCKER_COMPOSE_FILE up -d
    else
        echo 'Запуск через основной docker-compose.yml...'
        docker-compose up -d
    fi
"

# Ожидание запуска
log_info "⏳ Ожидание запуска сервисов..."
sleep 60

# Применение миграций
log_info "🔄 Применение миграций..."
apply_remote_migrations

# Дополнительное ожидание для применения миграций
log_info "⏳ Ожидание завершения миграций..."
sleep 30

# Проверка статуса
log_info "🔍 Проверка статуса сервисов..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус всех сервисов ==='
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker-compose -f $DOCKER_COMPOSE_FILE ps
    else
        docker-compose ps
    fi
    
    echo ''
    echo '=== Тест PostgreSQL ==='
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q postgres) pg_isready -U postgres 2>/dev/null && echo 'PostgreSQL готов' || echo 'PostgreSQL не готов'
    else
        docker exec \$(docker-compose ps -q postgres) pg_isready -U postgres 2>/dev/null && echo 'PostgreSQL готов' || echo 'PostgreSQL не готов'
    fi
    
    echo ''
    echo '=== Тест Redis ==='
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q redis) redis-cli ping 2>/dev/null && echo 'Redis отвечает' || echo 'Redis не отвечает'
    else
        docker exec \$(docker-compose ps -q redis) redis-cli ping 2>/dev/null && echo 'Redis отвечает' || echo 'Redis не отвечает'
    fi
    
    echo ''
    echo '=== Тест API ==='
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker exec \$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/ 2>/dev/null && echo 'API отвечает' || echo 'API не отвечает'
    else
        docker exec \$(docker-compose ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/ 2>/dev/null && echo 'API отвечает' || echo 'API не отвечает'
    fi
"

# Определение порта API
log_info "🌐 Определение порта API..."
API_PORT=$(ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker-compose -f $DOCKER_COMPOSE_FILE ps | grep api | awk '{print \$6}' | cut -d':' -f2 | cut -d'-' -f1
    else
        docker-compose ps | grep api | awk '{print \$6}' | cut -d':' -f2 | cut -d'-' -f1
    fi
")

if [ -z "$API_PORT" ]; then
    # Пробуем определить порт из конфигурации
    case $ENVIRONMENT in
        staging) API_PORT="8081" ;;
        prod|production) API_PORT="8080" ;;
        *) API_PORT="8080" ;;
    esac
fi

log_info "API порт: $API_PORT"

# Проверка доступности API
log_info "🌐 Проверка доступности API..."
if curl -s --connect-timeout 10 "http://$SERVER_IP:$API_PORT/" > /dev/null; then
    log_success "✅ API доступен по адресу: http://$SERVER_IP:$API_PORT"
    
    # Тест основных эндпоинтов
    log_info "🧪 Тестирование основных эндпоинтов..."
    
    # Тест Swagger
    if curl -s --connect-timeout 10 "http://$SERVER_IP:$API_PORT/swagger/index.html" > /dev/null; then
        log_success "✅ Swagger доступен: http://$SERVER_IP:$API_PORT/swagger/index.html"
    else
        log_warning "⚠️  Swagger недоступен"
    fi
    
    # Тест продуктов
    if curl -s --connect-timeout 10 "http://$SERVER_IP:$API_PORT/api/v1/products" > /dev/null; then
        log_success "✅ API продуктов работает"
    else
        log_warning "⚠️  API продуктов не отвечает"
    fi
    
else
    log_warning "⚠️  API пока недоступен"
fi

log_success "🎉 Деплой на облачный сервер завершен!"
echo ""

# Показываем логи
log_info "Показать логи всех сервисов? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "
        cd $REMOTE_DIR
        if [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
            docker-compose -f $DOCKER_COMPOSE_FILE logs -f
        else
            docker-compose logs -f
        fi
    "
fi

# Инструкции по дальнейшим действиям
echo ""
log_info "📋 Следующие шаги:"
echo "1. Проверьте что все сервисы работают:"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE ps'"
else
    echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose ps'"
fi
echo ""
echo "2. API доступен по адресу: http://$SERVER_IP:$API_PORT"
echo "3. Swagger документация: http://$SERVER_IP:$API_PORT/swagger/index.html"
echo ""
echo "4. Для тестирования используйте:"
echo "   curl http://$SERVER_IP:$API_PORT/api/v1/products"
echo ""
echo "5. Управление сервисами:"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f'"
else
    echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose logs -f'"
fi

# Функция применения миграций на удаленном сервере
apply_remote_migrations() {
    log_info "🔄 Применение миграций на удаленном сервере..."
    
    # Копируем скрипт миграций на сервер
    scp "scripts/remote-migrations.sh" "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"
    
    # Применяем миграции
    ssh "$REMOTE_USER@$SERVER_IP" "
        cd $REMOTE_DIR 2>/dev/null || exit 0
        chmod +x remote-migrations.sh
        ./remote-migrations.sh
    "
    
    log_success "Миграции применены на удаленном сервере"
} 
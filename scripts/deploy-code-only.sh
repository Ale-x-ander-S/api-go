#!/bin/bash

# Быстрое обновление только кода на сервере (без переустановки Docker и сервисов)
# Использование: ./deploy-code-only.sh [staging|prod] [server_ip] [user]

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

log_info "⚡ Быстрое обновление только кода"
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

# Проверка что сервисы уже запущены
log_info "🔍 Проверка статуса сервисов..."
SERVICES_RUNNING=$(ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Простая проверка без jq
    if [ -f \"docker-compose-simple.yml\" ]; then
        docker-compose -f docker-compose-simple.yml ps | grep -c 'Up'
    elif [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
        docker-compose -f $DOCKER_COMPOSE_FILE ps | grep -c 'Up'
    elif [ -f \"docker-compose.yml\" ]; then
        docker-compose ps | grep -c 'Up'
    else
        echo '0'
    fi
" 2>/dev/null || echo "0")

log_info "Найдено запущенных сервисов: $SERVICES_RUNNING"

if [ "$SERVICES_RUNNING" -eq "0" ]; then
    log_error "❌ Сервисы не запущены! Сначала выполните полный деплой:"
    echo "   make full-deploy ENV=$ENVIRONMENT SERVER=$SERVER_IP USER=$REMOTE_USER"
    exit 1
fi

log_success "✅ Сервисы уже запущены, обновляем только код"

# Функция для определения активного docker-compose файла
get_active_compose_file() {
    ssh "$REMOTE_USER@$SERVER_IP" "
        cd $REMOTE_DIR 2>/dev/null || exit 0
        
        if [ -f \"docker-compose-simple.yml\" ]; then
            echo 'docker-compose-simple.yml'
        elif [ -f \"$DOCKER_COMPOSE_FILE\" ]; then
            echo '$DOCKER_COMPOSE_FILE'
        elif [ -f \"docker-compose.yml\" ]; then
            echo 'docker-compose.yml'
        else
            echo ''
        fi
    "
}

# Получаем активный docker-compose файл
ACTIVE_COMPOSE_FILE=$(get_active_compose_file)

if [ -z "$ACTIVE_COMPOSE_FILE" ]; then
    log_error "❌ Не найден docker-compose файл на сервере!"
    exit 1
fi

log_info "📋 Используется docker-compose файл: $ACTIVE_COMPOSE_FILE"

# Создание директории на сервере (если не существует)
log_info "📁 Проверка директории на сервере..."
ssh "$REMOTE_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

# Копирование только измененных файлов кода
log_info "📤 Копирование файлов кода на сервер..."
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
log_success "Файлы кода скопированы на сервер"

# Пересборка только API контейнера
log_info "🔨 Пересборка API контейнера..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Останавливаем только API
    docker-compose -f $ACTIVE_COMPOSE_FILE stop api
    docker-compose -f $ACTIVE_COMPOSE_FILE rm -f api
    
    # Пересобираем и запускаем только API
    docker-compose -f $ACTIVE_COMPOSE_FILE up -d --build api
"

# Ожидание запуска API
log_info "⏳ Ожидание запуска API..."
sleep 30

# Проверка статуса API
log_info "🔍 Проверка статуса API..."
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    echo '=== Статус API ==='
    docker-compose -f $ACTIVE_COMPOSE_FILE ps api
    
    echo ''
    echo '=== Тест API ==='
    docker exec \$(docker-compose -f $ACTIVE_COMPOSE_FILE ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/ 2>/dev/null && echo 'API отвечает' || echo 'API не отвечает'
"

# Определение порта API
log_info "🌐 Определение порта API..."
log_info "Активный docker-compose файл: $ACTIVE_COMPOSE_FILE"

# Сначала покажем полный вывод docker-compose ps для диагностики
log_info "🔍 Диагностика docker-compose ps:"
ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    echo '=== Полный вывод docker-compose ps ==='
    docker-compose -f $ACTIVE_COMPOSE_FILE ps
    echo ''
    echo '=== Строка с API ==='
    docker-compose -f $ACTIVE_COMPOSE_FILE ps | grep api
"

API_PORT=$(ssh "$REMOTE_USER@$SERVER_IP" "
    cd $REMOTE_DIR 2>/dev/null || exit 0
    
    # Более надежный способ определения порта
    if [ -f \"$ACTIVE_COMPOSE_FILE\" ]; then
        # Получаем порт из docker-compose ps
        docker-compose -f $ACTIVE_COMPOSE_FILE ps | grep api | awk '{print \$6}' | sed 's/.*://' | cut -d'-' -f1
    else
        echo ''
    fi
")

log_info "Сырой вывод парсинга порта: '$API_PORT'"

# Если не удалось определить порт, используем значения по умолчанию
if [ -z "$API_PORT" ] || [ "$API_PORT" = "seconds" ] || [ "$API_PORT" = "Up" ] || [ "$API_PORT" = "running" ]; then
    log_warning "⚠️  Не удалось определить порт API, используем значения по умолчанию"
    case $ENVIRONMENT in
        staging) API_PORT="8081" ;;
        prod|production) API_PORT="8080" ;;
        *) API_PORT="8080" ;;
    esac
fi

log_info "Итоговый API порт: $API_PORT"

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

log_success "🎉 Быстрое обновление кода завершено!"
echo ""

# Показываем логи API
log_info "Показать логи API? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ssh "$REMOTE_USER@$SERVER_IP" "
        cd $REMOTE_DIR
        docker-compose -f $ACTIVE_COMPOSE_FILE logs -f api
    "
fi

# Инструкции по дальнейшим действиям
echo ""
log_info "📋 Следующие шаги:"
echo "1. Проверьте что API работает:"
echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f $ACTIVE_COMPOSE_FILE ps api'"
echo ""
echo "2. API доступен по адресу: http://$SERVER_IP:$API_PORT"
echo "3. Swagger документация: http://$SERVER_IP:$API_PORT/swagger/index.html"
echo ""
echo "4. Для тестирования используйте:"
echo "   curl http://$SERVER_IP:$API_PORT/api/v1/products"
echo ""
echo "5. Управление API:"
echo "   ssh $REMOTE_USER@$SERVER_IP 'cd $REMOTE_DIR && docker-compose -f $ACTIVE_COMPOSE_FILE logs -f api'"
echo ""
echo "6. Для полного обновления используйте:"
echo "   make full-deploy ENV=$ENVIRONMENT SERVER=$SERVER_IP USER=$REMOTE_USER" 
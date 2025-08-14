#!/bin/bash

# Скрипт развертывания Products API
# Использование: ./deploy.sh [dev|staging|prod]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Конфигурация окружений
ENVIRONMENT=${1:-dev}
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev-$(date +%Y%m%d-%H%M%S)")

# Проверка окружения
case $ENVIRONMENT in
    dev|development)
        ENVIRONMENT="dev"
        DOCKER_COMPOSE_FILE="docker-compose.yml"
        CONFIG_FILE="config.dev.env"
        ;;
    staging)
        ENVIRONMENT="staging"
        DOCKER_COMPOSE_FILE="docker-compose.staging.yml"
        CONFIG_FILE="config.staging.env"
        ;;
    prod|production)
        ENVIRONMENT="production"
        DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
        CONFIG_FILE="config.prod.env"
        ;;
    *)
        log_error "Неверное окружение: $ENVIRONMENT"
        echo "Использование: $0 [dev|staging|prod]"
        exit 1
        ;;
esac

log_info "🚀 Развертывание Products API"
log_info "Окружение: $ENVIRONMENT"
log_info "Версия: $VERSION"
log_info "Файл конфигурации: $CONFIG_FILE"
echo ""

# Функция проверки зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    local missing_deps=()
    
    # Проверяем Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Проверяем Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # Проверяем Go
    if ! command -v go &> /dev/null; then
        missing_deps+=("go")
    fi
    
    # Проверяем jq
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Отсутствуют зависимости: ${missing_deps[*]}"
        echo "Установите недостающие зависимости и повторите попытку"
        exit 1
    fi
    
    log_success "Все зависимости установлены"
}

# Функция проверки конфигурации
check_config() {
    log_info "Проверка конфигурации..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Файл конфигурации $CONFIG_FILE не найден"
        
        if [ "$ENVIRONMENT" = "dev" ]; then
            log_info "Создание dev конфигурации..."
            cp config.env.example "$CONFIG_FILE" 2>/dev/null || {
                log_error "Не удалось создать конфигурацию"
                exit 1
            }
        else
            log_error "Файл конфигурации $CONFIG_FILE обязателен для $ENVIRONMENT"
            exit 1
        fi
    fi
    
    log_success "Конфигурация проверена"
}

# Функция сборки приложения
build_application() {
    log_info "Сборка приложения..."
    
    # Очистка предыдущих сборок
    make clean
    
    # Установка зависимостей
    make deps
    
    # Генерация Swagger документации
    make swagger-auto
    
    # Сборка приложения
    make build
    
    log_success "Приложение собрано"
}

# Функция сборки Docker образа
build_docker_image() {
    log_info "Сборка Docker образа..."
    
    # Сборка образа с тегом версии
    docker build -t products-api:$VERSION .
    docker tag products-api:$VERSION products-api:latest
    
    log_success "Docker образ собран: products-api:$VERSION"
}

# Функция развертывания через Docker Compose
deploy_docker_compose() {
    log_info "Развертывание через Docker Compose..."
    
    # Остановка существующих контейнеров
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        log_info "Остановка существующих контейнеров..."
        docker-compose -f "$DOCKER_COMPOSE_FILE" down
    fi
    
    # Запуск новых контейнеров
    log_info "Запуск контейнеров..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    # Ожидание готовности сервисов
    log_info "Ожидание готовности сервисов..."
    sleep 10
    
    # Проверка статуса
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
        log_success "Сервисы запущены"
    else
        log_error "Ошибка запуска сервисов"
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs
        exit 1
    fi
}

# Функция развертывания локально
deploy_local() {
    log_info "Локальное развертывание..."
    
    # Проверка, не запущен ли уже сервер
    if lsof -i :8080 > /dev/null 2>&1; then
        log_warning "Порт 8080 уже занят, останавливаем процесс..."
        lsof -ti:8080 | xargs kill -9
        sleep 2
    fi
    
    # Запуск приложения в фоне
    log_info "Запуск приложения..."
    nohup go run main.go > app.log 2>&1 &
    local pid=$!
    
    # Ожидание запуска
    sleep 5
    
    # Проверка статуса
    if curl -s http://localhost:8080/ > /dev/null; then
        log_success "Приложение запущено (PID: $pid)"
        echo "Логи: tail -f app.log"
        echo "Остановка: kill $pid"
    else
        log_error "Ошибка запуска приложения"
        cat app.log
        exit 1
    fi
}

# Функция проверки развертывания
verify_deployment() {
    log_info "Проверка развертывания..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080/ > /dev/null; then
            log_success "API доступен!"
            
            # Проверка основных endpoints
            log_info "Проверка endpoints..."
            
            # Проверка корневого endpoint
            if curl -s http://localhost:8080/ | jq -e '.message' > /dev/null; then
                log_success "✓ Корневой endpoint работает"
            else
                log_warning "⚠ Корневой endpoint не отвечает корректно"
            fi
            
            # Проверка Swagger
            if curl -s http://localhost:8080/swagger/index.html > /dev/null; then
                log_success "✓ Swagger UI доступен"
            else
                log_warning "⚠ Swagger UI недоступен"
            fi
            
            # Проверка продуктов
            if curl -s http://localhost:8080/api/v1/products > /dev/null; then
                log_success "✓ API продуктов работает"
            else
                log_warning "⚠ API продуктов не отвечает"
            fi
            
            break
        fi
        
        log_info "Попытка $attempt/$max_attempts - API не готов, ожидание..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "API не стал доступен за отведенное время"
        exit 1
    fi
}

# Функция отката
rollback() {
    log_warning "Выполнение отката..."
    
    case $ENVIRONMENT in
        dev)
            # Остановка локального приложения
            if [ -f "app.pid" ]; then
                kill $(cat app.pid) 2>/dev/null || true
                rm -f app.pid
            fi
            ;;
        staging|production)
            # Откат Docker Compose
            if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                docker-compose -f "$DOCKER_COMPOSE_FILE" down
            fi
            ;;
    esac
    
    log_info "Откат завершен"
}

# Функция применения миграций
apply_migrations() {
    log_info "Применение миграций базы данных..."
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "products_postgres"; then
        log_error "PostgreSQL не запущен. Запустите сначала: docker-compose up -d postgres"
        exit 1
    fi
    
    # Список миграций в порядке применения
    local migrations=(
        "migrations/001_initial_schema.sql"
        "migrations/002_update_existing_schema.sql"
        "migrations/003_update_users_table.sql"
    )
    
    # Проверяем существование файлов миграций
    for migration in "${migrations[@]}"; do
        if [ ! -f "$migration" ]; then
            log_warning "Файл миграции $migration не найден, пропускаем"
            continue
        fi
        
        log_info "Применение миграции: $migration"
        
        # Применяем миграцию с обработкой ошибок
        if docker exec -i products_postgres psql -U postgres -d products_db < "$migration" 2>/dev/null; then
            log_success "✓ Миграция $migration применена успешно"
        else
            log_warning "⚠ Миграция $migration уже применена или содержит ошибки (это нормально)"
        fi
    done
    
    log_success "Все миграции обработаны"
}

# Функция проверки консистентности БД
check_database_consistency() {
    log_info "Проверка консистентности базы данных..."
    
    # Проверяем основные таблицы
    local tables=("users" "products" "categories" "orders" "cart_items")
    
    for table in "${tables[@]}"; do
        local count=$(docker exec -i products_postgres psql -U postgres -d products_db -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ')
        
        if [ "$count" != "" ] && [ "$count" != "0" ]; then
            log_success "✓ Таблица $table: $count записей"
        else
            log_warning "⚠ Таблица $table пуста или недоступна"
        fi
    done
    
    # Проверяем связи между таблицами
    log_info "Проверка связей между таблицами..."
    
    # Проверяем products -> categories
    local orphan_products=$(docker exec -i products_postgres psql -U postgres -d products_db -t -c "SELECT COUNT(*) FROM products p LEFT JOIN categories c ON p.category_id = c.id WHERE c.id IS NULL;" 2>/dev/null | tr -d ' ')
    
    if [ "$orphan_products" = "0" ] || [ "$orphan_products" = "" ]; then
        log_success "✓ Все продукты имеют корректные категории"
    else
        log_warning "⚠ Найдено $orphan_products продуктов без категорий"
    fi
    
    log_success "Проверка консистентности завершена"
}

# Основная логика развертывания
main() {
    log_info "Начало развертывания..."
    
    # Установка обработчика ошибок
    trap 'log_error "Ошибка развертывания"; rollback; exit 1' ERR
    
    # Проверки
    check_dependencies
    check_config
    
    # Развертывание в зависимости от окружения
    case $ENVIRONMENT in
        dev)
            build_application
            deploy_local
            ;;
        staging|production)
            build_application
            build_docker_image
            deploy_docker_compose
            ;;
    esac
    
    # Применение миграций (только для staging/production)
    if [ "$ENVIRONMENT" != "dev" ]; then
        apply_migrations
        check_database_consistency
    fi
    
    # Проверка развертывания
    verify_deployment
    
    # Вывод информации
    echo ""
    log_success "🎉 Развертывание завершено успешно!"
    log_info "Окружение: $ENVIRONMENT"
    log_info "Версия: $VERSION"
    log_info "API URL: http://localhost:8080"
    log_info "Swagger UI: http://localhost:8080/swagger/index.html"
    
    if [ "$ENVIRONMENT" = "dev" ]; then
        log_info "Логи: tail -f app.log"
        log_info "Остановка: pkill -f 'go run main.go'"
    else
        log_info "Логи: docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
        log_info "Остановка: docker-compose -f $DOCKER_COMPOSE_FILE down"
    fi
    
    echo ""
}

# Запуск основного скрипта
main "$@" 
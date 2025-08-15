#!/bin/bash

# Скрипт для применения миграции локально
# Использование: ./scripts/apply-migration-local.sh MIGRATION

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

# Проверяем аргументы
if [ $# -ne 1 ]; then
    log_error "Неверное количество аргументов"
    echo "Использование: $0 MIGRATION"
    echo "Пример: $0 007_add_stock_type_to_products"
    exit 1
fi

MIGRATION="$1"
MIGRATION_FILE="migrations/${MIGRATION}.sql"

# Проверяем существование файла миграции
if [ ! -f "$MIGRATION_FILE" ]; then
    log_error "Файл миграции не найден: $MIGRATION_FILE"
    exit 1
fi

log_info "Применение миграции $MIGRATION локально..."

# Проверяем, что Docker запущен
if ! docker ps > /dev/null 2>&1; then
    log_error "Docker не запущен"
    exit 1
fi

# Проверяем, что PostgreSQL контейнер запущен
if ! docker ps | grep -q "postgres"; then
    log_warning "PostgreSQL контейнер не запущен. Запускаем docker-compose..."
    docker-compose up -d postgres
    sleep 10
fi

# Получаем ID контейнера PostgreSQL
POSTGRES_CONTAINER=$(docker ps -q --filter "name=postgres")
if [ -z "$POSTGRES_CONTAINER" ]; then
    log_error "PostgreSQL контейнер не найден"
    exit 1
fi

echo "PostgreSQL контейнер: $POSTGRES_CONTAINER"

# Проверяем существование базы данных
log_info "Проверка существования базы данных products_db..."
if ! docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -lqt | cut -d \| -f 1 | grep -qw products_db; then
    log_info "База данных products_db не существует. Создаем..."
    docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -c "CREATE DATABASE products_db;"
    log_success "База данных products_db создана"
else
    log_info "База данных products_db уже существует"
fi

# Применяем миграцию
log_info "Применение миграции: $MIGRATION"
docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -d products_db < "$MIGRATION_FILE"

if [ $? -eq 0 ]; then
    log_success "✅ Миграция успешно применена"
else
    log_error "❌ Ошибка применения миграции"
    exit 1
fi 
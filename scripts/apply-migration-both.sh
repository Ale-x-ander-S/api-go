#!/bin/bash

# Скрипт для одновременного применения миграций на локальном и облачном сервере
# Использование: ./scripts/apply-migration-both.sh [migration_name]

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

# Конфигурация
MIGRATIONS_DIR="migrations"
LOCAL_DB_CONTAINER="products_postgres"

# Проверяем аргументы
if [ $# -eq 0 ]; then
    log_error "Укажите название миграции"
    echo "Использование: $0 migration_name"
    echo "Пример: $0 006_replace_weight_dimensions_with_color_size"
    exit 1
fi

MIGRATION_NAME="$1"
MIGRATION_FILE="${MIGRATIONS_DIR}/${MIGRATION_NAME}.sql"

# Проверяем существование файла миграции
if [ ! -f "$MIGRATION_FILE" ]; then
    log_error "Файл миграции не найден: $MIGRATION_FILE"
    exit 1
fi

log_info "Применение миграции: $MIGRATION_NAME"

# Функция применения миграции на локальном сервере
apply_local() {
    log_info "Применение миграции на локальном сервере..."
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "$LOCAL_DB_CONTAINER"; then
        log_error "Локальный PostgreSQL не запущен. Запустите docker-compose up -d"
        return 1
    fi
    
    # Применяем миграцию
    if docker exec -i "$LOCAL_DB_CONTAINER" psql -U postgres -d products_db < "$MIGRATION_FILE"; then
        log_success "Миграция успешно применена на локальном сервере"
        return 0
    else
        log_error "Ошибка применения миграции на локальном сервере"
        return 1
    fi
}

# Функция применения миграции на облачном сервере
apply_remote() {
    log_info "Применение миграции на облачном сервере..."
    
    # Проверяем переменные окружения для облачного сервера
    if [ -z "$REMOTE_DB_HOST" ] || [ -z "$REMOTE_DB_NAME" ] || [ -z "$REMOTE_DB_USER" ] || [ -z "$REMOTE_DB_PASSWORD" ]; then
        log_warning "Переменные окружения для облачного сервера не настроены"
        log_info "Создайте файл .env с переменными:"
        log_info "REMOTE_DB_HOST=your_host"
        log_info "REMOTE_DB_NAME=your_db_name"
        log_info "REMOTE_DB_USER=your_user"
        log_info "REMOTE_DB_PASSWORD=your_password"
        return 1
    fi
    
    # Применяем миграцию через PGPASSWORD
    if PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -f "$MIGRATION_FILE"; then
        log_success "Миграция успешно применена на облачном сервере"
        return 0
    else
        log_error "Ошибка применения миграции на облачном сервере"
        return 1
    fi
}

# Основная логика
log_info "Начинаем применение миграции на оба сервера..."

LOCAL_SUCCESS=false
REMOTE_SUCCESS=false

# Применяем на локальном сервере
if apply_local; then
    LOCAL_SUCCESS=true
fi

# Применяем на облачном сервере
if apply_remote; then
    REMOTE_SUCCESS=true
fi

# Выводим итоговый результат
echo
log_info "Результаты применения миграции:"
if [ "$LOCAL_SUCCESS" = true ]; then
    log_success "✓ Локальный сервер: УСПЕШНО"
else
    log_error "✗ Локальный сервер: ОШИБКА"
fi

if [ "$REMOTE_SUCCESS" = true ]; then
    log_success "✓ Облачный сервер: УСПЕШНО"
else
    log_warning "⚠ Облачный сервер: НЕ ПРИМЕНЕНО"
fi

echo
if [ "$LOCAL_SUCCESS" = true ] && [ "$REMOTE_SUCCESS" = true ]; then
    log_success "Миграция успешно применена на оба сервера!"
elif [ "$LOCAL_SUCCESS" = true ]; then
    log_warning "Миграция применена только на локальном сервере"
    log_info "Для применения на облачном сервере настройте переменные окружения"
else
    log_error "Миграция не была применена ни на одном сервере"
    exit 1
fi 
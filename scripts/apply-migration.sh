#!/bin/bash

# Скрипт для применения миграции на сервере
# Использование: ./scripts/apply-migration.sh ENV SERVER USER MIGRATION

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
if [ $# -ne 4 ]; then
    log_error "Неверное количество аргументов"
    echo "Использование: $0 ENV SERVER USER MIGRATION"
    echo "Пример: $0 prod 45.12.229.112 root 006_replace_weight_dimensions_with_color_size"
    exit 1
fi

ENV="$1"
SERVER="$2"
USER="$3"
MIGRATION="$4"
MIGRATION_FILE="migrations/${MIGRATION}.sql"

# Проверяем существование файла миграции
if [ ! -f "$MIGRATION_FILE" ]; then
    log_error "Файл миграции не найден: $MIGRATION_FILE"
    exit 1
fi

log_info "Применение миграции $MIGRATION на сервере $SERVER..."

# Копируем файл миграции на сервер
log_info "Копирование файла миграции на сервер..."
scp "$MIGRATION_FILE" "$USER@$SERVER:/tmp/"

if [ $? -ne 0 ]; then
    log_error "Ошибка копирования файла миграции на сервер"
    exit 1
fi

# Применяем миграцию на сервере
log_info "Применение миграции на сервере..."
ssh "$USER@$SERVER" << EOF
    set -e
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "postgres"; then
        echo "PostgreSQL не запущен. Запускаем docker-compose..."
        cd /root/api-go
        docker-compose up -d postgres
        sleep 10
    fi
    
    # Получаем ID контейнера PostgreSQL
    POSTGRES_CONTAINER=\$(docker ps -q --filter "name=postgres")
    echo "PostgreSQL контейнер: \$POSTGRES_CONTAINER"
    
    # Проверяем существование базы данных
    echo "Проверка существования базы данных products_db..."
    if ! docker exec -i \$POSTGRES_CONTAINER psql -U postgres -lqt | cut -d \| -f 1 | grep -qw products_db; then
        echo "База данных products_db не существует. Создаем..."
        docker exec -i \$POSTGRES_CONTAINER psql -U postgres -c "CREATE DATABASE products_db;"
        echo "База данных products_db создана"
    else
        echo "База данных products_db уже существует"
    fi
    
    # Применяем миграцию
    echo "Применение миграции: $MIGRATION"
    docker exec -i \$POSTGRES_CONTAINER psql -U postgres -d products_db < /tmp/${MIGRATION}.sql
    
    if [ \$? -eq 0 ]; then
        echo "✅ Миграция успешно применена"
    else
        echo "❌ Ошибка применения миграции"
        exit 1
    fi
    
    # Очищаем временный файл
    rm -f /tmp/${MIGRATION}.sql
EOF

if [ $? -eq 0 ]; then
    log_success "Миграция $MIGRATION успешно применена на сервере $SERVER"
else
    log_error "Ошибка применения миграции на сервере"
    exit 1
fi 
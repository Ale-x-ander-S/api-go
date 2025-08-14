#!/bin/bash

# Скрипт управления миграциями базы данных
# Использование: ./scripts/manage-migrations.sh [create|apply|status|rollback] [migration_name]

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
DB_NAME="products_db"
DB_USER="postgres"
DB_CONTAINER="products_postgres"

# Функция создания новой миграции
create_migration() {
    local migration_name="$1"
    
    if [ -z "$migration_name" ]; then
        log_error "Укажите название миграции"
        echo "Использование: $0 create migration_name"
        exit 1
    fi
    
    # Форматируем название
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="${MIGRATIONS_DIR}/${timestamp}_${migration_name}.sql"
    
    # Создаем директорию если не существует
    mkdir -p "$MIGRATIONS_DIR"
    
    # Создаем файл миграции
    cat > "$filename" << EOF
-- Миграция $(date +%Y-%m-%d): $migration_name
-- Дата: $(date)

-- ВАЖНО: Всегда используйте IF NOT EXISTS и IF EXISTS для безопасного применения
-- ВАЖНО: Делайте миграции обратимыми (добавляйте rollback секцию)

-- ========================================
-- UP MIGRATION (применение изменений)
-- ========================================

-- Здесь ваши SQL команды для изменения схемы
-- Примеры:
-- ALTER TABLE table_name ADD COLUMN IF NOT EXISTS new_column VARCHAR(100);
-- CREATE INDEX IF NOT EXISTS idx_name ON table_name(column_name);
-- ALTER TABLE table_name ADD CONSTRAINT IF NOT EXISTS constraint_name CHECK (condition);

-- ========================================
-- DOWN MIGRATION (откат изменений)
-- ========================================

-- Здесь команды для отката изменений
-- Примеры:
-- ALTER TABLE table_name DROP COLUMN IF EXISTS new_column;
-- DROP INDEX IF EXISTS idx_name;
-- ALTER TABLE table_name DROP CONSTRAINT IF EXISTS constraint_name;

-- ========================================
-- DATA MIGRATION (если нужно)
-- ========================================

-- Здесь команды для миграции данных
-- Примеры:
-- UPDATE table_name SET new_column = 'default_value' WHERE new_column IS NULL;
-- INSERT INTO table_name (column1, column2) VALUES ('value1', 'value2');

-- ========================================
-- VERIFICATION (проверка результата)
-- ========================================

-- Здесь команды для проверки результата миграции
-- Примеры:
-- SELECT COUNT(*) FROM table_name WHERE new_column IS NOT NULL;
-- SELECT * FROM table_name LIMIT 5;
EOF

    log_success "Создана новая миграция: $filename"
    log_info "Отредактируйте файл и запустите: $0 apply"
}

# Функция применения всех миграций
apply_migrations() {
    log_info "Применение миграций базы данных..."
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log_error "PostgreSQL не запущен. Запустите сначала: docker-compose up -d postgres"
        exit 1
    fi
    
    # Получаем список всех файлов миграций в порядке применения
    local migrations=($(ls -1 "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort))
    
    if [ ${#migrations[@]} -eq 0 ]; then
        log_warning "Миграции не найдены в директории $MIGRATIONS_DIR"
        return 0
    fi
    
    # Создаем таблицу для отслеживания примененных миграций
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << 'EOF' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64),
    execution_time_ms INTEGER
);
EOF
    
    # Применяем каждую миграцию
    for migration in "${migrations[@]}"; do
        local filename=$(basename "$migration")
        
        # Проверяем, была ли миграция уже применена
        local applied=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM schema_migrations WHERE filename = '$filename';" 2>/dev/null | tr -d ' ')
        
        if [ "$applied" = "1" ]; then
            log_info "✓ Миграция $filename уже применена, пропускаем"
            continue
        fi
        
        log_info "Применение миграции: $filename"
        
        # Засекаем время выполнения
        local start_time=$(date +%s%3N)
        
        # Применяем миграцию
        if docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$migration" 2>/dev/null; then
            local end_time=$(date +%s%3N)
            local execution_time=$((end_time - start_time))
            
            # Вычисляем checksum файла
            local checksum=$(sha256sum "$migration" | cut -d' ' -f1)
            
            # Записываем информацию о примененной миграции
            docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << EOF 2>/dev/null || true
INSERT INTO schema_migrations (filename, checksum, execution_time_ms) 
VALUES ('$filename', '$checksum', $execution_time);
EOF
            
            log_success "✓ Миграция $filename применена успешно (${execution_time}ms)"
        else
            log_error "❌ Ошибка применения миграции $filename"
            exit 1
        fi
    done
    
    log_success "Все миграции применены успешно"
}

# Функция проверки статуса миграций
check_migration_status() {
    log_info "Статус миграций базы данных..."
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log_error "PostgreSQL не запущен"
        return 1
    fi
    
    # Получаем список всех файлов миграций
    local migrations=($(ls -1 "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort))
    
    if [ ${#migrations[@]} -eq 0 ]; then
        log_warning "Миграции не найдены"
        return 0
    fi
    
    # Проверяем статус каждой миграции
    echo ""
    printf "%-50s %-15s %-20s %-10s\n" "Файл миграции" "Статус" "Дата применения" "Время (мс)"
    printf "%-50s %-15s %-20s %-10s\n" "------------------------------------------------" "---------------" "--------------------" "----------"
    
    for migration in "${migrations[@]}"; do
        local filename=$(basename "$migration")
        
        # Проверяем статус в БД
        local status_info=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT applied_at, execution_time_ms FROM schema_migrations WHERE filename = '$filename';" 2>/dev/null | tr -d ' ')
        
        if [ -n "$status_info" ]; then
            local applied_at=$(echo "$status_info" | cut -d'|' -f1 | tr -d ' ')
            local execution_time=$(echo "$status_info" | cut -d'|' -f2 | tr -d ' ')
            printf "%-50s %-15s %-20s %-10s\n" "$filename" "✓ Применена" "$applied_at" "$execution_time"
        else
            printf "%-50s %-15s %-20s %-10s\n" "$filename" "❌ Не применена" "-" "-"
        fi
    done
    
    echo ""
}

# Функция отката последней миграции
rollback_last_migration() {
    log_warning "Откат последней примененной миграции..."
    
    # Получаем последнюю примененную миграцию
    local last_migration=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT filename FROM schema_migrations ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null | tr -d ' ')
    
    if [ -z "$last_migration" ]; then
        log_warning "Нет примененных миграций для отката"
        return 0
    fi
    
    log_info "Последняя примененная миграция: $last_migration"
    read -p "Вы уверены, что хотите откатить эту миграцию? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Откат миграции $last_migration..."
        
        # Удаляем запись о миграции
        docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << EOF 2>/dev/null || true
DELETE FROM schema_migrations WHERE filename = '$last_migration';
EOF
        
        log_success "Миграция $last_migration откачена"
        log_warning "ВНИМАНИЕ: Вам нужно вручную откатить изменения в схеме БД!"
    else
        log_info "Откат отменен"
    fi
}

# Функция проверки целостности миграций
verify_migrations() {
    log_info "Проверка целостности миграций..."
    
    # Проверяем, что PostgreSQL запущен
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log_error "PostgreSQL не запущен"
        return 1
    fi
    
    # Получаем список примененных миграций
    local applied_migrations=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT filename, checksum FROM schema_migrations;" 2>/dev/null)
    
    if [ -z "$applied_migrations" ]; then
        log_info "Нет примененных миграций для проверки"
        return 0
    fi
    
    local errors=0
    
    # Проверяем каждую примененную миграцию
    while IFS='|' read -r filename checksum; do
        filename=$(echo "$filename" | tr -d ' ')
        checksum=$(echo "$checksum" | tr -d ' ')
        
        if [ -f "$MIGRATIONS_DIR/$filename" ]; then
            local current_checksum=$(sha256sum "$MIGRATIONS_DIR/$filename" | cut -d' ' -f1)
            
            if [ "$checksum" = "$current_checksum" ]; then
                log_success "✓ $filename: checksum совпадает"
            else
                log_error "❌ $filename: checksum не совпадает (файл изменен после применения)"
                errors=$((errors + 1))
            fi
        else
            log_error "❌ $filename: файл не найден"
            errors=$((errors + 1))
        fi
    done <<< "$applied_migrations"
    
    if [ $errors -eq 0 ]; then
        log_success "Все миграции прошли проверку целостности"
    else
        log_error "Найдено $errors ошибок в миграциях"
        return 1
    fi
}

# Основная логика
main() {
    local action="$1"
    local migration_name="$2"
    
    case $action in
        create)
            create_migration "$migration_name"
            ;;
        apply)
            apply_migrations
            ;;
        status)
            check_migration_status
            ;;
        rollback)
            rollback_last_migration
            ;;
        verify)
            verify_migrations
            ;;
        *)
            echo "Использование: $0 [create|apply|status|rollback|verify] [migration_name]"
            echo ""
            echo "Команды:"
            echo "  create <name>  - Создать новую миграцию"
            echo "  apply          - Применить все миграции"
            echo "  status         - Показать статус миграций"
            echo "  rollback       - Откатить последнюю миграцию"
            echo "  verify         - Проверить целостность миграций"
            echo ""
            echo "Примеры:"
            echo "  $0 create add_user_phone"
            echo "  $0 apply"
            echo "  $0 status"
            exit 1
            ;;
    esac
}

# Запуск основного скрипта
main "$@" 
#!/bin/bash

# Скрипт управления миграциями для удаленного сервера
set -e

MIGRATIONS_DIR="migrations"
DB_NAME="products_db_prod"
DB_USER="postgres"
DB_CONTAINER="products_postgres_prod"

# Создаем таблицу для отслеживания примененных миграций
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME << 'SQL' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64),
    execution_time_ms INTEGER
);
SQL

# Получаем список всех файлов миграций в порядке применения
if [ -d "$MIGRATIONS_DIR" ]; then
    migrations=($(ls -1 "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort))
    
    if [ ${#migrations[@]} -eq 0 ]; then
        echo "Миграции не найдены в директории $MIGRATIONS_DIR"
        exit 0
    fi
    
    # Применяем каждую миграцию
    for migration in "${migrations[@]}"; do
        filename=$(basename "$migration")
        
        # Проверяем, была ли миграция уже применена
        applied=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM schema_migrations WHERE filename = '$filename';" 2>/dev/null | tr -d ' ')
        
        if [ "$applied" = "1" ]; then
            echo "✓ Миграция $filename уже применена, пропускаем"
            continue
        fi
        
        echo "Применение миграции: $filename"
        
        # Засекаем время выполнения
        start_time=$(date +%s%3N)
        
        # Применяем миграцию
        if docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$migration" 2>/dev/null; then
            end_time=$(date +%s%3N)
            execution_time=$((end_time - start_time))
            
            # Вычисляем checksum файла
            checksum=$(sha256sum "$migration" | cut -d' ' -f1)
            
            # Записываем информацию о примененной миграции
            docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << SQL 2>/dev/null || true
INSERT INTO schema_migrations (filename, checksum, execution_time_ms) 
VALUES ('$filename', '$checksum', $execution_time);
SQL
            
            echo "✓ Миграция $filename применена успешно (${execution_time}ms)"
        else
            echo "❌ Ошибка применения миграции $filename"
            exit 1
        fi
    done
    
    echo "Все миграции применены успешно"
else
    echo "Директория миграций $MIGRATIONS_DIR не найдена"
fi 
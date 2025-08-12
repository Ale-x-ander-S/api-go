#!/bin/bash

# Скрипт для автоматической генерации Swagger документации
# Запускается при каждом запуске приложения

set -e

echo "🔄 Автоматическое обновление Swagger документации..."

# Проверяем, установлен ли swag
if ! command -v swag &> /dev/null; then
    echo "⚠️  swag не найден в PATH, пытаемся найти в GOPATH..."
    
    # Пытаемся найти в GOPATH
    GOPATH=${GOPATH:-$HOME/go}
    SWAG_PATH="$GOPATH/bin/swag"
    
    if [ -f "$SWAG_PATH" ]; then
        echo "✅ swag найден в $SWAG_PATH"
        export PATH="$GOPATH/bin:$PATH"
    else
        echo "❌ swag не найден. Установите: go install github.com/swaggo/swag/cmd/swag@latest"
        echo "📚 Приложение продолжит работу с существующей документацией"
        exit 0
    fi
fi

# Генерируем документацию
echo "📝 Генерация Swagger документации..."
if swag init -g main.go; then
    echo "✅ Swagger документация успешно обновлена!"
    echo "📊 Файлы созданы:"
    ls -la docs/
else
    echo "❌ Ошибка генерации Swagger документации"
    echo "📚 Приложение продолжит работу с существующей документацией"
    exit 0
fi 
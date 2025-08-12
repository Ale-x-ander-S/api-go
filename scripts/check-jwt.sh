#!/bin/bash

# Скрипт для проверки времени жизни JWT токена

set -e

echo "🔍 Проверка времени жизни JWT токена"
echo ""

# Проверяем, запущен ли сервер
if ! curl -s http://localhost:8080/ > /dev/null; then
    echo "❌ Сервер не запущен. Запустите: go run main.go"
    exit 1
fi

echo "📝 Введите данные для входа:"
read -p "Username: " username
read -s -p "Password: " password
echo ""

echo "🔐 Получение токена..."
response=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$username\",\"password\":\"$password\"}")

token=$(echo $response | jq -r '.token')
if [ "$token" = "null" ] || [ "$token" = "" ]; then
    echo "❌ Ошибка входа: $(echo $response | jq -r '.error')"
    exit 1
fi

echo "✅ Токен получен!"
echo ""

# Декодируем JWT токен (без проверки подписи)
echo "🔍 Анализ JWT токена:"
echo ""

# Разбиваем токен на части
IFS='.' read -ra TOKEN_PARTS <<< "$token"

if [ ${#TOKEN_PARTS[@]} -eq 3 ]; then
    # Декодируем payload (вторая часть)
    payload="${TOKEN_PARTS[1]}"
    
    # Добавляем padding если нужно
    padding=$((4 - ${#payload} % 4))
    if [ $padding -ne 4 ]; then
        payload="${payload}$(printf '=%.0s' $(seq 1 $padding))"
    fi
    
    # Декодируем base64
    decoded_payload=$(echo "$payload" | base64 -d 2>/dev/null || echo "$payload" | base64 -d 2>/dev/null)
    
    echo "📋 Payload токена:"
    echo "$decoded_payload" | jq '.' 2>/dev/null || echo "$decoded_payload"
    echo ""
    
    # Извлекаем время истечения
    exp=$(echo "$decoded_payload" | jq -r '.exp' 2>/dev/null)
    iat=$(echo "$decoded_payload" | jq -r '.iat' 2>/dev/null)
    
    if [ "$exp" != "null" ] && [ "$exp" != "" ]; then
        # Конвертируем Unix timestamp в читаемую дату
        expiry_date=$(date -r "$exp" "+%Y-%m-%d %H:%M:%S")
        issued_date=$(date -r "$iat" "+%Y-%m-%d %H:%M:%S")
        
        echo "⏰ Время жизни токена:"
        echo "   Выдан: $issued_date"
        echo "   Истекает: $expiry_date"
        
        # Вычисляем оставшееся время
        current_time=$(date +%s)
        remaining_seconds=$((exp - current_time))
        
        if [ $remaining_seconds -gt 0 ]; then
            remaining_hours=$((remaining_seconds / 3600))
            remaining_minutes=$(((remaining_seconds % 3600) / 60))
            echo "   Осталось: ${remaining_hours}ч ${remaining_minutes}м"
        else
            echo "   ❌ Токен истек!"
        fi
    else
        echo "⚠️  Не удалось извлечь время истечения"
    fi
else
    echo "❌ Неверный формат JWT токена"
fi

echo ""
echo "🔧 Текущие настройки JWT:"
echo "   JWT_EXPIRY_HOURS: ${JWT_EXPIRY_HOURS:-24} часов"
echo "   JWT_REFRESH_EXPIRY_DAYS: ${JWT_REFRESH_EXPIRY_DAYS:-7} дней"
echo ""
echo "💡 Для изменения времени жизни токена отредактируйте config.env" 
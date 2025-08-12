#!/bin/bash

# Скрипт для получения JWT токена для тестирования API

set -e

echo "🔑 Получение JWT токена для тестирования API"
echo ""

# Проверяем, запущен ли сервер
if ! curl -s http://localhost:8080/ > /dev/null; then
    echo "❌ Сервер не запущен. Запустите: go run main.go"
    exit 1
fi

echo "📝 Выберите действие:"
echo "1) Войти как обычный пользователь"
echo "2) Войти как администратор"
echo "3) Зарегистрировать нового пользователя"
echo "4) Зарегистрировать нового администратора"
echo ""

read -p "Введите номер (1-4): " choice

case $choice in
    1)
        echo "🔐 Вход как обычный пользователь..."
        read -p "Username: " username
        read -s -p "Password: " password
        echo ""
        
        response=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$username\",\"password\":\"$password\"}")
        
        token=$(echo $response | jq -r '.token')
        if [ "$token" != "null" ] && [ "$token" != "" ]; then
            echo "✅ Токен получен:"
            echo "Bearer $token"
            echo ""
            echo "📋 Используйте в Swagger UI:"
            echo "1) Нажмите кнопку 'Authorize' (🔒)"
            echo "2) Введите: Bearer $token"
            echo "3) Нажмите 'Authorize'"
        else
            echo "❌ Ошибка входа: $(echo $response | jq -r '.error')"
        fi
        ;;
        
    2)
        echo "🔐 Вход как администратор..."
        read -p "Username: " username
        read -s -p "Password: " password
        echo ""
        
        response=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$username\",\"password\":\"$password\"}")
        
        token=$(echo $response | jq -r '.token')
        if [ "$token" != "null" ] && [ "$token" != "" ]; then
            echo "✅ Токен администратора получен:"
            echo "Bearer $token"
            echo ""
            echo "📋 Используйте в Swagger UI:"
            echo "1) Нажмите кнопку 'Authorize' (🔒)"
            echo "2) Введите: Bearer $token"
            echo "3) Нажмите 'Authorize'"
            echo ""
            echo "🚀 Теперь вы можете создавать/изменять/удалять продукты!"
        else
            echo "❌ Ошибка входа: $(echo $response | jq -r '.error')"
        fi
        ;;
        
    3)
        echo "📝 Регистрация нового пользователя..."
        read -p "Username: " username
        read -p "Email: " email
        read -s -p "Password: " password
        echo ""
        
        response=$(curl -s -X POST http://localhost:8080/api/v1/auth/register \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$username\",\"email\":\"$email\",\"password\":\"$password\"}")
        
        if echo $response | jq -e '.id' > /dev/null; then
            echo "✅ Пользователь зарегистрирован!"
            echo "Теперь войдите в систему (выберите опцию 1)"
        else
            echo "❌ Ошибка регистрации: $(echo $response | jq -r '.error')"
        fi
        ;;
        
    4)
        echo "📝 Регистрация нового администратора..."
        read -p "Username: " username
        read -p "Email: " email
        read -s -p "Password: " password
        echo ""
        
        # Сначала регистрируем пользователя
        response=$(curl -s -X POST http://localhost:8080/api/v1/auth/register \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$username\",\"email\":\"$email\",\"password\":\"$password\"}")
        
        if echo $response | jq -e '.id' > /dev/null; then
            echo "✅ Пользователь зарегистрирован!"
            echo "⚠️  Для изменения роли на admin используйте SQL:"
            echo "UPDATE users SET role = 'admin' WHERE username = '$username';"
            echo ""
            echo "После изменения роли войдите в систему (выберите опцию 2)"
        else
            echo "❌ Ошибка регистрации: $(echo $response | jq -r '.error')"
        fi
        ;;
        
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "🌐 Swagger UI: http://localhost:8080/swagger/index.html"
echo "📚 Документация API: http://localhost:8080/" 
#!/bin/bash

# Скрипт для тестирования API endpoints
# Убедитесь, что сервер запущен на порту 8080

BASE_URL="http://localhost:8080/api/v1"
JWT_TOKEN=""

echo "🚀 Тестирование Products API"
echo "================================"

# Проверка статуса API
echo "1. Проверка статуса API..."
curl -s "$BASE_URL/../" | jq . || echo "API недоступен"

# Регистрация пользователя
echo -e "\n2. Регистрация пользователя..."
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }')

echo "Ответ: $REGISTER_RESPONSE"

# Вход пользователя
echo -e "\n3. Вход пользователя..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }')

echo "Ответ: $LOGIN_RESPONSE"

# Извлекаем JWT токен
JWT_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
if [ "$JWT_TOKEN" != "null" ] && [ "$JWT_TOKEN" != "" ]; then
    echo "✅ JWT токен получен"
else
    echo "❌ Ошибка получения JWT токена"
    exit 1
fi

# Получение списка продуктов (публичный endpoint)
echo -e "\n4. Получение списка продуктов..."
curl -s "$BASE_URL/products" | jq '.[0:2]' || echo "Ошибка получения продуктов"

# Получение продукта по ID
echo -e "\n5. Получение продукта по ID..."
curl -s "$BASE_URL/products/1" | jq . || echo "Ошибка получения продукта"

# Создание нового продукта (требует аутентификации)
echo -e "\n6. Создание нового продукта..."
CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "name": "Тестовый продукт",
    "description": "Описание тестового продукта",
    "price": 99.99,
    "category": "Тест",
    "stock": 5
  }')

echo "Ответ: $CREATE_RESPONSE"

# Обновление продукта (требует аутентификации)
echo -e "\n7. Обновление продукта..."
UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/products/1" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "price": 149.99,
    "stock": 15
  }')

echo "Ответ: $UPDATE_RESPONSE"

# Получение обновленного продукта
echo -e "\n8. Получение обновленного продукта..."
curl -s "$BASE_URL/products/1" | jq . || echo "Ошибка получения продукта"

# Фильтрация по категории
echo -e "\n9. Фильтрация продуктов по категории 'Электроника'..."
curl -s "$BASE_URL/products?category=Электроника" | jq . || echo "Ошибка фильтрации"

# Пагинация
echo -e "\n10. Пагинация продуктов (страница 1, лимит 2)..."
curl -s "$BASE_URL/products?page=1&limit=2" | jq . || echo "Ошибка пагинации"

echo -e "\n✅ Тестирование завершено!"
echo "📚 Swagger документация: http://localhost:8080/swagger/index.html" 
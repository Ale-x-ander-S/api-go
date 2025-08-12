# Примеры использования Products API

## Быстрый старт

### 1. Запуск сервера

```bash
# Локально
go run main.go

# Или через Docker Compose
docker-compose up -d
```

### 2. Проверка статуса

```bash
curl http://localhost:8080/
```

## Аутентификация

### Регистрация пользователя

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "securepassword123"
  }'
```

**Ответ:**
```json
{
  "id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "role": "user",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Вход пользователя

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "securepassword123"
  }'
```

**Ответ:**
```json
{
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "role": "user",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

## Работа с продуктами

### Получение списка продуктов

```bash
# Все продукты
curl http://localhost:8080/api/v1/products

# С пагинацией
curl "http://localhost:8080/api/v1/products?page=1&limit=5"

# Фильтрация по категории
curl "http://localhost:8080/api/v1/products?category=Электроника"
```

### Получение продукта по ID

```bash
curl http://localhost:8080/api/v1/products/1
```

### Создание продукта (требует аутентификации)

```bash
curl -X POST http://localhost:8080/api/v1/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "Новый продукт",
    "description": "Описание нового продукта",
    "price": 199.99,
    "category": "Электроника",
    "stock": 25,
    "image_url": "https://example.com/image.jpg"
  }'
```

### Обновление продукта (требует аутентификации)

```bash
curl -X PUT http://localhost:8080/api/v1/products/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "price": 249.99,
    "stock": 30
  }'
```

### Удаление продукта (требует аутентификации)

```bash
curl -X DELETE http://localhost:8080/api/v1/products/1 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Примеры на разных языках

### Python

```python
import requests
import json

BASE_URL = "http://localhost:8080/api/v1"

# Регистрация
def register_user(username, email, password):
    response = requests.post(f"{BASE_URL}/auth/register", json={
        "username": username,
        "email": email,
        "password": password
    })
    return response.json()

# Вход
def login_user(username, password):
    response = requests.post(f"{BASE_URL}/auth/login", json={
        "username": username,
        "password": password
    })
    return response.json()

# Создание продукта
def create_product(token, product_data):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/products", 
                           json=product_data, headers=headers)
    return response.json()

# Использование
user = register_user("testuser", "test@example.com", "password123")
login_data = login_user("testuser", "password123")
token = login_data["token"]

product = create_product(token, {
    "name": "Python Product",
    "price": 99.99,
    "category": "Software"
})
```

### JavaScript (Node.js)

```javascript
const axios = require('axios');

const BASE_URL = 'http://localhost:8080/api/v1';

class ProductsAPI {
    constructor() {
        this.token = null;
    }

    async register(username, email, password) {
        const response = await axios.post(`${BASE_URL}/auth/register`, {
            username,
            email,
            password
        });
        return response.data;
    }

    async login(username, password) {
        const response = await axios.post(`${BASE_URL}/auth/login`, {
            username,
            password
        });
        this.token = response.data.token;
        return response.data;
    }

    async createProduct(productData) {
        const response = await axios.post(`${BASE_URL}/products`, productData, {
            headers: { Authorization: `Bearer ${this.token}` }
        });
        return response.data;
    }

    async getProducts(params = {}) {
        const response = await axios.get(`${BASE_URL}/products`, { params });
        return response.data;
    }
}

// Использование
async function main() {
    const api = new ProductsAPI();
    
    try {
        await api.register('jsuser', 'js@example.com', 'password123');
        await api.login('jsuser', 'password123');
        
        const product = await api.createProduct({
            name: 'JavaScript Product',
            price: 79.99,
            category: 'Development'
        });
        
        console.log('Создан продукт:', product);
    } catch (error) {
        console.error('Ошибка:', error.response?.data || error.message);
    }
}

main();
```

### cURL с переменными

```bash
#!/bin/bash

# Настройки
API_URL="http://localhost:8080/api/v1"
USERNAME="testuser"
PASSWORD="password123"

# Функция для получения токена
get_token() {
    local response=$(curl -s -X POST "$API_URL/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
    
    echo $response | jq -r '.token'
}

# Функция для создания продукта
create_product() {
    local token=$1
    local name=$2
    local price=$3
    
    curl -s -X POST "$API_URL/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "{\"name\":\"$name\",\"price\":$price,\"category\":\"Test\"}"
}

# Основной скрипт
echo "Получение токена..."
TOKEN=$(get_token)

if [ "$TOKEN" != "null" ] && [ "$TOKEN" != "" ]; then
    echo "Токен получен: ${TOKEN:0:20}..."
    
    echo "Создание продукта..."
    create_product "$TOKEN" "Тестовый продукт" 99.99
    
    echo "Получение списка продуктов..."
    curl -s "$API_URL/products" | jq '.[0:3]'
else
    echo "Ошибка получения токена"
fi
```

## Обработка ошибок

### Примеры ошибок

**400 Bad Request - Неверные данные:**
```json
{
  "error": "Неверные данные: Key: 'ProductCreateRequest.Price' Error:Field validation for 'Price' failed on the 'gt' tag"
}
```

**401 Unauthorized - Токен отсутствует:**
```json
{
  "error": "Заголовок Authorization отсутствует"
}
```

**401 Unauthorized - Недействительный токен:**
```json
{
  "error": "Недействительный токен: token is expired"
}
```

**404 Not Found - Продукт не найден:**
```json
{
  "error": "Продукт не найден"
}
```

**409 Conflict - Пользователь уже существует:**
```json
{
  "error": "Пользователь с таким именем уже существует"
}
```

## Тестирование производительности

### Apache Bench (ab)

```bash
# Тест получения продуктов
ab -n 1000 -c 10 http://localhost:8080/api/v1/products

# Тест с аутентификацией
ab -n 100 -c 5 -H "Authorization: Bearer YOUR_TOKEN" \
   -p product_data.json -T application/json \
   http://localhost:8080/api/v1/products
```

### wrk

```bash
# Базовый тест
wrk -t12 -c400 -d30s http://localhost:8080/api/v1/products

# Тест с Lua скриптом для аутентификации
wrk -t12 -c400 -d30s -s auth_test.lua http://localhost:8080/api/v1/products
```

## Мониторинг и логи

### Проверка логов

```bash
# Если запущено через Docker
docker logs products_api

# Если запущено локально
tail -f api.log
```

### Метрики здоровья

```bash
# Проверка статуса
curl http://localhost:8080/health

# Статистика
curl http://localhost:8080/stats
```

## Интеграция с другими системами

### Webhook для уведомлений

```bash
# Настройка webhook URL в конфигурации
WEBHOOK_URL=https://your-service.com/webhook

# Отправка уведомлений при создании продукта
curl -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "event": "product.created",
    "product_id": 123,
    "timestamp": "2024-01-15T10:30:00Z"
  }'
```

### Экспорт данных

```bash
# Экспорт всех продуктов в JSON
curl -s "http://localhost:8080/api/v1/products?limit=1000" > products_export.json

# Экспорт в CSV (требует дополнительной обработки)
curl -s "http://localhost:8080/api/v1/products?limit=1000" | \
  jq -r '.[] | [.id, .name, .price, .category, .stock] | @csv' > products.csv
``` 
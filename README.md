# Products API

REST API для управления продуктами с JWT аутентификацией, написанный на Go.

## Возможности

- 🔐 JWT аутентификация и авторизация
- 📦 CRUD операции с продуктами
- 🗄️ PostgreSQL база данных
- 📚 Swagger документация
- 🚀 Готовность к продакшену
- 📝 Подробные комментарии в коде

## Структура проекта

```
api-go/
├── config/          # Конфигурация приложения
├── database/        # Работа с базой данных
├── handlers/        # HTTP обработчики
├── middleware/      # Middleware (CORS, аутентификация)
├── models/          # Модели данных
├── routes/          # Настройка маршрутов
├── utils/           # Утилиты (JWT, хеширование)
├── config.env       # Переменные окружения
├── go.mod           # Зависимости Go
├── main.go          # Точка входа
└── README.md        # Документация
```

## Требования

- Go 1.21+
- PostgreSQL 12+
- Swag CLI (для генерации Swagger)

## Установка и запуск

### 1. Клонирование и установка зависимостей

```bash
git clone <repository-url>
cd api-go
go mod tidy
```

### 2. Настройка базы данных

Создайте базу данных PostgreSQL:

```sql
CREATE DATABASE products_db;
```

### 3. Настройка переменных окружения

Отредактируйте файл `config.env`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=products_db
DB_SSL_MODE=disable

JWT_SECRET=your-super-secret-jwt-key-change-in-production
SERVER_PORT=8080
```

### 4. Установка Swag CLI

```bash
go install github.com/swaggo/swag/cmd/swag@latest
```

### 5. Генерация Swagger документации

```bash
swag init
```

### 6. Запуск приложения

```bash
go run main.go
```

API будет доступен по адресу: `http://localhost:8080`

## API Endpoints

### Аутентификация

- `POST /api/v1/auth/register` - Регистрация пользователя
- `POST /api/v1/auth/login` - Вход пользователя

### Продукты

#### Публичные (без аутентификации)
- `GET /api/v1/products` - Получить список продуктов
- `GET /api/v1/products/:id` - Получить продукт по ID

#### Защищенные (требуют JWT токен)
- `POST /api/v1/products` - Создать продукт
- `PUT /api/v1/products/:id` - Обновить продукт
- `DELETE /api/v1/products/:id` - Удалить продукт

## Примеры использования

### Регистрация пользователя

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Вход пользователя

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }'
```

### Создание продукта (с токеном)

```bash
curl -X POST http://localhost:8080/api/v1/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "Тестовый продукт",
    "description": "Описание продукта",
    "price": 99.99,
    "category": "Электроника",
    "stock": 10
  }'
```

## Swagger документация

После запуска приложения Swagger документация доступна по адресу:
`http://localhost:8080/swagger/index.html`

## Особенности архитектуры

### 1. Модульность
Код организован в логические пакеты, что обеспечивает легкое расширение и поддержку.

### 2. Middleware
- **CORS** - для кросс-доменных запросов
- **Аутентификация** - проверка JWT токенов
- **Логирование** - детальное логирование запросов

### 3. Валидация
Используются теги Go для валидации входящих данных.

### 4. Безопасность
- Хеширование паролей с bcrypt
- JWT токены с настраиваемым временем жизни
- Проверка ролей пользователей

### 5. Обработка ошибок
Единообразная обработка ошибок с понятными сообщениями.

## Расширение функциональности

### Добавление новых моделей

1. Создайте модель в `models/`
2. Добавьте таблицу в `database/database.go`
3. Создайте обработчик в `handlers/`
4. Добавьте маршруты в `routes/routes.go`

### Добавление новых middleware

1. Создайте файл в `middleware/`
2. Подключите в `routes/routes.go`

### Добавление новых утилит

1. Создайте файл в `utils/`
2. Импортируйте в нужных местах

## Тестирование

```bash
go test ./...
```

## Линтинг

```bash
golangci-lint run
```

## Деплой

### Docker

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
CMD ["./main"]
```

### Переменные окружения для продакшена

- Измените `JWT_SECRET` на сложный секретный ключ
- Настройте `DB_SSL_MODE=require` для продакшена
- Используйте переменные окружения вместо файла `config.env`

## Лицензия

MIT 
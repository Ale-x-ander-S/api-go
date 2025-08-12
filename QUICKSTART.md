# 🚀 Быстрый старт Products API

## Вариант 1: Docker Compose (рекомендуется)

```bash
# 1. Запуск всех сервисов
docker-compose up -d

# 2. Проверка статуса
curl http://localhost:8080/

# 3. Swagger документация
open http://localhost:8080/swagger/index.html
```

## Вариант 2: Локальный запуск

```bash
# 1. Установка зависимостей
go mod tidy

# 2. Установка Swag CLI
go install github.com/swaggo/swag/cmd/swag@latest

# 3. Генерация Swagger
export PATH=$PATH:$(go env GOPATH)/bin
swag init

# 4. Запуск PostgreSQL (убедитесь что установлен)
# Создайте базу данных products_db

# 5. Запуск API
go run main.go
```

## 🧪 Тестирование

```bash
# Запуск тестового скрипта
./test_api.sh

# Или вручную:
# 1. Регистрация
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"123456"}'

# 2. Вход
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456"}'

# 3. Получение продуктов
curl http://localhost:8080/api/v1/products
```

## 📚 Полезные команды

```bash
# Показать все доступные команды
make help

# Установка инструментов разработки
make tools

# Запуск в режиме разработки
make dev

# Сборка и запуск
make start

# Очистка
make clean
```

## 🔧 Настройка

Отредактируйте `config.env`:
```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=products_db
JWT_SECRET=your-secret-key
```

## 📍 Endpoints

- **API**: http://localhost:8080/api/v1
- **Swagger**: http://localhost:8080/swagger/index.html
- **pgAdmin**: http://localhost:5050 (admin@admin.com / admin)

## 🆘 Решение проблем

**Ошибка подключения к БД:**
- Проверьте что PostgreSQL запущен
- Проверьте настройки в config.env

**Swagger не работает:**
- Выполните `swag init`
- Проверьте что docs/ папка создана

**Порт занят:**
- Измените SERVER_PORT в config.env
- Или остановите процесс на порту 8080 
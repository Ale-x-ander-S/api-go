# 🚀 Products API - Инструкция по использованию

## ✅ Что создано

Полноценный REST API на Go с PostgreSQL, JWT аутентификацией и Swagger документацией.

## 📁 Структура проекта

```
api-go/
├── 📁 config/          # Конфигурация приложения
│   └── config.go       # Загрузка переменных окружения
├── 📁 database/        # Работа с базой данных
│   └── database.go     # Подключение к PostgreSQL
├── 📁 handlers/        # HTTP обработчики
│   ├── auth.go         # Аутентификация (регистрация, вход)
│   └── product.go      # CRUD операции с продуктами
├── 📁 middleware/      # Middleware
│   ├── auth.go         # JWT аутентификация
│   ├── cors.go         # CORS заголовки
│   └── logger.go       # Логирование запросов
├── 📁 models/          # Модели данных
│   ├── user.go         # Пользователь
│   └── product.go      # Продукт
├── 📁 routes/          # Маршруты API
│   └── routes.go       # Настройка всех endpoints
├── 📁 utils/           # Утилиты
│   ├── jwt.go          # Работа с JWT токенами
│   └── password.go     # Хеширование паролей
├── 📁 docs/            # Swagger документация (генерируется)
├── 🐳 Dockerfile       # Контейнеризация
├── 🐳 docker-compose.yml # Запуск с PostgreSQL
├── 🔧 Makefile         # Команды для разработки
├── 📖 README.md        # Подробная документация
├── 🚀 QUICKSTART.md    # Быстрый старт
├── 📚 examples.md      # Примеры использования
├── 🧪 test_api.sh     # Скрипт тестирования
├── ⚙️ config.env       # Переменные окружения
├── 🗄️ init.sql         # Инициализация базы данных
└── 🎯 main.go          # Точка входа приложения
```

## 🚀 Быстрый запуск

### Вариант 1: Через Makefile (рекомендуется)

```bash
# Показать все команды
make help

# Полная настройка проекта
make setup

# Запуск с проверками
make start

# Остановка и очистка
make clean
```

### Вариант 2: Ручной запуск

```bash
# 1. Создать базу данных
createdb products_db

# 2. Установить зависимости
go mod tidy

# 3. Генерировать Swagger
export PATH=$PATH:$(go env GOPATH)/bin
swag init

# 4. Запустить API
go run main.go
```

### Вариант 3: Docker Compose

```bash
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Остановка
docker-compose down
```

## 🔐 API Endpoints

### Аутентификация (публичные)
- **`POST /api/v1/auth/register`** - Регистрация пользователя
- **`POST /api/v1/auth/login`** - Вход и получение JWT токена

### Продукты (публичные)
- **`GET /api/v1/products`** - Список продуктов
  - `?page=1&limit=10` - пагинация
  - `?category=Электроника` - фильтрация
- **`GET /api/v1/products/:id`** - Продукт по ID

### Продукты (защищенные - требуют JWT токен)
- **`POST /api/v1/products`** - Создание продукта
- **`PUT /api/v1/products/:id`** - Обновление продукта
- **`DELETE /api/v1/products/:id`** - Удаление продукта

## 🧪 Тестирование

### Автоматическое тестирование
```bash
# Запуск тестового скрипта
./test_api.sh

# Или через Makefile
make test
```

### Ручное тестирование
```bash
# 1. Регистрация
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"123456"}'

# 2. Вход
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456"}'

# 3. Создание продукта (с токеном)
curl -X POST http://localhost:8080/api/v1/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"name":"Тест","price":99.99,"category":"Тест"}'
```

## 📚 Swagger документация

После запуска доступна по адресу:
`http://localhost:8080/swagger/index.html`

## 🔧 Настройка

### Переменные окружения (config.env)
```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=products_db
DB_SSL_MODE=disable
JWT_SECRET=your-super-secret-jwt-key
SERVER_PORT=8080
```

### База данных
```sql
-- Создание базы
CREATE DATABASE products_db;

-- Или через psql
createdb products_db;
```

## 🚀 Расширение функциональности

### Добавить новую модель (например, Order)

1. **Создать модель** в `models/order.go`:
```go
type Order struct {
    ID        int       `json:"id" db:"id"`
    UserID    int       `json:"user_id" db:"user_id"`
    ProductID int       `json:"product_id" db:"product_id"`
    Quantity  int       `json:"quantity" db:"quantity"`
    Status    string    `json:"status" db:"status"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
}
```

2. **Добавить таблицу** в `database/database.go`:
```sql
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

3. **Создать обработчик** в `handlers/order.go`

4. **Добавить маршруты** в `routes/routes.go`

### Добавить новый middleware

1. Создать файл в `middleware/`
2. Подключить в `routes/routes.go`

### Добавить новую утилиту

1. Создать файл в `utils/`
2. Импортировать где нужно

## 🐳 Docker команды

```bash
# Сборка образа
make docker-build

# Запуск в Docker
make docker-run

# Просмотр логов
make logs
```

## 📊 Мониторинг

```bash
# Статус приложения
make status

# Проверка готовности
make check

# Логи (если в Docker)
make logs
```

## 🆘 Решение проблем

### Порт занят
```bash
# Найти процесс
lsof -ti:8080

# Остановить процесс
lsof -ti:8080 | xargs kill -9
```

### Ошибка подключения к БД
- Проверьте что PostgreSQL запущен
- Проверьте настройки в config.env
- Создайте базу данных: `createdb products_db`

### Swagger не работает
- Выполните: `swag init`
- Проверьте что docs/ папка создана

### Зависимости не установлены
```bash
go mod tidy
go mod download
```

## 🎯 Готовые команды Makefile

```bash
make help          # Показать все команды
make setup         # Полная настройка проекта
make start         # Запуск с проверками
make dev           # Режим разработки с автоперезагрузкой
make build         # Сборка приложения
make test          # Запуск тестов
make lint          # Проверка кода линтером
make clean         # Очистка
make docker-build  # Сборка Docker образа
make docker-run    # Запуск в Docker
```

## 🌟 Готово к использованию!

Проект полностью настроен и готов к работе. Все функции протестированы и работают корректно.

**Следующие шаги:**
1. Настройте переменные окружения в `config.env`
2. Запустите через `make start`
3. Откройте Swagger: `http://localhost:8080/swagger/index.html`
4. Протестируйте API через `./test_api.sh`

Удачи в разработке! 🚀 
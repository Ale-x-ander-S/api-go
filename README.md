# 🚀 Products API - Go

RESTful API для управления продуктами интернет-магазина, написанный на Go с использованием Gin, PostgreSQL и Redis.

## ✨ Возможности

- 🔐 JWT аутентификация и авторизация
- 📦 CRUD операции для продуктов
- 🗂️ Категории продуктов
- 🛒 Корзина покупок
- 📋 Заказы и отзывы
- 💾 Кэширование в Redis
- 📊 Swagger документация
- 🐳 Docker контейнеризация
- 🌍 Поддержка окружений (dev, staging, prod)

## 🚀 Быстрый старт

### Локальная разработка

```bash
# Клонирование репозитория
git clone <repository-url>
cd api-go

# Установка зависимостей
go mod download

# Запуск локально
make deploy-local

# Тестирование API
./test_api.sh
```

### Деплой на сервер

```bash
# Простой деплой (рекомендуется)
make deploy-simple ENV=prod SERVER=YOUR_IP USER=root

# Пример
make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root
```

## 🛠️ Основные команды

```bash
# Локальная разработка
make deploy-local          # Запуск локально
make swagger-auto         # Генерация Swagger документации

# Управление миграциями БД
make migration-create      # Создать новую миграцию
make migrate               # Применить миграции
make migration-status      # Показать статус миграций
make migration-verify      # Проверить целостность

# Деплой
make deploy-simple        # Простой деплой без healthcheck
make deploy-cloud         # Деплой с healthcheck
make clean-deploy         # Полная очистка и передеплой

# Исправление проблем
make fix-databases        # Исправление всех проблем с БД
make fix-redis            # Исправление проблем с Redis
make fix-postgres         # Исправление проблем с PostgreSQL
```

## 📁 Структура проекта

```
api-go/
├── cache/           # Redis кэширование
├── config/          # Конфигурация приложения
├── database/        # Подключение к БД и Redis
├── handlers/        # HTTP обработчики
├── middleware/      # Middleware (CORS, JWT, логирование)
├── migrations/      # SQL миграции
├── models/          # Модели данных
├── routes/          # Маршрутизация
├── scripts/         # Скрипты деплоя и исправления
├── utils/           # Утилиты (JWT, пароли)
├── main.go          # Точка входа
├── Dockerfile       # Docker образ
└── docker-compose.*.yml # Docker Compose конфигурации
```

## 🔧 Конфигурация

### Переменные окружения

```bash
# База данных
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=products_db
DB_SSL_MODE=disable

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
REDIS_TTL=3600

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_DAYS=7

# Сервер
SERVER_PORT=8080
ENVIRONMENT=development
LOG_LEVEL=debug
```

### Окружения

- **Development**: `config.dev.env` - локальная разработка
- **Staging**: `config.staging.env` - тестовое окружение
- **Production**: `config.prod.env` - продакшн

## 🐳 Docker

### Локальный запуск

```bash
# Запуск всех сервисов
docker-compose up -d

# Только базы данных
docker-compose up postgres redis -d

# Логи
docker-compose logs -f
```

### Production деплой

```bash
# Деплой на сервер
make deploy-simple ENV=prod SERVER=YOUR_IP USER=root

# Проверка статуса
ssh root@YOUR_IP "cd /opt/api-go && docker-compose -f docker-compose-simple.yml ps"

# Логи
ssh root@YOUR_IP "cd /opt/api-go && docker-compose -f docker-compose-simple.yml logs -f"
```

## 📚 API Endpoints

### Аутентификация
- `POST /api/v1/auth/register` - Регистрация
- `POST /api/v1/auth/login` - Вход
- `POST /api/v1/auth/refresh` - Обновление токена

### Продукты
- `GET /api/v1/products` - Список продуктов (с пагинацией)
- `GET /api/v1/products/{id}` - Продукт по ID
- `POST /api/v1/products` - Создание продукта
- `PUT /api/v1/products/{id}` - Обновление продукта
- `DELETE /api/v1/products/{id}` - Удаление продукта

### Категории
- `GET /api/v1/categories` - Список категорий
- `GET /api/v1/categories/{id}` - Категория по ID

### Корзина
- `GET /api/v1/cart` - Корзина пользователя
- `POST /api/v1/cart` - Добавление в корзину
- `PUT /api/v1/cart/{id}` - Обновление количества
- `DELETE /api/v1/cart/{id}` - Удаление из корзины

### Заказы
- `GET /api/v1/orders` - Заказы пользователя
- `POST /api/v1/orders` - Создание заказа

## 🔍 Swagger документация

После запуска приложения Swagger UI доступен по адресу:
- **Локально**: http://localhost:8080/swagger/index.html
- **Сервер**: http://YOUR_IP:8082/swagger/index.html

## 🚀 Деплой

### Простой деплой (рекомендуется)

```bash
# 1. Настройка сервера
# Убедитесь что на сервере установлены Docker и Docker Compose

# 2. Деплой
make deploy-simple ENV=prod SERVER=YOUR_IP USER=root

# 3. Проверка
curl http://YOUR_IP:8082/health
curl http://YOUR_IP:8082/api/v1/products?page=1&limit=5
```

### Что делает deploy-simple

- ✅ Создает `docker-compose-simple.yml` на сервере
- ✅ Без healthcheck для быстрого запуска
- ✅ Правильные пароли и настройки
- ✅ Автоматическая проверка работы
- ✅ Подробные логи и диагностика

## 🛠️ Troubleshooting

### Проблемы с API

```bash
# Проверка логов
docker-compose logs -f api

# Перезапуск сервиса
docker-compose restart api

# Проверка переменных окружения
docker exec products_api_dev env | grep -E "(REDIS|DB)"
```

### Проблемы с базой данных

```bash
# Исправление PostgreSQL
make fix-postgres ENV=prod SERVER=YOUR_IP USER=root

# Исправление Redis
make fix-redis ENV=prod SERVER=YOUR_IP USER=root

# Полное исправление
make fix-databases ENV=prod SERVER=YOUR_IP USER=root
```

### Проблемы с деплоем

```bash
# Полная очистка и передеплой
make clean-deploy ENV=prod SERVER=YOUR_IP USER=root

# Проверка конфигурации
make check-config
```

## 📊 Мониторинг

### Проверка статуса

```bash
# Статус всех сервисов
docker-compose ps

# Использование ресурсов
docker stats

# Логи в реальном времени
docker-compose logs -f
```

### Health checks

```bash
# API
curl http://localhost:8080/health

# PostgreSQL
docker exec products_postgres_dev pg_isready -U postgres

# Redis
docker exec products_redis_dev redis-cli ping
```

## 🤝 Вклад в проект

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл `LICENSE` для получения дополнительной информации.

## 📞 Поддержка

Если у вас есть вопросы или проблемы:

1. Проверьте документацию в папке `docs/`
2. Посмотрите логи приложения
3. Используйте команды `make fix-*` для исправления проблем
4. Создайте Issue в репозитории

## 🔄 Управление миграциями БД

Для безопасного деплоя изменений в схеме базы данных используйте систему миграций:

```bash
# Создание новой миграции
make migration-create NAME=add_new_column

# Применение миграций
make migrate

# Проверка статуса
make migration-status

# Проверка целостности
make migration-verify
```

**📖 Подробная документация:** [MIGRATION_DEPLOYMENT.md](MIGRATION_DEPLOYMENT.md)

---

**Products API** - мощное и простое решение для управления продуктами интернет-магазина! 🚀 
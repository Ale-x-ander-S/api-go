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
make test-api
```

### Деплой на облачный сервер

```bash
# Полный деплой (первый раз или при проблемах)
make full-deploy ENV=prod SERVER=YOUR_IP USER=root

# Пример
make full-deploy ENV=prod SERVER=45.12.229.112 USER=root

# Быстрое обновление только кода (для ежедневных изменений)
make deploy-code-only ENV=prod SERVER=YOUR_IP USER=root
```

## 🛠️ Основные команды

```bash
# Локальная разработка
make deploy-local          # Запуск локально
make dev                   # Режим разработки с автоперезагрузкой
make swagger-auto         # Генерирование Swagger документации

# Деплой на сервер
make full-deploy           # Полный деплой на сервер
make deploy-code-only      # Быстрое обновление только кода

# Утилиты
make test-api             # Тестирование API
make check-config         # Проверка конфигурации
make tools                # Установка инструментов разработки
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
├── scripts/         # Скрипты деплоя
├── utils/           # Утилиты (JWT, пароли)
├── main.go          # Точка входа
├── Dockerfile       # Docker образ
└── docker-compose.yml # Docker Compose конфигурация
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

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRY_HOURS=24
```

## 🚀 Деплой

### Первый деплой на сервер

```bash
make full-deploy ENV=prod SERVER=45.12.229.112 USER=root
```

**Что происходит:**
- 🐳 Устанавливает Docker и Docker Compose
- 🗄️ Создает PostgreSQL и Redis контейнеры
- 🔐 Генерирует случайные пароли и JWT секреты
- 🚀 Запускает API приложение
- 🔄 Применяет миграции БД

### Обновление кода

```bash
make deploy-code-only ENV=prod SERVER=45.12.229.112 USER=root
```

**Что происходит:**
- 📤 Копирует только измененные файлы кода
- 🔨 Пересобирает только API контейнер
- ✅ Проверяет работоспособность
- ⚡ Время выполнения: ~1-2 минуты

## 🧪 Тестирование

```bash
# Локальное тестирование
make test-api

# Или вручную через Swagger UI
open http://localhost:8080/swagger/index.html
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

## 📍 Endpoints

- **API**: http://localhost:8080/api/v1
- **Swagger**: http://localhost:8080/swagger/index.html
- **Главная**: http://localhost:8080/

## 🆘 Решение проблем

**Ошибка подключения к БД:**
- Проверьте что PostgreSQL запущен
- Проверьте настройки в config.env

**Swagger не работает:**
- Выполните: `make swagger-auto`
- Проверьте что docs/ папка создана

**Проблемы с деплоем:**
- Используйте `make full-deploy` для полного деплоя
- Используйте `make deploy-code-only` для обновления кода
- Проверьте SSH соединение с сервером

## 🤝 Вклад в проект

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. Смотрите файл `LICENSE` для деталей. 
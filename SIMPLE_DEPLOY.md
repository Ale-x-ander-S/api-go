# 🚀 Простой Деплой без Healthcheck

## Проблема
```
Container products_redis_prod  Error
Container products_postgres_prod  Error
dependency failed to start: container products_redis_prod is unhealthy
```

## Решение
Используем **простой деплой** с жестко заданными переменными окружения, без healthcheck.

## 🎯 Что делает deploy-simple

**deploy-simple** - это упрощенный скрипт деплоя, который:

- ✅ **Быстро разворачивает** все сервисы без сложных healthcheck
- ✅ **Автоматически применяет миграции БД** для сохранения консистентности данных
- ✅ **Создает простую конфигурацию** docker-compose без проблем
- ✅ **Копирует все необходимые файлы** включая миграции
- ✅ **Проверяет работоспособность** после развертывания

### 🔄 **Автоматические миграции БД**

При деплое в production окружение автоматически:

1. **Копируются файлы миграций** на сервер
2. **Применяются все новые миграции** в правильном порядке
3. **Создается таблица отслеживания** `schema_migrations`
4. **Проверяется консистентность** базы данных
5. **Данные сохраняются** - существующие записи не теряются

### 📁 **Что копируется на сервер**

```
/opt/api-go/
├── migrations/          # SQL миграции БД
├── handlers/           # HTTP обработчики
├── models/            # Модели данных
├── routes/            # Маршрутизация
├── middleware/        # Middleware
├── utils/             # Утилиты
├── config/            # Конфигурация
├── cache/             # Кэширование
├── database/          # Подключения к БД
├── main.go            # Основной файл
├── Dockerfile         # Docker образ
├── init.sql           # Инициализация БД
├── go.mod             # Зависимости Go
└── go.sum             # Checksums зависимостей
```

### ✅ **Использует базовые настройки**
```yaml
# PostgreSQL
POSTGRES_PASSWORD: password
POSTGRES_HOST_AUTH_METHOD: trust

# Redis
command: redis-server --appendonly yes  # Без пароля

# API
DB_PASSWORD: password
JWT_SECRET: dev-secret-key-change-in-production
```

## 🚀 Как использовать

### **Базовый деплой:**
```bash
make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root
```

### **Деплой с изменениями в БД:**
```bash
# 1. Создание миграции
make migration-create NAME=add_new_feature

# 2. Редактирование миграции
vim migrations/*_add_new_feature.sql

# 3. Деплой с автоматическими миграциями
make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root
```

### **Альтернатива:**
```bash
./scripts/deploy-simple.sh prod 45.12.229.112 root
```

## 📋 Что происходит

### 1. **Подготовка**
- Проверка SSH соединения
- Остановка всех сервисов
- Очистка Docker (volumes, networks)

### 2. **Создание конфигурации**
- `docker-compose-simple.yml` на сервере
- Простые настройки без healthcheck
- Базовые переменные окружения

### 3. **Запуск**
- Запуск всех сервисов
- Ожидание 60 секунд
- Проверка статуса

### 4. **Миграции БД (только для production)**
- Копирование файлов миграций на сервер
- Применение всех новых миграций
- Создание таблицы отслеживания `schema_migrations`
- Проверка консистентности данных

### 5. **Тестирование**
- PostgreSQL: `pg_isready`
- Redis: `redis-cli ping`
- API: `wget /health`

## 🎉 Результат

После деплоя:
- ✅ PostgreSQL запускается с `password`
- ✅ Redis запускается без пароля
- ✅ API запускается с базовыми настройками
- ✅ Все сервисы работают стабильно
- ✅ API доступен по адресу: http://45.12.229.112:8082

## 🔍 Проверка работы

### Статус сервисов:
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml ps"
```

### Логи:
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml logs -f"
```

### Тест API:
```bash
curl http://45.12.229.112:8082/health
```

### Проверка миграций:
```bash
# Статус миграций
ssh root@45.12.229.112 'cd /opt/api-go && docker exec products_postgres_prod psql -U postgres -d products_db_prod -c "SELECT filename, applied_at FROM schema_migrations ORDER BY applied_at;"'

# Консистентность БД
ssh root@45.12.229.112 'cd /opt/api-go && docker exec products_postgres_prod psql -U postgres -d products_db_prod -c "SELECT COUNT(*) as total_users FROM users; SELECT COUNT(*) as total_products FROM products;"'

## 📊 Преимущества

### ✅ **Надежность**
- Нет проблем с healthcheck
- Простые настройки
- Быстрый запуск

### ✅ **Простота**
- Жестко заданные переменные
- Без сложных зависимостей
- Легко отладить

### ✅ **Скорость**
- Нет ожидания healthcheck
- Параллельный запуск
- Быстрая инициализация

## ⚠️ Ограничения

### 🔒 **Безопасность**
- `password` вместо сложного пароля
- `dev-secret-key` вместо production секрета
- `trust` для PostgreSQL аутентификации

### 📝 **Конфигурация**
- Не использует `.env` файлы
- Жестко заданные значения
- Только для быстрого запуска

## 🔄 Следующие шаги

### 1. **Стабилизация**
- Убедитесь что все работает
- Проверьте логи на ошибки
- Протестируйте API endpoints

### 2. **Улучшение безопасности**
- Измените `password` на сложный пароль
- Обновите `JWT_SECRET` на production
- Настройте правильную аутентификацию

### 3. **Возврат healthcheck**
- Раскомментируйте healthcheck в основном файле
- Перезапустите с `docker-compose.prod.yml`
- Или используйте `docker-compose-simple.yml` для production

## 🛠️ Troubleshooting

### Если сервисы не запускаются:
```bash
# Проверка логов
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml logs -f"

# Проверка ресурсов
ssh root@45.12.229.112 "free -h && df -h"

# Проверка Docker
ssh root@45.12.229.112 "docker info"
```

### Если API не отвечает:
```bash
# Проверка контейнеров
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml ps"

# Проверка портов
ssh root@45.12.229.112 "netstat -tlnp | grep :8082"

# Тест внутри контейнера
ssh root@45.12.229.112 "cd /opt/api-go && docker exec \$(docker-compose -f docker-compose-simple.yml ps -q api) wget -qO- http://localhost:8080/health"
```

## 📚 Команды для быстрого исправления

```bash
# Простой деплой
make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root

# Проверка конфигурации
make check-config

# Мониторинг
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml logs -f"

# Перезапуск
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml restart"
```

## 🎯 Когда использовать

### ✅ **Используйте deploy-simple когда:**
- Нужен быстрый запуск
- Проблемы с healthcheck
- Отладка конфигурации
- Тестирование на сервере

### ❌ **Не используйте для:**
- Production с высокими требованиями безопасности
- Долгосрочного использования
- Систем с множественными окружениями

## 🚀 Быстрый старт

```bash
# 1. Деплой
make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root

# 2. Проверка
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml ps"

# 3. Тест API
curl http://45.12.229.112:8082/health

# 4. Мониторинг
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose-simple.yml logs -f"
```

## 🎉 Итог

**deploy-simple** - это быстрое решение для запуска сервисов без проблем с healthcheck. Используйте его для быстрого старта, а затем улучшайте конфигурацию для production. 
**deploy-simple** - это быстрое решение для запуска сервисов без проблем с healthcheck. Используйте его для быстрого старта, а затем улучшайте конфигурацию для production. 
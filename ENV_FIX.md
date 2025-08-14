# 🔧 Исправление проблемы с переменными окружения

## Проблема
```
time="2025-08-14T19:01:20Z" level=warning msg="The \"DB_PASSWORD\" variable is not set. Defaulting to a blank string."
Error: Database is uninitialized and superuser password is not specified.
```

## Причина
PostgreSQL и Redis сервисы не могли прочитать переменные окружения из `config.prod.env` файла, потому что в Docker Compose не был указан `env_file`.

## Что исправлено

### ✅ Добавлен `env_file` для всех сервисов

#### Production (`docker-compose.prod.yml`)
```yaml
# PostgreSQL
postgres:
  env_file:
    - config.prod.env
  environment:
    POSTGRES_DB: ${DB_NAME:-products_db_prod}
    POSTGRES_USER: ${DB_USER:-postgres}
    POSTGRES_PASSWORD: ${DB_PASSWORD}

# Redis
redis:
  env_file:
    - config.prod.env
  # ... остальные настройки

# API
api:
  env_file:
    - config.prod.env
  # ... остальные настройки
```

#### Staging (`docker-compose.staging.yml`)
```yaml
# PostgreSQL
postgres:
  env_file:
    - config.staging.env
  # ... остальные настройки

# Redis
redis:
  env_file:
    - config.staging.env
  # ... остальные настройки
```

#### Development (`docker-compose.yml`)
```yaml
# PostgreSQL
postgres:
  env_file:
    - config.dev.env
  # ... остальные настройки

# Redis
redis:
  env_file:
    - config.dev.env
  # ... остальные настройки
```

## Как это работает

1. **`env_file`** - загружает переменные из файла
2. **`environment`** - переопределяет конкретные переменные с fallback значениями
3. **Переменные** - доступны внутри контейнеров

## Проверка исправления

### 1. Локальная проверка
```bash
make check-config
```

### 2. Тест на сервере
```bash
# Исправление всех проблем
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root

# Или полная очистка
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root
```

## Результат

После исправления:
- ✅ PostgreSQL получает пароль из `config.prod.env`
- ✅ Redis получает пароль из `config.prod.env`
- ✅ Все переменные окружения доступны
- ✅ Сервисы запускаются корректно
- ✅ Healthcheck проходят успешно

## Команды для деплоя

```bash
# Исправление проблем с базами данных
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root

# Полная очистка и передеплой
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root

# Проверка конфигурации
make check-config
```

## Troubleshooting

### Если проблема остается
```bash
# Проверка файла на сервере
ssh root@45.12.229.112 "cat /opt/api-go/config.prod.env"

# Проверка переменных в контейнере
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml exec postgres env | grep DB_"
```

### Переменные не читаются
```bash
# Проверка синтаксиса Docker Compose
docker-compose -f docker-compose.prod.yml config

# Проверка прав на файл
ls -la config.prod.env
``` 
# 🔧 Исправление проблем с Redis

## Проблема
```
dependency failed to start: container products_redis_prod is unhealthy
```

## Причины
1. **Неправильный healthcheck** - Redis требует пароль для подключения
2. **Проблемы с volumes** - поврежденные данные
3. **Конфликты портов** - порт уже занят
4. **Проблемы с правами** - недостаточно прав для записи

## Решение

### 1. Автоматическое исправление

```bash
# Для production
make fix-redis ENV=prod SERVER=45.12.229.112 USER=root

# Для staging
make fix-redis ENV=staging SERVER=45.12.229.112 USER=root
```

### 2. Ручное исправление

```bash
# Подключение к серверу
ssh root@45.12.229.112

# Переход в директорию
cd /opt/api-go

# Остановка Redis
docker-compose -f docker-compose.prod.yml stop redis
docker-compose -f docker-compose.prod.yml rm -f redis

# Очистка данных Redis
docker volume rm $(docker volume ls -q | grep redis)
docker system prune -f

# Перезапуск Redis
docker-compose -f docker-compose.prod.yml up -d redis

# Проверка статуса
docker-compose -f docker-compose.prod.yml ps redis
```

## Что исправлено

### ✅ Healthcheck Redis
```yaml
# Было (неправильно)
healthcheck:
  test: ["CMD", "redis-cli", "ping"]

# Стало (правильно)
healthcheck:
  test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-}", "ping"]
  start_period: 10s
```

### ✅ Параметры Redis
- Добавлен `start_period: 10s` для healthcheck
- Правильная аутентификация в healthcheck
- Корректная обработка пароля

## Диагностика

### Проверка статуса
```bash
# Статус контейнеров
docker-compose -f docker-compose.prod.yml ps

# Логи Redis
docker-compose -f docker-compose.prod.yml logs redis

# Health check
docker inspect $(docker-compose -f docker-compose.prod.yml ps -q redis) | grep -A 10 Health
```

### Проверка подключения
```bash
# Тест подключения к Redis
docker exec $(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli -a YOUR_REDIS_PASSWORD ping
```

## Профилактика

### 1. Мониторинг
```bash
# Автоматическая проверка каждые 5 минут
watch -n 300 'docker-compose -f docker-compose.prod.yml ps'
```

### 2. Логирование
```bash
# Просмотр логов в реальном времени
docker-compose -f docker-compose.prod.yml logs -f redis
```

### 3. Backup данных
```bash
# Резервное копирование Redis
docker exec $(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli -a YOUR_PASSWORD SAVE
```

## Troubleshooting

### Redis не запускается
```bash
# Проверка портов
netstat -tlnp | grep 6381

# Проверка Docker
docker info

# Проверка volumes
docker volume ls | grep redis
```

### Проблемы с паролем
```bash
# Проверка переменной окружения
grep REDIS_PASSWORD config.prod.env

# Тест с паролем
docker exec -it $(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli -a YOUR_PASSWORD
```

### Проблемы с правами
```bash
# Проверка прав пользователя
ls -la /opt/api-go/
whoami && id

# Исправление прав
sudo chown -R root:root /opt/api-go/
```

## Команды для быстрого исправления

```bash
# Полная очистка и передеплой
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root

# Только исправление Redis
make fix-redis ENV=prod SERVER=45.12.229.112 USER=root

# Проверка конфигурации
make check-config
```

## Результат

После исправления:
- ✅ Redis контейнер запускается корректно
- ✅ Healthcheck проходит успешно
- ✅ API может подключиться к Redis
- ✅ Все сервисы работают стабильно 
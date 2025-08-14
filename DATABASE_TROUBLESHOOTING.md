# 🔧 Исправление проблем с базами данных

## Проблемы

### 1. PostgreSQL
```
dependency failed to start: container products_postgres_prod is unhealthy
```

### 2. Redis
```
dependency failed to start: container products_redis_prod is unhealthy
```

## Причины

1. **Неправильные healthcheck** - не учитывают аутентификацию
2. **Проблемы с volumes** - поврежденные данные
3. **Конфликты портов** - порты уже заняты
4. **Проблемы с правами** - недостаточно прав для записи
5. **Недостаточно ресурсов** - мало памяти/диска

## Решения

### 1. Автоматическое исправление всех проблем

```bash
# Универсальное исправление
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root
```

### 2. Исправление конкретных проблем

```bash
# Только PostgreSQL
make fix-postgres ENV=prod SERVER=45.12.229.112 USER=root

# Только Redis
make fix-redis ENV=prod SERVER=45.12.229.112 USER=root
```

### 3. Полная очистка и передеплой

```bash
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root
```

## Что исправлено

### ✅ PostgreSQL Healthcheck
```yaml
# Было (неправильно)
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres} -d ${DB_NAME:-products_db_prod}"]

# Стало (правильно)
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -d products_db_prod"]
  start_period: 30s
```

### ✅ Redis Healthcheck
```yaml
# Было (неправильно)
healthcheck:
  test: ["CMD", "redis-cli", "ping"]

# Стало (правильно)
healthcheck:
  test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-}", "ping"]
  start_period: 10s
```

## Скрипты исправления

### 1. `fix-databases.sh` - Универсальный
- Полная диагностика системы
- Очистка Docker
- Исправление прав доступа
- Перезапуск всех сервисов
- Тестирование подключений

### 2. `fix-postgres.sh` - PostgreSQL
- Диагностика PostgreSQL
- Очистка данных
- Перезапуск контейнера
- Тест подключения

### 3. `fix-redis.sh` - Redis
- Диагностика Redis
- Очистка данных
- Перезапуск контейнера
- Тест подключения

## Ручное исправление

### PostgreSQL
```bash
ssh root@45.12.229.112
cd /opt/api-go

# Остановка
docker-compose -f docker-compose.prod.yml stop postgres
docker-compose -f docker-compose.prod.yml rm -f postgres

# Очистка
docker volume rm $(docker volume ls -q | grep postgres)
docker system prune -f

# Перезапуск
docker-compose -f docker-compose.prod.yml up -d postgres

# Проверка
docker-compose -f docker-compose.prod.yml ps postgres
```

### Redis
```bash
ssh root@45.12.229.112
cd /opt/api-go

# Остановка
docker-compose -f docker-compose.prod.yml stop redis
docker-compose -f docker-compose.prod.yml rm -f redis

# Очистка
docker volume rm $(docker volume ls -q | grep redis)
docker system prune -f

# Перезапуск
docker-compose -f docker-compose.prod.yml up -d redis

# Проверка
docker-compose -f docker-compose.prod.yml ps redis
```

## Диагностика

### Проверка статуса
```bash
# Статус всех сервисов
docker-compose -f docker-compose.prod.yml ps

# Логи конкретного сервиса
docker-compose -f docker-compose.prod.yml logs postgres
docker-compose -f docker-compose.prod.yml logs redis
```

### Проверка подключений
```bash
# PostgreSQL
docker exec $(docker-compose -f docker-compose.prod.yml ps -q postgres) pg_isready -U postgres

# Redis
docker exec $(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli -a YOUR_PASSWORD ping

# API
docker exec $(docker-compose -f docker-compose.prod.yml ps -q api) wget --no-verbose --tries=1 --spider http://localhost:8080/health
```

### Системная диагностика
```bash
# Дисковое пространство
df -h

# Память
free -h

# Сетевые порты
netstat -tlnp | grep -E '(543|637|808)'

# Docker info
docker info
```

## Профилактика

### 1. Мониторинг ресурсов
```bash
# Автоматическая проверка каждые 5 минут
watch -n 300 'df -h && free -h && docker stats --no-stream'
```

### 2. Логирование
```bash
# Логи всех сервисов
docker-compose -f docker-compose.prod.yml logs -f

# Логи конкретного сервиса
docker-compose -f docker-compose.prod.yml logs -f postgres
```

### 3. Backup данных
```bash
# PostgreSQL
docker exec $(docker-compose -f docker-compose.prod.yml ps -q postgres) pg_dump -U postgres products_db_prod > backup.sql

# Redis
docker exec $(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli --rdb /data/dump.rdb
```

## Troubleshooting

### Сервис не запускается
```bash
# Проверка логов
docker-compose -f docker-compose.prod.yml logs SERVICE_NAME

# Проверка статуса
docker-compose -f docker-compose.prod.yml ps SERVICE_NAME

# Проверка конфигурации
docker-compose -f docker-compose.prod.yml config
```

### Health check не проходит
```bash
# Проверка health check
docker inspect $(docker-compose -f docker-compose.prod.yml ps -q SERVICE_NAME) | grep -A 10 Health

# Ручной тест
docker exec CONTAINER_ID COMMAND
```

### Проблемы с правами
```bash
# Проверка прав
ls -la /opt/api-go/
whoami && id

# Исправление прав
sudo chown -R root:root /opt/api-go/
sudo chmod -R 755 /opt/api-go/
```

## Команды для быстрого исправления

```bash
# Универсальное исправление (рекомендуется)
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root

# Конкретные проблемы
make fix-postgres ENV=prod SERVER=45.12.229.112 USER=root
make fix-redis ENV=prod SERVER=45.12.229.112 USER=root

# Полная очистка
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root

# Проверка конфигурации
make check-config
```

## Результат

После исправления:
- ✅ PostgreSQL контейнер запускается корректно
- ✅ Redis контейнер запускается корректно
- ✅ Все healthcheck проходят успешно
- ✅ API может подключиться к базам данных
- ✅ Все сервисы работают стабильно 
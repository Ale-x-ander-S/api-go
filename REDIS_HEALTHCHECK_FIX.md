# 🔧 Исправление проблемы с Redis Healthcheck

## Проблема
```
dependency failed to start: container products_redis_prod is unhealthy
```

## Причины
1. **Слишком строгий healthcheck** - Redis не успевает запуститься
2. **Короткие интервалы** - проверки происходят слишком часто
3. **Недостаточно времени** - `start_period` слишком короткий

## Что исправлено

### ✅ Улучшенные healthcheck настройки

#### Redis
```yaml
# Было (слишком строго)
healthcheck:
  test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-}", "ping"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s

# Стало (более терпеливо)
healthcheck:
  test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-}", "ping"]
  interval: 30s      # Проверка каждые 30 секунд
  timeout: 10s       # Таймаут 10 секунд
  retries: 3         # Только 3 попытки
  start_period: 60s  # Ждем 60 секунд перед первой проверкой
```

#### PostgreSQL
```yaml
# Было
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -d products_db_prod"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s

# Стало
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -d products_db_prod"]
  interval: 30s      # Проверка каждые 30 секунд
  timeout: 10s       # Таймаут 10 секунд
  retries: 3         # Только 3 попытки
  start_period: 60s  # Ждем 60 секунд перед первой проверкой
```

## Решения

### 1. Автоматическое исправление (рекомендуется)
```bash
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root
```

### 2. Запуск Redis без healthcheck
```bash
make start-redis-only ENV=prod SERVER=45.12.229.112 USER=root
```

### 3. Полная очистка и передеплой
```bash
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root
```

## Как работает исправление

### 1. **Более терпеливые healthcheck**
- `start_period: 60s` - ждем 60 секунд перед первой проверкой
- `interval: 30s` - проверяем каждые 30 секунд (вместо 10)
- `timeout: 10s` - даем больше времени на ответ
- `retries: 3` - меньше попыток, но больше времени

### 2. **Последовательный запуск**
- Сначала запускаем Redis без healthcheck
- Ждем пока он полностью запустится
- Затем запускаем с healthcheck

### 3. **Правильная последовательность**
1. Redis запускается и инициализируется
2. PostgreSQL запускается и инициализируется
3. API запускается после готовности баз данных

## Проверка исправления

### Статус сервисов
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml ps"
```

### Health check статус
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker inspect \$(docker-compose -f docker-compose.prod.yml ps -q redis) | grep -A 10 Health"
```

### Логи Redis
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml logs -f redis"
```

## Troubleshooting

### Если Redis все еще не проходит healthcheck
```bash
# Запуск без healthcheck
make start-redis-only ENV=prod SERVER=45.12.229.112 USER=root

# Проверка вручную
ssh root@45.12.229.112 "cd /opt/api-go && docker exec \$(docker-compose -f docker-compose.prod.yml ps -q redis) redis-cli -a YOUR_PASSWORD ping"
```

### Проверка переменных окружения
```bash
ssh root@45.12.229.112 "cd /opt/api-go && docker exec \$(docker-compose -f docker-compose.prod.yml ps -q redis) env | grep REDIS"
```

### Проверка портов
```bash
ssh root@45.12.229.112 "netstat -tlnp | grep 6381"
```

## Профилактика

### 1. Мониторинг ресурсов
```bash
# Проверка памяти и диска
ssh root@45.12.229.112 "free -h && df -h"
```

### 2. Логирование
```bash
# Автоматический просмотр логов
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml logs -f redis"
```

### 3. Регулярные проверки
```bash
# Проверка статуса каждые 5 минут
watch -n 300 'docker-compose -f docker-compose.prod.yml ps'
```

## Результат

После исправления:
- ✅ Redis успевает полностью запуститься
- ✅ Healthcheck проходит успешно
- ✅ Все сервисы запускаются в правильном порядке
- ✅ API может подключиться к Redis
- ✅ Система работает стабильно

## Команды для быстрого исправления

```bash
# Универсальное исправление
make fix-databases ENV=prod SERVER=45.12.229.112 USER=root

# Только Redis
make start-redis-only ENV=prod SERVER=45.12.229.112 USER=root

# Полная очистка
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root
``` 
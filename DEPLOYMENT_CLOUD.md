# 🚀 Деплой на облачный сервер

## Быстрый старт

### 1. Подготовка production конфигурации

```bash
# Генерация безопасных паролей и ключей
./scripts/generate-prod-config.sh
```

Это создаст:
- `config.prod.env` - production конфигурация с безопасными паролями
- `.env` - переменные для docker-compose

### 2. Деплой на сервер

```bash
# Деплой staging
./scripts/deploy-cloud.sh staging YOUR_SERVER_IP

# Деплой production
./scripts/deploy-cloud.sh prod YOUR_SERVER_IP
```

## Структура конфигурации

### Development (локально)
- `config.dev.env` - настройки для разработки
- `docker-compose.yml` - локальный запуск

### Staging
- `config.staging.env` - настройки для тестирования
- `docker-compose.staging.yml` - staging окружение
- Порт: 8081

### Production
- `config.prod.env` - production настройки
- `docker-compose.prod.yml` - production окружение
- Порт: 8082
- Nginx: порты 80/443

## Требования к серверу

- Docker и Docker Compose
- SSH доступ
- Минимум 2GB RAM
- 20GB свободного места

## Безопасность

### Production
- SSL/TLS обязателен
- Сильные пароли для БД и Redis
- JWT секрет минимум 50 символов
- Firewall настроен
- Регулярные обновления

### Переменные окружения
```bash
# Обязательные для production
DB_PASSWORD=strong_password_here
REDIS_PASSWORD=strong_redis_password
JWT_SECRET=very_long_random_string_here

# Опциональные
DB_SSL_MODE=require
LOG_LEVEL=warn
```

## Мониторинг

### Проверка статуса
```bash
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml ps"
```

### Логи
```bash
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml logs -f api"
```

### Health check
```bash
curl http://YOUR_SERVER_IP:8082/health
```

## Troubleshooting

### Проблемы с подключением к БД
- Проверьте пароли в `config.prod.env`
- Убедитесь что PostgreSQL запущен
- Проверьте сетевые настройки

### Redis не подключается
- Проверьте пароль Redis
- Убедитесь что Redis запущен
- Проверьте порты

### API не отвечает
- Проверьте логи: `docker-compose logs api`
- Убедитесь что все сервисы запущены
- Проверьте порты и firewall

## Обновление

```bash
# Остановка
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml down"

# Обновление кода
scp -r . user@server:~/api-go/

# Запуск
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml up -d"
```

## Backup

### База данных
```bash
ssh user@server "docker exec products_postgres_prod pg_dump -U postgres products_db_prod > backup.sql"
scp user@server:~/api-go/backup.sql ./
```

### Redis
```bash
ssh user@server "docker exec products_redis_prod redis-cli --rdb /data/dump.rdb"
scp user@server:~/api-go/dump.rdb ./
``` 
# 🚀 Развертывание Products API

## 📋 Обзор

Полная система развертывания для Products API с поддержкой множественных окружений, CI/CD и автоматизации.

## 🏗️ Архитектура развертывания

### Окружения

- **🔧 Development** - локальная разработка
- **🚀 Staging** - тестирование перед продакшеном  
- **🏭 Production** - продакшен окружение

### Компоненты

- **PostgreSQL** - основная база данных
- **Redis** - кэширование
- **API** - Go приложение
- **Nginx** - reverse proxy (production)

## 🚀 Быстрый старт

### 1. Первое развертывание

```bash
# Развертывание в development окружении
make deploy

# Или через скрипт
./deploy.sh dev
```

### 2. Развертывание во всех окружениях

```bash
# Развертывание во всех окружениях
make deploy-all

# Или по отдельности
make deploy-staging
make deploy-prod
```

## 🔧 Команды развертывания

### Основные команды

```bash
# Development
make deploy              # Развертывание в dev
./deploy.sh dev         # Через скрипт

# Staging  
make deploy-staging     # Развертывание в staging
./deploy.sh staging     # Через скрипт

# Production
make deploy-prod        # Развертывание в production
./deploy.sh prod        # Через скрипт

# Все окружения
make deploy-all         # Развертывание везде
```

### CI/CD команды

```bash
# Полный CI/CD процесс
make ci-cd              # Development
make ci-cd-staging      # Staging
make ci-cd-prod         # Production

# Или через скрипт
./scripts/ci-cd.sh dev main
./scripts/ci-cd.sh staging main
./scripts/ci-cd.sh prod main
```

## 📊 Управление окружениями

### Мониторинг

```bash
# Статус всех окружений
make env-status

# Мониторинг сервисов
make monitor

# Логи всех окружений
make env-logs
```

### Управление

```bash
# Остановка всех окружений
make env-stop

# Диагностика системы
make diagnose
```

## 🔄 Процесс развертывания

### Development

1. **Проверка зависимостей** - Go, Docker, Redis
2. **Сборка приложения** - `go build`
3. **Генерация Swagger** - автоматически
4. **Запуск локально** - `go run main.go`
5. **Проверка работоспособности**

### Staging/Production

1. **Проверка зависимостей**
2. **Сборка приложения**
3. **Сборка Docker образа**
4. **Развертывание через Docker Compose**
5. **Проверка health checks**
6. **Валидация endpoints**

## 📁 Конфигурационные файлы

### Development
- `config.env` - основная конфигурация
- `docker-compose.yml` - локальные сервисы

### Staging
- `config.staging.env` - staging конфигурация
- `docker-compose.staging.yml` - staging сервисы

### Production
- `config.prod.env` - production конфигурация
- `docker-compose.prod.yml` - production сервисы

## 🔐 Переменные окружения

### Обязательные

```env
# База данных
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=products_db

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# JWT
JWT_SECRET=your-secret-key

# Сервер
SERVER_PORT=8080
```

### Опциональные

```env
# Окружение
ENVIRONMENT=development
LOG_LEVEL=debug

# SSL
DB_SSL_MODE=disable
REDIS_TTL=3600
```

## 🐳 Docker развертывание

### Сборка образа

```bash
# Сборка с тегом версии
docker build -t products-api:latest .

# Сборка для конкретной версии
docker build -t products-api:v1.0.0 .
```

### Запуск контейнеров

```bash
# Development
docker-compose up -d

# Staging
docker-compose -f docker-compose.staging.yml up -d

# Production
docker-compose -f docker-compose.prod.yml up -d
```

## 🔄 Обновление приложения

### Автоматическое обновление

```bash
# Обновление из Git
make update

# Обновление зависимостей
make update-deps

# Перезапуск с новым кодом
make deploy
```

### Ручное обновление

```bash
# Остановка
make env-stop

# Обновление кода
git pull origin main

# Пересборка и развертывание
make deploy
```

## 🚨 Откат изменений

### Автоматический откат

Скрипт развертывания автоматически выполняет откат при ошибках:

```bash
# При ошибке развертывания автоматически:
# 1. Останавливает новые контейнеры
# 2. Возвращает предыдущую версию
# 3. Логирует ошибку
```

### Ручной откат

```bash
# Остановка текущего развертывания
make env-stop

# Возврат к предыдущей версии
git checkout HEAD~1

# Развертывание предыдущей версии
make deploy
```

## 📊 Мониторинг и логи

### Логи приложения

```bash
# Development
tail -f app.log

# Staging
docker-compose -f docker-compose.staging.yml logs -f api

# Production
docker-compose -f docker-compose.prod.yml logs -f api
```

### Health checks

```bash
# Проверка API
curl http://localhost:8080/

# Проверка Swagger
curl http://localhost:8080/swagger/index.html

# Проверка продуктов
curl http://localhost:8080/api/v1/products
```

## 🔒 Безопасность

### Production рекомендации

1. **Сильные пароли** для всех сервисов
2. **SSL/TLS** сертификаты
3. **Firewall** правила
4. **Регулярные обновления** зависимостей
5. **Мониторинг** безопасности

### Переменные безопасности

```env
# Никогда не коммитьте в Git!
JWT_SECRET=very-long-random-string-here
DB_PASSWORD=very-strong-password
REDIS_PASSWORD=strong-redis-password
```

## 🚀 CI/CD Pipeline

### Этапы

1. **Git проверка** - статус репозитория
2. **Тестирование** - `make test`
3. **Качество кода** - `make lint`
4. **Создание тега** - версионирование
5. **Развертывание** - автоматическое
6. **Уведомления** - статус развертывания
7. **Очистка** - временные файлы

### Автоматизация

```bash
# Git hooks для автоматического развертывания
.git/hooks/pre-commit    # Проверка перед коммитом
.git/hooks/post-commit   # Автоматическое развертывание
```

## 📈 Масштабирование

### Горизонтальное масштабирование

```yaml
# docker-compose.prod.yml
api:
  deploy:
    replicas: 3
    resources:
      limits:
        memory: 512M
        cpus: '0.5'
```

### Load Balancer

```yaml
# nginx/nginx.conf
upstream api_servers {
    server api:8080;
    server api2:8080;
    server api3:8080;
}
```

## 🆘 Troubleshooting

### Частые проблемы

1. **Порт занят**
   ```bash
   lsof -i :8080 | xargs kill -9
   ```

2. **Docker не запущен**
   ```bash
   open -a Docker
   ```

3. **База данных недоступна**
   ```bash
   docker-compose up -d postgres
   ```

4. **Redis недоступен**
   ```bash
   make redis-start
   ```

### Диагностика

```bash
# Полная диагностика
make diagnose

# Проверка зависимостей
make check

# Статус сервисов
make env-status
```

## 📚 Дополнительные ресурсы

- **Makefile** - все команды развертывания
- **deploy.sh** - основной скрипт развертывания
- **scripts/ci-cd.sh** - CI/CD автоматизация
- **docker-compose.*.yml** - конфигурации окружений

## 🎯 Лучшие практики

1. **Всегда тестируйте** в staging перед production
2. **Используйте версионирование** для всех развертываний
3. **Мониторьте логи** после развертывания
4. **Автоматизируйте** повторяющиеся задачи
5. **Документируйте** изменения конфигурации

---

🚀 **Готово к развертыванию!** Используйте `make deploy` для быстрого старта. 
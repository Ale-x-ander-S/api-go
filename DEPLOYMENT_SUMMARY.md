# 📋 Сводка по настройке деплоя

## ✅ Что исправлено

### 1. Структура конфигурации
- **Development**: `config.dev.env` - для локальной разработки
- **Staging**: `config.staging.env` - для тестирования
- **Production**: `config.prod.env` - для продакшена

### 2. Docker Compose файлы
- **Development**: `docker-compose.yml` - локальный запуск
- **Staging**: `docker-compose.staging.yml` - staging окружение
- **Production**: `docker-compose.prod.yml` - production с nginx

### 3. Безопасность
- Автоматическая генерация сильных паролей
- Отдельные JWT ключи для каждого окружения
- SSL/TLS настройки для production
- Безопасные настройки Redis

## 🚀 Команды для деплоя

### Локально
```bash
make deploy-local
```

### На облачный сервер
```bash
# Staging
make deploy-cloud ENV=staging SERVER=YOUR_IP

# Production  
make deploy-cloud ENV=prod SERVER=YOUR_IP
```

### Подготовка production
```bash
make generate-prod-config
```

### Проверка конфигурации
```bash
make check-config
```

## 🔧 Структура портов

| Окружение | API | PostgreSQL | Redis | Nginx |
|-----------|-----|------------|-------|-------|
| Development | 8080 | 5432 | 6379 | - |
| Staging | 8081 | 5433 | 6380 | - |
| Production | 8082 | 5434 | 6381 | 80/443 |

## 📁 Файлы конфигурации

```
├── config.dev.env          # Development настройки
├── config.staging.env      # Staging настройки  
├── config.prod.env         # Production настройки
├── .env                    # Переменные для docker-compose
├── docker-compose.yml      # Development
├── docker-compose.staging.yml  # Staging
├── docker-compose.prod.yml     # Production
└── scripts/
    ├── generate-prod-config.sh # Генерация production конфигурации
    ├── deploy-cloud.sh         # Деплой на облачный сервер
    └── check-config.sh         # Проверка конфигурации
```

## 🔐 Безопасность

### Production требования
- JWT_SECRET минимум 50 символов
- Сильные пароли для БД и Redis
- SSL/TLS включен
- Firewall настроен
- Регулярные обновления

### Автоматическая генерация
```bash
./scripts/generate-prod-config.sh
```
Создает:
- Безопасные пароли
- Сильные JWT ключи
- Production конфигурацию
- .env файл для docker-compose

## 🌐 Деплой на сервер

### Требования к серверу
- Docker + Docker Compose
- SSH доступ
- 2GB+ RAM
- 20GB+ места

### Процесс деплоя
1. Генерация production конфигурации
2. Копирование файлов на сервер
3. Сборка и запуск контейнеров
4. Проверка статуса
5. Мониторинг логов

## 📊 Мониторинг

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

## 🆘 Troubleshooting

### Частые проблемы
1. **Пароли не совпадают** - используй `make generate-prod-config`
2. **Порты заняты** - проверь `make check-config`
3. **SSL ошибки** - настрой сертификаты для production
4. **Подключение к БД** - проверь пароли и сеть

### Полезные команды
```bash
# Полная диагностика
make check-config

# Пересборка на сервере
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml down && docker-compose -f docker-compose.prod.yml up -d --build"

# Проверка логов
docker-compose -f docker-compose.prod.yml logs -f
```

## 🎯 Следующие шаги

1. **Настрой SSL сертификаты** для production
2. **Настрой мониторинг** (Prometheus, Grafana)
3. **Настрой backup** базы данных
4. **Настрой CI/CD** pipeline
5. **Добавь health checks** для всех сервисов

## 📞 Поддержка

- **Документация**: `DEPLOYMENT_CLOUD.md`
- **Быстрый старт**: `QUICK_DEPLOY.md`
- **Примеры**: `examples.md`
- **Использование**: `USAGE.md` 
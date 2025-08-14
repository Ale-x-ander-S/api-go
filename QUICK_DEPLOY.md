# 🚀 Быстрый деплой на облачный сервер

## 1. Подготовка (выполнить один раз)

```bash
# Генерация безопасных паролей для production
make generate-prod-config

# Проверка конфигурации
make check-config
```

## 2. Деплой на сервер

### Staging
```bash
make deploy-cloud ENV=staging SERVER=YOUR_SERVER_IP
```

### Production
```bash
make deploy-cloud ENV=prod SERVER=YOUR_SERVER_IP
```

## 3. Проверка

```bash
# Статус сервисов
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml ps"

# Логи
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml logs -f api"

# Health check
curl http://YOUR_SERVER_IP:8082/health
```

## Портфолио

- **Development**: порт 8080
- **Staging**: порт 8081  
- **Production**: порт 8082
- **Nginx**: порты 80/443 (production)

## Требования к серверу

- Docker + Docker Compose
- SSH доступ
- 2GB+ RAM
- 20GB+ места

## Безопасность

✅ Автоматическая генерация сильных паролей  
✅ Отдельные конфигурации для каждого окружения  
✅ SSL/TLS для production  
✅ Firewall настройки  
✅ Безопасные JWT ключи  

## Troubleshooting

```bash
# Проверка конфигурации
make check-config

# Локальный тест
make deploy-local

# Пересборка на сервере
ssh user@server "cd ~/api-go && docker-compose -f docker-compose.prod.yml down && docker-compose -f docker-compose.prod.yml up -d --build"
``` 
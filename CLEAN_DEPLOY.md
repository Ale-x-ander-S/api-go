# 🧹 Полная очистка и передеплой на сервер

## Проблема
Неудачный деплой в папку `/opt/api-go` на сервере Selectel. Нужно полностью очистить и сделать новый деплой.

## Решение

### 1. Автоматическая очистка и передеплой

```bash
# Для production
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root

# Для staging
make clean-deploy ENV=staging SERVER=45.12.229.112 USER=root
```

### 2. Ручная очистка (если нужно)

```bash
# Подключение к серверу
ssh root@45.12.229.112

# Остановка всех контейнеров
cd /opt/api-go
docker-compose down --remove-orphans --volumes
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Удаление образов
docker rmi $(docker images -q)
docker system prune -af --volumes

# Очистка директории
sudo rm -rf /opt/api-go
sudo mkdir -p /opt/api-go
sudo chown root:root /opt/api-go
```

## Что делает скрипт clean-deploy.sh

### 🛑 Остановка и очистка
- Останавливает все Docker контейнеры
- Удаляет все образы и volumes
- Полностью очищает директорию `/opt/api-go`

### 📁 Копирование файлов
- Docker Compose конфигурации
- Конфигурационные файлы
- Исходный код Go
- Nginx настройки

### 🔧 Установка зависимостей
- Проверяет/устанавливает Go
- Собирает Docker образы
- Запускает все сервисы

### ✅ Проверка
- Статус сервисов
- Доступность API
- Логи приложения

## Использование

### Простой запуск
```bash
make clean-deploy ENV=prod SERVER=45.12.229.112
```

### С указанием пользователя
```bash
make clean-deploy ENV=prod SERVER=45.12.229.112 USER=ubuntu
```

### Прямой вызов скрипта
```bash
./scripts/clean-deploy.sh prod 45.12.229.112 root
```

## Параметры

- **ENV**: `staging` или `prod`
- **SERVER**: IP адрес сервера (45.12.229.112)
- **USER**: SSH пользователь (по умолчанию root)

## Результат

После выполнения:
- ✅ Сервер полностью очищен
- ✅ Новый код развернут
- ✅ Все сервисы запущены
- ✅ API доступен по адресу: http://45.12.229.112:8082

## Мониторинг

```bash
# Статус сервисов
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml ps"

# Логи
ssh root@45.12.229.112 "cd /opt/api-go && docker-compose -f docker-compose.prod.yml logs -f api"

# Health check
curl http://45.12.229.112:8082/health
```

## ⚠️ Внимание

- Скрипт **полностью удаляет** все данные в `/opt/api-go`
- Останавливает **все** Docker контейнеры на сервере
- Удаляет **все** Docker образы
- Требует **sudo** права для очистки директории

## Troubleshooting

### Ошибка SSH
```bash
# Проверка ключей
ssh-add -l

# Тест подключения
ssh -v root@45.12.229.112
```

### Ошибка Docker
```bash
# Проверка Docker на сервере
ssh root@45.12.229.112 "docker --version"
ssh root@45.12.229.112 "docker-compose --version"
```

### Проблемы с правами
```bash
# Проверка прав пользователя
ssh root@45.12.229.112 "whoami && id"
``` 
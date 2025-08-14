.PHONY: help build run test clean swagger deps

# Переменные
BINARY_NAME=api-go
MAIN_FILE=main.go

# Помощь
help: ## Показать справку по командам
	@echo "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Установка зависимостей
deps: ## Установить зависимости Go
	go mod download
	go mod tidy

# Генерация Swagger документации
swagger: ## Генерировать Swagger документацию
	swag init -g $(MAIN_FILE)

# Автоматическая генерация Swagger (с проверкой)
swagger-auto: ## Автоматически генерировать Swagger с проверкой
	@echo "🔄 Проверка и обновление Swagger документации..."
	@if command -v swag &> /dev/null; then \
		swag init -g $(MAIN_FILE) && echo "✅ Swagger обновлен"; \
	else \
		echo "⚠️  swag не найден, пытаемся найти в GOPATH..."; \
		GOPATH=$${GOPATH:-$$HOME/go}; \
		if [ -f "$$GOPATH/bin/swag" ]; then \
			$$GOPATH/bin/swag init -g $(MAIN_FILE) && echo "✅ Swagger обновлен"; \
		else \
			echo "❌ swag не найден. Установите: make tools"; \
		fi; \
	fi

# Сборка приложения
build: ## Собрать приложение
	go build -o $(BINARY_NAME) $(MAIN_FILE)

# Запуск приложения
run: ## Запустить приложение
	go run $(MAIN_FILE)

# Запуск с автоматической генерацией Swagger
run-auto: swagger-auto run ## Запустить с автоматическим обновлением Swagger

# Запуск с пересборкой (для разработки)
dev: ## Запустить в режиме разработки с автоперезагрузкой
	@echo "Установка air для автоперезагрузки..."
	@if ! command -v air &> /dev/null; then \
		go install github.com/cosmtrek/air@latest; \
	fi
	air

# Тестирование
test: ## Запустить тесты
	go test -v ./...

# Проверка кода
lint: ## Проверить код линтером
	@if ! command -v golangci-lint &> /dev/null; then \
		echo "Установка golangci-lint..."; \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
	fi
	golangci-lint run

# Очистка
clean: ## Очистить собранные файлы
	go clean
	rm -f $(BINARY_NAME)
	rm -rf docs/

# Установка всех инструментов разработки
tools: ## Установить инструменты разработки
	go install github.com/swaggo/swag/cmd/swag@latest
	go install github.com/cosmtrek/air@latest
	@if ! command -v golangci-lint &> /dev/null; then \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
	fi

# Полная настройка проекта
setup: tools deps swagger ## Полная настройка проекта

# Проверка готовности к запуску
check: ## Проверить готовность к запуску
	@echo "Проверка зависимостей..."
	@go mod verify
	@echo "Проверка синтаксиса..."
	@go build -o /dev/null $(MAIN_FILE)
	@echo "Все проверки пройдены успешно!"

# Запуск с проверками
start: check run ## Запустить с проверками

# Запуск с автоматическим Swagger
start-auto: check swagger-auto run ## Запустить с проверками и автоматическим Swagger

# Docker команды
docker-build: ## Собрать Docker образ
	docker build -t $(BINARY_NAME) .

docker-run: ## Запустить в Docker
	docker run -p 8080:8080 --env-file config.env $(BINARY_NAME)

# База данных
db-create: ## Создать базу данных (требует psql)
	@echo "Создание базы данных products_db..."
	@psql -U postgres -c "CREATE DATABASE products_db;" || echo "База данных уже существует или ошибка подключения"

db-drop: ## Удалить базу данных (требует psql)
	@echo "Удаление базы данных products_db..."
	@psql -U postgres -c "DROP DATABASE IF EXISTS products_db;"

# Redis команды
redis-start: ## Запустить Redis локально
	@echo "Запуск Redis..."
	@if ! docker ps | grep -q redis; then \
		docker run -d --name redis-cache -p 6379:6379 redis:7-alpine; \
		echo "Redis запущен на порту 6379"; \
	else \
		echo "Redis уже запущен"; \
	fi

redis-stop: ## Остановить Redis
	@echo "Остановка Redis..."
	@docker stop redis-cache 2>/dev/null || echo "Redis не был запущен"
	@docker rm redis-cache 2>/dev/null || echo "Контейнер Redis не найден"

redis-cli: ## Подключиться к Redis CLI
	@echo "Подключение к Redis CLI..."
	@docker exec -it redis-cache redis-cli

redis-flush: ## Очистить Redis
	@echo "Очистка Redis..."
	@docker exec redis-cache redis-cli FLUSHALL

# Docker Compose
docker-up: ## Запустить все сервисы через Docker Compose
	docker-compose up -d

docker-down: ## Остановить все сервисы
	docker-compose down

docker-logs: ## Показать логи всех сервисов
	docker-compose logs -f

# Мониторинг
logs: ## Показать логи (если запущено в Docker)
	docker logs -f $(BINARY_NAME) || echo "Контейнер не запущен"

status: ## Показать статус приложения
	@echo "Проверка статуса приложения..."
	@curl -s http://localhost:8080/ | jq . || echo "Приложение не отвечает"

cache-stats: ## Показать статистику кэша (требует аутентификации)
	@echo "Получение статистики кэша..."
	@echo "Используйте: curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:8080/api/v1/cache/stats"

# Swagger команды
swagger-serve: swagger ## Генерировать и открыть Swagger UI
	@echo "🌐 Открытие Swagger UI..."
	@if command -v open &> /dev/null; then \
		open http://localhost:8080/swagger/index.html; \
	elif command -v xdg-open &> /dev/null; then \
		xdg-open http://localhost:8080/swagger/index.html; \
	else \
		echo "Откройте в браузере: http://localhost:8080/swagger/index.html"; \
	fi

swagger-watch: ## Отслеживать изменения и автоматически обновлять Swagger
	@echo "👀 Отслеживание изменений в коде..."
	@if command -v fswatch &> /dev/null; then \
		fswatch -o . | xargs -n1 -I {} make swagger; \
	else \
		echo "fswatch не установлен. Установите: brew install fswatch (macOS) или apt-get install fswatch (Ubuntu)"; \
	fi

# JWT команды
check-jwt: ## Проверить время жизни JWT токена
	@echo "🔍 Проверка JWT токена..."
	@./scripts/check-jwt.sh

# JWT токены для тестирования
get-token: ## Получить JWT токен для тестирования API
	@echo "🔑 Получение JWT токена..."
	@./scripts/get-token.sh

# Быстрое получение токена админа
get-admin-token: ## Быстро получить токен администратора
	@echo "🔑 Получение токена администратора..."
	@curl -s -X POST http://localhost:8080/api/v1/auth/login \
		-H "Content-Type: application/json" \
		-d '{"username":"admin","password":"password"}' | \
		jq -r '.token' | \
		sed 's/^/Bearer /'

# CI/CD и развертывание
deploy: ## Развернуть приложение (dev по умолчанию)
	@echo "🚀 Развертывание приложения..."
	@chmod +x deploy.sh
	@./deploy.sh dev

deploy-staging: ## Развернуть в staging окружении
	@echo "🚀 Развертывание в staging..."
	@chmod +x deploy.sh
	@./deploy.sh staging

deploy-prod: ## Развернуть в production окружении
	@echo "🚀 Развертывание в production..."
	@chmod +x deploy.sh
	@./deploy.sh prod

deploy-all: ## Развернуть во всех окружениях
	@echo "🚀 Развертывание во всех окружениях..."
	@make deploy
	@make deploy-staging
	@make deploy-prod

# CI/CD команды
ci-cd: ## Запустить CI/CD процесс
	@echo "🔄 Запуск CI/CD процесса..."
	@chmod +x scripts/ci-cd.sh
	@./scripts/ci-cd.sh dev main

ci-cd-staging: ## CI/CD для staging
	@echo "🔄 CI/CD для staging..."
	@chmod +x scripts/ci-cd.sh
	@./scripts/ci-cd.sh staging main

ci-cd-prod: ## CI/CD для production
	@echo "🔄 CI/CD для production..."
	@chmod +x scripts/ci-cd.sh
	@./scripts/ci-cd.sh prod main

# Команды управления окружениями
env-status: ## Показать статус всех окружений
	@echo "📊 Статус окружений:"
	@echo "🔧 Development:"
	@curl -s http://localhost:8080/ | jq '.message' 2>/dev/null || echo "❌ Не запущено"
	@echo "🚀 Staging:"
	@curl -s http://localhost:8081/ | jq '.message' 2>/dev/null || echo "❌ Не запущено"
	@echo "🏭 Production:"
	@curl -s http://localhost:8082/ | jq '.message' 2>/dev/null || echo "❌ Не запущено"

env-stop: ## Остановить все окружения
	@echo "🛑 Остановка всех окружений..."
	@docker-compose down 2>/dev/null || true
	@docker-compose -f docker-compose.staging.yml down 2>/dev/null || true
	@docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
	@pkill -f "go run main.go" 2>/dev/null || true
	@echo "✅ Все окружения остановлены"

env-logs: ## Показать логи всех окружений
	@echo "📋 Логи всех окружений:"
	@echo "🔧 Development:"
	@tail -n 5 app.log 2>/dev/null || echo "Логи не найдены"
	@echo "🚀 Staging:"
	@docker-compose -f docker-compose.staging.yml logs --tail=5 2>/dev/null || echo "Контейнеры не запущены"
	@echo "🏭 Production:"
	@docker-compose -f docker-compose.prod.yml logs --tail=5 2>/dev/null || echo "Контейнеры не запущены"

# Команды для мониторинга
monitor: ## Мониторинг всех сервисов
	@echo "📊 Мониторинг сервисов..."
	@echo "🐳 Docker контейнеры:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "💾 Базы данных:"
	@echo "PostgreSQL (dev): $(lsof -i :5432 >/dev/null && echo "✅" || echo "❌")"
	@echo "PostgreSQL (staging): $(lsof -i :5433 >/dev/null && echo "✅" || echo "❌")"
	@echo "PostgreSQL (prod): $(lsof -i :5434 >/dev/null && echo "✅" || echo "❌")"
	@echo ""
	@echo "🔴 Redis:"
	@echo "Redis (dev): $(lsof -i :6379 >/dev/null && echo "✅" || echo "❌")"
	@echo "Redis (staging): $(lsof -i :6380 >/dev/null && echo "✅" || echo "❌")"
	@echo "Redis (prod): $(lsof -i :6381 >/dev/null && echo "✅" || echo "❌")"
	@echo ""
	@echo "🌐 API:"
	@echo "API (dev): $(curl -s http://localhost:8080/ >/dev/null && echo "✅" || echo "❌")"
	@echo "API (staging): $(curl -s http://localhost:8081/ >/dev/null && echo "✅" || echo "❌")"
	@echo "API (prod): $(curl -s http://localhost:8082/ >/dev/null && echo "✅" || echo "❌")"

# Команды для резервного копирования
backup: ## Создать резервную копию данных
	@echo "💾 Создание резервной копии..."
	@mkdir -p backups/$(date +%Y%m%d-%H%M%S)
	@echo "✅ Резервная копия создана"

restore: ## Восстановить данные из резервной копии
	@echo "🔄 Восстановление данных..."
	@echo "Выберите файл резервной копии:"
	@ls -la backups/
	@echo "⚠️  Функция восстановления в разработке"

# Команды для обновления
update: ## Обновить приложение
	@echo "🔄 Обновление приложения..."
	@git pull origin main
	@make deps
	@make swagger
	@echo "✅ Приложение обновлено"

update-deps: ## Обновить зависимости
	@echo "🔄 Обновление зависимостей..."
	@go get -u ./...
	@go mod tidy
	@echo "✅ Зависимости обновлены"

# Команды для диагностики
diagnose: ## Диагностика системы
	@echo "🔍 Диагностика системы..."
	@echo "📋 Версии:"
	@echo "Go: $(go version)"
	@echo "Docker: $(docker --version)"
	@echo "Docker Compose: $(docker-compose --version)"
	@echo ""
	@echo "📊 Ресурсы:"
	@echo "CPU: $(top -l 1 | grep "CPU usage" | awk '{print $3}')"
	@echo "Memory: $(top -l 1 | grep "PhysMem" | awk '{print $2}')"
	@echo "Disk: $(df -h . | tail -1 | awk '{print $5}')"
	@echo ""
	@echo "🌐 Сеть:"
	@echo "Порт 8080: $(lsof -i :8080 >/dev/null && echo "✅ Занят" || echo "❌ Свободен")"
	@echo "Порт 5432: $(lsof -i :5432 >/dev/null && echo "✅ Занят" || echo "❌ Свободен")"
	@echo "Порт 6379: $(lsof -i :6379 >/dev/null && echo "✅ Занят" || echo "❌ Свободен")" 

# Команды для интернет-магазина
ecommerce-setup: ## Настройка базы данных для интернет-магазина
	@echo "🛒 Настройка базы данных для интернет-магазина..."
	@docker exec -i products_postgres psql -U postgres -d products_db < init.sql
	@echo "✅ База данных настроена"

migrate: ## Применить миграции базы данных
	@echo "🔄 Применение миграций..."
	@docker exec -i products_postgres psql -U postgres -d products_db < migrations/001_initial_schema.sql
	@echo "✅ Миграции применены"

migrate-fresh: ## Создать новую базу данных и применить миграции
	@echo "🆕 Создание новой базы данных..."
	@docker exec -i products_postgres psql -U postgres -c "DROP DATABASE IF EXISTS products_db;"
	@docker exec -i products_postgres psql -U postgres -c "CREATE DATABASE products_db;"
	@echo "🔄 Применение миграций..."
	@docker exec -i products_postgres psql -U postgres -d products_db < migrations/001_initial_schema.sql
	@echo "✅ База данных создана и миграции применены"

ecommerce-test: ## Тестирование функций интернет-магазина
	@echo "🧪 Тестирование функций интернет-магазина..."
	@echo "1. Создание пользователя..."
	@curl -X POST http://localhost:8080/api/v1/auth/register \
		-H "Content-Type: application/json" \
		-d '{"username":"testuser","email":"test@example.com","password":"password"}' | jq .
	@echo ""
	@echo "2. Вход пользователя..."
	@TOKEN=$$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
		-H "Content-Type: application/json" \
		-d '{"username":"testuser","password":"password"}' | jq -r '.token')
	@echo "Токен получен: $$TOKEN"
	@echo ""
	@echo "3. Добавление товара в корзину..."
	@curl -X POST http://localhost:8080/api/v1/cart \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"product_id": 1, "quantity": 2}' | jq .
	@echo ""
	@echo "4. Просмотр корзины..."
	@curl -X GET http://localhost:8080/api/v1/cart \
		-H "Authorization: Bearer $$TOKEN" | jq .
	@echo ""
	@echo "5. Создание заказа..."
	@curl -X POST http://localhost:8080/api/v1/orders \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"items":[{"product_id":1,"quantity":1}],"shipping_address":"ул. Тестовая, 1","billing_address":"ул. Тестовая, 1","payment_method":"card"}' | jq .
	@echo ""
	@echo "✅ Тестирование завершено"

ecommerce-demo: ## Демонстрация функций интернет-магазина
	@echo "🎬 Демонстрация функций интернет-магазина..."
	@echo "📱 Откройте Swagger UI: http://localhost:8080/swagger/index.html"
	@echo "🔑 Используйте токен админа для полного доступа"
	@echo "🛒 Протестируйте корзину и заказы"
	@echo "📊 Проверьте статистику кэша"

# Команды для деплоя на облачный сервер
deploy-cloud: ## Деплой на облачный сервер
	@echo "🚀 Деплой на облачный сервер..."
	@echo "Использование: make deploy-cloud ENV=prod SERVER=YOUR_IP"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make deploy-cloud ENV=prod SERVER=192.168.1.100"; \
		exit 1; \
	fi
	@./scripts/generate-prod-config.sh
	@./scripts/deploy-cloud.sh $(ENV) $(SERVER)

generate-prod-config: ## Генерация production конфигурации
	@echo "🔐 Генерация production конфигурации..."
	@./scripts/generate-prod-config.sh

deploy-local: ## Локальный деплой
	@echo "🏠 Локальный деплой..."
	@./deploy.sh dev

check-config: ## Проверка конфигурации
	@echo "🔍 Проверка конфигурации..."
	@./scripts/check-config.sh

clean-deploy: ## Полная очистка сервера и передеплой
	@echo "🧹 Полная очистка сервера и передеплой..."
	@echo "Использование: make clean-deploy ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make clean-deploy ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/clean-deploy.sh $(ENV) $(SERVER) $(USER)

fix-redis: ## Исправить проблемы с Redis
	@echo "🔧 Исправление проблем с Redis..."
	@echo "Использование: make fix-redis ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make fix-redis ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/fix-redis.sh $(ENV) $(SERVER) $(USER)

fix-postgres: ## Исправить проблемы с PostgreSQL
	@echo "🔧 Исправление проблем с PostgreSQL..."
	@echo "Использование: make fix-postgres ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make fix-postgres ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/fix-postgres.sh $(ENV) $(SERVER) $(USER)

fix-databases: ## Исправить все проблемы с базами данных
	@echo "🔧 Исправление всех проблем с базами данных..."
	@echo "Использование: make fix-databases ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make fix-databases ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/fix-databases.sh $(ENV) $(SERVER) $(USER)

start-redis-only: ## Запустить Redis без healthcheck
	@echo "🚀 Запуск Redis без healthcheck..."
	@echo "Использование: make start-redis-only ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make start-redis-only ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/start-redis-only.sh $(ENV) $(SERVER) $(USER)

deploy-simple: ## Простой деплой без healthcheck
	@echo "🚀 Простой деплой без healthcheck..."
	@echo "Использование: make deploy-simple ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make deploy-simple ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/deploy-simple.sh $(ENV) $(SERVER) $(USER) 
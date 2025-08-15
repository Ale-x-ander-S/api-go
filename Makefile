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

# Swagger документация
swagger: ## Перегенерировать Swagger документацию
	@echo "📚 Генерация Swagger документации..."
	@if command -v ~/go/bin/swag &> /dev/null; then \
		~/go/bin/swag init -g main.go; \
		echo "✅ Swagger документация обновлена"; \
	elif command -v swag &> /dev/null; then \
		swag init -g main.go; \
		echo "✅ Swagger документация обновлена"; \
	else \
		echo "⚠️  swag не установлен. Установите: go install github.com/swaggo/swag/cmd/swag@latest"; \
		exit 1; \
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
	docker run -d --name redis-local -p 6379:6379 redis:7-alpine

redis-stop: ## Остановить Redis локально
	@echo "Остановка Redis..."
	docker stop redis-local || true
	docker rm redis-local || true

redis-cli: ## Подключиться к Redis CLI
	@echo "Подключение к Redis CLI..."
	docker exec -it redis-local redis-cli

# Локальная разработка
deploy-local: ## Локальный деплой
	@echo "🏠 Локальный деплой..."
	@docker-compose up -d

# Деплой на облачный сервер
full-deploy: ## Полный деплой на облачный сервер
	@echo "🚀 Полный деплой на облачный сервер..."
	@echo "Использование: make full-deploy ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make full-deploy ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/full-deploy.sh $(ENV) $(SERVER) $(USER)

# Быстрое обновление только кода
deploy-code-only: swagger ## Быстрое обновление только кода на сервере
	@echo "⚡ Быстрое обновление только кода..."
	@echo "Использование: make deploy-code-only ENV=prod SERVER=YOUR_IP USER=root"
	@if [ -z "$(ENV)" ] || [ -z "$(SERVER)" ]; then \
		echo "❌ Укажите ENV и SERVER"; \
		echo "Пример: make deploy-code-only ENV=prod SERVER=45.12.229.112 USER=root"; \
		exit 1; \
	fi
	@./scripts/deploy-code-only.sh $(ENV) $(SERVER) $(USER)

# Проверка конфигурации
check-config: ## Проверка конфигурации
	@echo "🔍 Проверка конфигурации..."
	@./scripts/check-config.sh

# Тестирование API
test-api: ## Тестирование API
	@echo "🧪 Тестирование API..."
	@./test_api.sh

# Демонстрация функций
demo: ## Демонстрация функций интернет-магазина
	@echo "🎬 Демонстрация функций интернет-магазина..."
	@echo "📱 Откройте Swagger UI: http://localhost:8080/swagger/index.html"
	@echo "🔑 Используйте токен админа для полного доступа"
	@echo "🛒 Протестируйте корзину и заказы"
	@echo "📊 Проверьте статистику кэша" 
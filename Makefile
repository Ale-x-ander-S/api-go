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

# Сборка приложения
build: ## Собрать приложение
	go build -o $(BINARY_NAME) $(MAIN_FILE)

# Запуск приложения
run: ## Запустить приложение
	go run $(MAIN_FILE)

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
# Многоэтапная сборка для оптимизации размера образа
FROM golang:1.21-alpine AS builder

# Устанавливаем необходимые пакеты для сборки
RUN apk add --no-cache git ca-certificates tzdata

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем файлы зависимостей
COPY go.mod ./

# Скачиваем зависимости и восстанавливаем go.sum если нужно
RUN go mod download
RUN if [ -f go.sum ]; then go mod verify || go mod tidy; else go mod tidy; fi

# Копируем исходный код
COPY . .

# Генерируем Swagger документацию
RUN go install github.com/swaggo/swag/cmd/swag@latest
RUN swag init -g main.go

# Собираем приложение
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Финальный образ
FROM alpine:latest

# Устанавливаем необходимые пакеты
RUN apk --no-cache add ca-certificates tzdata

# Создаем пользователя для безопасности
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем собранное приложение из builder этапа
COPY --from=builder /app/main .

# Копируем Swagger документацию
COPY --from=builder /app/docs ./docs

# Меняем владельца файлов
RUN chown -R appuser:appgroup /app

# Переключаемся на непривилегированного пользователя
USER appuser

# Открываем порт
EXPOSE 8080

# Проверяем здоровье приложения
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Запускаем приложение
CMD ["./main"] 
package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"api-go/config"
	"api-go/database"
	_ "api-go/docs" // Импорт для Swagger документации
	"api-go/middleware"
	"api-go/routes"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

// @title Products API
// @version 1.0
// @description REST API для управления продуктами с Redis кэшированием
// @host localhost:8080
// @BasePath /api/v1
// @schemes http https

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Введите JWT токен в формате: Bearer <your-token>

// @tag.name auth
// @tag.description Операции аутентификации

// @tag.name products
// @tag.description Операции с продуктами

// @tag.name cache
// @tag.description Операции с кэшем
func main() {
	// Автоматически генерируем Swagger документацию при запуске
	if err := generateSwaggerDocs(); err != nil {
		log.Printf("Предупреждение: Не удалось сгенерировать Swagger документацию: %v", err)
		log.Println("Приложение продолжит работу с существующей документацией")
	} else {
		log.Println("Swagger документация успешно обновлена")
	}

	// Загружаем переменные окружения
	if err := godotenv.Load("config.env"); err != nil {
		log.Println("Файл config.env не найден, используем системные переменные")
	}

	// Инициализируем конфигурацию
	cfg := config.Load()

	// Подключаемся к базе данных PostgreSQL
	db, err := database.Connect(cfg.Database)
	if err != nil {
		log.Fatal("Ошибка подключения к базе данных:", err)
	}
	defer db.Close()

	// Пытаемся подключиться к Redis, если не получается - запускаем автоматически
	redisClient := database.NewRedisClient(cfg.Redis)
	if err := redisClient.Connect(); err != nil {
		log.Printf("Предупреждение: Redis недоступен: %v", err)
		log.Println("Пытаемся запустить Redis автоматически...")

		if err := startRedisAutomatically(); err != nil {
			log.Printf("Не удалось запустить Redis автоматически: %v", err)
			log.Println("Приложение продолжит работу без кэширования")
		} else {
			log.Println("Redis запущен автоматически, повторная попытка подключения...")
			time.Sleep(2 * time.Second) // Ждем запуска Redis

			if err := redisClient.Connect(); err != nil {
				log.Printf("Предупреждение: Redis все еще недоступен, кэширование отключено: %v", err)
			} else {
				defer redisClient.Close()
				log.Println("Redis подключен, кэширование активно")
			}
		}
	} else {
		defer redisClient.Close()
		log.Println("Redis подключен, кэширование активно")
	}

	// Инициализируем таблицы
	if err := database.InitTables(db); err != nil {
		log.Fatal("Ошибка инициализации таблиц:", err)
	}

	// Создаем Gin роутер
	router := gin.Default()

	// Добавляем middleware для логирования и CORS
	router.Use(middleware.CORS())
	router.Use(middleware.Logger())

	// Инициализируем маршруты
	routes.SetupRoutes(router, db, cfg, redisClient)

	// Запускаем сервер
	port := os.Getenv("SERVER_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Сервер запущен на порту %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatal("Ошибка запуска сервера:", err)
	}
}

// generateSwaggerDocs автоматически генерирует Swagger документацию
func generateSwaggerDocs() error {
	// Получаем путь к исполняемому файлу swag
	swagPath, err := exec.LookPath("swag")
	if err != nil {
		// Пытаемся найти в GOPATH
		gopath := os.Getenv("GOPATH")
		if gopath == "" {
			gopath = filepath.Join(os.Getenv("HOME"), "go")
		}
		swagPath = filepath.Join(gopath, "bin", "swag")

		// Проверяем, существует ли файл
		if _, err := os.Stat(swagPath); os.IsNotExist(err) {
			return err
		}
	}

	// Создаем команду для генерации Swagger
	cmd := exec.Command(swagPath, "init", "-g", "main.go")
	cmd.Dir = "." // Устанавливаем рабочую директорию

	// Выполняем команду
	if err := cmd.Run(); err != nil {
		return err
	}

	return nil
}

// startRedisAutomatically пытается запустить Redis автоматически
func startRedisAutomatically() error {
	// Проверяем, доступен ли Docker
	if _, err := exec.LookPath("docker"); err != nil {
		return err
	}

	// Проверяем, не запущен ли уже Redis
	cmd := exec.Command("docker", "ps", "--filter", "name=redis-cache", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err == nil && len(output) > 0 {
		log.Println("Redis уже запущен в Docker")
		return nil
	}

	// Запускаем Redis
	log.Println("Запуск Redis через Docker...")
	cmd = exec.Command("docker", "run", "-d", "--name", "redis-cache", "-p", "6379:6379", "redis:7-alpine")

	if err := cmd.Run(); err != nil {
		return err
	}

	log.Println("Redis успешно запущен в Docker")
	return nil
}

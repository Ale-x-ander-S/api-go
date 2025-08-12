package main

import (
	"log"
	"os"

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
// @description REST API для управления продуктами
// @host localhost:8080
// @BasePath /api/v1
func main() {
	// Загружаем переменные окружения
	if err := godotenv.Load("config.env"); err != nil {
		log.Println("Файл config.env не найден, используем системные переменные")
	}

	// Инициализируем конфигурацию
	cfg := config.Load()

	// Подключаемся к базе данных
	db, err := database.Connect(cfg.Database)
	if err != nil {
		log.Fatal("Ошибка подключения к базе данных:", err)
	}
	defer db.Close()

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
	routes.SetupRoutes(router, db, cfg)

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

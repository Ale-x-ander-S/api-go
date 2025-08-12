package routes

import (
	"database/sql"

	"api-go/config"
	_ "api-go/docs" // Импорт для Swagger документации
	"api-go/handlers"
	"api-go/middleware"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// SetupRoutes настраивает все маршруты API
func SetupRoutes(router *gin.Engine, db *sql.DB, cfg *config.Config) {
	// Создаем экземпляры обработчиков
	authHandler := handlers.NewAuthHandler(db, cfg)
	productHandler := handlers.NewProductHandler(db)

	// Группа маршрутов для API v1
	v1 := router.Group("/api/v1")
	{
		// Публичные маршруты (без аутентификации)
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
		}

		// Публичные маршруты для продуктов
		products := v1.Group("/products")
		{
			products.GET("", productHandler.GetProducts)
			products.GET("/:id", productHandler.GetProduct)
		}

		// Защищенные маршруты (требуют аутентификации)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg))
		{
			// Маршруты для управления продуктами (требуют аутентификации)
			protected.POST("/products", productHandler.CreateProduct)
			protected.PUT("/products/:id", productHandler.UpdateProduct)
			protected.DELETE("/products/:id", productHandler.DeleteProduct)
		}
	}

	// Добавляем Swagger документацию
	router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Корневой маршрут с информацией об API
	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Products API v1.0",
			"docs":    "/swagger/index.html",
			"endpoints": gin.H{
				"auth": gin.H{
					"POST /api/v1/auth/register": "Регистрация пользователя",
					"POST /api/v1/auth/login":    "Вход пользователя",
				},
				"products": gin.H{
					"GET    /api/v1/products":     "Получить список продуктов",
					"GET    /api/v1/products/:id": "Получить продукт по ID",
					"POST   /api/v1/products":     "Создать продукт (требует аутентификации)",
					"PUT    /api/v1/products/:id": "Обновить продукт (требует аутентификации)",
					"DELETE /api/v1/products/:id": "Удалить продукт (требует аутентификации)",
				},
			},
		})
	})
}

package routes

import (
	"database/sql"

	"api-go/cache"
	"api-go/config"
	"api-go/database"
	_ "api-go/docs" // Импорт для Swagger документации
	"api-go/handlers"
	"api-go/middleware"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// SetupRoutes настраивает все маршруты API
func SetupRoutes(router *gin.Engine, db *sql.DB, cfg *config.Config, redisClient *database.RedisClient) {
	// Создаем кэш для продуктов
	productCache := cache.NewProductCache(redisClient)

	// Создаем экземпляры обработчиков
	authHandler := handlers.NewAuthHandler(db, cfg)
	productHandler := handlers.NewProductHandler(db, productCache)
	cacheHandler := handlers.NewCacheHandler(productCache)

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
			// Маршруты для управления кэшем (требуют аутентификации)
			cache := protected.Group("/cache")
			{
				cache.GET("/stats", cacheHandler.GetCacheStats)
				cache.POST("/invalidate", cacheHandler.InvalidateCache)
			}
		}

		// Административные маршруты (требуют роль admin)
		admin := v1.Group("")
		admin.Use(middleware.AuthMiddleware(cfg), middleware.AdminMiddleware())
		{
			// Маршруты для управления продуктами (требуют роль admin)
			admin.POST("/products", productHandler.CreateProduct)
			admin.PUT("/products/:id", productHandler.UpdateProduct)
			admin.DELETE("/products/:id", productHandler.DeleteProduct)
		}
	}

	// Добавляем Swagger документацию
	router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Корневой маршрут с информацией об API
	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Products API v1.0",
			"docs":    "/swagger/index.html",
			"features": gin.H{
				"caching": "Redis кэш для продуктов",
				"auth":    "JWT аутентификация с ролями",
				"swagger": "Автоматическая документация",
			},
			"endpoints": gin.H{
				"auth": gin.H{
					"POST /api/v1/auth/register": "Регистрация пользователя",
					"POST /api/v1/auth/login":    "Вход пользователя",
				},
				"products": gin.H{
					"GET    /api/v1/products":     "Получить список продуктов (с кэшированием)",
					"GET    /api/v1/products/:id": "Получить продукт по ID (с кэшированием)",
					"POST   /api/v1/products":     "Создать продукт (требует роль admin, инвалидирует кэш)",
					"PUT    /api/v1/products/:id": "Обновить продукт (требует роль admin, инвалидирует кэш)",
					"DELETE /api/v1/products/:id": "Удалить продукт (требует роль admin, инвалидирует кэш)",
				},
				"cache": gin.H{
					"GET  /api/v1/cache/stats":      "Статистика кэша (требует аутентификации)",
					"POST /api/v1/cache/invalidate": "Инвалидация всего кэша (требует аутентификации)",
				},
			},
			"security": gin.H{
				"note": "Управление продуктами доступно только пользователям с ролью 'admin'",
			},
		})
	})
}

package routes

import (
	"api-go/cache"
	"api-go/config"
	"api-go/database"
	"api-go/handlers"
	"api-go/middleware"
	"database/sql"

	_ "api-go/docs"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// SetupRoutes настраивает все маршруты приложения
func SetupRoutes(cfg *config.Config, db *sql.DB, redisClient *database.RedisClient) *gin.Engine {
	r := gin.Default()

	// Middleware
	r.Use(middleware.CORS())
	r.Use(middleware.Logger())

	// Swagger документация
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Корневой маршрут
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Products API v1.0",
			"features": []string{
				"JWT Authentication",
				"Role-based Access Control",
				"Redis Caching",
				"Product Management",
				"Shopping Cart",
				"Order Management",
				"Category Management",
				"Review System",
				"Swagger Documentation",
			},
			"endpoints": gin.H{
				"auth":       "/api/v1/auth/*",
				"products":   "/api/v1/products/*",
				"categories": "/api/v1/categories/*",
				"orders":     "/api/v1/orders/*",
				"cart":       "/api/v1/cart/*",
				"reviews":    "/api/v1/reviews/*",
				"cache":      "/api/v1/cache/*",
			},
			"swagger": "/swagger/index.html",
		})
	})

	// API v1
	v1 := r.Group("/api/v1")
	{
		// Аутентификация
		auth := v1.Group("/auth")
		{
			authHandler := handlers.NewAuthHandler(db, cfg)
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
		}

		// Защищенные маршруты (требуют аутентификации)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg))
		{
			// Продукты (чтение)
			productHandler := handlers.NewProductHandler(db, cache.NewProductCache(redisClient))
			protected.GET("/products", productHandler.GetProducts)
			protected.GET("/products/:id", productHandler.GetProduct)

			// Корзина
			cartHandler := handlers.NewCartHandler(db)
			protected.GET("/cart", cartHandler.GetCart)
			protected.POST("/cart", cartHandler.AddToCart)
			protected.PUT("/cart/:id", cartHandler.UpdateCartItem)
			protected.DELETE("/cart/:id", cartHandler.RemoveFromCart)
			protected.POST("/cart/clear", cartHandler.ClearCart)

			// Заказы
			orderHandler := handlers.NewOrderHandler(db)
			protected.GET("/orders", orderHandler.GetOrders)
			protected.GET("/orders/:id", orderHandler.GetOrder)
			protected.POST("/orders", orderHandler.CreateOrder)
			protected.PUT("/orders/:id", orderHandler.UpdateOrder)
			protected.POST("/orders/:id/cancel", orderHandler.CancelOrder)

			// Кэш
			cacheHandler := handlers.NewCacheHandler(cache.NewProductCache(redisClient))
			protected.GET("/cache/stats", cacheHandler.GetCacheStats)
			protected.POST("/cache/invalidate", cacheHandler.InvalidateCache)
		}

		// Админские маршруты (требуют роль admin)
		admin := v1.Group("")
		admin.Use(middleware.AuthMiddleware(cfg))
		admin.Use(middleware.AdminMiddleware())
		{
			// Продукты (создание, обновление, удаление)
			productHandler := handlers.NewProductHandler(db, cache.NewProductCache(redisClient))
			admin.POST("/products", productHandler.CreateProduct)
			admin.PUT("/products/:id", productHandler.UpdateProduct)
			admin.DELETE("/products/:id", productHandler.DeleteProduct)

			// Категории
			// TODO: Добавить CategoryHandler
			// categoryHandler := handlers.NewCategoryHandler(db)
			// admin.GET("/categories", categoryHandler.GetCategories)
			// admin.GET("/categories/:id", categoryHandler.GetCategory)
			// admin.POST("/categories", categoryHandler.CreateCategory)
			// admin.PUT("/categories/:id", categoryHandler.UpdateCategory)
			// admin.DELETE("/categories/:id", categoryHandler.DeleteCategory)

			// Отзывы (модерация)
			// TODO: Добавить ReviewHandler
			// reviewHandler := handlers.NewReviewHandler(db)
			// admin.GET("/reviews", reviewHandler.GetReviews)
			// admin.PUT("/reviews/:id", reviewHandler.UpdateReview)
			// admin.DELETE("/reviews/:id", reviewHandler.DeleteReview)

			// Заказы (управление)
			orderHandler := handlers.NewOrderHandler(db)
			admin.GET("/admin/orders", orderHandler.GetOrders)       // Все заказы для админа
			admin.PUT("/admin/orders/:id", orderHandler.UpdateOrder) // Обновление статуса заказа
		}

		// Публичные маршруты
		{
			// Категории (чтение)
			// TODO: Добавить CategoryHandler
			// categoryHandler := handlers.NewCategoryHandler(db)
			// v1.GET("/categories", categoryHandler.GetCategories)
			// v1.GET("/categories/:id", categoryHandler.GetCategory)

			// Отзывы (чтение)
			// TODO: Добавить ReviewHandler
			// reviewHandler := handlers.NewReviewHandler(db)
			// v1.GET("/products/:id/reviews", reviewHandler.GetProductReviews)
			// v1.POST("/products/:id/reviews", reviewHandler.CreateReview) // Требует аутентификации
		}
	}

	return r
}

package cache

import (
	"context"
	"fmt"
	"log"
	"strconv"

	"api-go/database"
	"api-go/models"
)

// ProductCache представляет кэш для продуктов
type ProductCache struct {
	redis *database.RedisClient
}

// NewProductCache создает новый кэш для продуктов
func NewProductCache(redis *database.RedisClient) *ProductCache {
	return &ProductCache{
		redis: redis,
	}
}

// Ключи кэша
const (
	AllProductsKey     = "products:all"         // Все продукты
	ProductKey         = "product:%d"           // Конкретный продукт
	ProductCategoryKey = "products:category:%s" // По категории
)

// GetProducts получает список продуктов из кэша
func (c *ProductCache) GetProducts(ctx context.Context, page, limit int, categoryID string) ([]models.ProductResponse, error) {
	// Всегда получаем все продукты из кэша
	var allProducts []models.ProductResponse
	err := c.redis.Get(ctx, AllProductsKey, &allProducts)
	if err != nil {
		return nil, err
	}

	// Фильтруем по category_id если нужно
	if categoryID != "" {
		allProducts = c.filterByCategoryID(allProducts, categoryID)
	}

	// Применяем пагинацию
	start := (page - 1) * limit
	end := start + limit
	if start >= len(allProducts) {
		return []models.ProductResponse{}, nil
	}
	if end > len(allProducts) {
		end = len(allProducts)
	}

	return allProducts[start:end], nil
}

// SetProducts сохраняет все продукты в кэш
func (c *ProductCache) SetProducts(ctx context.Context, products []models.ProductResponse) error {
	err := c.redis.Set(ctx, AllProductsKey, products)
	if err != nil {
		log.Printf("Ошибка сохранения всех продуктов в кэш: %v", err)
		return err
	}

	log.Printf("Все продукты сохранены в кэш: %d штук", len(products))
	return nil
}

// GetProduct получает продукт по ID из кэша
func (c *ProductCache) GetProduct(ctx context.Context, id int) (*models.ProductResponse, error) {
	key := fmt.Sprintf(ProductKey, id)

	var product models.ProductResponse
	err := c.redis.Get(ctx, key, &product)
	if err != nil {
		return nil, err
	}

	log.Printf("Продукт загружен из кэша: %s", key)
	return &product, nil
}

// SetProduct сохраняет продукт в кэш
func (c *ProductCache) SetProduct(ctx context.Context, product models.ProductResponse) error {
	key := fmt.Sprintf(ProductKey, product.ID)

	err := c.redis.Set(ctx, key, product)
	if err != nil {
		log.Printf("Ошибка сохранения продукта в кэш: %v", err)
		return err
	}

	log.Printf("Продукт сохранен в кэш: %s", key)
	return nil
}

// InvalidateProductCache инвалидирует кэш продукта
func (c *ProductCache) InvalidateProductCache(ctx context.Context, productID int) error {
	// Удаляем конкретный продукт
	key := fmt.Sprintf(ProductKey, productID)
	err := c.redis.Delete(ctx, key)
	if err != nil {
		log.Printf("Ошибка удаления продукта из кэша: %v", err)
	}

	// Инвалидируем все списки продуктов
	err = c.redis.DeletePattern(ctx, "products:*")
	if err != nil {
		log.Printf("Ошибка инвалидации списков продуктов: %v", err)
		return err
	}

	log.Printf("Кэш продуктов инвалидирован для продукта ID: %d", productID)
	return nil
}

// InvalidateAllProductCache инвалидирует весь кэш продуктов
func (c *ProductCache) InvalidateAllProductCache(ctx context.Context) error {
	err := c.redis.DeletePattern(ctx, "products:*")
	if err != nil {
		log.Printf("Ошибка инвалидации всего кэша продуктов: %v", err)
		return err
	}

	log.Println("Весь кэш продуктов инвалидирован")
	return nil
}

// GetCacheStats возвращает статистику кэша
func (c *ProductCache) GetCacheStats(ctx context.Context) map[string]interface{} {
	stats := make(map[string]interface{})

	// Подсчитываем количество ключей по паттернам
	patterns := []string{
		AllProductsKey,
		"product:*",
		"products:category:*",
	}

	for _, pattern := range patterns {
		keys, err := c.redis.GetClient().Keys(ctx, pattern).Result()
		if err != nil {
			stats[pattern] = "error"
		} else {
			stats[pattern] = len(keys)
		}
	}

	// Добавляем информацию о количестве продуктов в кэше
	var allProducts []models.ProductResponse
	err := c.redis.Get(ctx, AllProductsKey, &allProducts)
	if err == nil {
		stats["cached_products_count"] = len(allProducts)
	} else {
		stats["cached_products_count"] = 0
	}

	return stats
}

// filterByCategoryID фильтрует продукты по ID категории
func (c *ProductCache) filterByCategoryID(products []models.ProductResponse, categoryID string) []models.ProductResponse {
	var filtered []models.ProductResponse

	// Конвертируем categoryID в int для сравнения
	id, err := strconv.Atoi(categoryID)
	if err != nil {
		// Если не удалось конвертировать, возвращаем пустой список
		return filtered
	}

	for _, product := range products {
		if product.CategoryID != nil && *product.CategoryID == id {
			filtered = append(filtered, product)
		}
	}

	return filtered
}

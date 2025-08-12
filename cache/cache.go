package cache

import (
	"context"
	"fmt"
	"log"

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
	ProductListKey     = "products:list"
	ProductKey         = "product:%d"
	ProductCategoryKey = "products:category:%s"
	ProductPageKey     = "products:page:%d:limit:%d"
)

// GetProducts получает список продуктов из кэша
func (c *ProductCache) GetProducts(ctx context.Context, page, limit int, category string) ([]models.ProductResponse, error) {
	var key string

	if category != "" {
		key = fmt.Sprintf(ProductCategoryKey, category)
	} else {
		key = fmt.Sprintf(ProductPageKey, page, limit)
	}

	var products []models.ProductResponse
	err := c.redis.Get(ctx, key, &products)
	if err != nil {
		return nil, err
	}

	log.Printf("Продукты загружены из кэша: %s", key)
	return products, nil
}

// SetProducts сохраняет список продуктов в кэш
func (c *ProductCache) SetProducts(ctx context.Context, page, limit int, category string, products []models.ProductResponse) error {
	var key string

	if category != "" {
		key = fmt.Sprintf(ProductCategoryKey, category)
	} else {
		key = fmt.Sprintf(ProductPageKey, page, limit)
	}

	err := c.redis.Set(ctx, key, products)
	if err != nil {
		log.Printf("Ошибка сохранения в кэш: %v", err)
		return err
	}

	log.Printf("Продукты сохранены в кэш: %s", key)
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
		"products:list",
		"product:*",
		"products:category:*",
		"products:page:*",
	}

	for _, pattern := range patterns {
		keys, err := c.redis.GetClient().Keys(ctx, pattern).Result()
		if err != nil {
			stats[pattern] = "error"
		} else {
			stats[pattern] = len(keys)
		}
	}

	return stats
}

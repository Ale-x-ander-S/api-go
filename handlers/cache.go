package handlers

import (
	"net/http"

	"api-go/cache"

	"github.com/gin-gonic/gin"
)

// CacheHandler обрабатывает запросы для работы с кэшем
type CacheHandler struct {
	cache *cache.ProductCache
}

// NewCacheHandler создает новый экземпляр CacheHandler
func NewCacheHandler(productCache *cache.ProductCache) *CacheHandler {
	return &CacheHandler{
		cache: productCache,
	}
}

// GetCacheStats возвращает статистику кэша
// @Summary Статистика кэша
// @Description Возвращает статистику использования Redis кэша
// @Tags cache
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Failure 401 {object} map[string]string
// @Router /cache/stats [get]
func (h *CacheHandler) GetCacheStats(c *gin.Context) {
	ctx := c.Request.Context()
	stats := h.cache.GetCacheStats(ctx)

	c.JSON(http.StatusOK, gin.H{
		"cache_stats": stats,
		"message":     "Статистика кэша получена",
	})
}

// InvalidateCache инвалидирует весь кэш продуктов
// @Summary Инвалидация кэша
// @Description Инвалидирует весь кэш продуктов (требует аутентификации)
// @Tags cache
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Router /cache/invalidate [post]
func (h *CacheHandler) InvalidateCache(c *gin.Context) {
	ctx := c.Request.Context()

	if err := h.cache.InvalidateAllProductCache(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка инвалидации кэша: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Весь кэш продуктов инвалидирован",
	})
}

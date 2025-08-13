package handlers

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"api-go/cache"
	"api-go/models"

	"github.com/gin-gonic/gin"
)

// ProductHandler обрабатывает запросы для работы с продуктами
type ProductHandler struct {
	db    *sql.DB
	cache *cache.ProductCache
}

// NewProductHandler создает новый экземпляр ProductHandler
func NewProductHandler(db *sql.DB, productCache *cache.ProductCache) *ProductHandler {
	return &ProductHandler{
		db:    db,
		cache: productCache,
	}
}

// CreateProduct создает новый продукт
// @Summary Создание продукта
// @Description Создает новый продукт (требует роль admin)
// @Tags products
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param product body models.ProductCreateRequest true "Данные продукта"
// @Success 201 {object} models.ProductResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /products [post]
func (h *ProductHandler) CreateProduct(c *gin.Context) {
	var req models.ProductCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	var product models.Product
	err := h.db.QueryRow(`
		INSERT INTO products (name, description, price, category_id, stock, image_url, sku, weight, dimensions, is_active, is_featured, sort_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, name, description, price, category_id, stock, image_url, sku, weight, dimensions, is_active, is_featured, sort_order, created_at, updated_at
	`, req.Name, req.Description, req.Price, req.CategoryID, req.Stock, req.ImageURL, req.SKU, req.Weight, req.Dimensions, req.IsActive, req.IsFeatured, req.SortOrder,
	).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.CategoryID, &product.Stock, &product.ImageURL, &product.SKU, &product.Weight, &product.Dimensions, &product.IsActive, &product.IsFeatured, &product.SortOrder, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка создания продукта: " + err.Error()})
		return
	}

	// Инвалидируем кэш продуктов
	if h.cache != nil {
		h.cache.InvalidateAllProductCache(c.Request.Context())
	}

	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		CategoryID:  product.CategoryID,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		SKU:         product.SKU,
		Weight:      product.Weight,
		Dimensions:  product.Dimensions,
		IsActive:    product.IsActive,
		IsFeatured:  product.IsFeatured,
		SortOrder:   product.SortOrder,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusCreated, response)
}

// GetProducts получает список продуктов с пагинацией и фильтрацией
// @Summary Список продуктов
// @Description Возвращает список продуктов с пагинацией и фильтрацией
// @Tags products
// @Produce json
// @Param page query int false "Номер страницы" default(1)
// @Param limit query int false "Количество элементов на странице" default(10)
// @Param category_id query string false "Фильтр по ID категории"
// @Param search query string false "Поиск по названию"
// @Param min_price query number false "Минимальная цена"
// @Param max_price query number false "Максимальная цена"
// @Param sort query string false "Сортировка (name, price, created_at)" default(created_at)
// @Param order query string false "Порядок сортировки (asc, desc)" default(desc)
// @Success 200 {object} models.ProductListResponse
// @Failure 500 {object} map[string]string
// @Router /products [get]
func (h *ProductHandler) GetProducts(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	categoryID := c.Query("category_id")
	search := c.Query("search")
	minPrice := c.Query("min_price")
	maxPrice := c.Query("max_price")
	sort := c.DefaultQuery("sort", "created_at")
	order := c.DefaultQuery("order", "desc")

	log.Printf("DEBUG: Sort: %s, Order: %s", sort, order)

	// Проверяем кэш
	if h.cache != nil {
		log.Printf("DEBUG: Checking cache for page=%d, limit=%d, category_id=%s", page, limit, categoryID)
		cachedProducts, err := h.cache.GetProducts(c.Request.Context(), page, limit, categoryID)
		if err == nil {
			log.Printf("DEBUG: Cache HIT, returning %d products", len(cachedProducts))
			c.Header("X-Cache", "HIT")
			c.JSON(http.StatusOK, models.ProductListResponse{
				Products: cachedProducts,
				Total:    len(cachedProducts),
				Page:     page,
				Limit:    limit,
			})
			return
		}
		log.Printf("DEBUG: Cache MISS, error: %v", err)
	}

	c.Header("X-Cache", "MISS")

	offset := (page - 1) * limit

	// Формируем SQL запрос
	whereClause := "WHERE is_active = true"
	args := []interface{}{}
	argIndex := 1

	if categoryID != "" {
		whereClause += fmt.Sprintf(" AND category_id = $%d", argIndex)
		args = append(args, categoryID)
		argIndex++
	}

	if search != "" {
		whereClause += fmt.Sprintf(" AND (name ILIKE $%d OR description ILIKE $%d)", argIndex, argIndex)
		args = append(args, "%"+search+"%", "%"+search+"%")
		argIndex++
	}

	if minPrice != "" {
		whereClause += fmt.Sprintf(" AND price >= $%d", argIndex)
		args = append(args, minPrice)
		argIndex++
	}

	if maxPrice != "" {
		whereClause += fmt.Sprintf(" AND price <= $%d", argIndex)
		args = append(args, maxPrice)
		argIndex++
	}

	// Получаем общее количество продуктов
	var total int
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM products %s", whereClause)
	log.Printf("DEBUG: Count Query: %s", countQuery)
	log.Printf("DEBUG: Count Args: %v", args)

	err := h.db.QueryRow(countQuery, args...).Scan(&total)
	if err != nil {
		log.Printf("DEBUG: Error counting products: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка подсчета продуктов"})
		return
	}
	log.Printf("DEBUG: Total products found: %d", total)

	// Получаем продукты
	query := fmt.Sprintf(`
		SELECT p.id, p.name, p.description, p.price, COALESCE(p.category_id, 0), p.stock, COALESCE(p.image_url, ''), COALESCE(p.sku, ''), COALESCE(p.weight, 0), COALESCE(p.dimensions, ''), p.is_active, p.is_featured, p.sort_order, p.created_at, p.updated_at, c.slug as category_slug
		FROM products p
		LEFT JOIN categories c ON p.category_id = c.id
		%s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, whereClause, sort, order, argIndex, argIndex+1)

	// Логируем SQL запрос для отладки
	log.Printf("DEBUG: SQL Query: %s", query)
	log.Printf("DEBUG: Args: %v", args)

	args = append(args, limit, offset)
	rows, err := h.db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения продуктов"})
		return
	}
	defer rows.Close()

	var products []models.ProductResponse
	log.Printf("DEBUG: Starting to scan rows...")
	for rows.Next() {
		var product models.Product
		var categorySlug sql.NullString
		err := rows.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.CategoryID, &product.Stock, &product.ImageURL, &product.SKU, &product.Weight, &product.Dimensions, &product.IsActive, &product.IsFeatured, &product.SortOrder, &product.CreatedAt, &product.UpdatedAt, &categorySlug)
		if err != nil {
			log.Printf("DEBUG: Error scanning row: %v", err)
			continue
		}
		log.Printf("DEBUG: Scanned product: ID=%d, Name=%s", product.ID, product.Name)

		response := models.ProductResponse{
			ID:          product.ID,
			Name:        product.Name,
			Description: product.Description,
			Price:       product.Price,
			CategoryID:  product.CategoryID,
			Stock:       product.Stock,
			ImageURL:    product.ImageURL,
			SKU:         product.SKU,
			Weight:      product.Weight,
			Dimensions:  product.Dimensions,
			IsActive:    product.IsActive,
			IsFeatured:  product.IsFeatured,
			SortOrder:   product.SortOrder,
			CreatedAt:   product.CreatedAt,
			UpdatedAt:   product.UpdatedAt,
		}

		// Заполняем slug категории
		if categorySlug.Valid {
			response.CategorySlug = categorySlug.String
		}

		products = append(products, response)
	}

	// Сохраняем все продукты в кэш (если кэш пустой)
	if h.cache != nil {
		// Проверяем есть ли уже продукты в кэше
		_, err := h.cache.GetProducts(c.Request.Context(), 1, 1, "")
		if err != nil {
			// Кэш пустой, получаем все продукты с категориями и сохраняем
			allProductsQuery := `
				SELECT p.id, p.name, p.description, p.price, COALESCE(p.category_id, 0), p.stock, COALESCE(p.image_url, ''), COALESCE(p.sku, ''), COALESCE(p.weight, 0), COALESCE(p.dimensions, ''), p.is_active, p.is_featured, p.sort_order, p.created_at, p.updated_at, c.slug as category_slug
				FROM products p
				LEFT JOIN categories c ON p.category_id = c.id
				WHERE p.is_active = true
				ORDER BY p.id ASC
			`
			allRows, err := h.db.Query(allProductsQuery)
			if err == nil {
				defer allRows.Close()
				var allProducts []models.ProductResponse
				for allRows.Next() {
					var product models.Product
					var categorySlug sql.NullString
					err := allRows.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.CategoryID, &product.Stock, &product.ImageURL, &product.SKU, &product.Weight, &product.Dimensions, &product.IsActive, &product.IsFeatured, &product.SortOrder, &product.CreatedAt, &product.UpdatedAt, &categorySlug)
					if err == nil {
						response := models.ProductResponse{
							ID:          product.ID,
							Name:        product.Name,
							Description: product.Description,
							Price:       product.Price,
							CategoryID:  product.CategoryID,
							Stock:       product.Stock,
							ImageURL:    product.ImageURL,
							SKU:         product.SKU,
							Weight:      product.Weight,
							Dimensions:  product.Dimensions,
							IsActive:    product.IsActive,
							IsFeatured:  product.IsFeatured,
							SortOrder:   product.SortOrder,
							CreatedAt:   product.CreatedAt,
							UpdatedAt:   product.UpdatedAt,
						}
						// Добавляем slug категории в response для фильтрации
						if categorySlug.Valid {
							response.CategorySlug = categorySlug.String
						}
						allProducts = append(allProducts, response)
					}
				}
				// Сохраняем все продукты в кэш
				h.cache.SetProducts(c.Request.Context(), allProducts)
				log.Printf("DEBUG: Все продукты сохранены в кэш: %d штук", len(allProducts))
			}
		}
	}

	response := models.ProductListResponse{
		Products: products,
		Total:    total,
		Page:     page,
		Limit:    limit,
	}

	c.JSON(http.StatusOK, response)
}

// GetProduct получает продукт по ID
// @Summary Получение продукта по ID
// @Description Возвращает информацию о продукте по его ID
// @Tags products
// @Produce json
// @Param id path int true "ID продукта"
// @Success 200 {object} models.ProductResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /products/{id} [get]
func (h *ProductHandler) GetProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID продукта"})
		return
	}

	// Проверяем кэш
	if h.cache != nil {
		cachedProduct, err := h.cache.GetProduct(c.Request.Context(), id)
		if err == nil {
			c.Header("X-Cache", "HIT")
			c.JSON(http.StatusOK, cachedProduct)
			return
		}
	}

	c.Header("X-Cache", "MISS")

	var product models.Product
	err = h.db.QueryRow(`
		SELECT id, name, description, price, COALESCE(category_id, 0), stock, COALESCE(image_url, ''), COALESCE(sku, ''), COALESCE(weight, 0), COALESCE(dimensions, ''), is_active, is_featured, sort_order, created_at, updated_at
		FROM products WHERE id = $1 AND is_active = true
	`, id).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.CategoryID, &product.Stock, &product.ImageURL, &product.SKU, &product.Weight, &product.Dimensions, &product.IsActive, &product.IsFeatured, &product.SortOrder, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Продукт не найден"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения продукта"})
		}
		return
	}

	// Сохраняем в кэш
	if h.cache != nil {
		productResponse := models.ProductResponse{
			ID:          product.ID,
			Name:        product.Name,
			Description: product.Description,
			Price:       product.Price,
			CategoryID:  product.CategoryID,
			Stock:       product.Stock,
			ImageURL:    product.ImageURL,
			SKU:         product.SKU,
			Weight:      product.Weight,
			Dimensions:  product.Dimensions,
			IsActive:    product.IsActive,
			IsFeatured:  product.IsFeatured,
			SortOrder:   product.SortOrder,
			CreatedAt:   product.CreatedAt,
			UpdatedAt:   product.UpdatedAt,
		}
		h.cache.SetProduct(c.Request.Context(), productResponse)
	}

	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		CategoryID:  product.CategoryID,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		SKU:         product.SKU,
		Weight:      product.Weight,
		Dimensions:  product.Dimensions,
		IsActive:    product.IsActive,
		IsFeatured:  product.IsFeatured,
		SortOrder:   product.SortOrder,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusOK, response)
}

// UpdateProduct обновляет продукт
// @Summary Обновление продукта
// @Description Обновляет информацию о продукте (требует роль admin)
// @Tags products
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID продукта"
// @Param product body models.ProductUpdateRequest true "Данные для обновления"
// @Success 200 {object} models.ProductResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /products/{id} [put]
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID продукта"})
		return
	}

	var req models.ProductUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	// Проверяем, что продукт существует
	var exists bool
	err = h.db.QueryRow("SELECT EXISTS(SELECT 1 FROM products WHERE id = $1)", id).Scan(&exists)
	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Продукт не найден"})
		return
	}

	// Формируем SQL запрос для обновления
	query := "UPDATE products SET updated_at = $1"
	args := []interface{}{time.Now()}
	argIndex := 2

	if req.Name != nil {
		query += fmt.Sprintf(", name = $%d", argIndex)
		args = append(args, *req.Name)
		argIndex++
	}

	if req.Description != nil {
		query += fmt.Sprintf(", description = $%d", argIndex)
		args = append(args, *req.Description)
		argIndex++
	}

	if req.Price != nil {
		query += fmt.Sprintf(", price = $%d", argIndex)
		args = append(args, *req.Price)
		argIndex++
	}

	if req.CategoryID != nil {
		query += fmt.Sprintf(", category_id = $%d", argIndex)
		args = append(args, *req.CategoryID)
		argIndex++
	}

	if req.Stock != nil {
		query += fmt.Sprintf(", stock = $%d", argIndex)
		args = append(args, *req.Stock)
		argIndex++
	}

	if req.ImageURL != nil {
		query += fmt.Sprintf(", image_url = $%d", argIndex)
		args = append(args, *req.ImageURL)
		argIndex++
	}

	if req.SKU != nil {
		query += fmt.Sprintf(", sku = $%d", argIndex)
		args = append(args, *req.SKU)
		argIndex++
	}

	if req.Weight != nil {
		query += fmt.Sprintf(", weight = $%d", argIndex)
		args = append(args, *req.Weight)
		argIndex++
	}

	if req.Dimensions != nil {
		query += fmt.Sprintf(", dimensions = $%d", argIndex)
		args = append(args, *req.Dimensions)
		argIndex++
	}

	if req.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argIndex)
		args = append(args, *req.IsActive)
		argIndex++
	}

	if req.IsFeatured != nil {
		query += fmt.Sprintf(", is_featured = $%d", argIndex)
		args = append(args, *req.IsFeatured)
		argIndex++
	}

	if req.SortOrder != nil {
		query += fmt.Sprintf(", sort_order = $%d", argIndex)
		args = append(args, *req.SortOrder)
		argIndex++
	}

	query += " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, id)

	_, err = h.db.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления продукта"})
		return
	}

	// Получаем обновленный продукт
	var product models.Product
	err = h.db.QueryRow(`
		SELECT id, name, description, price, category_id, stock, image_url, sku, weight, dimensions, is_active, is_featured, sort_order, created_at, updated_at
		FROM products WHERE id = $1
	`, id).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.CategoryID, &product.Stock, &product.ImageURL, &product.SKU, &product.Weight, &product.Dimensions, &product.IsActive, &product.IsFeatured, &product.SortOrder, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения обновленного продукта"})
		return
	}

	// Инвалидируем кэш продуктов
	if h.cache != nil {
		h.cache.InvalidateProductCache(c.Request.Context(), id)
	}

	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		CategoryID:  product.CategoryID,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		SKU:         product.SKU,
		Weight:      product.Weight,
		Dimensions:  product.Dimensions,
		IsActive:    product.IsActive,
		IsFeatured:  product.IsFeatured,
		SortOrder:   product.SortOrder,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusOK, response)
}

// DeleteProduct удаляет продукт
// @Summary Удаление продукта
// @Description Удаляет продукт из системы (требует роль admin)
// @Tags products
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID продукта"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /products/{id} [delete]
func (h *ProductHandler) DeleteProduct(c *gin.Context) {
	// Получаем ID из URL
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID продукта"})
		return
	}

	// Проверяем, существует ли продукт
	var existingProduct models.Product
	err = h.db.QueryRow("SELECT id FROM products WHERE id = $1", id).Scan(&existingProduct.ID)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Продукт не найден"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка проверки продукта"})
		return
	}

	// Удаляем продукт
	_, err = h.db.Exec("DELETE FROM products WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка удаления продукта"})
		return
	}

	// Инвалидируем кэш после удаления продукта
	ctx := context.Background()
	if err := h.cache.InvalidateProductCache(ctx, id); err != nil {
		// Логируем ошибку, но не прерываем выполнение
		c.Header("X-Cache-Invalidation", "failed")
	}

	c.JSON(http.StatusOK, gin.H{"message": "Продукт успешно удален"})
}

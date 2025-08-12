package handlers

import (
	"database/sql"
	"net/http"
	"strconv"
	"time"

	"api-go/models"

	"github.com/gin-gonic/gin"
)

// ProductHandler обрабатывает запросы для работы с продуктами
type ProductHandler struct {
	db *sql.DB
}

// NewProductHandler создает новый экземпляр ProductHandler
func NewProductHandler(db *sql.DB) *ProductHandler {
	return &ProductHandler{db: db}
}

// CreateProduct создает новый продукт
// @Summary Создание продукта
// @Description Создает новый продукт в системе (требует аутентификации)
// @Tags products
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param product body models.ProductCreateRequest true "Данные продукта"
// @Success 201 {object} models.ProductResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Router /products [post]
func (h *ProductHandler) CreateProduct(c *gin.Context) {
	var req models.ProductCreateRequest

	// Валидируем входящие данные
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	// Создаем продукт
	var product models.Product
	err := h.db.QueryRow(`
		INSERT INTO products (name, description, price, category, stock, image_url) 
		VALUES ($1, $2, $3, $4, $5, $6) 
		RETURNING id, name, description, price, category, stock, image_url, created_at, updated_at`,
		req.Name, req.Description, req.Price, req.Category, req.Stock, req.ImageURL,
	).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock, &product.ImageURL, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка создания продукта"})
		return
	}

	// Формируем ответ
	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		Category:    product.Category,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusCreated, response)
}

// GetProducts возвращает список всех продуктов
// @Summary Получение списка продуктов
// @Description Возвращает список всех продуктов с пагинацией
// @Tags products
// @Produce json
// @Param page query int false "Номер страницы (по умолчанию 1)"
// @Param limit query int false "Количество продуктов на странице (по умолчанию 10)"
// @Param category query string false "Фильтр по категории"
// @Success 200 {array} models.ProductResponse
// @Router /products [get]
func (h *ProductHandler) GetProducts(c *gin.Context) {
	// Получаем параметры пагинации
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	category := c.Query("category")

	// Вычисляем offset
	offset := (page - 1) * limit

	// Формируем SQL запрос
	var query string
	var args []interface{}

	if category != "" {
		query = `SELECT id, name, description, price, category, stock, image_url, created_at, updated_at 
				 FROM products WHERE category = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`
		args = []interface{}{category, limit, offset}
	} else {
		query = `SELECT id, name, description, price, category, stock, image_url, created_at, updated_at 
				 FROM products ORDER BY created_at DESC LIMIT $1 OFFSET $2`
		args = []interface{}{limit, offset}
	}

	// Выполняем запрос
	rows, err := h.db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения продуктов"})
		return
	}
	defer rows.Close()

	// Собираем результаты
	var products []models.ProductResponse
	for rows.Next() {
		var product models.Product
		err := rows.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock, &product.ImageURL, &product.CreatedAt, &product.UpdatedAt)
		if err != nil {
			continue
		}

		response := models.ProductResponse{
			ID:          product.ID,
			Name:        product.Name,
			Description: product.Description,
			Price:       product.Price,
			Category:    product.Category,
			Stock:       product.Stock,
			ImageURL:    product.ImageURL,
			CreatedAt:   product.CreatedAt,
			UpdatedAt:   product.UpdatedAt,
		}
		products = append(products, response)
	}

	c.JSON(http.StatusOK, products)
}

// GetProduct возвращает продукт по ID
// @Summary Получение продукта по ID
// @Description Возвращает информацию о конкретном продукте
// @Tags products
// @Produce json
// @Param id path int true "ID продукта"
// @Success 200 {object} models.ProductResponse
// @Failure 404 {object} map[string]string
// @Router /products/{id} [get]
func (h *ProductHandler) GetProduct(c *gin.Context) {
	// Получаем ID из URL
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID продукта"})
		return
	}

	// Ищем продукт в базе
	var product models.Product
	err = h.db.QueryRow(`
		SELECT id, name, description, price, category, stock, image_url, created_at, updated_at 
		FROM products WHERE id = $1`,
		id,
	).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock, &product.ImageURL, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Продукт не найден"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения продукта"})
		return
	}

	// Формируем ответ
	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		Category:    product.Category,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusOK, response)
}

// UpdateProduct обновляет существующий продукт
// @Summary Обновление продукта
// @Description Обновляет информацию о продукте (требует аутентификации)
// @Tags products
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID продукта"
// @Param product body models.ProductUpdateRequest true "Данные для обновления"
// @Success 200 {object} models.ProductResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /products/{id} [put]
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
	// Получаем ID из URL
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID продукта"})
		return
	}

	var req models.ProductUpdateRequest

	// Валидируем входящие данные
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
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

	// Формируем SQL запрос для обновления
	query := "UPDATE products SET updated_at = $1"
	args := []interface{}{time.Now()}
	argIndex := 2

	if req.Name != nil {
		query += ", name = $" + strconv.Itoa(argIndex)
		args = append(args, *req.Name)
		argIndex++
	}
	if req.Description != nil {
		query += ", description = $" + strconv.Itoa(argIndex)
		args = append(args, *req.Description)
		argIndex++
	}
	if req.Price != nil {
		query += ", price = $" + strconv.Itoa(argIndex)
		args = append(args, *req.Price)
		argIndex++
	}
	if req.Category != nil {
		query += ", category = $" + strconv.Itoa(argIndex)
		args = append(args, *req.Category)
		argIndex++
	}
	if req.Stock != nil {
		query += ", stock = $" + strconv.Itoa(argIndex)
		args = append(args, *req.Stock)
		argIndex++
	}
	if req.ImageURL != nil {
		query += ", image_url = $" + strconv.Itoa(argIndex)
		args = append(args, *req.ImageURL)
		argIndex++
	}

	query += " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, id)

	// Выполняем обновление
	_, err = h.db.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления продукта"})
		return
	}

	// Получаем обновленный продукт
	var product models.Product
	err = h.db.QueryRow(`
		SELECT id, name, description, price, category, stock, image_url, created_at, updated_at 
		FROM products WHERE id = $1`,
		id,
	).Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock, &product.ImageURL, &product.CreatedAt, &product.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения обновленного продукта"})
		return
	}

	// Формируем ответ
	response := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		Category:    product.Category,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	c.JSON(http.StatusOK, response)
}

// DeleteProduct удаляет продукт
// @Summary Удаление продукта
// @Description Удаляет продукт из системы (требует аутентификации)
// @Tags products
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID продукта"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
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

	c.JSON(http.StatusOK, gin.H{"message": "Продукт успешно удален"})
}

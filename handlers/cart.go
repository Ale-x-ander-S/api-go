package handlers

import (
	"database/sql"
	"net/http"
	"strconv"
	"time"

	"api-go/models"

	"github.com/gin-gonic/gin"
)

// CartHandler обрабатывает запросы для работы с корзиной
type CartHandler struct {
	db *sql.DB
}

// NewCartHandler создает новый экземпляр CartHandler
func NewCartHandler(db *sql.DB) *CartHandler {
	return &CartHandler{
		db: db,
	}
}

// GetCart получает корзину пользователя
// @Summary Получение корзины
// @Description Возвращает содержимое корзины аутентифицированного пользователя
// @Tags cart
// @Produce json
// @Security BearerAuth
// @Success 200 {object} models.CartResponse
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/cart [get]
func (h *CartHandler) GetCart(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Получаем товары в корзине
	rows, err := h.db.Query(`
		SELECT ci.id, ci.user_id, ci.product_id, ci.quantity, ci.price, ci.created_at, ci.updated_at,
		       p.id, p.name, p.description, p.image_url, COALESCE(p.category_id, 0), p.stock, COALESCE(p.sku, ''), p.is_active, p.created_at, p.updated_at
		FROM cart_items ci
		JOIN products p ON ci.product_id = p.id
		WHERE ci.user_id = $1 AND p.is_active = true
		ORDER BY ci.created_at DESC
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения корзины"})
		return
	}
	defer rows.Close()

	var items []models.CartItemResponse
	var totalPrice float64
	var totalItems int

	for rows.Next() {
		var item models.CartItem
		var product models.Product
		err := rows.Scan(
			&item.ID, &item.UserID, &item.ProductID, &item.Quantity, &item.Price, &item.CreatedAt, &item.UpdatedAt,
			&product.ID, &product.Name, &product.Description, &product.ImageURL, &product.CategoryID, &product.Stock, &product.SKU, &product.IsActive, &product.CreatedAt, &product.UpdatedAt,
		)
		if err != nil {
			continue
		}

		productResponse := models.ProductResponse{
			ID:          product.ID,
			Name:        product.Name,
			Description: product.Description,
			Price:       product.Price,
			CategoryID:  product.CategoryID,
			Stock:       product.Stock,
			ImageURL:    product.ImageURL,
			SKU:         product.SKU,
			IsActive:    product.IsActive,
			CreatedAt:   product.CreatedAt,
			UpdatedAt:   product.UpdatedAt,
		}

		itemTotal := item.Price * float64(item.Quantity)
		totalPrice += itemTotal
		totalItems += item.Quantity

		itemResponse := models.CartItemResponse{
			ID:        item.ID,
			UserID:    item.UserID,
			ProductID: item.ProductID,
			Product:   productResponse,
			Quantity:  item.Quantity,
			Price:     item.Price,
			Total:     itemTotal,
			CreatedAt: item.CreatedAt,
			UpdatedAt: item.UpdatedAt,
		}

		items = append(items, itemResponse)
	}

	response := models.CartResponse{
		Items:      items,
		TotalItems: totalItems,
		TotalPrice: totalPrice,
		ItemCount:  len(items),
	}

	c.JSON(http.StatusOK, response)
}

// AddToCart добавляет товар в корзину
// @Summary Добавление товара в корзину
// @Description Добавляет товар в корзину аутентифицированного пользователя
// @Tags cart
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param item body models.CartItemRequest true "Данные товара"
// @Success 201 {object} models.CartItemResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/cart [post]
func (h *CartHandler) AddToCart(c *gin.Context) {
	var req models.CartItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Проверяем, что продукт существует и активен
	var price float64
	var stock int
	err := h.db.QueryRow("SELECT price, stock FROM products WHERE id = $1 AND is_active = true", req.ProductID).Scan(&price, &stock)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Продукт не найден или неактивен"})
		return
	}

	if stock < req.Quantity {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Недостаточно товара на складе"})
		return
	}

	// Проверяем, есть ли уже такой товар в корзине
	var existingID int
	var existingQuantity int
	err = h.db.QueryRow("SELECT id, quantity FROM cart_items WHERE user_id = $1 AND product_id = $2", userID, req.ProductID).Scan(&existingID, &existingQuantity)

	if err == sql.ErrNoRows {
		// Товара нет в корзине, добавляем новый
		var cartItemID int
		err = h.db.QueryRow(`
			INSERT INTO cart_items (user_id, product_id, quantity, price)
			VALUES ($1, $2, $3, $4)
			RETURNING id
		`, userID, req.ProductID, req.Quantity, price).Scan(&cartItemID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка добавления товара в корзину"})
			return
		}

		// Получаем добавленный товар
		cartItem, err := h.getCartItemByID(cartItemID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения товара из корзины"})
			return
		}

		c.JSON(http.StatusCreated, cartItem)
		return
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка проверки корзины"})
		return
	}

	// Товар уже есть в корзине, обновляем количество
	newQuantity := existingQuantity + req.Quantity
	if newQuantity > stock {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Недостаточно товара на складе"})
		return
	}

	_, err = h.db.Exec("UPDATE cart_items SET quantity = $1, updated_at = $2 WHERE id = $3",
		newQuantity, time.Now(), existingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления количества товара"})
		return
	}

	// Получаем обновленный товар
	cartItem, err := h.getCartItemByID(existingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения товара из корзины"})
		return
	}

	c.JSON(http.StatusOK, cartItem)
}

// UpdateCartItem обновляет количество товара в корзине
// @Summary Обновление товара в корзине
// @Description Обновляет количество товара в корзине
// @Tags cart
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID товара в корзине"
// @Param item body models.CartItemUpdateRequest true "Данные для обновления"
// @Success 200 {object} models.CartItemResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/cart/{id} [put]
func (h *CartHandler) UpdateCartItem(c *gin.Context) {
	cartItemID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID товара"})
		return
	}

	var req models.CartItemUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Проверяем, что товар принадлежит пользователю
	var itemUserID int
	var productID int
	err = h.db.QueryRow("SELECT user_id, product_id FROM cart_items WHERE id = $1", cartItemID).Scan(&itemUserID, &productID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Товар в корзине не найден"})
		return
	}

	if itemUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Доступ запрещен"})
		return
	}

	// Проверяем остаток товара
	var stock int
	err = h.db.QueryRow("SELECT stock FROM products WHERE id = $1 AND is_active = true", productID).Scan(&stock)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Продукт не найден"})
		return
	}

	if req.Quantity > stock {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Недостаточно товара на складе"})
		return
	}

	// Обновляем количество
	_, err = h.db.Exec("UPDATE cart_items SET quantity = $1, updated_at = $2 WHERE id = $3",
		req.Quantity, time.Now(), cartItemID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления товара"})
		return
	}

	// Получаем обновленный товар
	cartItem, err := h.getCartItemByID(cartItemID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения товара из корзины"})
		return
	}

	c.JSON(http.StatusOK, cartItem)
}

// RemoveFromCart удаляет товар из корзины
// @Summary Удаление товара из корзины
// @Description Удаляет товар из корзины пользователя
// @Tags cart
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID товара в корзине"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/cart/{id} [delete]
func (h *CartHandler) RemoveFromCart(c *gin.Context) {
	cartItemID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID товара"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Проверяем, что товар принадлежит пользователю
	var itemUserID int
	err = h.db.QueryRow("SELECT user_id FROM cart_items WHERE id = $1", cartItemID).Scan(&itemUserID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Товар в корзине не найден"})
		return
	}

	if itemUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Доступ запрещен"})
		return
	}

	// Удаляем товар
	_, err = h.db.Exec("DELETE FROM cart_items WHERE id = $1", cartItemID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка удаления товара"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Товар успешно удален из корзины"})
}

// ClearCart очищает корзину пользователя
// @Summary Очистка корзины
// @Description Удаляет все товары из корзины пользователя
// @Tags cart
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/cart/clear [post]
func (h *CartHandler) ClearCart(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	_, err := h.db.Exec("DELETE FROM cart_items WHERE user_id = $1", userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка очистки корзины"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Корзина успешно очищена"})
}

// Вспомогательные методы

// getCartItemByID получает товар из корзины по ID
func (h *CartHandler) getCartItemByID(cartItemID int) (*models.CartItemResponse, error) {
	var item models.CartItem
	var product models.Product
	err := h.db.QueryRow(`
		SELECT ci.id, ci.user_id, ci.product_id, ci.quantity, ci.price, ci.created_at, ci.updated_at,
		       p.id, p.name, p.description, p.image_url, COALESCE(p.category_id, 0), p.stock, COALESCE(p.sku, ''), p.is_active, p.created_at, p.updated_at
		FROM cart_items ci
		JOIN products p ON ci.product_id = p.id
		WHERE ci.id = $1
	`, cartItemID).Scan(
		&item.ID, &item.UserID, &item.ProductID, &item.Quantity, &item.Price, &item.CreatedAt, &item.UpdatedAt,
		&product.ID, &product.Name, &product.Description, &product.ImageURL, &product.CategoryID, &product.Stock, &product.SKU, &product.IsActive, &product.CreatedAt, &product.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	productResponse := models.ProductResponse{
		ID:          product.ID,
		Name:        product.Name,
		Description: product.Description,
		Price:       product.Price,
		CategoryID:  product.CategoryID,
		Stock:       product.Stock,
		ImageURL:    product.ImageURL,
		SKU:         product.SKU,
		IsActive:    product.IsActive,
		CreatedAt:   product.CreatedAt,
		UpdatedAt:   product.UpdatedAt,
	}

	return &models.CartItemResponse{
		ID:        item.ID,
		UserID:    item.UserID,
		ProductID: item.ProductID,
		Product:   productResponse,
		Quantity:  item.Quantity,
		Price:     item.Price,
		Total:     item.Price * float64(item.Quantity),
		CreatedAt: item.CreatedAt,
		UpdatedAt: item.UpdatedAt,
	}, nil
}

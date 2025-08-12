package handlers

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"api-go/models"

	"github.com/gin-gonic/gin"
)

// OrderHandler обрабатывает запросы для работы с заказами
type OrderHandler struct {
	db *sql.DB
}

// NewOrderHandler создает новый экземпляр OrderHandler
func NewOrderHandler(db *sql.DB) *OrderHandler {
	return &OrderHandler{
		db: db,
	}
}

// CreateOrder создает новый заказ
// @Summary Создание заказа
// @Description Создает новый заказ для аутентифицированного пользователя
// @Tags orders
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param order body models.OrderCreateRequest true "Данные заказа"
// @Success 201 {object} models.OrderResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/orders [post]
func (h *OrderHandler) CreateOrder(c *gin.Context) {
	var req models.OrderCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	// Получаем ID пользователя из JWT токена
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Начинаем транзакцию
	tx, err := h.db.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка базы данных"})
		return
	}
	defer tx.Rollback()

	// Создаем заказ
	var orderID int
	err = tx.QueryRow(`
		INSERT INTO orders (user_id, status, total_amount, shipping_address, billing_address, payment_method)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, userID, models.OrderStatusPending, 0, req.ShippingAddress, req.BillingAddress, req.PaymentMethod).Scan(&orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка создания заказа"})
		return
	}

	var totalAmount float64

	// Добавляем товары в заказ
	for _, item := range req.Items {
		// Получаем информацию о продукте
		var price float64
		var stock int
		err := tx.QueryRow("SELECT price, stock FROM products WHERE id = $1 AND is_active = true", item.ProductID).Scan(&price, &stock)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Продукт с ID %d не найден", item.ProductID)})
			return
		}

		if stock < item.Quantity {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Недостаточно товара для продукта с ID %d", item.ProductID)})
			return
		}

		// Добавляем товар в заказ
		itemTotal := price * float64(item.Quantity)
		totalAmount += itemTotal

		_, err = tx.Exec(`
			INSERT INTO order_items (order_id, product_id, quantity, price, total)
			VALUES ($1, $2, $3, $4, $5)
		`, orderID, item.ProductID, item.Quantity, price, itemTotal)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка добавления товара в заказ"})
			return
		}

		// Обновляем остаток товара
		_, err = tx.Exec("UPDATE products SET stock = stock - $1 WHERE id = $2", item.Quantity, item.ProductID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления остатка товара"})
			return
		}
	}

	// Обновляем общую сумму заказа
	_, err = tx.Exec("UPDATE orders SET total_amount = $1 WHERE id = $2", totalAmount, orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления суммы заказа"})
		return
	}

	// Подтверждаем транзакцию
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка подтверждения заказа"})
		return
	}

	// Получаем созданный заказ
	order, err := h.getOrderByID(orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения заказа"})
		return
	}

	c.JSON(http.StatusCreated, order)
}

// GetOrders получает список заказов пользователя
// @Summary Список заказов пользователя
// @Description Возвращает список заказов для аутентифицированного пользователя
// @Tags orders
// @Produce json
// @Security BearerAuth
// @Param page query int false "Номер страницы" default(1)
// @Param limit query int false "Количество элементов на странице" default(10)
// @Param status query string false "Статус заказа"
// @Success 200 {object} models.OrderListResponse
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/orders [get]
func (h *OrderHandler) GetOrders(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	status := c.Query("status")

	offset := (page - 1) * limit

	// Формируем SQL запрос
	whereClause := "WHERE user_id = $1"
	args := []interface{}{userID}
	argIndex := 2

	if status != "" {
		whereClause += fmt.Sprintf(" AND status = $%d", argIndex)
		args = append(args, status)
		argIndex++
	}

	// Получаем общее количество заказов
	var total int
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM orders %s", whereClause)
	err := h.db.QueryRow(countQuery, args...).Scan(&total)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка подсчета заказов"})
		return
	}

	// Получаем заказы
	query := fmt.Sprintf(`
		SELECT id, user_id, status, total_amount, tax_amount, discount_amount, 
		       shipping_address, billing_address, payment_method, payment_status, 
		       notes, created_at, updated_at
		FROM orders %s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIndex, argIndex+1)

	args = append(args, limit, offset)
	rows, err := h.db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения заказов"})
		return
	}
	defer rows.Close()

	var orders []models.OrderResponse
	for rows.Next() {
		var order models.Order
		err := rows.Scan(
			&order.ID, &order.UserID, &order.Status, &order.TotalAmount,
			&order.TaxAmount, &order.DiscountAmount, &order.ShippingAddress,
			&order.BillingAddress, &order.PaymentMethod, &order.PaymentStatus,
			&order.Notes, &order.CreatedAt, &order.UpdatedAt,
		)
		if err != nil {
			continue
		}

		// Получаем товары заказа
		items, err := h.getOrderItems(order.ID)
		if err != nil {
			continue
		}

		orderResponse := models.OrderResponse{
			ID:              order.ID,
			UserID:          order.UserID,
			Status:          order.Status,
			TotalAmount:     order.TotalAmount,
			TaxAmount:       order.TaxAmount,
			DiscountAmount:  order.DiscountAmount,
			ShippingAddress: order.ShippingAddress,
			BillingAddress:  order.BillingAddress,
			PaymentMethod:   order.PaymentMethod,
			PaymentStatus:   order.PaymentStatus,
			Notes:           order.Notes,
			Items:           items,
			CreatedAt:       order.CreatedAt,
			UpdatedAt:       order.UpdatedAt,
		}

		orders = append(orders, orderResponse)
	}

	response := models.OrderListResponse{
		Orders: orders,
		Total:  total,
		Page:   page,
		Limit:  limit,
	}

	c.JSON(http.StatusOK, response)
}

// GetOrder получает заказ по ID
// @Summary Получение заказа по ID
// @Description Возвращает информацию о заказе по его ID
// @Tags orders
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID заказа"
// @Success 200 {object} models.OrderResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/orders/{id} [get]
func (h *OrderHandler) GetOrder(c *gin.Context) {
	orderID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID заказа"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Проверяем, что заказ принадлежит пользователю
	var orderUserID int
	err = h.db.QueryRow("SELECT user_id FROM orders WHERE id = $1", orderID).Scan(&orderUserID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Заказ не найден"})
		return
	}

	if orderUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Доступ запрещен"})
		return
	}

	order, err := h.getOrderByID(orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения заказа"})
		return
	}

	c.JSON(http.StatusOK, order)
}

// UpdateOrder обновляет заказ
// @Summary Обновление заказа
// @Description Обновляет информацию о заказе (только для админов)
// @Tags orders
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID заказа"
// @Param order body models.OrderUpdateRequest true "Данные для обновления"
// @Success 200 {object} models.OrderResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/orders/{id} [put]
func (h *OrderHandler) UpdateOrder(c *gin.Context) {
	orderID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID заказа"})
		return
	}

	var req models.OrderUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверные данные: " + err.Error()})
		return
	}

	// Проверяем, что заказ существует
	var exists bool
	err = h.db.QueryRow("SELECT EXISTS(SELECT 1 FROM orders WHERE id = $1)", orderID).Scan(&exists)
	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Заказ не найден"})
		return
	}

	// Формируем SQL запрос для обновления
	query := "UPDATE orders SET updated_at = $1"
	args := []interface{}{time.Now()}
	argIndex := 2

	if req.Status != nil {
		query += fmt.Sprintf(", status = $%d", argIndex)
		args = append(args, *req.Status)
		argIndex++
	}

	if req.ShippingAddress != nil {
		query += fmt.Sprintf(", shipping_address = $%d", argIndex)
		args = append(args, *req.ShippingAddress)
		argIndex++
	}

	if req.BillingAddress != nil {
		query += fmt.Sprintf(", billing_address = $%d", argIndex)
		args = append(args, *req.BillingAddress)
		argIndex++
	}

	if req.PaymentStatus != nil {
		query += fmt.Sprintf(", payment_status = $%d", argIndex)
		args = append(args, *req.PaymentStatus)
		argIndex++
	}

	if req.Notes != nil {
		query += fmt.Sprintf(", notes = $%d", argIndex)
		args = append(args, *req.Notes)
		argIndex++
	}

	query += " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, orderID)

	_, err = h.db.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка обновления заказа"})
		return
	}

	// Получаем обновленный заказ
	order, err := h.getOrderByID(orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения заказа"})
		return
	}

	c.JSON(http.StatusOK, order)
}

// CancelOrder отменяет заказ
// @Summary Отмена заказа
// @Description Отменяет заказ (только для владельца заказа)
// @Tags orders
// @Produce json
// @Security BearerAuth
// @Param id path int true "ID заказа"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/v1/orders/{id}/cancel [post]
func (h *OrderHandler) CancelOrder(c *gin.Context) {
	orderID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Неверный ID заказа"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Пользователь не аутентифицирован"})
		return
	}

	// Проверяем, что заказ принадлежит пользователю
	var orderUserID int
	var status string
	err = h.db.QueryRow("SELECT user_id, status FROM orders WHERE id = $1", orderID).Scan(&orderUserID, &status)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Заказ не найден"})
		return
	}

	if orderUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Доступ запрещен"})
		return
	}

	// Проверяем, что заказ можно отменить
	if status != string(models.OrderStatusPending) && status != string(models.OrderStatusConfirmed) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Заказ нельзя отменить в текущем статусе"})
		return
	}

	// Начинаем транзакцию
	tx, err := h.db.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка базы данных"})
		return
	}
	defer tx.Rollback()

	// Отменяем заказ
	_, err = tx.Exec("UPDATE orders SET status = $1, updated_at = $2 WHERE id = $3",
		models.OrderStatusCancelled, time.Now(), orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка отмены заказа"})
		return
	}

	// Возвращаем товары на склад
	rows, err := tx.Query("SELECT product_id, quantity FROM order_items WHERE order_id = $1", orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка получения товаров заказа"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var productID, quantity int
		if err := rows.Scan(&productID, &quantity); err != nil {
			continue
		}

		_, err = tx.Exec("UPDATE products SET stock = stock + $1 WHERE id = $2", quantity, productID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка возврата товара на склад"})
			return
		}
	}

	// Подтверждаем транзакцию
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ошибка подтверждения отмены заказа"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Заказ успешно отменен"})
}

// Вспомогательные методы

// getOrderByID получает заказ по ID с товарами
func (h *OrderHandler) getOrderByID(orderID int) (*models.OrderResponse, error) {
	var order models.Order
	err := h.db.QueryRow(`
		SELECT id, user_id, status, total_amount, tax_amount, discount_amount,
		       shipping_address, billing_address, payment_method, payment_status,
		       notes, created_at, updated_at
		FROM orders WHERE id = $1
	`, orderID).Scan(
		&order.ID, &order.UserID, &order.Status, &order.TotalAmount,
		&order.TaxAmount, &order.DiscountAmount, &order.ShippingAddress,
		&order.BillingAddress, &order.PaymentMethod, &order.PaymentStatus,
		&order.Notes, &order.CreatedAt, &order.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	items, err := h.getOrderItems(orderID)
	if err != nil {
		return nil, err
	}

	return &models.OrderResponse{
		ID:              order.ID,
		UserID:          order.UserID,
		Status:          order.Status,
		TotalAmount:     order.TotalAmount,
		TaxAmount:       order.TaxAmount,
		DiscountAmount:  order.DiscountAmount,
		ShippingAddress: order.ShippingAddress,
		BillingAddress:  order.BillingAddress,
		PaymentMethod:   order.PaymentMethod,
		PaymentStatus:   order.PaymentStatus,
		Notes:           order.Notes,
		Items:           items,
		CreatedAt:       order.CreatedAt,
		UpdatedAt:       order.UpdatedAt,
	}, nil
}

// getOrderItems получает товары заказа
func (h *OrderHandler) getOrderItems(orderID int) ([]models.OrderItemResponse, error) {
	rows, err := h.db.Query(`
		SELECT oi.id, oi.order_id, oi.product_id, oi.quantity, oi.price, oi.discount, oi.total,
		       p.name, p.description, p.image_url, p.category_id, p.stock, p.sku, p.is_active, p.created_at, p.updated_at
		FROM order_items oi
		JOIN products p ON oi.product_id = p.id
		WHERE oi.order_id = $1
	`, orderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.OrderItemResponse
	for rows.Next() {
		var item models.OrderItem
		var product models.Product
		err := rows.Scan(
			&item.ID, &item.OrderID, &item.ProductID, &item.Quantity, &item.Price, &item.Discount, &item.Total,
			&product.Name, &product.Description, &product.ImageURL, &product.CategoryID, &product.Stock, &product.SKU, &product.IsActive, &product.CreatedAt, &product.UpdatedAt,
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

		itemResponse := models.OrderItemResponse{
			ID:        item.ID,
			OrderID:   item.OrderID,
			ProductID: item.ProductID,
			Product:   productResponse,
			Quantity:  item.Quantity,
			Price:     item.Price,
			Discount:  item.Discount,
			Total:     item.Total,
		}

		items = append(items, itemResponse)
	}

	return items, nil
}

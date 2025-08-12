package models

import (
	"time"
)

// OrderStatus статус заказа
type OrderStatus string

const (
	OrderStatusPending    OrderStatus = "pending"    // Ожидает подтверждения
	OrderStatusConfirmed  OrderStatus = "confirmed"  // Подтвержден
	OrderStatusProcessing OrderStatus = "processing" // В обработке
	OrderStatusShipped    OrderStatus = "shipped"    // Отправлен
	OrderStatusDelivered  OrderStatus = "delivered"  // Доставлен
	OrderStatusCancelled  OrderStatus = "cancelled"  // Отменен
	OrderStatusRefunded   OrderStatus = "refunded"   // Возвращен
)

// Order представляет заказ
type Order struct {
	ID              int         `json:"id" db:"id"`
	UserID          int         `json:"user_id" db:"user_id"`
	Status          OrderStatus `json:"status" db:"status"`
	TotalAmount     float64     `json:"total_amount" db:"total_amount"`
	TaxAmount       float64     `json:"tax_amount" db:"tax_amount"`
	DiscountAmount  float64     `json:"discount_amount" db:"discount_amount"`
	ShippingAddress string      `json:"shipping_address" db:"shipping_address"`
	BillingAddress  string      `json:"billing_address" db:"billing_address"`
	PaymentMethod   string      `json:"payment_method" db:"payment_method"`
	PaymentStatus   string      `json:"payment_status" db:"payment_status"`
	Notes           string      `json:"notes" db:"notes"`
	CreatedAt       time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time   `json:"updated_at" db:"updated_at"`
}

// OrderItem представляет товар в заказе
type OrderItem struct {
	ID        int     `json:"id" db:"id"`
	OrderID   int     `json:"order_id" db:"order_id"`
	ProductID int     `json:"product_id" db:"product_id"`
	Quantity  int     `json:"quantity" db:"quantity"`
	Price     float64 `json:"price" db:"price"`
	Discount  float64 `json:"discount" db:"discount"`
	Total     float64 `json:"total" db:"total"`
}

// OrderCreateRequest запрос на создание заказа
type OrderCreateRequest struct {
	Items           []OrderItemRequest `json:"items" binding:"required,min=1"`
	ShippingAddress string             `json:"shipping_address" binding:"required"`
	BillingAddress  string             `json:"billing_address" binding:"required"`
	PaymentMethod   string             `json:"payment_method" binding:"required"`
	Notes           string             `json:"notes"`
}

// OrderItemRequest запрос на добавление товара в заказ
type OrderItemRequest struct {
	ProductID int `json:"product_id" binding:"required"`
	Quantity  int `json:"quantity" binding:"required,min=1"`
}

// OrderUpdateRequest запрос на обновление заказа
type OrderUpdateRequest struct {
	Status          *OrderStatus `json:"status"`
	ShippingAddress *string      `json:"shipping_address"`
	BillingAddress  *string      `json:"billing_address"`
	PaymentStatus   *string      `json:"payment_status"`
	Notes           *string      `json:"notes"`
}

// OrderResponse ответ с информацией о заказе
type OrderResponse struct {
	ID              int                 `json:"id"`
	UserID          int                 `json:"user_id"`
	Status          OrderStatus         `json:"status"`
	TotalAmount     float64             `json:"total_amount"`
	TaxAmount       float64             `json:"tax_amount"`
	DiscountAmount  float64             `json:"discount_amount"`
	ShippingAddress string              `json:"shipping_address"`
	BillingAddress  string              `json:"billing_address"`
	PaymentMethod   string              `json:"payment_method"`
	PaymentStatus   string              `json:"payment_status"`
	Notes           string              `json:"notes"`
	Items           []OrderItemResponse `json:"items"`
	CreatedAt       time.Time           `json:"created_at"`
	UpdatedAt       time.Time           `json:"updated_at"`
}

// OrderItemResponse ответ с информацией о товаре в заказе
type OrderItemResponse struct {
	ID        int             `json:"id"`
	OrderID   int             `json:"order_id"`
	ProductID int             `json:"product_id"`
	Product   ProductResponse `json:"product"`
	Quantity  int             `json:"quantity"`
	Price     float64         `json:"price"`
	Discount  float64         `json:"discount"`
	Total     float64         `json:"total"`
}

// OrderListResponse ответ со списком заказов
type OrderListResponse struct {
	Orders []OrderResponse `json:"orders"`
	Total  int             `json:"total"`
	Page   int             `json:"page"`
	Limit  int             `json:"limit"`
}

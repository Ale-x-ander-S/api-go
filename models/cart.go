package models

import (
	"time"
)

// CartItem представляет товар в корзине
type CartItem struct {
	ID        int       `json:"id" db:"id"`
	UserID    int       `json:"user_id" db:"user_id"`
	ProductID int       `json:"product_id" db:"product_id"`
	Quantity  int       `json:"quantity" db:"quantity"`
	Price     float64   `json:"price" db:"price"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// CartItemRequest запрос на добавление товара в корзину
type CartItemRequest struct {
	ProductID int `json:"product_id" binding:"required"`
	Quantity  int `json:"quantity" binding:"required,min=1"`
}

// CartItemUpdateRequest запрос на обновление товара в корзине
type CartItemUpdateRequest struct {
	Quantity int `json:"quantity" binding:"required,min=1"`
}

// CartItemResponse ответ с информацией о товаре в корзине
type CartItemResponse struct {
	ID        int             `json:"id"`
	UserID    int             `json:"user_id"`
	ProductID int             `json:"product_id"`
	Product   ProductResponse `json:"product"`
	Quantity  int             `json:"quantity"`
	Price     float64         `json:"price"`
	Total     float64         `json:"total"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

// CartResponse ответ с информацией о корзине
type CartResponse struct {
	Items      []CartItemResponse `json:"items"`
	TotalItems int                `json:"total_items"`
	TotalPrice float64            `json:"total_price"`
	ItemCount  int                `json:"item_count"`
}

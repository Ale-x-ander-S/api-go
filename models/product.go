package models

import (
	"time"
)

// Product представляет продукт в системе
type Product struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name" binding:"required"`
	Description string    `json:"description" db:"description"`
	Price       float64   `json:"price" db:"price" binding:"required,gt=0"`
	Category    string    `json:"category" db:"category"`
	Stock       int       `json:"stock" db:"stock" binding:"gte=0"`
	ImageURL    string    `json:"image_url" db:"image_url"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// ProductCreateRequest представляет запрос на создание продукта
type ProductCreateRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description string  `json:"description"`
	Price       float64 `json:"price" binding:"required,gt=0"`
	Category    string  `json:"category"`
	Stock       int     `json:"stock" binding:"gte=0"`
	ImageURL    string  `json:"image_url"`
}

// ProductUpdateRequest представляет запрос на обновление продукта
type ProductUpdateRequest struct {
	Name        *string  `json:"name"`
	Description *string  `json:"description"`
	Price       *float64 `json:"price" binding:"omitempty,gt=0"`
	Category    *string  `json:"category"`
	Stock       *int     `json:"stock" binding:"omitempty,gte=0"`
	ImageURL    *string  `json:"image_url"`
}

// ProductResponse представляет ответ с продуктом
type ProductResponse struct {
	ID          int       `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Price       float64   `json:"price"`
	Category    string    `json:"category"`
	Stock       int       `json:"stock"`
	ImageURL    string    `json:"image_url"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

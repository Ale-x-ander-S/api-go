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
	CategoryID  *int      `json:"category_id" db:"category_id"`
	Stock       int       `json:"stock" db:"stock" binding:"gte=0"`
	ImageURL    string    `json:"image_url" db:"image_url"`
	SKU         string    `json:"sku" db:"sku"`
	Weight      *float64  `json:"weight" db:"weight"`
	Dimensions  string    `json:"dimensions" db:"dimensions"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	IsFeatured  bool      `json:"is_featured" db:"is_featured"`
	SortOrder   int       `json:"sort_order" db:"sort_order"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// ProductCreateRequest представляет запрос на создание продукта
type ProductCreateRequest struct {
	Name        string   `json:"name" binding:"required"`
	Description string   `json:"description"`
	Price       float64  `json:"price" binding:"required,gt=0"`
	CategoryID  *int     `json:"category_id"`
	Stock       int      `json:"stock" binding:"gte=0"`
	ImageURL    string   `json:"image_url"`
	SKU         string   `json:"sku"`
	Weight      *float64 `json:"weight"`
	Dimensions  string   `json:"dimensions"`
	IsActive    bool     `json:"is_active"`
	IsFeatured  bool     `json:"is_featured"`
	SortOrder   int      `json:"sort_order"`
}

// ProductUpdateRequest представляет запрос на обновление продукта
type ProductUpdateRequest struct {
	Name        *string  `json:"name"`
	Description *string  `json:"description"`
	Price       *float64 `json:"price" binding:"omitempty,gt=0"`
	CategoryID  *int     `json:"category_id"`
	Stock       *int     `json:"stock" binding:"omitempty,gte=0"`
	ImageURL    *string  `json:"image_url"`
	SKU         *string  `json:"sku"`
	Weight      *float64 `json:"weight"`
	Dimensions  *string  `json:"dimensions"`
	IsActive    *bool    `json:"is_active"`
	IsFeatured  *bool    `json:"is_featured"`
	SortOrder   *int     `json:"sort_order"`
}

// ProductResponse представляет ответ с продуктом
type ProductResponse struct {
	ID           int       `json:"id"`
	Name         string    `json:"name"`
	Description  string    `json:"description"`
	Price        float64   `json:"price"`
	CategoryID   *int      `json:"category_id"`
	CategorySlug string    `json:"category_slug,omitempty"`
	Stock        int       `json:"stock"`
	ImageURL     string    `json:"image_url"`
	SKU          string    `json:"sku"`
	Weight       *float64  `json:"weight"`
	Dimensions   string    `json:"dimensions"`
	IsActive     bool      `json:"is_active"`
	IsFeatured   bool      `json:"is_featured"`
	SortOrder    int       `json:"sort_order"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ProductListResponse представляет ответ со списком продуктов
type ProductListResponse struct {
	Products []ProductResponse `json:"products"`
	Total    int               `json:"total"`
	Page     int               `json:"page"`
	Limit    int               `json:"limit"`
}

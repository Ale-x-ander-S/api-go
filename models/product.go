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
	StockType   string    `json:"stock_type" db:"stock_type"`
	ImageURL    string    `json:"image_url" db:"image_url"`
	SKU         string    `json:"sku" db:"sku"`
	Color       string    `json:"color" db:"color"`
	Size        string    `json:"size" db:"size"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	IsFeatured  bool      `json:"is_featured" db:"is_featured"`
	SortOrder   int       `json:"sort_order" db:"sort_order"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// ProductCreateRequest представляет запрос на создание продукта
type ProductCreateRequest struct {
	Name        string  `json:"name" binding:"required" example:"iPhone 15 Pro"`
	Description string  `json:"description" example:"Смартфон Apple с чипом A17 Pro"`
	Price       float64 `json:"price" binding:"required,gt=0" example:"999.99"`
	CategoryID  *int    `json:"category_id" example:"1"`
	Stock       int     `json:"stock" binding:"gte=0" example:"50"`
	StockType   string  `json:"stock_type" example:"piece"`
	ImageURL    string  `json:"image_url" example:"https://example.com/iphone15.jpg"`
	SKU         string  `json:"sku" example:"IPHONE15-PRO"`
	Color       string  `json:"color" example:"Titanium"`
	Size        string  `json:"size" example:"6.1 inch"`
	IsActive    bool    `json:"is_active" example:"true"`
	IsFeatured  bool    `json:"is_featured" example:"true"`
	SortOrder   int     `json:"sort_order" example:"1"`
}

// ProductUpdateRequest представляет запрос на обновление продукта
type ProductUpdateRequest struct {
	Name        *string  `json:"name" example:"iPhone 15 Pro Updated"`
	Description *string  `json:"description" example:"Обновленное описание продукта"`
	Price       *float64 `json:"price" binding:"omitempty,gt=0" example:"899.99"`
	CategoryID  *int     `json:"category_id" example:"1"`
	Stock       *int     `json:"stock" binding:"omitempty,gte=0" example:"45"`
	StockType   *string  `json:"stock_type" example:"piece"`
	ImageURL    *string  `json:"image_url" example:"https://example.com/iphone15-updated.jpg"`
	SKU         *string  `json:"sku" example:"IPHONE15-PRO-UPD"`
	Color       *string  `json:"color" example:"Titanium"`
	Size        *string  `json:"size" example:"6.1 inch"`
	IsActive    *bool    `json:"is_active" example:"true"`
	IsFeatured  *bool    `json:"is_featured" example:"false"`
	SortOrder   *int     `json:"sort_order" example:"2"`
}

// ProductResponse представляет ответ с продуктом
type ProductResponse struct {
	ID           int       `json:"id" example:"1"`
	Name         string    `json:"name" example:"iPhone 15 Pro"`
	Description  string    `json:"description" example:"Смартфон Apple с чипом A17 Pro"`
	Price        float64   `json:"price" example:"999.99"`
	CategoryID   *int      `json:"category_id" example:"1"`
	CategorySlug string    `json:"category_slug,omitempty" example:"smartphones"`
	Stock        int       `json:"stock" example:"50"`
	StockType    string    `json:"stock_type" example:"piece"`
	ImageURL     string    `json:"image_url" example:"https://example.com/iphone15.jpg"`
	SKU          string    `json:"sku" example:"IPHONE15-PRO"`
	Color        string    `json:"color" example:"Titanium"`
	Size         string    `json:"size" example:"6.1 inch"`
	IsActive     bool      `json:"is_active" example:"true"`
	IsFeatured   bool      `json:"is_featured" example:"true"`
	SortOrder    int       `json:"sort_order" example:"1"`
	CreatedAt    time.Time `json:"created_at" example:"2025-08-15T10:00:00Z"`
	UpdatedAt    time.Time `json:"updated_at" example:"2025-08-15T10:00:00Z"`
}

// ProductListResponse представляет ответ со списком продуктов
type ProductListResponse struct {
	Products []ProductResponse `json:"products"`
	Total    int               `json:"total" example:"100"`
	Page     int               `json:"page" example:"1"`
	Limit    int               `json:"limit" example:"10"`
}

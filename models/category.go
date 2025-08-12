package models

import (
	"time"
)

// Category представляет категорию товаров
type Category struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	Slug        string    `json:"slug" db:"slug"`
	ImageURL    string    `json:"image_url" db:"image_url"`
	ParentID    *int      `json:"parent_id" db:"parent_id"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	SortOrder   int       `json:"sort_order" db:"sort_order"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// CategoryCreateRequest запрос на создание категории
type CategoryCreateRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
	Slug        string `json:"slug" binding:"required"`
	ImageURL    string `json:"image_url"`
	ParentID    *int   `json:"parent_id"`
	IsActive    bool   `json:"is_active"`
	SortOrder   int    `json:"sort_order"`
}

// CategoryUpdateRequest запрос на обновление категории
type CategoryUpdateRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Slug        *string `json:"slug"`
	ImageURL    *string `json:"image_url"`
	ParentID    *int    `json:"parent_id"`
	IsActive    *bool   `json:"is_active"`
	SortOrder   *int    `json:"sort_order"`
}

// CategoryResponse ответ с информацией о категории
type CategoryResponse struct {
	ID           int       `json:"id"`
	Name         string    `json:"name"`
	Description  string    `json:"description"`
	Slug         string    `json:"slug"`
	ImageURL     string    `json:"image_url"`
	ParentID     *int      `json:"parent_id"`
	IsActive     bool      `json:"is_active"`
	SortOrder    int       `json:"sort_order"`
	ProductCount int       `json:"product_count"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// CategoryTreeResponse ответ с древовидной структурой категорий
type CategoryTreeResponse struct {
	Category CategoryResponse   `json:"category"`
	Children []CategoryResponse `json:"children"`
	Products []ProductResponse  `json:"products"`
}

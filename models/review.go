package models

import (
	"time"
)

// Review представляет отзыв о товаре
type Review struct {
	ID         int       `json:"id" db:"id"`
	UserID     int       `json:"user_id" db:"user_id"`
	ProductID  int       `json:"product_id" db:"product_id"`
	Rating     int       `json:"rating" db:"rating"`
	Title      string    `json:"title" db:"title"`
	Comment    string    `json:"comment" db:"comment"`
	IsVerified bool      `json:"is_verified" db:"is_verified"`
	IsActive   bool      `json:"is_active" db:"is_active"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

// ReviewCreateRequest запрос на создание отзыва
type ReviewCreateRequest struct {
	ProductID int    `json:"product_id" binding:"required"`
	Rating    int    `json:"rating" binding:"required,min=1,max=5"`
	Title     string `json:"title" binding:"required,min=3,max=100"`
	Comment   string `json:"comment" binding:"required,min=10,max=1000"`
}

// ReviewUpdateRequest запрос на обновление отзыва
type ReviewUpdateRequest struct {
	Rating   *int    `json:"rating" binding:"omitempty,min=1,max=5"`
	Title    *string `json:"title" binding:"omitempty,min=3,max=100"`
	Comment  *string `json:"comment" binding:"omitempty,min=10,max=1000"`
	IsActive *bool   `json:"is_active"`
}

// ReviewResponse ответ с информацией об отзыве
type ReviewResponse struct {
	ID         int       `json:"id"`
	UserID     int       `json:"user_id"`
	Username   string    `json:"username"`
	ProductID  int       `json:"product_id"`
	Rating     int       `json:"rating"`
	Title      string    `json:"title"`
	Comment    string    `json:"comment"`
	IsVerified bool      `json:"is_verified"`
	IsActive   bool      `json:"is_active"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// ReviewListResponse ответ со списком отзывов
type ReviewListResponse struct {
	Reviews       []ReviewResponse `json:"reviews"`
	Total         int              `json:"total"`
	Page          int              `json:"page"`
	Limit         int              `json:"limit"`
	AverageRating float64          `json:"average_rating"`
}

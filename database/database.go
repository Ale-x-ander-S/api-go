package database

import (
	"database/sql"
	"fmt"
	"log"

	"api-go/config"

	_ "github.com/lib/pq"
)

// Connect устанавливает соединение с базой данных PostgreSQL
func Connect(cfg config.DatabaseConfig) (*sql.DB, error) {
	// Формируем строку подключения
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Name, cfg.SSLMode)

	// Открываем соединение
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("ошибка открытия соединения с БД: %w", err)
	}

	// Проверяем соединение
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ошибка проверки соединения с БД: %w", err)
	}

	log.Println("Успешное подключение к базе данных PostgreSQL")
	return db, nil
}

// InitTables создает необходимые таблицы в базе данных
func InitTables(db *sql.DB) error {
	// SQL для создания таблицы пользователей
	createUsersTable := `
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		username VARCHAR(50) UNIQUE NOT NULL,
		email VARCHAR(100) UNIQUE NOT NULL,
		password VARCHAR(255) NOT NULL,
		role VARCHAR(20) DEFAULT 'user',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`

	// SQL для создания таблицы продуктов
	createProductsTable := `
	CREATE TABLE IF NOT EXISTS products (
		id SERIAL PRIMARY KEY,
		name VARCHAR(200) NOT NULL,
		description TEXT,
		price DECIMAL(10,2) NOT NULL CHECK (price > 0),
		category VARCHAR(100),
		stock INTEGER DEFAULT 0 CHECK (stock >= 0),
		image_url TEXT,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`

	// Создаем таблицы
	if _, err := db.Exec(createUsersTable); err != nil {
		return fmt.Errorf("ошибка создания таблицы users: %w", err)
	}

	if _, err := db.Exec(createProductsTable); err != nil {
		return fmt.Errorf("ошибка создания таблицы products: %w", err)
	}

	log.Println("Таблицы успешно инициализированы")
	return nil
}

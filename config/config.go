package config

import (
	"os"
	"strconv"
)

// Config содержит всю конфигурацию приложения
type Config struct {
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Server   ServerConfig
}

// DatabaseConfig содержит настройки базы данных
type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	Name     string
	SSLMode  string
}

// RedisConfig содержит настройки Redis
type RedisConfig struct {
	Host     string
	Port     int
	Password string
	DB       int
	TTL      int // Время жизни кэша в секундах
}

// JWTConfig содержит настройки JWT
type JWTConfig struct {
	Secret string
}

// ServerConfig содержит настройки сервера
type ServerConfig struct {
	Port string
}

// Load загружает конфигурацию из переменных окружения
func Load() *Config {
	dbPort, _ := strconv.Atoi(getEnv("DB_PORT", "5432"))
	redisPort, _ := strconv.Atoi(getEnv("REDIS_PORT", "6379"))
	redisDB, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))
	redisTTL, _ := strconv.Atoi(getEnv("REDIS_TTL", "3600"))

	return &Config{
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     dbPort,
			User:     getEnv("DB_USER", "postgres"),
			Password: getEnv("DB_PASSWORD", "password"),
			Name:     getEnv("DB_NAME", "products_db"),
			SSLMode:  getEnv("DB_SSL_MODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     redisPort,
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       redisDB,
			TTL:      redisTTL,
		},
		JWT: JWTConfig{
			Secret: getEnv("JWT_SECRET", "default-secret-key"),
		},
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
		},
	}
}

// getEnv получает значение переменной окружения или возвращает значение по умолчанию
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

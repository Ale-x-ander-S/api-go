package database

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"api-go/config"

	"github.com/redis/go-redis/v9"
)

// RedisClient представляет клиент Redis для кэширования
type RedisClient struct {
	client *redis.Client
	cfg    config.RedisConfig
}

// NewRedisClient создает новый Redis клиент
func NewRedisClient(cfg config.RedisConfig) *RedisClient {
	client := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	return &RedisClient{
		client: client,
		cfg:    cfg,
	}
}

// Connect проверяет соединение с Redis
func (r *RedisClient) Connect() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := r.client.Ping(ctx).Result()
	if err != nil {
		return fmt.Errorf("ошибка подключения к Redis: %w", err)
	}

	log.Println("Успешное подключение к Redis")
	return nil
}

// Close закрывает соединение с Redis
func (r *RedisClient) Close() error {
	return r.client.Close()
}

// Set устанавливает значение в кэш
func (r *RedisClient) Set(ctx context.Context, key string, value interface{}) error {
	jsonValue, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("ошибка сериализации значения: %w", err)
	}

	return r.client.Set(ctx, key, jsonValue, time.Duration(r.cfg.TTL)*time.Second).Err()
}

// Get получает значение из кэша
func (r *RedisClient) Get(ctx context.Context, key string, dest interface{}) error {
	val, err := r.client.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return fmt.Errorf("ключ не найден в кэше")
		}
		return fmt.Errorf("ошибка получения из кэша: %w", err)
	}

	return json.Unmarshal([]byte(val), dest)
}

// Delete удаляет ключ из кэша
func (r *RedisClient) Delete(ctx context.Context, key string) error {
	return r.client.Del(ctx, key).Err()
}

// DeletePattern удаляет ключи по паттерну
func (r *RedisClient) DeletePattern(ctx context.Context, pattern string) error {
	keys, err := r.client.Keys(ctx, pattern).Result()
	if err != nil {
		return fmt.Errorf("ошибка поиска ключей по паттерну: %w", err)
	}

	if len(keys) > 0 {
		return r.client.Del(ctx, keys...).Err()
	}

	return nil
}

// Exists проверяет существование ключа
func (r *RedisClient) Exists(ctx context.Context, key string) bool {
	result, err := r.client.Exists(ctx, key).Result()
	if err != nil {
		return false
	}
	return result > 0
}

// GetClient возвращает Redis клиент для прямого доступа
func (r *RedisClient) GetClient() *redis.Client {
	return r.client
}

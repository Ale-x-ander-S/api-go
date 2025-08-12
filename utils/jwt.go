package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims представляет данные, хранящиеся в JWT токене
type Claims struct {
	UserID   int    `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// GenerateToken создает новый JWT токен для пользователя
func GenerateToken(userID int, username, role, secret string, expiryHours int) (string, error) {
	// Создаем claims для токена
	claims := Claims{
		UserID:   userID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(expiryHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "products-api",
			Subject:   username,
		},
	}

	// Создаем токен с claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Подписываем токен секретным ключом
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// ValidateToken проверяет и декодирует JWT токен
func ValidateToken(tokenString, secret string) (*Claims, error) {
	// Парсим токен
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Проверяем алгоритм подписи
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("неожиданный метод подписи")
		}
		return []byte(secret), nil
	})

	if err != nil {
		return nil, err
	}

	// Проверяем, что токен действителен
	if !token.Valid {
		return nil, errors.New("токен недействителен")
	}

	// Извлекаем claims
	claims, ok := token.Claims.(*Claims)
	if !ok {
		return nil, errors.New("не удалось извлечь claims из токена")
	}

	return claims, nil
}

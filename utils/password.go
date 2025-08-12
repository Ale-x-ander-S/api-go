package utils

import (
	"golang.org/x/crypto/bcrypt"
)

// HashPassword создает хеш пароля с использованием bcrypt
func HashPassword(password string) (string, error) {
	// Генерируем хеш с cost 12 (рекомендуемое значение)
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return "", err
	}
	return string(hashedBytes), nil
}

// CheckPasswordHash проверяет, соответствует ли пароль хешу
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

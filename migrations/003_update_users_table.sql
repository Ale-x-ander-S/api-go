-- Миграция 003: Изменение таблицы users для авторизации по email
-- Дата: 2025-08-13

-- Удаляем уникальное ограничение с username
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_username_key;

-- Добавляем уникальное ограничение на email
ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);

-- Обновляем существующих пользователей, если email дублируется
-- (в реальном проекте нужно решить конфликты вручную)
UPDATE users SET email = 'user1@example.com' WHERE id = 1;
UPDATE users SET email = 'user2@example.com' WHERE id = 2;
UPDATE users SET email = 'admin@example.com' WHERE id = 3;

-- Проверяем результат
SELECT id, username, email, role FROM users; 
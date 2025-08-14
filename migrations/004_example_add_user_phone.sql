-- Миграция 2025-01-20: add_user_phone
-- Дата: Mon Jan 20 10:30:00 MSK 2025
-- Описание: Добавление поля phone_number в таблицу users

-- ========================================
-- UP MIGRATION (применение изменений)
-- ========================================

-- Добавляем новую колонку для телефона
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- Добавляем комментарий к колонке
COMMENT ON COLUMN users.phone_number IS 'Номер телефона пользователя';

-- Обновляем существующие записи значением по умолчанию
UPDATE users SET phone_number = 'Не указан' WHERE phone_number IS NULL;

-- Создаем индекс для быстрого поиска по телефону
CREATE INDEX IF NOT EXISTS idx_users_phone_number ON users(phone_number);

-- ========================================
-- DOWN MIGRATION (откат изменений)
-- ========================================

-- Удаляем индекс
-- DROP INDEX IF EXISTS idx_users_phone_number;

-- Удаляем колонку (осторожно!)
-- ALTER TABLE users DROP COLUMN IF EXISTS phone_number;

-- ========================================
-- DATA MIGRATION (если нужно)
-- ========================================

-- Здесь можно добавить логику миграции данных
-- Например, парсинг телефона из других полей или импорт из внешних источников

-- Пример: если у вас есть поле notes с телефоном, можно его распарсить
-- UPDATE users SET phone_number = REGEXP_REPLACE(notes, '.*тел[а-я]*[:\s]*([0-9+\-\(\)\s]+).*', '\1') 
-- WHERE notes ~ 'тел[а-я]*[:\s]*[0-9+\-\(\)\s]+' AND phone_number = 'Не указан';

-- ========================================
-- VERIFICATION (проверка результата)
-- ========================================

-- Проверяем, что колонка добавлена
SELECT COUNT(*) FROM users WHERE phone_number IS NOT NULL;

-- Проверяем, что все пользователи имеют значение в поле phone_number
SELECT COUNT(*) as total_users, 
       COUNT(phone_number) as users_with_phone,
       COUNT(CASE WHEN phone_number != 'Не указан' THEN 1 END) as users_with_real_phone
FROM users;

-- Проверяем индекс
SELECT indexname, tablename, indexdef 
FROM pg_indexes 
WHERE tablename = 'users' AND indexname = 'idx_users_phone_number'; 
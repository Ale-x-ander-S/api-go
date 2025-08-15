-- Миграция 006: Замена полей weight и dimensions на color и size
-- Дата: 2025-01-15

-- Добавляем новые поля
ALTER TABLE products ADD COLUMN IF NOT EXISTS color VARCHAR(50);
ALTER TABLE products ADD COLUMN IF NOT EXISTS size VARCHAR(50);

-- Удаляем старые поля (если они существуют)
ALTER TABLE products DROP COLUMN IF EXISTS weight;
ALTER TABLE products DROP COLUMN IF EXISTS dimensions;

-- Обновляем комментарии к таблице
COMMENT ON COLUMN products.color IS 'Цвет продукта';
COMMENT ON COLUMN products.size IS 'Размер продукта'; 
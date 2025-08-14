-- Миграция 005: Исправление ограничения SKU для продуктов
-- Дата: 2025-01-20
-- Описание: Делаем SKU необязательным и исправляем дублирующиеся ограничения

-- ========================================
-- UP MIGRATION (применение изменений)
-- ========================================

-- Удаляем дублирующийся уникальный индекс (если существует)
DROP INDEX IF EXISTS products_sku_key;

-- Удаляем дублирующийся уникальный индекс (если существует)
DROP INDEX IF EXISTS products_sku_unique;

-- Создаем новый уникальный индекс, который позволяет NULL значения
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku_unique ON products(sku) WHERE sku IS NOT NULL;

-- Добавляем комментарий к ограничению
COMMENT ON INDEX idx_products_sku_unique IS 'Уникальный индекс для SKU, разрешает NULL значения';

-- ========================================
-- DOWN MIGRATION (откат изменений)
-- ========================================

-- Восстанавливаем строгое уникальное ограничение
-- DROP INDEX IF EXISTS idx_products_sku_unique;
-- CREATE UNIQUE INDEX products_sku_key ON products(sku);

-- ========================================
-- DATA MIGRATION (если нужно)
-- ========================================

-- Очищаем дублирующиеся SKU, оставляя только уникальные
-- Это нужно только если у тебя есть дублирующиеся SKU в данных
-- UPDATE products SET sku = NULL WHERE sku IN (
--     SELECT sku FROM products 
--     WHERE sku IS NOT NULL 
--     GROUP BY sku 
--     HAVING COUNT(*) > 1
-- );

-- ========================================
-- VERIFICATION (проверка результата)
-- ========================================

-- Проверяем, что индекс создан правильно
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'products' AND indexname = 'idx_products_sku_unique';

-- Проверяем, что можно создавать продукты без SKU
-- SELECT COUNT(*) FROM products WHERE sku IS NULL; 
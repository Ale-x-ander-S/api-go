-- Миграция 007: Добавление поля stock_type в таблицу products
-- Дата: 2024-12-19

-- Добавляем поле stock_type типа VARCHAR(50) с значением по умолчанию 'piece'
ALTER TABLE products ADD COLUMN stock_type VARCHAR(50) NOT NULL DEFAULT 'piece';

-- Добавляем комментарий к полю
COMMENT ON COLUMN products.stock_type IS 'Тип единицы измерения товара (piece, kg, liter, meter, etc.)';

-- Создаем индекс для оптимизации поиска по типу товара
CREATE INDEX idx_products_stock_type ON products(stock_type); 
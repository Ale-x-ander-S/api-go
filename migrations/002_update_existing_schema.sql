-- Миграция 002: Обновление существующей структуры базы данных
-- Дата: 2025-08-12

-- Добавляем недостающие поля в таблицу users
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- Обновляем таблицу products: заменяем category на category_id
-- Сначала создаем временную таблицу с новой структурой
CREATE TABLE IF NOT EXISTS products_new (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    category_id INTEGER REFERENCES categories(id),
    stock INTEGER DEFAULT 0 CHECK (stock >= 0),
    image_url TEXT,
    sku VARCHAR(100) UNIQUE,
    weight DECIMAL(8,2),
    dimensions VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Копируем данные из старой таблицы
INSERT INTO products_new (id, name, description, price, stock, image_url, created_at, updated_at)
SELECT id, name, description, price, stock, image_url, created_at, updated_at FROM products;

-- Удаляем старую таблицу и переименовываем новую
DROP TABLE products CASCADE;
ALTER TABLE products_new RENAME TO products;

-- Создаем индексы для новой таблицы products
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);

-- Обновляем данные продуктов, устанавливая category_id на основе существующих категорий
UPDATE products SET category_id = 5 WHERE name LIKE '%iPhone%';
UPDATE products SET category_id = 6 WHERE name LIKE '%MacBook%';
UPDATE products SET category_id = 7 WHERE name LIKE '%Футболка%';
UPDATE products SET category_id = 8 WHERE name LIKE '%Платье%';
UPDATE products SET category_id = 3 WHERE name LIKE '%Книга%';
UPDATE products SET category_id = 4 WHERE name LIKE '%мяч%';

-- Добавляем недостающие поля в таблицу products
ALTER TABLE products ADD COLUMN IF NOT EXISTS sku VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS weight DECIMAL(8,2);
ALTER TABLE products ADD COLUMN IF NOT EXISTS dimensions VARCHAR(50);
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- Обновляем SKU для существующих продуктов
UPDATE products SET sku = 'IPHONE15PRO' WHERE name LIKE '%iPhone%';
UPDATE products SET sku = 'MACBOOKAIRM2' WHERE name LIKE '%MacBook%';
UPDATE products SET sku = 'TSHIRT-MEN' WHERE name LIKE '%Футболка%';
UPDATE products SET sku = 'DRESS-WOMEN' WHERE name LIKE '%Платье%';
UPDATE products SET sku = 'BOOK-WAR-PEACE' WHERE name LIKE '%Книга%';
UPDATE products SET sku = 'BALL-FOOTBALL' WHERE name LIKE '%мяч%';

-- Создаем уникальный индекс для SKU
CREATE UNIQUE INDEX IF NOT EXISTS products_sku_key ON products(sku);

-- Обновляем триггер для updated_at
CREATE OR REPLACE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column(); 
-- Инициализация базы данных products_db
-- Этот скрипт выполняется автоматически при первом запуске PostgreSQL контейнера

-- Создаем базу данных (если не существует)
-- В Docker контейнере база уже создана через переменные окружения

-- Создаем таблицу пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создаем таблицу продуктов
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    category VARCHAR(100),
    stock INTEGER DEFAULT 0 CHECK (stock >= 0),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создаем индексы для улучшения производительности
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at);

-- Создаем тестового администратора (пароль: admin123)
-- В продакшене удалите эту строку!
INSERT INTO users (username, email, password, role) 
VALUES ('admin', 'admin@example.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/8QJ8K8O', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Создаем несколько тестовых продуктов
INSERT INTO products (name, description, price, category, stock, image_url) VALUES
('iPhone 15 Pro', 'Современный смартфон с мощным процессором', 999.99, 'Электроника', 50, 'https://example.com/iphone15.jpg'),
('MacBook Air M2', 'Легкий ноутбук с чипом Apple M2', 1299.99, 'Электроника', 25, 'https://example.com/macbook-air.jpg'),
('Nike Air Max', 'Спортивная обувь для бега', 129.99, 'Обувь', 100, 'https://example.com/nike-airmax.jpg'),
('Книга "Go Programming"', 'Руководство по программированию на Go', 49.99, 'Книги', 200, 'https://example.com/go-book.jpg'),
('Кофемашина DeLonghi', 'Автоматическая кофемашина', 299.99, 'Бытовая техника', 15, 'https://example.com/coffee-machine.jpg')
ON CONFLICT (id) DO NOTHING;

-- Создаем триггер для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Применяем триггер к таблице users
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Применяем триггер к таблице products
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Выводим информацию о созданных таблицах
SELECT 'База данных успешно инициализирована!' as status;
SELECT 'Таблицы:' as info;
SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public'; 
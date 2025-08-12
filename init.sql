-- Инициализация базы данных для Products API с интернет-магазином

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы категорий
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    slug VARCHAR(100) UNIQUE NOT NULL,
    image_url VARCHAR(255),
    parent_id INTEGER REFERENCES categories(id),
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы продуктов
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER REFERENCES categories(id),
    stock INTEGER DEFAULT 0,
    image_url VARCHAR(255),
    sku VARCHAR(100) UNIQUE,
    weight DECIMAL(8,2),
    dimensions VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы заказов
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    total_amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    shipping_address TEXT NOT NULL,
    billing_address TEXT NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы товаров в заказе
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) NOT NULL,
    product_id INTEGER REFERENCES products(id) NOT NULL,
    quantity INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы корзины
CREATE TABLE IF NOT EXISTS cart_items (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    product_id INTEGER REFERENCES products(id) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- Создание таблицы отзывов
CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    product_id INTEGER REFERENCES products(id) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(100) NOT NULL,
    comment TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы избранных товаров
CREATE TABLE IF NOT EXISTS wishlist (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    product_id INTEGER REFERENCES products(id) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- Создание таблицы купонов/скидок
CREATE TABLE IF NOT EXISTS coupons (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL,
    min_order_amount DECIMAL(10,2) DEFAULT 0,
    max_discount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы истории заказов
CREATE TABLE IF NOT EXISTS order_history (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) NOT NULL,
    status VARCHAR(20) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание индексов для оптимизации
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug);

-- Создание триггеров для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cart_items_updated_at BEFORE UPDATE ON cart_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_coupons_updated_at BEFORE UPDATE ON coupons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Вставка тестовых данных

-- Тестовый администратор
INSERT INTO users (username, email, password, role, first_name, last_name) VALUES 
('admin', 'admin@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'Admin', 'User')
ON CONFLICT (username) DO NOTHING;

-- Тестовый пользователь
INSERT INTO users (username, email, password, role, first_name, last_name) VALUES 
('testuser', 'user@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'user', 'Test', 'User')
ON CONFLICT (username) DO NOTHING;

-- Категории
INSERT INTO categories (name, description, slug, sort_order) VALUES 
('Электроника', 'Электронные устройства и гаджеты', 'electronics', 1),
('Одежда', 'Мужская и женская одежда', 'clothing', 2),
('Книги', 'Художественная и техническая литература', 'books', 3),
('Спорт', 'Спортивные товары и оборудование', 'sports', 4)
ON CONFLICT (slug) DO NOTHING;

-- Подкатегории
INSERT INTO categories (name, description, slug, parent_id, sort_order) VALUES 
('Смартфоны', 'Мобильные телефоны', 'smartphones', 1, 1),
('Ноутбуки', 'Портативные компьютеры', 'laptops', 1, 2),
('Мужская одежда', 'Одежда для мужчин', 'mens-clothing', 2, 1),
('Женская одежда', 'Одежда для женщин', 'womens-clothing', 2, 2)
ON CONFLICT (slug) DO NOTHING;

-- Продукты
INSERT INTO products (name, description, price, category_id, stock, sku, is_featured) VALUES 
('iPhone 15 Pro', 'Новейший смартфон Apple с мощным процессором', 99999.99, 5, 50, 'IPHONE15PRO', true),
('MacBook Air M2', 'Легкий и мощный ноутбук с чипом M2', 149999.99, 6, 25, 'MACBOOKAIRM2', true),
('Футболка мужская', 'Хлопковая футболка для повседневной носки', 2999.99, 7, 100, 'TSHIRT-MENS', false),
('Платье женское', 'Элегантное платье для особых случаев', 5999.99, 8, 75, 'DRESS-WOMENS', false),
('Книга "Война и мир"', 'Классический роман Льва Толстого', 899.99, 3, 200, 'BOOK-WAR-PEACE', false),
('Футбольный мяч', 'Профессиональный футбольный мяч', 3999.99, 4, 30, 'BALL-FOOTBALL', false)
ON CONFLICT (sku) DO NOTHING;

-- Тестовые отзывы
INSERT INTO reviews (user_id, product_id, rating, title, comment, is_verified) VALUES 
(2, 1, 5, 'Отличный телефон!', 'Очень доволен покупкой. Камера работает великолепно, батарея держит долго.', true),
(2, 2, 4, 'Хороший ноутбук', 'Мощный и легкий. Единственный минус - высокая цена.', true),
(2, 3, 5, 'Качественная футболка', 'Материал приятный, размер соответствует.', true)
ON CONFLICT DO NOTHING;

-- Тестовые купоны
INSERT INTO coupons (code, description, discount_type, discount_value, min_order_amount, usage_limit, valid_until) VALUES 
('WELCOME10', 'Скидка 10% для новых клиентов', 'percentage', 10.00, 5000.00, 100, CURRENT_TIMESTAMP + INTERVAL '30 days'),
('SAVE500', 'Скидка 500 рублей на заказ от 10000', 'fixed', 500.00, 10000.00, 50, CURRENT_TIMESTAMP + INTERVAL '60 days')
ON CONFLICT (code) DO NOTHING;

-- Создание представления для статистики продуктов
CREATE OR REPLACE VIEW product_stats AS
SELECT 
    p.id,
    p.name,
    p.price,
    p.stock,
    c.name as category_name,
    COUNT(r.id) as review_count,
    COALESCE(AVG(r.rating), 0) as average_rating,
    COUNT(oi.id) as order_count,
    COALESCE(SUM(oi.quantity), 0) as total_sold
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN reviews r ON p.id = r.product_id AND r.is_active = true
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status IN ('confirmed', 'processing', 'shipped', 'delivered')
GROUP BY p.id, p.name, p.price, p.stock, c.name;

-- Создание представления для корзины пользователя
CREATE OR REPLACE VIEW user_cart AS
SELECT 
    ci.id,
    ci.user_id,
    ci.product_id,
    ci.quantity,
    ci.price,
    p.name as product_name,
    p.image_url,
    p.stock,
    (ci.quantity * ci.price) as total_price
FROM cart_items ci
JOIN products p ON ci.product_id = p.id
WHERE p.is_active = true AND p.stock > 0;

-- Создание представления для заказов пользователя
CREATE OR REPLACE VIEW user_orders AS
SELECT 
    o.id,
    o.user_id,
    o.status,
    o.total_amount,
    o.created_at,
    COUNT(oi.id) as item_count,
    STRING_AGG(p.name, ', ') as product_names
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
GROUP BY o.id, o.user_id, o.status, o.total_amount, o.created_at; 
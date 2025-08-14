#!/bin/bash

# Скрипт генерации production конфигурации
# Генерирует безопасные пароли и ключи

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log_info "🔐 Генерация production конфигурации..."

# Генерируем безопасные пароли
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)

# Создаем production конфигурацию
cat > config.prod.env << EOF
# База данных PostgreSQL (Production)
DB_HOST=postgres
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=products_db_prod
DB_SSL_MODE=require

# Redis для кэширования (Production)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=0
REDIS_TTL=3600

# JWT настройки (Production)
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_DAYS=7

# Сервер (Production)
SERVER_PORT=8080

# Окружение
ENVIRONMENT=production
LOG_LEVEL=warn
EOF

log_success "✅ Production конфигурация создана в config.prod.env"
log_info "📝 Сохраните эти пароли в безопасном месте:"
echo ""
echo "DB_PASSWORD: ${DB_PASSWORD}"
echo "REDIS_PASSWORD: ${REDIS_PASSWORD}"
echo "JWT_SECRET: ${JWT_SECRET}"
echo ""

# Создаем .env файл для docker-compose
cat > .env << EOF
# Production environment variables
DB_PASSWORD=${DB_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
JWT_SECRET=${JWT_SECRET}
EOF

log_success "✅ .env файл создан для docker-compose"
log_warning "⚠️  Не забудьте добавить .env в .gitignore!" 
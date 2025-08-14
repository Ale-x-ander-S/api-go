#!/bin/bash

# Скрипт проверки конфигурации
# Проверяет все env файлы и docker-compose конфигурации

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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔍 Проверка конфигурации проекта..."
echo ""

# Проверка env файлов
check_env_file() {
    local file=$1
    local env_name=$2
    
    if [ -f "$file" ]; then
        log_success "✅ $env_name: $file"
        
        # Проверка обязательных переменных
        local missing_vars=()
        
        while IFS= read -r line; do
            # Пропускаем комментарии и пустые строки
            if [[ $line =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                continue
            fi
            
            # Извлекаем имя переменной
            var_name=$(echo "$line" | cut -d'=' -f1)
            
            # Проверяем что переменная не пустая
            if [[ $line =~ ^[[:space:]]*[A-Z_]+=[[:space:]]*$ ]]; then
                missing_vars+=("$var_name")
            fi
        done < "$file"
        
        if [ ${#missing_vars[@]} -ne 0 ]; then
            log_warning "⚠️  Пустые переменные в $env_name:"
            printf '   %s\n' "${missing_vars[@]}"
        fi
        
    else
        log_error "❌ $env_name: $file не найден"
    fi
}

# Проверка docker-compose файлов
check_docker_compose() {
    local file=$1
    local env_name=$2
    
    if [ -f "$file" ]; then
        log_success "✅ $env_name: $file"
        
        # Проверка синтаксиса
        if docker-compose -f "$file" config > /dev/null 2>&1; then
            log_success "   Синтаксис корректный"
        else
            log_error "   ❌ Ошибка синтаксиса"
        fi
        
    else
        log_error "❌ $env_name: $file не найден"
    fi
}

# Проверяем все env файлы
log_info "📁 Проверка файлов конфигурации:"
check_env_file "config.dev.env" "Development"
check_env_file "config.staging.env" "Staging"
check_env_file "config.prod.env" "Production"
echo ""

# Проверяем docker-compose файлы
log_info "🐳 Проверка Docker Compose файлов:"
check_docker_compose "docker-compose.yml" "Development"
check_docker_compose "docker-compose.staging.yml" "Staging"
check_docker_compose "docker-compose.prod.yml" "Production"
echo ""

# Проверка портов
log_info "🔌 Проверка портов:"
ports_dev=$(grep -o '"[0-9]\+:[0-9]\+"' docker-compose.yml | head -1 | tr -d '"' | cut -d':' -f1 2>/dev/null || echo "8080")
ports_staging=$(grep -o '"[0-9]\+:[0-9]\+"' docker-compose.staging.yml | head -1 | tr -d '"' | cut -d':' -f1 2>/dev/null || echo "8081")
ports_prod=$(grep -o '"[0-9]\+:[0-9]\+"' docker-compose.prod.yml | head -1 | tr -d '"' | cut -d':' -f1 2>/dev/null || echo "8082")

echo "   Development: порт $ports_dev"
echo "   Staging: порт $ports_staging"
echo "   Production: порт $ports_prod"

# Проверка на конфликты портов
if [ "$ports_dev" = "$ports_staging" ] || [ "$ports_dev" = "$ports_prod" ] || [ "$ports_staging" = "$ports_prod" ]; then
    log_warning "⚠️  Обнаружены конфликты портов!"
fi
echo ""

# Проверка безопасности
log_info "🔒 Проверка безопасности:"
if [ -f "config.prod.env" ]; then
    # Проверка JWT секрета
    jwt_secret=$(grep "^JWT_SECRET=" config.prod.env | cut -d'=' -f2)
    if [ ${#jwt_secret} -lt 30 ]; then
        log_warning "⚠️  JWT_SECRET слишком короткий (${#jwt_secret} символов)"
    else
        log_success "✅ JWT_SECRET достаточной длины"
    fi
    
    # Проверка паролей
    db_password=$(grep "^DB_PASSWORD=" config.prod.env | cut -d'=' -f2)
    if [ "$db_password" = "CHANGE_THIS_PASSWORD_IN_PRODUCTION" ]; then
        log_warning "⚠️  DB_PASSWORD не изменен с дефолтного значения"
    else
        log_success "✅ DB_PASSWORD изменен"
    fi
    
    redis_password=$(grep "^REDIS_PASSWORD=" config.prod.env | cut -d'=' -f2)
    if [ "$redis_password" = "CHANGE_THIS_REDIS_PASSWORD" ]; then
        log_warning "⚠️  REDIS_PASSWORD не изменен с дефолтного значения"
    else
        log_success "✅ REDIS_PASSWORD изменен"
    fi
else
    log_warning "⚠️  config.prod.env не найден - проверка безопасности пропущена"
fi
echo ""

# Итоговая оценка
log_info "📊 Итоговая оценка:"
if [ -f "config.dev.env" ] && [ -f "config.staging.env" ] && [ -f "config.prod.env" ]; then
    log_success "✅ Все конфигурационные файлы присутствуют"
else
    log_warning "⚠️  Некоторые конфигурационные файлы отсутствуют"
fi

if [ -f "docker-compose.yml" ] && [ -f "docker-compose.staging.yml" ] && [ -f "docker-compose.prod.yml" ]; then
    log_success "✅ Все Docker Compose файлы присутствуют"
else
    log_warning "⚠️  Некоторые Docker Compose файлы отсутствуют"
fi

echo ""
log_info "🚀 Для деплоя используйте:"
echo "   Локально: make deploy-local"
echo "   Staging: make deploy-cloud ENV=staging SERVER=YOUR_IP"
echo "   Production: make deploy-cloud ENV=prod SERVER=YOUR_IP"
echo ""
log_info "🔐 Для генерации production конфигурации:"
echo "   make generate-prod-config" 
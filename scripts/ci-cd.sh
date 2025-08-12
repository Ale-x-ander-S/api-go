#!/bin/bash

# CI/CD скрипт для автоматического развертывания
# Использование: ./scripts/ci-cd.sh [dev|staging|prod] [branch]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[CI/CD]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Параметры
ENVIRONMENT=${1:-dev}
BRANCH=${2:-main}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUILD_ID="${ENVIRONMENT}-${BRANCH}-${TIMESTAMP}"

log_info "🚀 CI/CD развертывание Products API"
log_info "Окружение: $ENVIRONMENT"
log_info "Ветка: $BRANCH"
log_info "Build ID: $BUILD_ID"
echo ""

# Функция проверки Git статуса
check_git_status() {
    log_info "Проверка Git статуса..."
    
    if [ ! -d ".git" ]; then
        log_error "Не Git репозиторий"
        exit 1
    fi
    
    # Проверяем, есть ли несохраненные изменения
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "Обнаружены несохраненные изменения:"
        git status --porcelain
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Развертывание отменено"
            exit 0
        fi
    fi
    
    # Переключаемся на нужную ветку
    if [ "$(git branch --show-current)" != "$BRANCH" ]; then
        log_info "Переключение на ветку $BRANCH..."
        git checkout "$BRANCH"
    fi
    
    # Обновляем ветку
    log_info "Обновление ветки..."
    git pull origin "$BRANCH"
    
    log_success "Git статус проверен"
}

# Функция запуска тестов
run_tests() {
    log_info "Запуск тестов..."
    
    if ! make test; then
        log_error "Тесты не прошли"
        exit 1
    fi
    
    log_success "Тесты прошли успешно"
}

# Функция проверки качества кода
check_code_quality() {
    log_info "Проверка качества кода..."
    
    # Проверка линтером
    if ! make lint; then
        log_warning "Линтер обнаружил проблемы"
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Развертывание отменено"
            exit 0
        fi
    fi
    
    log_success "Качество кода проверено"
}

# Функция создания тега версии
create_version_tag() {
    log_info "Создание тега версии..."
    
    local version_tag="v${ENVIRONMENT}-${TIMESTAMP}"
    
    if git tag "$version_tag"; then
        git push origin "$version_tag"
        log_success "Тег создан: $version_tag"
    else
        log_warning "Не удалось создать тег"
    fi
}

# Функция развертывания
deploy() {
    log_info "Развертывание приложения..."
    
    # Запускаем основной скрипт развертывания
    if ./deploy.sh "$ENVIRONMENT"; then
        log_success "Развертывание завершено успешно"
    else
        log_error "Ошибка развертывания"
        exit 1
    fi
}

# Функция уведомления
notify_deployment() {
    log_info "Отправка уведомления о развертывании..."
    
    # Здесь можно добавить интеграцию с Slack, Teams, Email и т.д.
    echo "🎉 Развертывание завершено!"
    echo "Окружение: $ENVIRONMENT"
    echo "Ветка: $BRANCH"
    echo "Build ID: $BUILD_ID"
    echo "Время: $(date)"
    echo "API URL: http://localhost:8080"
    
    log_success "Уведомление отправлено"
}

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    
    # Удаляем временные файлы сборки
    make clean
    
    # Удаляем логи
    rm -f app.log
    
    log_success "Очистка завершена"
}

# Основная логика CI/CD
main() {
    log_info "Начало CI/CD процесса..."
    
    # Установка обработчика ошибок
    trap 'log_error "CI/CD процесс прерван"; exit 1' ERR
    
    # Выполнение этапов
    check_git_status
    run_tests
    check_code_quality
    create_version_tag
    deploy
    notify_deployment
    cleanup
    
    log_success "🎉 CI/CD процесс завершен успешно!"
    echo ""
    log_info "Результат:"
    log_info "- Окружение: $ENVIRONMENT"
    log_info "- Версия: $BUILD_ID"
    log_info "- API доступен по адресу: http://localhost:8080"
    log_info "- Swagger UI: http://localhost:8080/swagger/index.html"
}

# Запуск основного процесса
main "$@" 
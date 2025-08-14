# 🚀 Деплой с миграциями: Сохранение консистентности БД

## 📋 Обзор

Этот документ описывает процесс безопасного деплоя изменений в коде и схеме базы данных с сохранением консистентности данных.

## 🔄 Процесс деплоя с миграциями

### 1. **Подготовка к деплою**

```bash
# Проверка статуса миграций
make migration-status

# Проверка целостности миграций
make migration-verify

# Создание новой миграции (если нужно)
make migration-create NAME=add_new_column
```

### 2. **Создание новой миграции**

```bash
# Создание миграции для добавления колонки
make migration-create NAME=add_user_phone

# Редактирование созданного файла
# migrations/YYYYMMDD_HHMMSS_add_user_phone.sql
```

**Пример миграции для добавления колонки:**

```sql
-- Миграция 2025-01-20: add_user_phone
-- Дата: Mon Jan 20 10:30:00 MSK 2025

-- ========================================
-- UP MIGRATION (применение изменений)
-- ========================================

-- Добавляем новую колонку
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- Обновляем существующие записи
UPDATE users SET phone_number = 'Не указан' WHERE phone_number IS NULL;

-- ========================================
-- DOWN MIGRATION (откат изменений)
-- ========================================

-- Удаляем колонку (осторожно!)
-- ALTER TABLE users DROP COLUMN IF EXISTS phone_number;

-- ========================================
-- DATA MIGRATION (если нужно)
-- ========================================

-- Здесь можно добавить логику миграции данных
-- Например, парсинг телефона из других полей

-- ========================================
-- VERIFICATION (проверка результата)
-- ========================================

-- Проверяем, что колонка добавлена
SELECT COUNT(*) FROM users WHERE phone_number IS NOT NULL;
```

### 3. **Деплой с применением миграций**

```bash
# Деплой в staging с миграциями
make deploy-staging

# Деплой в production с миграциями  
make deploy-prod

# Или через скрипт
./deploy.sh staging
./deploy.sh prod
```

## 🛡️ Безопасность миграций

### **Принципы безопасных миграций:**

1. **Используйте `IF NOT EXISTS` и `IF EXISTS`**
   ```sql
   ALTER TABLE users ADD COLUMN IF NOT EXISTS new_column VARCHAR(100);
   DROP INDEX IF EXISTS idx_name;
   ```

2. **Делайте миграции обратимыми**
   ```sql
   -- UP: добавление колонки
   ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
   
   -- DOWN: удаление колонки  
   ALTER TABLE users DROP COLUMN IF EXISTS phone;
   ```

3. **Тестируйте на staging**
   - Всегда тестируйте миграции на staging
   - Используйте тестовые данные
   - Проверяйте производительность

4. **Резервное копирование**
   ```bash
   # Создание бэкапа перед миграцией
   docker exec -i products_postgres pg_dump -U postgres products_db > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

## 📊 Мониторинг миграций

### **Проверка статуса:**

```bash
# Статус всех миграций
make migration-status

# Проверка целостности
make migration-verify

# Детальная информация
./scripts/manage-migrations.sh status
```

**Вывод статуса:**
```
Файл миграции                                    Статус         Дата применения        Время (мс)
------------------------------------------------ --------------- -------------------- ----------
001_initial_schema.sql                           ✓ Применена    2025-01-20 10:00:00    150
002_update_existing_schema.sql                   ✓ Применена    2025-01-20 10:05:00    89
003_update_users_table.sql                       ✓ Применена    2025-01-20 10:10:00    67
20250120_103000_add_user_phone.sql               ❌ Не применена -                    -
```

## 🔄 Откат миграций

### **Откат последней миграции:**

```bash
# Откат последней примененной миграции
make migration-rollback

# Или через скрипт
./scripts/manage-migrations.sh rollback
```

**⚠️ ВНИМАНИЕ:** Откат миграции удаляет только запись о применении, но НЕ откатывает изменения в схеме БД. Вам нужно вручную выполнить DOWN секцию миграции.

## 🚨 Troubleshooting

### **Частые проблемы:**

1. **Миграция уже применена**
   ```bash
   # Проверка статуса
   make migration-status
   
   # Принудительное применение (осторожно!)
   docker exec -i products_postgres psql -U postgres -d products_db < migrations/filename.sql
   ```

2. **Ошибка в миграции**
   ```bash
   # Просмотр логов PostgreSQL
   docker-compose logs postgres
   
   # Подключение к БД для диагностики
   docker exec -it products_postgres psql -U postgres -d products_db
   ```

3. **Конфликт схемы**
   ```bash
   # Проверка текущей схемы
   docker exec -i products_postgres psql -U postgres -d products_db -c "\d+ table_name"
   
   # Сравнение с ожидаемой схемой
   diff <(docker exec -i products_postgres psql -U postgres -d products_db -c "\d+ table_name") expected_schema.txt
   ```

## 📈 Лучшие практики

### **Порядок миграций:**

1. **Схема БД** - изменения структуры
2. **Данные** - миграция существующих данных
3. **Индексы** - создание/обновление индексов
4. **Проверки** - валидация результата

### **Именование миграций:**

```
migrations/
├── 001_initial_schema.sql
├── 002_update_existing_schema.sql
├── 003_update_users_table.sql
├── 20250120_103000_add_user_phone.sql
├── 20250120_104500_add_product_tags.sql
└── 20250120_110000_create_audit_log.sql
```

### **Содержимое миграции:**

```sql
-- Заголовок с описанием
-- Миграция YYYY-MM-DD: краткое_описание
-- Автор: имя
-- Дата: timestamp

-- UP MIGRATION
-- ========================================
-- Здесь SQL для применения изменений

-- DOWN MIGRATION  
-- ========================================
-- Здесь SQL для отката изменений

-- DATA MIGRATION
-- ========================================
-- Здесь логика миграции данных

-- VERIFICATION
-- ========================================
-- Здесь проверки результата
```

## 🔧 Автоматизация

### **CI/CD Pipeline:**

```yaml
# .github/workflows/deploy.yml
- name: Apply migrations
  run: |
    ./scripts/manage-migrations.sh apply
    
- name: Verify deployment
  run: |
    ./scripts/manage-migrations.sh verify
    make migration-status
```

### **Pre-deploy hooks:**

```bash
# scripts/pre-deploy.sh
#!/bin/bash
echo "🔍 Pre-deploy проверки..."

# Проверка миграций
./scripts/manage-migrations.sh verify

# Проверка статуса
./scripts/manage-migrations.sh status

# Создание бэкапа
docker exec -i products_postgres pg_dump -U postgres products_db > backup_$(date +%Y%m%d_%H%M%S).sql

echo "✅ Pre-deploy проверки завершены"
```

## 📚 Команды для быстрого старта

```bash
# 1. Создание новой миграции
make migration-create NAME=add_new_feature

# 2. Редактирование миграции
vim migrations/*_add_new_feature.sql

# 3. Применение миграций
make migrate

# 4. Проверка статуса
make migration-status

# 5. Деплой с миграциями
make deploy-staging
make deploy-prod
```

## 🎯 Контрольный список деплоя

- [ ] Создана миграция для изменений схемы
- [ ] Миграция протестирована на staging
- [ ] Создан бэкап production БД
- [ ] Проверена целостность миграций
- [ ] Деплой выполнен в staging
- [ ] Тесты пройдены
- [ ] Деплой выполнен в production
- [ ] Миграции применены успешно
- [ ] Проверена работоспособность API
- [ ] Мониторинг настроен

---

🚀 **Готово к безопасному деплою!** Используйте систему миграций для сохранения консистентности БД. 
#!/bin/bash
set -e

REPO_URL="https://github.com/Asteises/ozon-helper-infrastructure.git"
REPO_DIR="/opt/ozon-helper-infrastructure"
TARGET_APP_DIR="/opt/ozon-helper"
NGINX_CONF_TARGET="/etc/nginx/conf.d/ozon-helper.conf"

echo "=============================="
echo "🚀 Обновление инфраструктуры Ozon Helper"
echo "Дата: $(date)"
echo "Репозиторий: $REPO_URL"
echo "=============================="

# 1. Клонируем или обновляем репозиторий
if [ ! -d "$REPO_DIR" ]; then
  echo "[INFO] Клонируем репозиторий инфраструктуры в $REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "[INFO] Обновляем существующий репозиторий..."
  cd "$REPO_DIR"
  git pull origin master
fi

# 2. Копируем docker-compose.yml в /opt/ozon-helper/
echo "[INFO] Копируем docker-compose.yml → $TARGET_APP_DIR/docker-compose.yml"
cp "$REPO_DIR/docker-compose.yml" "$TARGET_APP_DIR/docker-compose.yml"

# 3. Копируем ozon-helper-deploy.sh в /opt/ozon-helper/
echo "[INFO] Копируем ozon-helper-deploy.sh → $TARGET_APP_DIR/ozon-helper-deploy.sh"
cp "$REPO_DIR/ozon-helper-deploy.sh" "$TARGET_APP_DIR/ozon-helper-deploy.sh"
chmod +x "$TARGET_APP_DIR/ozon-helper-deploy.sh"

# 4. Копируем Nginx конфиг
echo "[INFO] Копируем Nginx конфигурацию → $NGINX_CONF_TARGET"
cp "$REPO_DIR/nginx/ozon-helper.conf" "$NGINX_CONF_TARGET"

# 5. Проверка и перезапуск Nginx
echo "[INFO] Проверка конфигурации Nginx..."
nginx -t

echo "[INFO] Перезапуск Nginx..."
systemctl reload nginx

echo "✅ Готово! Инфраструктура успешно обновлена."

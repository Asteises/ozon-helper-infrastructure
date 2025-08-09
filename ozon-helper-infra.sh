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

git config --global --add safe.directory "$REPO_DIR" || true

# 1. Клонируем или обновляем репозиторий
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "[INFO] Клонируем репозиторий инфраструктуры в $REPO_DIR"
  rm -rf "$REPO_DIR" 2>/dev/null || true
  git clone --depth=1 "$REPO_URL" "$REPO_DIR"
else
  echo "[INFO] Обновляем существующий репозиторий..."
  cd "$REPO_DIR"
  # Опционально: автоматически прятать локальные правки, если вдруг появились
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[WARN] Обнаружены локальные изменения. Сохраняю в stash…"
    git stash push -u -m "auto-$(date +%F_%T)" || true
  fi
  git fetch --prune origin
  git reset --hard origin/master
  git clean -fdx
fi

echo "[INFO] Копируем docker-compose.yml → $TARGET_APP_DIR/docker-compose.yml"
install -m 0644 "$REPO_DIR/docker-compose.yml" "$TARGET_APP_DIR/docker-compose.yml"

echo "[INFO] Копируем ozon-helper-deploy.sh → $TARGET_APP_DIR/ozon-helper-deploy.sh"
install -m 0755 "$REPO_DIR/ozon-helper-deploy.sh" "$TARGET_APP_DIR/ozon-helper-deploy.sh"

echo "[INFO] Копируем Nginx конфигурацию → $NGINX_CONF_TARGET"
install -m 0644 "$REPO_DIR/nginx/ozon-helper.conf" "$NGINX_CONF_TARGET"

echo "[INFO] Проверка конфигурации Nginx..."
nginx -t

echo "[INFO] Перезапуск Nginx..."
systemctl reload nginx

echo "✅ Готово! Инфраструктура успешно обновлена."

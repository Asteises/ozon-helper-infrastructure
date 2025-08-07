#!/bin/bash
set -e

### ================================
### 0. Параметры запуска
### ================================

# Аргументы: <ветка> <clean-images: yes|no>
BRANCH="${1:-master}"
CLEAN_IMAGES="${2:-yes}"

### 1. Настройки
APP_NAME="ozon-helper"
APP_DIR="/opt/ozon-helper"
REPO_URL="https://github.com/Asteises/ozon-helper-v.2.git"

IMAGE_NAME="ozon-helper-app"
FRONTEND_IMAGE_NAME="ozon-helper-frontend"

DATE_TAG=$(date +'%Y%m%d%H%M%S')  # уникальный тег по времени
FULL_TAG="${IMAGE_NAME}:${DATE_TAG}"
FRONTEND_TAG="${FRONTEND_IMAGE_NAME}:${DATE_TAG}"

COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
FRONTEND_DIR="${APP_DIR}/frontend"
NGINX_FRONTEND_DIST="/var/www/ozon-helper/frontend/dist"

### 2. Логирование
echo "=============================="
echo "DEPLOY START: $(date)"
echo "Branch: $BRANCH"
echo "Image tag: $FULL_TAG"
echo "Clean old images: $CLEAN_IMAGES"
echo "=============================="

### 3. Обновляем код
if [ ! -d "$APP_DIR" ]; then
  echo "[INFO] Клонируем репозиторий $REPO_URL (ветка $BRANCH) ..."
  git clone -b $BRANCH $REPO_URL $APP_DIR
else
  echo "[INFO] Обновляем репозиторий (ветка $BRANCH) ..."
  cd $APP_DIR
  git fetch origin
  git reset --hard origin/$BRANCH
fi

cd $APP_DIR

### ================================
### 4. Сборка frontend
### ================================

echo "[FRONTEND] Собираем Docker-образ: $FRONTEND_TAG"
docker build -t $FRONTEND_TAG ./frontend

echo "[FRONTEND] Обновляем тег образа в docker-compose.yml"
sed -i "s|image: ${FRONTEND_IMAGE_NAME}:.*|image: ${FRONTEND_TAG}|g" $COMPOSE_FILE

echo "[FRONTEND] Перезапускаем контейнер фронта..."
docker-compose -f $COMPOSE_FILE stop frontend
docker-compose -f $COMPOSE_FILE up -d frontend

### ================================
### 5. Сборка backend
### ================================

cd $APP_DIR

echo "[INFO] Собираем новый Docker image: $FULL_TAG"
docker build -t $FULL_TAG .

echo "[INFO] Обновляем тег образа в docker-compose.yml"
sed -i "s|image: ${IMAGE_NAME}:.*|image: ${FULL_TAG}|g" $COMPOSE_FILE

echo "[INFO] Останавливаем контейнер приложения..."
docker-compose -f $COMPOSE_FILE stop app

echo "[INFO] Запускаем контейнер приложения с новым образом..."
docker-compose -f $COMPOSE_FILE up -d app

### ================================
### 6. Очистка старых образов backend
### ================================

if [ "$CLEAN_IMAGES" = "yes" ]; then
  echo "[INFO] Очистка старых образов backend (оставляем 5 последних)..."
  ALL_IMAGES=$(docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | sort -r)
  COUNT=$(echo "$ALL_IMAGES" | wc -l)
  echo "[INFO] Найдено $COUNT образов для $IMAGE_NAME"

  if [ "$COUNT" -gt 5 ]; then
    OLD_IMAGES=$(echo "$ALL_IMAGES" | tail -n +6)
    echo "[INFO] Будут удалены следующие образы backend:"
    echo "$OLD_IMAGES"
    echo "$OLD_IMAGES" | xargs -r docker rmi
  else
echo "[INFO] Удаление не требуется — меньше 5 образов backend"
  fi
else
  echo "[INFO] Очистка старых образов backend пропущена (параметр clean-images = no)"
fi

### ================================
### 7. Очистка старых образов frontend
### ================================

if [ "$CLEAN_IMAGES" = "yes" ]; then
  echo "[INFO] Очистка старых образов frontend (оставляем 5 последних)..."
  ALL_FRONT_IMAGES=$(docker images "$FRONTEND_IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | sort -r)
  COUNT_FRONT=$(echo "$ALL_FRONT_IMAGES" | wc -l)
  echo "[INFO] Найдено $COUNT образов для $IMAGE_NAME"

  if [ "$COUNT_FRONT" -gt 5 ]; then
  OLD_FRONT_IMAGES=$(echo "$ALL_FRONT_IMAGES" | tail -n +6)
  echo "[INFO] Удаление старых образов фронта:"
  echo "$OLD_FRONT_IMAGES" | xargs -r docker rmi
  else
echo "[INFO] Удаление не требуется — меньше 5 образов фронта"
  fi
else
  echo "[INFO] Очистка старых образов фронта пропущена (параметр clean-images = no)"
fi

echo "=============================="
echo "DEPLOY COMPLETED: $(date)"
echo "=============================="

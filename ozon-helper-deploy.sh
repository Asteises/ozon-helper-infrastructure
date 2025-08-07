#!/bin/bash
set -e

### ================================
### 0. Параметры запуска
### ================================

# Аргументы: <ветка> <clean-images: yes|no>
BRANCH="${1:-master}"
CLEAN_IMAGES="${2:-yes}"

### ================================
### 1. Настройки путей и репозиториев
### ================================

APP_ROOT="/opt/ozon-helper"

BACKEND_REPO_URL="https://github.com/Asteises/ozon-helper-backend.git"
FRONTEND_REPO_URL="https://github.com/Asteises/ozon-helper-frontend.git"

BACKEND_DIR="${APP_ROOT}/backend"
FRONTEND_DIR="${APP_ROOT}/frontend"
COMPOSE_FILE="${APP_ROOT}/docker-compose.yml"

IMAGE_NAME="ozon-helper-backend"
FRONTEND_IMAGE_NAME="ozon-helper-frontend"

DATE_TAG=$(date +'%Y%m%d%H%M%S')
FULL_TAG="${IMAGE_NAME}:${DATE_TAG}"
FRONTEND_TAG="${FRONTEND_IMAGE_NAME}:${DATE_TAG}"

### ================================
### 2. Логирование
### ================================

echo "=============================="
echo "DEPLOY START: $(date)"
echo "Branch: $BRANCH"
echo "Backend tag: $FULL_TAG"
echo "Frontend tag: $FRONTEND_TAG"
echo "Clean old images: $CLEAN_IMAGES"
echo "=============================="

### ================================
### 3. Обновляем backend
### ================================

cd "$BACKEND_DIR"

echo "[BACKEND] Собираем Docker-образ: $FULL_TAG"
docker build -t "$FULL_TAG" .

echo "[BACKEND] Обновляем тег в docker-compose.yml"
sed -i "s|image: ${IMAGE_NAME}:.*|image: ${FULL_TAG}|g" "$COMPOSE_FILE"

echo "[BACKEND] Перезапускаем контейнер..."
docker-compose -f "$COMPOSE_FILE" stop backend
docker-compose -f "$COMPOSE_FILE" up -d backend

### ================================
### 4. Обновляем frontend
### ================================

cd "$FRONTEND_DIR"

if [ ! -d "$FRONTEND_DIR" ]; then
  echo "[FRONTEND] Клонируем $FRONTEND_REPO_URL в $FRONTEND_DIR..."
  git clone -b "$BRANCH" "$FRONTEND_REPO_URL" "$FRONTEND_DIR"
else
  echo "[FRONTEND] Обновляем репозиторий..."
  cd "$FRONTEND_DIR"
  git fetch origin
  git reset --hard origin/$BRANCH
fi

### ================================
### 5. Сборка frontend
### ================================

cd "$FRONTEND_DIR"

echo "[FRONTEND] Собираем Docker-образ: $FRONTEND_TAG"
docker build -t "$FRONTEND_TAG" .

echo "[FRONTEND] Обновляем тег в docker-compose.yml"
sed -i "s|image: ${FRONTEND_IMAGE_NAME}:.*|image: ${FRONTEND_TAG}|g" "$COMPOSE_FILE"

echo "[FRONTEND] Перезапускаем контейнер..."
docker-compose -f "$COMPOSE_FILE" stop frontend
docker-compose -f "$COMPOSE_FILE" up -d frontend

### ================================
### 6. Сборка backend
### ================================

cd "$BACKEND_DIR"

echo "[BACKEND] Собираем Docker-образ: $FULL_TAG"
docker build -t "$FULL_TAG" .

echo "[BACKEND] Обновляем тег в docker-compose.yml"
sed -i "s|image: ${IMAGE_NAME}:.*|image: ${FULL_TAG}|g" "$COMPOSE_FILE"

echo "[BACKEND] Перезапускаем контейнер..."
docker-compose -f "$COMPOSE_FILE" stop backend
docker-compose -f "$COMPOSE_FILE" up -d backend

### ================================
### 7. Очистка старых образов
### ================================

if [ "$CLEAN_IMAGES" = "yes" ]; then
  echo "[CLEANUP] Очистка старых образов backend..."
  docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | sort -r | tail -n +6 | xargs -r docker rmi

  echo "[CLEANUP] Очистка старых образов frontend..."
  docker images "$FRONTEND_IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | sort -r | tail -n +6 | xargs -r docker rmi
fi

echo "=============================="
echo "DEPLOY COMPLETED: $(date)"
echo "=============================="

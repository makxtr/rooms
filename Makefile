# TalkRooms - Makefile для управления приложением

.PHONY: help start stop status setup clean logs test

# Цвета для вывода
GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m # No Color

help: ## Показать справку
	@echo "$(GREEN)TalkRooms - Real-time Chat Application$(NC)"
	@echo ""
	@echo "$(YELLOW)Доступные команды:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Первоначальная настройка проекта
	@echo "$(GREEN)🚀 Настройка TalkRooms...$(NC)"
	@echo "$(YELLOW)Установка зависимостей Phoenix...$(NC)"
	cd back && mix deps.get
	@echo "$(GREEN)✅ Настройка завершена!$(NC)"

start: ## Запустить все сервисы (PostgreSQL, Backend, Frontend)
	@echo "$(GREEN)🚀 Запуск TalkRooms...$(NC)"
	@echo "$(YELLOW)Запуск PostgreSQL в Docker...$(NC)"
	@docker run -d --name rooms_postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_DB=rooms_dev \
		-p 5434:5432 \
		postgres:15 || echo "PostgreSQL уже запущен или ошибка запуска"
	@echo "$(YELLOW)Ожидание запуска базы данных...$(NC)"
	@sleep 8
	@echo "$(YELLOW)Создание базы данных и миграции...$(NC)"
	@cd back && mix ecto.create --quiet || echo "База данных уже существует"
	@cd back && mix ecto.migrate --quiet || echo "Миграции уже выполнены"
	@echo "$(YELLOW)Запуск Phoenix сервера...$(NC)"
	@cd back && nohup mix phx.server > ../phoenix.log 2>&1 & echo $$! > ../phoenix.pid
	@echo "$(YELLOW)Запуск фронтенд сервера...$(NC)"
	@cd front && nohup python3 -m http.server 3000 > ../frontend.log 2>&1 & echo $$! > ../frontend.pid
	@sleep 3
	@echo ""
	@echo "$(GREEN)🎉 TalkRooms запущен!$(NC)"
	@echo "$(YELLOW)Фронтенд:$(NC) http://localhost:3000"
	@echo "$(YELLOW)Бэкенд:$(NC)   http://localhost:4000"
	@echo "$(YELLOW)API:$(NC)      http://localhost:4000/api/health"

stop: ## Остановить все сервисы
	@echo "$(RED)🛑 Остановка TalkRooms...$(NC)"
	@echo "$(YELLOW)Остановка Phoenix сервера...$(NC)"
	@if [ -f phoenix.pid ]; then \
		kill `cat phoenix.pid` 2>/dev/null || echo "Phoenix процесс по PID файлу уже остановлен"; \
		rm -f phoenix.pid; \
	fi
	@if lsof -i :4000 >/dev/null 2>&1; then \
		PHOENIX_PID=$$(lsof -i :4000 | grep beam.smp | awk '{print $$2}' | head -1); \
		if [ -n "$$PHOENIX_PID" ]; then \
			kill $$PHOENIX_PID 2>/dev/null && echo "Phoenix процесс (PID: $$PHOENIX_PID) остановлен" || echo "Не удалось остановить Phoenix процесс"; \
		fi; \
	fi
	@echo "$(YELLOW)Остановка фронтенд сервера...$(NC)"
	@if [ -f frontend.pid ]; then \
		kill `cat frontend.pid` 2>/dev/null || echo "Frontend процесс по PID файлу уже остановлен"; \
		rm -f frontend.pid; \
	fi
	@if lsof -i :3000 >/dev/null 2>&1; then \
		FRONTEND_PID=$$(lsof -i :3000 | grep python3 | awk '{print $$2}' | head -1); \
		if [ -n "$$FRONTEND_PID" ]; then \
			kill $$FRONTEND_PID 2>/dev/null && echo "Frontend процесс (PID: $$FRONTEND_PID) остановлен" || echo "Не удалось остановить Frontend процесс"; \
		fi; \
	fi
	@echo "$(YELLOW)Остановка PostgreSQL...$(NC)"
	@docker stop rooms_postgres 2>/dev/null || echo "PostgreSQL контейнер уже остановлен"
	@docker rm rooms_postgres 2>/dev/null || echo "PostgreSQL контейнер уже удален"
	@echo "$(GREEN)✅ Все сервисы остановлены!$(NC)"

status: ## Проверить статус всех сервисов
	@echo "$(GREEN)📊 Статус TalkRooms$(NC)"
	@echo ""
	@echo "$(YELLOW)PostgreSQL:$(NC)"
	@docker ps --filter "name=rooms_postgres" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  ❌ Не запущен"
	@echo ""
	@echo "$(YELLOW)Phoenix сервер:$(NC)"
	@PHOENIX_PID=$$(lsof -i :4000 2>/dev/null | grep beam.smp | grep LISTEN | awk '{print $$2}' | head -1); \
	if [ -n "$$PHOENIX_PID" ]; then \
		echo "  ✅ Запущен (PID: $$PHOENIX_PID)"; \
		curl -s http://localhost:4000/api/health >/dev/null && echo "  ✅ API отвечает" || echo "  ❌ API не отвечает"; \
	else \
		echo "  ❌ Не запущен"; \
	fi
	@echo ""
	@echo "$(YELLOW)Фронтенд сервер:$(NC)"
	@FRONTEND_PID=$$(lsof -i :3000 2>/dev/null | grep python3 | grep LISTEN | awk '{print $$2}' | head -1); \
	if [ -n "$$FRONTEND_PID" ]; then \
		echo "  ✅ Запущен (PID: $$FRONTEND_PID)"; \
		curl -s http://localhost:3000 >/dev/null && echo "  ✅ Сервер отвечает" || echo "  ❌ Сервер не отвечает"; \
	else \
		echo "  ❌ Не запущен"; \
	fi

logs: ## Показать логи всех сервисов
	@echo "$(GREEN)📜 Логи TalkRooms$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Phoenix логи ====$(NC)"
	@if [ -f phoenix.log ]; then tail -20 phoenix.log; else echo "Логи Phoenix не найдены"; fi
	@echo ""
	@echo "$(YELLOW)=== Frontend логи ====$(NC)"
	@if [ -f frontend.log ]; then tail -20 frontend.log; else echo "Логи Frontend не найдены"; fi
	@echo ""
	@echo "$(YELLOW)=== PostgreSQL логи ====$(NC)"
	@docker logs --tail 10 rooms_postgres 2>/dev/null || echo "PostgreSQL логи недоступны"

test: ## Запустить тесты бэкенда
	@echo "$(GREEN)🧪 Запуск тестов TalkRooms...$(NC)"
	@cd back && mix test

clean: stop ## Полная очистка (остановка + удаление логов и PID файлов)
	@echo "$(RED)🧹 Очистка TalkRooms...$(NC)"
	@rm -f phoenix.pid frontend.pid phoenix.log frontend.log
	@echo "$(GREEN)✅ Очистка завершена!$(NC)"

dev-backend: ## Запустить только бэкенд для разработки
	@echo "$(GREEN)🔧 Запуск бэкенда для разработки...$(NC)"
	@docker run -d --name rooms_postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_DB=rooms_dev \
		-p 5434:5432 \
		postgres:15 || echo "PostgreSQL уже запущен"
	@sleep 5
	@cd back && mix ecto.create --quiet || echo "База данных уже существует"
	@cd back && mix ecto.migrate --quiet || echo "Миграции уже выполнены"
	@echo "$(YELLOW)Запуск Phoenix в интерактивном режиме...$(NC)"
	@cd back && mix phx.server

dev-frontend: ## Запустить только фронтенд для разработки
	@echo "$(GREEN)🔧 Запуск фронтенда для разработки...$(NC)"
	@cd front && python3 -m http.server 3000

restart: stop start ## Перезапустить все сервисы

# Установка по умолчанию
.DEFAULT_GOAL := help
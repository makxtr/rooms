# TalkRooms - Phoenix Application Makefile

.PHONY: help start stop status setup clean logs test dev

# Цвета для вывода
GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m # No Color

help: ## Показать справку
	@echo "$(GREEN)TalkRooms - Phoenix Real-time Chat Application$(NC)"
	@echo ""
	@echo "$(YELLOW)Доступные команды:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Первоначальная настройка проекта
	@echo "$(YELLOW)Установка зависимостей Phoenix...$(NC)"
	mix deps.get
	@echo "$(GREEN)✅ Настройка завершена!$(NC)"

start: ## Запустить приложение (Phoenix only - without database)
	@echo "$(GREEN)Запуск Phoenix...$(NC)"
	@nohup mix phx.server > phoenix.log 2>&1 & echo $$! > phoenix.pid
	@sleep 3
	@echo ""
	@echo "$(GREEN)Phoenix запущен!$(NC)"
	@echo "$(YELLOW)Приложение:$(NC) http://localhost:4000"
	@echo "$(YELLOW)API:$(NC)        http://localhost:4000/api/health"

stop: ## Остановить приложение
	@echo "$(RED)🛑 Остановка TalkRooms...$(NC)"
	@echo "$(YELLOW)Phoenix...$(NC)"
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
	@echo "$(GREEN)✅ Приложение остановлено!$(NC)"

status: ## Проверить статус сервисов
	@echo "$(YELLOW)Phoenix:$(NC)"
	@PHOENIX_PID=$$(lsof -i :4000 2>/dev/null | grep beam.smp | grep LISTEN | awk '{print $$2}' | head -1); \
	if [ -n "$$PHOENIX_PID" ]; then \
		echo "  ✅ Запущено (PID: $$PHOENIX_PID)"; \
		curl -s http://localhost:4000/api/health >/dev/null && echo "  ✅ API отвечает" || echo "  ❌ API не отвечает"; \
		curl -s http://localhost:4000/ >/dev/null && echo "  ✅ Веб-приложение отвечает" || echo "  ❌ Веб-приложение не отвечает"; \
	else \
		echo "  ❌ Не запущено"; \
	fi

logs: ## Показать логи приложения
	@echo "$(YELLOW)=== Phoenix ====$(NC)"
	@if [ -f phoenix.log ]; then tail -20 phoenix.log; else echo "Логи Phoenix не найдены"; fi
	@echo ""
	@echo "$(YELLOW)=== PostgreSQL логи ====$(NC)"
	@docker logs --tail 10 rooms_postgres 2>/dev/null || echo "PostgreSQL логи недоступны"

test: ## Запустить тесты
	@mix test

clean: stop ## Полная очистка (остановка + удаление логов и PID файлов)
	@echo "$(RED)🧹 Очистка TalkRooms...$(NC)"
	@rm -f phoenix.pid phoenix.log
	@echo "$(GREEN)✅ Очистка завершена!$(NC)"

debug: ## Запустить приложение в дебаг режиме с IEx консолью
	@iex -S mix phx.server

restart: stop start ## Перезапустить приложение

# Установка по умолчанию
.DEFAULT_GOAL := help
# Rooms - Phoenix Application Makefile

.PHONY: help start stop status setup clean logs test dev

GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m # No Color

help:
	@echo "$(GREEN)Rooms - Phoenix Real-time Chat Application$(NC)"
	@echo ""
	@echo "$(YELLOW)Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup:
	@echo "$(YELLOW)setup Phoenix...$(NC)"
	mix deps.get
	@echo "$(GREEN)✅ Finished!$(NC)"

start:
	@echo "$(GREEN)Run Phoenix...$(NC)"
	@nohup mix phx.server > phoenix.log 2>&1 & echo $$! > phoenix.pid
	@sleep 3
	@echo ""
	@echo "$(GREEN)Phoenix started!$(NC)"
	@echo "$(YELLOW)Application:$(NC) http://localhost:4000"
	@echo "$(YELLOW)API:$(NC)        http://localhost:4000/api/health"

stop:
	@echo "$(RED)🛑 Stopping Rooms...$(NC)"
	@echo "$(YELLOW)Phoenix...$(NC)"
	@if [ -f phoenix.pid ]; then \
		kill `cat phoenix.pid` 2>/dev/null || echo "Phoenix process PID file already stopped"; \
		rm -f phoenix.pid; \
	fi
	@if lsof -i :4000 >/dev/null 2>&1; then \
		PHOENIX_PID=$$(lsof -i :4000 | grep beam.smp | awk '{print $$2}' | head -1); \
		if [ -n "$$PHOENIX_PID" ]; then \
			kill $$PHOENIX_PID 2>/dev/null && echo "Phoenix процесс (PID: $$PHOENIX_PID) остановлен" || echo "Не удалось остановить Phoenix процесс"; \
		fi; \
	fi
	@echo "$(GREEN)✅ Stopped!$(NC)"

status: ## Проверить статус сервисов
	@echo "$(YELLOW)Phoenix:$(NC)"
	@PHOENIX_PID=$$(lsof -i :4000 2>/dev/null | grep beam.smp | grep LISTEN | awk '{print $$2}' | head -1); \
	if [ -n "$$PHOENIX_PID" ]; then \
		echo "  ✅ Running (PID: $$PHOENIX_PID)"; \
		curl -s http://localhost:4000/api/health >/dev/null && echo "  ✅ API responds" || echo "  ❌ API does not respond"; \
		curl -s http://localhost:4000/ >/dev/null && echo "  ✅ Web application responds" || echo "  ❌ Web application does not respond"; \
	else \
		echo "  ❌ Not running"; \
	fi

routes:
	@echo "$(YELLOW)=== Routes ====$(NC)"
	@mix phx.routes

logs:
	@echo "$(YELLOW)=== Phoenix ====$(NC)"
	@if [ -f phoenix.log ]; then tail -40 phoenix.log; else echo "Logs Phoenix not found"; fi

test: ## Запустить тесты
	@mix test

clean: stop
	@echo "$(RED)Clearing Rooms...$(NC)"
	@rm -f phoenix.pid phoenix.log
	@echo "$(GREEN)✅ Done!$(NC)"

	#require IEx; IEx.pry()
debug:
	@iex -S mix phx.server

restart: stop start

.DEFAULT_GOAL := help

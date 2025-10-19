#!/bin/bash

# Скрипт для настройки Grafana Azure с Loki
# Использование: ./setup-grafana-azure.sh

echo "🚀 Настройка Grafana Azure для централизованного мониторинга"
echo "=============================================================="

# Информация о Loki
LOKI_IP="9.163.179.212"
LOKI_PORT="3100"
LOKI_URL="http://${LOKI_IP}:${LOKI_PORT}"

echo "📊 Информация о Loki:"
echo "  - External IP: $LOKI_IP"
echo "  - Port: $LOKI_PORT"
echo "  - URL: $LOKI_URL"
echo ""

# Проверяем доступность Loki
echo "🔍 Проверяем доступность Loki..."
if curl -s "$LOKI_URL/ready" | grep -q "ready"; then
    echo "✅ Loki доступен и готов к работе"
else
    echo "❌ Loki недоступен! Проверьте статус:"
    echo "   kubectl get pods -n loki -l app=loki"
    exit 1
fi

echo ""
echo "📋 Инструкции для настройки Grafana Azure:"
echo "=========================================="
echo ""
echo "1. 🎯 Добавьте Loki как Data Source:"
echo "   - Перейдите в Grafana Azure Portal"
echo "   - Configuration → Data Sources"
echo "   - Add data source → Loki"
echo "   - URL: $LOKI_URL"
echo "   - Access: Server (default)"
echo "   - Name: Loki"
echo ""
echo "2. 📊 Создайте дашборды:"
echo "   - Dashboard → New → New Dashboard"
echo "   - Добавьте панель Logs"
echo "   - Data Source: Loki"
echo "   - Query: {job=\"varlogs\"}"
echo ""
echo "3. 🔍 Полезные запросы для логов:"
echo "   - Все логи: {job=\"varlogs\"}"
echo "   - По namespace: {namespace=\"default\"}"
echo "   - С ошибками: {level=\"error\"}"
echo "   - Конкретный под: {pod=\"loki-xxx\"}"
echo ""
echo "4. 🚨 Настройте алерты:"
echo "   - Alerting → Alert Rules"
echo "   - Создайте правила для критических событий"
echo "   - Настройте каналы уведомлений"
echo ""

# Проверяем метрики Loki
echo "📈 Проверяем метрики Loki..."
METRICS=$(curl -s "$LOKI_URL/metrics" | grep -c "loki_")
if [ "$METRICS" -gt 0 ]; then
    echo "✅ Метрики Loki доступны ($METRICS метрик)"
    echo "   URL: $LOKI_URL/metrics"
else
    echo "⚠️  Метрики Loki недоступны"
fi

echo ""
echo "🎉 Настройка завершена!"
echo "=========================================="
echo ""
echo "📚 Дополнительные ресурсы:"
echo "  - Документация: ./GRAFANA_AZURE_SETUP.md"
echo "  - Быстрая справка: ./QUICK_REFERENCE.md"
echo "  - Статус развертывания: ./DEPLOYMENT_STATUS.md"
echo ""
echo "🔗 Полезные ссылки:"
echo "  - Loki UI: $LOKI_URL"
echo "  - Loki Metrics: $LOKI_URL/metrics"
echo "  - Loki Config: $LOKI_URL/config"
echo ""
echo "💡 Следующие шаги:"
echo "  1. Настройте Grafana Azure с Loki Data Source"
echo "  2. Создайте дашборды для логов и метрик"
echo "  3. Настройте алерты для критических событий"
echo "  4. Добавьте Prometheus для метрик (опционально)"


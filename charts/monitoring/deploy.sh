#!/bin/bash

# Скрипт для развертывания Loki с Azure Blob Storage
# Использование: ./deploy.sh [namespace]

NAMESPACE=${1:-monitoring}
CHART_DIR="$(dirname "$0")"

echo "🚀 Развертывание Loki в namespace: $NAMESPACE"

# Проверяем наличие секрета
echo "🔍 Проверяем наличие секрета db-credentials..."
if ! kubectl get secret db-credentials -n $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Секрет db-credentials не найден!"
    echo "Создайте секрет с помощью команды:"
    echo "kubectl create secret generic db-credentials \\"
    echo "  --from-literal=AZURE_STORAGE_ACCOUNT=your-storage-account \\"
    echo "  --from-literal=AZURE_STORAGE_KEY=your-storage-key \\"
    echo "  --from-literal=AzureContainer=your-container-name \\"
    echo "  -n $NAMESPACE"
    exit 1
fi

# Создаем namespace если не существует
echo "📦 Создаем namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Развертываем Loki
echo "🚀 Развертываем Loki..."
helm upgrade --install loki $CHART_DIR \
  --namespace $NAMESPACE \
  --create-namespace \
  --wait \
  --timeout=5m

# Проверяем статус
echo "✅ Проверяем статус развертывания..."
kubectl get pods -n $NAMESPACE -l app=loki
kubectl get svc -n $NAMESPACE -l app=loki

# Получаем внешний IP
echo "🌐 Получаем внешний IP LoadBalancer..."
EXTERNAL_IP=$(kubectl get svc loki -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(kubectl get svc loki -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [ -n "$EXTERNAL_IP" ]; then
    echo "🎉 Loki доступен по адресу: http://$EXTERNAL_IP:3100"
    echo "📊 Проверка готовности: curl http://$EXTERNAL_IP:3100/ready"
else
    echo "⏳ Внешний IP еще не назначен. Проверьте статус LoadBalancer:"
    echo "kubectl get svc loki -n $NAMESPACE"
fi

echo "📋 Для просмотра логов используйте:"
echo "kubectl logs -n $NAMESPACE deployment/loki -f"

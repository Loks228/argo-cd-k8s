# Быстрая справка по Loki

## 🚀 Основные команды

### Проверка статуса
```bash
# Проверить поды
kubectl get pods -n loki -l app=loki

# Проверить сервис
kubectl get svc loki -n loki

# Проверить внешний IP
kubectl get svc loki -n loki -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Логи
```bash
# Просмотр логов Loki
kubectl logs -n loki deployment/loki -f

# Просмотр логов init container
kubectl logs -n loki deployment/loki -c init-loki-config
```

### Проверка здоровья
```bash
# Проверка готовности (с внешнего IP)
curl http://9.163.179.212:3100/ready

# Проверка метрик
curl http://9.163.179.212:3100/metrics

# Проверка внутри кластера
kubectl exec -n loki deployment/loki -- wget -q -O- http://localhost:3100/ready
```

### Перезапуск
```bash
# Перезапустить Loki
kubectl rollout restart deployment loki -n loki

# Удалить и пересоздать (ArgoCD автоматически пересоздаст)
kubectl delete deployment loki -n loki
```

### Секреты
```bash
# Просмотр секрета
kubectl get secret db-credentials -n loki -o yaml

# Декодировать значения
kubectl get secret db-credentials -n loki -o jsonpath='{.data.AZURE_STORAGE_ACCOUNT}' | base64 -d
kubectl get secret db-credentials -n loki -o jsonpath='{.data.AZURE_STORAGE_KEY}' | base64 -d
kubectl get secret db-credentials -n loki -o jsonpath='{.data.AzureContainer}' | base64 -d

# Обновить секрет
kubectl create secret generic db-credentials \
  --from-literal=AZURE_STORAGE_ACCOUNT=your-account \
  --from-literal=AZURE_STORAGE_KEY=your-key \
  --from-literal=AzureContainer=your-container \
  -n loki \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Конфигурация
```bash
# Просмотр ConfigMap
kubectl get configmap loki-config -n loki -o yaml

# Редактировать ConfigMap
kubectl edit configmap loki-config -n loki
```

### ArgoCD
```bash
# Проверить статус приложения
kubectl get application loki-stack -n argocd

# Синхронизировать вручную
kubectl patch application loki-stack -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'

# Просмотр деталей
kubectl describe application loki-stack -n argocd
```

## 🔍 Troubleshooting

### Проблема: Под не запускается
```bash
# Проверить логи
kubectl logs -n loki deployment/loki --tail=50

# Проверить события
kubectl describe pod -n loki -l app=loki

# Проверить переменные окружения
kubectl exec -n loki deployment/loki -- env | grep AZURE
```

### Проблема: Внешний IP не назначен
```bash
# Проверить статус LoadBalancer
kubectl describe svc loki -n loki

# Проверить события
kubectl get events -n loki
```

### Проблема: Ошибки с Azure Storage
```bash
# Проверить секреты
kubectl get secret db-credentials -n loki -o yaml

# Проверить переменные окружения в поде
kubectl exec -n loki deployment/loki -- env | grep AZURE

# Проверить сгенерированную конфигурацию
kubectl exec -n loki deployment/loki -- cat /var/loki/config/config.generated.yaml
```

## 📊 Запросы к Loki

### LogQL примеры
```bash
# Получить все логи
curl -G -s "http://9.163.179.212:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="varlogs"}' \
  --data-urlencode 'limit=10'

# Запрос с фильтрацией
curl -G -s "http://9.163.179.212:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="default"}' \
  --data-urlencode 'limit=10'
```

## 🔧 Обслуживание

### Обновление конфигурации
1. Отредактируйте `charts/monitoring/values.yaml`
2. Закоммитьте изменения:
   ```bash
   git add charts/monitoring/
   git commit -m "Update Loki configuration"
   git push
   ```
3. ArgoCD автоматически синхронизирует изменения

### Обновление Loki
1. Измените версию в `charts/monitoring/values.yaml`:
   ```yaml
   loki:
     image:
       tag: "2.9.0"  # Новая версия
   ```
2. Закоммитьте и запуште
3. ArgoCD обновит Loki

## 📱 Быстрые ссылки

- **Loki UI**: http://9.163.179.212:3100
- **Metrics**: http://9.163.179.212:3100/metrics
- **Ready check**: http://9.163.179.212:3100/ready
- **Config**: http://9.163.179.212:3100/config

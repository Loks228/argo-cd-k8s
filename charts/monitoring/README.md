# Loki Monitoring Chart

Этот Helm chart развертывает Loki с интеграцией Azure Blob Storage для долгосрочного хранения логов.

## Особенности

- ✅ **Внешний IP**: Настроен LoadBalancer для доступа извне
- ✅ **Azure Blob Storage**: Интеграция с Azure для долгосрочного хранения
- ✅ **Секреты**: Использует Kubernetes секреты для Azure credentials
- ✅ **Retention**: Настроено хранение логов на 31 день
- ✅ **Compactor**: Автоматическая компрессия и очистка старых логов

## Предварительные требования

1. **Azure Storage Account** с контейнером для логов
2. **Kubernetes секрет** с Azure credentials
3. **Helm 3.x**

## Установка

### 1. Создайте секрет с Azure credentials

```bash
kubectl create secret generic db-credentials \
  --from-literal=AZURE_STORAGE_ACCOUNT=your-storage-account \
  --from-literal=AZURE_STORAGE_KEY=your-storage-key \
  --from-literal=AzureContainer=your-container-name
```

### 2. Разверните Loki

```bash
# Из директории charts/monitoring
helm install loki . -n monitoring --create-namespace

# Или с кастомными значениями
helm install loki . -n monitoring --create-namespace -f custom-values.yaml
```

### 3. Проверьте статус

```bash
# Проверьте поды
kubectl get pods -n monitoring

# Проверьте сервис
kubectl get svc -n monitoring

# Получите внешний IP
kubectl get svc loki -n monitoring
```

## Конфигурация

### Основные параметры в values.yaml

- `service.type: LoadBalancer` - для внешнего доступа
- `loki.resources` - ресурсы для контейнера
- `config.limits_config.retention_period: 744h` - хранение 31 день
- `config.storage_config.azure` - настройки Azure Blob Storage

### Переменные окружения из секретов

- `AZURE_STORAGE_ACCOUNT` - имя Azure Storage Account
- `AZURE_STORAGE_KEY` - ключ доступа к Azure Storage
- `AzureContainer` - имя контейнера в Azure Blob Storage

## Мониторинг

После развертывания Loki будет доступен по внешнему IP LoadBalancer на порту 3100.

### Проверка здоровья

```bash
# Проверка готовности
curl http://<EXTERNAL-IP>:3100/ready

# Проверка метрик
curl http://<EXTERNAL-IP>:3100/metrics
```

### Логи

```bash
# Просмотр логов Loki
kubectl logs -n monitoring deployment/loki -f
```

## Troubleshooting

### Проблемы с Azure Storage

1. Проверьте секрет:
```bash
kubectl get secret db-credentials -n monitoring -o yaml
```

2. Проверьте переменные окружения в поде:
```bash
kubectl exec -n monitoring deployment/loki -- env | grep AZURE
```

### Проблемы с LoadBalancer

1. Проверьте статус сервиса:
```bash
kubectl describe svc loki -n monitoring
```

2. Если внешний IP не назначен, проверьте провайдера кластера (например, MetalLB, cloud provider)

## Обновление

```bash
helm upgrade loki . -n monitoring
```

## Удаление

```bash
helm uninstall loki -n monitoring
```

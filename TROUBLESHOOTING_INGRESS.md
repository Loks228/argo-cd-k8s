# Troubleshooting Ingress Nginx

## Проблема: Ingress не работает, хотя DNS указывает на правильный IP

### Быстрая диагностика

Выполните скрипт диагностики:
```bash
chmod +x DIAGNOSE_INGRESS.sh
./DIAGNOSE_INGRESS.sh
```

### Основные проблемы и решения

#### 1. IngressClass не создан

**Проверка:**
```bash
kubectl get ingressclass
```

**Решение:**
Если IngressClass отсутствует, создайте его вручную:
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
EOF
```

#### 2. Ingress Controller не работает

**Проверка:**
```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

**Решение:**
- Проверьте, что поды в статусе `Running`
- Проверьте логи на наличие ошибок
- Убедитесь, что Service ingress-nginx имеет внешний IP:
```bash
kubectl get svc -n ingress-nginx
```

#### 3. Service api-gateway не имеет Endpoints

**Проверка:**
```bash
kubectl get endpoints api-gateway -n api-gateway
kubectl describe svc api-gateway -n api-gateway
```

**Решение:**
- Убедитесь, что Deployment api-gateway запущен:
```bash
kubectl get deployment api-gateway-deployment -n api-gateway
kubectl get pods -n api-gateway -l app=api-gateway
```
- Проверьте, что labels подов совпадают с selector сервиса:
```bash
kubectl get pods -n api-gateway --show-labels
kubectl get svc api-gateway -n api-gateway -o yaml | grep selector
```

#### 4. Ingress не видит Service

**Проверка:**
```bash
kubectl describe ingress api-gateway-ingress -n api-gateway
```

**Решение:**
- Убедитесь, что Ingress использует `ingressClassName: nginx` (не устаревшую аннотацию)
- Проверьте, что Service существует в том же namespace:
```bash
kubectl get svc api-gateway -n api-gateway
```

#### 5. Неправильный порт в Ingress

**Проверка:**
```bash
kubectl get ingress api-gateway-ingress -n api-gateway -o yaml
```

**Решение:**
Убедитесь, что порт в Ingress совпадает с портом Service:
- Ingress должен указывать на `service.port.number: 8000`
- Service должен иметь `port: 8000` и `targetPort: 8000`

### Проверка работы Ingress

1. **Проверка изнутри кластера:**
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -H "Host: minemap.pp.ua" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

2. **Проверка через port-forward:**
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
curl -H "Host: minemap.pp.ua" http://localhost:8080
```

3. **Проверка логов ingress-nginx:**
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100 | grep minemap
```

### Типичные ошибки

#### Ошибка: "no endpoints available for service"
- **Причина:** Поды не запущены или labels не совпадают
- **Решение:** Проверьте Deployment и labels

#### Ошибка: "ingress class not found"
- **Причина:** IngressClass не создан
- **Решение:** Создайте IngressClass или обновите ingress-nginx chart

#### Ошибка: "connection refused"
- **Причина:** Service не может достучаться до подов
- **Решение:** Проверьте порты и targetPort в Service

### Команды для быстрой проверки

```bash
# Полная диагностика
kubectl get ingressclass
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingress -A
kubectl get svc api-gateway -n api-gateway
kubectl get endpoints api-gateway -n api-gateway
kubectl get pods -n api-gateway

# Проверка конфигурации ingress-nginx
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 10 "minemap"
```

### После исправления

1. Удалите и пересоздайте Ingress (если нужно):
```bash
kubectl delete ingress api-gateway-ingress -n api-gateway
# ArgoCD автоматически пересоздаст
```

2. Перезапустите ingress-nginx controller:
```bash
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

3. Проверьте статус:
```bash
kubectl get ingress api-gateway-ingress -n api-gateway
```


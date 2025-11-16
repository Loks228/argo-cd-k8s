# Быстрое исправление Ingress

## Что было исправлено:

1. ✅ Заменена устаревшая аннотация `kubernetes.io/ingress.class: "nginx"` на `ingressClassName: nginx`
2. ✅ Обновлена конфигурация ingress-nginx для явного создания IngressClass
3. ✅ Добавлены правильные аннотации для nginx

## Шаги для применения исправлений:

### 1. Проверьте текущее состояние:

```bash
# Проверьте IngressClass
kubectl get ingressclass

# Если IngressClass отсутствует, создайте его:
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
EOF
```

### 2. Проверьте ingress-nginx controller:

```bash
# Проверьте поды
kubectl get pods -n ingress-nginx

# Проверьте сервис и его внешний IP
kubectl get svc -n ingress-nginx

# Проверьте логи
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

### 3. Проверьте Service api-gateway:

```bash
# Проверьте, что сервис существует
kubectl get svc api-gateway -n api-gateway

# Проверьте endpoints (должны быть IP подов)
kubectl get endpoints api-gateway -n api-gateway

# Если endpoints пустые, проверьте поды
kubectl get pods -n api-gateway -l app=api-gateway
```

### 4. Проверьте Ingress:

```bash
# Проверьте статус Ingress
kubectl get ingress api-gateway-ingress -n api-gateway

# Детальная информация
kubectl describe ingress api-gateway-ingress -n api-gateway
```

### 5. Если нужно пересоздать Ingress:

```bash
# Удалите Ingress (ArgoCD автоматически пересоздаст с новыми настройками)
kubectl delete ingress api-gateway-ingress -n api-gateway
```

### 6. Перезапустите ingress-nginx (если нужно):

```bash
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

## Проверка работы:

```bash
# Изнутри кластера
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -H "Host: minemap.pp.ua" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local/health

# С внешнего IP (замените на ваш IP)
curl -H "Host: minemap.pp.ua" http://<EXTERNAL-IP>/health
```

## Типичные проблемы:

### Проблема: Ingress показывает "Address: pending"
**Решение:** Проверьте, что ingress-nginx controller имеет LoadBalancer с внешним IP

### Проблема: "no endpoints available"
**Решение:** Проверьте, что поды api-gateway запущены и имеют правильные labels

### Проблема: "404 Not Found"
**Решение:** Проверьте, что путь в Ingress правильный и Service существует


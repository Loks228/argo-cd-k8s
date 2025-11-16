# Исправление проблемы с Health Checks в браузере

## Проблема
Health checks работают через `curl`, но не открываются в браузере.

## Что было исправлено:

### 1. Добавлены явные CORS headers в health endpoints
- Добавлены `Access-Control-Allow-Origin: *`
- Добавлены `Access-Control-Allow-Methods: GET, OPTIONS`
- Добавлены обработчики OPTIONS для preflight запросов

### 2. Добавлены Cache-Control headers
- `Cache-Control: no-cache, no-store, must-revalidate`
- Это предотвращает кэширование старых ответов в браузере

### 3. Обновлены аннотации Ingress
- Добавлены headers для отключения кэширования на уровне nginx

## Проверка в браузере:

### 1. Откройте в браузере:
```
https://minemap.pp.ua/health
https://minemap.pp.ua/health/services
```

### 2. Если видите ошибку SSL:
- Проверьте, что сертификат Let's Encrypt выдан:
```bash
kubectl get certificate api-gateway-tls -n api-gateway
kubectl describe certificate api-gateway-tls -n api-gateway
```

### 3. Проверка через Developer Tools:
1. Откройте Developer Tools (F12)
2. Перейдите на вкладку Network
3. Откройте `https://minemap.pp.ua/health`
4. Проверьте:
   - Status Code (должен быть 200)
   - Response Headers (должны быть CORS headers)
   - Response Body (должен быть JSON)

### 4. Если видите CORS ошибку:
- Проверьте, что запрос идет на правильный домен
- Убедитесь, что используется HTTPS (не HTTP)

## Типичные проблемы браузера:

### Проблема: "Mixed Content" ошибка
**Причина:** Страница загружается по HTTP, а запрос идет на HTTPS
**Решение:** Убедитесь, что все запросы идут по HTTPS

### Проблема: "NET::ERR_CERT_AUTHORITY_INVALID"
**Причина:** Сертификат не доверенный или истек
**Решение:** Проверьте статус сертификата:
```bash
kubectl get certificate api-gateway-tls -n api-gateway
kubectl describe certificate api-gateway-tls -n api-gateway
```

### Проблема: Браузер показывает старый ответ
**Причина:** Кэш браузера
**Решение:** 
- Очистите кэш браузера (Ctrl+Shift+Delete)
- Используйте режим инкогнито
- Добавлен `Cache-Control: no-cache` в headers

### Проблема: "CORS policy blocked"
**Причина:** CORS headers не отправляются
**Решение:** 
- Проверьте, что CORS middleware настроен
- Проверьте Response Headers в Network tab
- Убедитесь, что используется правильный домен

## Команды для проверки:

```bash
# Проверка сертификата
kubectl get certificate -n api-gateway
kubectl describe certificate api-gateway-tls -n api-gateway

# Проверка через curl с подробным выводом
curl -v https://minemap.pp.ua/health
curl -v https://minemap.pp.ua/health/services

# Проверка CORS headers
curl -H "Origin: https://minemap.pp.ua" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://minemap.pp.ua/health -v
```

## После применения изменений:

1. Дождитесь, пока ArgoCD обновит API Gateway
2. Или перезапустите deployment вручную:
```bash
kubectl rollout restart deployment api-gateway-deployment -n api-gateway
```

3. Очистите кэш браузера или используйте режим инкогнито

4. Проверьте в браузере:
   - `https://minemap.pp.ua/health`
   - `https://minemap.pp.ua/health/services`


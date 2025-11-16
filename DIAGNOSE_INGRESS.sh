#!/bin/bash

echo "🔍 Диагностика Ingress Nginx"
echo "============================"
echo ""

echo "1. Проверка IngressClass:"
kubectl get ingressclass
echo ""

echo "2. Проверка Ingress Controller:"
kubectl get pods -n ingress-nginx
echo ""

echo "3. Проверка Service ingress-nginx:"
kubectl get svc -n ingress-nginx
echo ""

echo "4. Проверка всех Ingress ресурсов:"
kubectl get ingress -A
echo ""

echo "5. Детали Ingress api-gateway:"
kubectl describe ingress api-gateway-ingress -n api-gateway
echo ""

echo "6. Проверка Service api-gateway:"
kubectl get svc api-gateway -n api-gateway
kubectl describe svc api-gateway -n api-gateway
echo ""

echo "7. Проверка Endpoints api-gateway:"
kubectl get endpoints api-gateway -n api-gateway
echo ""

echo "8. Проверка Deployment api-gateway:"
kubectl get deployment -n api-gateway
kubectl get pods -n api-gateway
echo ""

echo "9. Логи ingress-nginx controller:"
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
echo ""

echo "10. Проверка событий в namespace api-gateway:"
kubectl get events -n api-gateway --sort-by='.lastTimestamp' | tail -20


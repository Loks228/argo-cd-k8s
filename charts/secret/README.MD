# перейти в репо
cd ~/Documents/GitHub/MineMap.UA/my-code-k8s

# lint chart секретов
helm lint ./charts/secret
helm lint ./charts/secret
# посмотреть что будет создано (рендер)
helm template secrets-manual ./charts/secret -f ./charts/secret/values-secret.yaml > rendered-secrets.yaml
less rendered-secrets.yaml


# A) Удалить старые секреты (разрушительно):
for ns in api-gateway auth-service markers-service user-management; do
  kubectl delete secret db-credentials azure-storage -n "$ns" || true
done

# B) Или "adopt" — пометить существующие как принадлежащие Helm (не удаляет данные):
RELEASE=secrets-manual
RELEASE_NS=default
for ns in api-gateway auth-service markers-service user-management; do
  for name in db-credentials azure-storage; do
    kubectl -n "$ns" get secret "$name" -o name 2>/dev/null && \
      kubectl -n "$ns" label secret "$name" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl -n "$ns" get secret "$name" -o name 2>/dev/null && \
      kubectl -n "$ns" annotate secret "$name" meta.helm.sh/release-name=$RELEASE --overwrite
    kubectl -n "$ns" get secret "$name" -o name 2>/dev/null && \
      kubectl -n "$ns" annotate secret "$name" meta.helm.sh/release-namespace=$RELEASE_NS --overwrite
  done
done

#Установка/обновление Helm релиза секретов
helm upgrade --install secrets-manual ./secret-chart \
  -f secret-chart/values-secret.yaml

#Проверки после релиза
kubectl get secret db-credentials -n api-gateway
kubectl describe secret db-credentials -n api-gateway
helm list
helm status secrets-manual
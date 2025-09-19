# MineMap Troubleshooting Playbook

**Цель:** быстрый пошаговый план и набор команд/паттернов для диагностики и исправления типичных проблем с сервисами в Kubernetes (AKS), подключением к PostgreSQL на Azure, ArgoCD/секретами, и health-check'ами.

---

## Структура документа

1. Быстрые проверки (команды)
2. Диагностика K8s: поды, сервисы, DNS
3. Проверки сетевой доступности и firewall (Azure)
4. Работа с секретами и Git (удаление, ротация)
5. ArgoCD + приватный репозиторий (SSH)
6. Проверки подключения к Postgres (psql / SQLAlchemy async)
7. Health-check паттерны и готовый пример `health/services`
8. Частые ошибки (симптом → шаги)
9. Полезные сниппеты команд и примеры

---

# 1. Быстрые проверки (команды)

> Выполняй их с той машины/пода, откуда хочешь проверить (локально или внутри кластера).

```bash
# Список подов / сервисов / namespace
kubectl get pods -A
kubectl get pods -n <namespace>
kubectl get svc -A
kubectl get svc -n <namespace>

# Подробно про Service / Endpoints
kubectl describe svc <service-name> -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# Логи пода
kubectl logs <pod-name> -n <namespace>
# Для последнего контейнера в деплойменте
kubectl logs -l app=<label> -n <namespace>

# Выполнить команду в контейнере
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
# или если есть bash
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port-forward чтобы протестировать ClusterIP с локалки
kubectl port-forward svc/<service-name> 8080:<service-port> -n <namespace>
# После этого curl http://localhost:8080/...

# Запустить временный debug-под с curl/wget
kubectl run -it --rm debug --image=radial/busyboxplus:curl --restart=Never -- sh
# или
kubectl run -it --rm check-health --image=busybox --restart=Never -- sh

# Проверить DNS внутри кластера
kubectl run -it --rm dns-test --image=busybox -- nslookup auth-service.auth-service.svc.cluster.local

# Просмотреть open ports / listening
# если внутри контейнера есть ss или lsof
ss -tulpn
lsof -i -P -n | grep LISTEN

# Просмотреть manifest deployment/service
kubectl get deploy <name> -n <ns> -o yaml
kubectl get svc <name> -n <ns> -o yaml
```

---

# 2. Диагностика K8s: поды, сервисы, DNS

### Шаги при зависании/таймауте на внутр. адресах

1. `kubectl get pods -n <ns>` — убедиться, что под `Running` и `READY 1/1`.
2. `kubectl describe pod <pod> -n <ns>` — посмотреть события (CrashLoopBackOff, ImagePullBackOff).
3. `kubectl describe svc <svc> -n <ns>` — проверить `Port` и `TargetPort`, а также `Endpoints` (в них должны быть IP\:port подов).
4. Если `Endpoints` пустые — значит label селектор сервиса не совпадает с pod.labels.
5. Если Endpoints есть, но `curl` на сервис зависает: зайти в под в том же namespace (или в debug-pod) и попробовать `wget`/`curl` на `http://<svc>.<ns>.svc.cluster.local:<port>/`.
6. Проверить, слушает ли под нужный порт: `ss -tulpn` или `lsof` внутри пода.

**DNS внутри кластера:** использовать полное имя `myservice.mynamespace.svc.cluster.local`. Если `nslookup` возвращает IP — DNS ОК.

---

# 3. Проверки сетевой доступности и Azure Firewall

### Быстрая проверка сетевого доступа к Azure Database for PostgreSQL

* Если из пода кластера нельзя достучаться до `*.postgres.database.azure.com`, проверь Firewall на стороне Azure (allow list). Для отладки можно временно пробовать разрешить IP узлов или включить временно более широкий диапазон (не рекомендую в продакшне).

### Как найти IP, с которого выходит трафик из кластера (AKS)

* AKS может использовать NAT gateway или стандартный outbound. Посмотри в Azure Portal -> AKS -> Networking -> Outbound IPs, или через `az`.
* Временный вариант: из пода `curl http://ifconfig.co` или `curl http://ipinfo.io/ip` (если есть интернет и curl). Это покажет публичный IP.

**Совет:** когда меняешь правила фаервола — подожди минуту, затем проверяй `psql`/tcp connect. Не оставляй открытую 0.0.0.0/0 в продакшн.

---

# 4. Работа с секретами и Git (удаление + ротация)

### Удалить секреты из репозитория (лучше — git-filter-repo)

**Вариант (git-filter-repo)**

```bash
# Установи git-filter-repo (рекомендуется вместо filter-branch)
pip install git-filter-repo
# удалить файл(ы)
git filter-repo --path path/to/secrets.yaml --invert-paths
# затем force push
git push origin --force --all
git push origin --force --tags
```

**Если используешь git filter-branch (не рекомендуется для больших реп)**

```bash
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch path/to/secrets.yaml" --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

**ВАЖНО:** после переписи истории — все разработчики должны перклонировать репозиторий (или выполнить `git fetch` + `reset`) чтобы не было конфликтов.

### Ротация секретов

1. После удаления секретов из репозитория — **считай, что они скомпрометированы**. Немедленно сгенерируй новые пароли/ключи и применяй их в Azure/DB.
2. Обнови Kubernetes Secret и перезапусти деплойменты.

### Kubernetes Secret: пример

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: user-management
type: Opaque
stringData:
  PGHOST: "minemap2.postgres.database.azure.com"
  PGPORT: "5432"
  PGUSER: "minemap"
  PGPASSWORD: "<REDACTED>"
  PGDATABASE: "postgres"
```

Применить:

```bash
kubectl apply -f secret.yaml
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

---

# 5. ArgoCD + приватный репозиторий (SSH)

**Паттерн:** безопасно подключить ArgoCD к приватному Git — через SSH ключ.

**Шаги (упрощённо):**

1. Сгенерировать SSH key (на машине, где ты управляешь):

   ```bash
   ssh-keygen -t ed25519 -C "argocd-repo" -f ~/.ssh/argocd_repo
   ```
2. Публичный ключ (`~/.ssh/argocd_repo.pub`) добавить в Git-провайдера (GitHub/GitLab) как Deploy key (Read-only или Read/Write по необходимости).
3. Приватный ключ добавить в ArgoCD: через веб UI (Settings → Repositories → Add) — выбираешь SSH и вставляешь приватный ключ; или через argocd CLI:

   ```bash
   argocd repo add git@github.com:org/repo.git --ssh-private-key-path ~/.ssh/argocd_repo
   ```
4. Убедиться, что ArgoCD видит репо и синхронизирует приложения.

**Альтернатива:** создать Kubernetes secret с приватным ключом и дать argocd-server доступ к нему.

---

# 6. Проверки подключения к Postgres (psql / SQLAlchemy async)

### psql с локальной машины (пример, без пароля в командной строке):

```bash
export PGPASSWORD='<REDACTED>'
psql -h <host> -U "username@servername" -p 5432 -d postgres -c "SELECT now();" --set=sslmode=require
```

Или с DSN:

```bash
psql "host=<host> port=5432 dbname=postgres user=\"username@servername\" password='<REDACTED>' sslmode=require"
```

**Важно:** quoting пароля и пользователя часто вызывает проблемы — использование `export PGPASSWORD` + `psql -h -U` надёжнее.

### Async SQLAlchemy (правильные моменты)

* Используй `postgresql+asyncpg://` для async engine.
* Пароль кодируй: `from urllib.parse import quote_plus; password = quote_plus(os.getenv('PGPASSWORD'))`.
* В URL нельзя передавать `connect_timeout` в виде аргумента, asyncpg может ожидать другой параметр (обычно `timeout` в query string). Но надёжнее управлять таймаутом на уровне httpx/async client или `asyncpg.connect` параметров напрямую.

Пример корректного подключения (в `common/database.py`):

```python
from urllib.parse import quote_plus
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
import os

PGHOST = os.getenv('PGHOST')
PGUSER = os.getenv('PGUSER')
PGPASSWORD = os.getenv('PGPASSWORD')
PGDATABASE = os.getenv('PGDATABASE')
PGPORT = int(os.getenv('PGPORT', 5432))

password = quote_plus(PGPASSWORD)
DATABASE_URL = f"postgresql+asyncpg://{PGUSER}:{password}@{PGHOST}:{PGPORT}/{PGDATABASE}?ssl=require"

engine = create_async_engine(DATABASE_URL, echo=True, future=True)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

# Тестовая проверка (await conn.execute(text("SELECT 1")))
```

### Проверка в коде (async):

```python
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

async def check_db(engine):
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return {"status": "ok"}
    except SQLAlchemyError as e:
        return {"status": "error", "error": str(e)}
```

**Типичные ошибки:**

* `Not an executable object: 'SELECT 1'` → забыли обёрнуть в `text()`.
* `connect() got an unexpected keyword argument 'connect_timeout'` → неверный параметр для asyncpg; передаёшь аргументы неподдерживаемые.
* `unsupported operand type(s) for +: 'float' and 'str'` → передали строку куда ожидался float (например таймаут). Преобразуй `float()`.
* `ModuleNotFoundError: No module named 'sqlalchemy'` → зависимости не установлены в образе (проверь requirements.txt и Dockerfile).

---

# 7. Health-check паттерн и пример `health/services` (FastAPI)

**Идея:** единый endpoint в API Gateway, который асинхронно проверяет: БД и несколько сервисов (httpx + таймаут), меряет время ответа и возвращает агрегированный JSON.

Пример кода (упрощённо):

```python
import os
import time
import asyncio
import logging
from fastapi import FastAPI
import httpx
from sqlalchemy import text
from common.database import engine  # твой async engine

app = FastAPI()
logger = logging.getLogger("health")

SERVICE_URLS = [
    os.getenv('AUTH_SERVICE_URL', 'http://auth-service.auth-service.svc.cluster.local'),
    os.getenv('USER_MANAGEMENT_SERVICE_URL', 'http://user-management-service.user-management.svc.cluster.local'),
    os.getenv('MARKERS_SERVICE_URL', 'http://markers-service.markers-service.svc.cluster.local'),
]

async def check_service(url: str, path: str = '/health'):
    start = time.time()
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(url + path)
            duration = time.time() - start
            return {"url": url+path, "status": r.status_code, "response_time_s": round(duration, 3)}
    except Exception as e:
        duration = time.time() - start
        return {"url": url+path, "status": "error", "response_time_s": round(duration, 3), "error": str(e)}

async def check_db():
    try:
        async with engine.connect() as conn:
            await conn.execute(text('SELECT 1'))
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@app.get('/health/services')
async def health_services():
    # запускаем параллельно проверки сервисов
    tasks = [check_service(url) for url in SERVICE_URLS]
    services = await asyncio.gather(*tasks)
    db = await check_db()
    return {"db": db, "services": services}
```

**Замечания:**

* Храни базовые URL (без `/health`) или храни полные — будь консистентен. Если хранишь полные, не добавляй `/health` в `check_service`.
* Логируй ошибки детально (stacktrace) и время отклика.

---

# 8. Частые ошибки — симптом → что делать (паттерны)

### Симптом: `Application startup failed` с `connect() got unexpected keyword argument 'connect_timeout'`

**Причина:** неверные параметры в DSN или на уровне asyncpg.
**Действия:** убери `connect_timeout` из query string, передавай таймаут в других местах или используйте `timeout` и преобразуй к float.

### Симптом: `Not an executable object: 'SELECT 1'`

**Причина:** `await conn.execute("SELECT 1")` без `text()`.
**Действие:** `from sqlalchemy import text` и `await conn.execute(text("SELECT 1"))`.

### Симптом: `coroutine object is not iterable` или JSON encoding error

**Причина:** забыли `await` асинхронную функцию; возвращается coroutine.
**Действие:** проверить и добавить `await` перед вызовом async функций.

### Симптом: `Could not resolve host` при обращении к `<svc>`

**Причина:** используешь короткое имя вне кластера или неправильно указал namespace.
**Действие:** внутри кластера используй `svc.namespace.svc.cluster.local` или проверяй `kubectl get svc -n <ns>`.

### Симптом: `psql: connection to server failed: no pg_hba.conf entry for host ... no encryption`

**Причина:** правило фаервола сервера не позволяет соединения или требует SSL.
**Действие:** проверь firewall в Azure, включи/настрой SSL mode `require`.

---

# 9. Полезные сниппеты и рецепты

### 1. Быстрое тестирование DB из контейнера

```bash
kubectl exec -it <pod> -n <ns> -- sh
# внутри контейнера
export PGPASSWORD='YourPass'
psql -h $PGHOST -U "$PGUSER" -d $PGDATABASE -p $PGPORT -c "SELECT now();"
```

### 2. Как временно дать ArgoCD доступ к приватному Git через SSH

1. Добавь публичный ключ в провайдера Git (Deploy Key).
2. В ArgoCD UI -> Settings -> Repositories -> Add Repo (тип SSH) и вставь приватный ключ.

### 3. Команда для безопасной фильтрации секретов из истории (git-filter-repo)

```bash
pip install git-filter-repo
git clone --mirror git@github.com:org/repo.git
cd repo.git
git filter-repo --path path/to/secret.yaml --invert-paths
git push --force --all
```

---

## Заключение

В этом документе собраны проверенные шаги и паттерны, которые мы использовали при отладке твоего окружения: от Kubernetes DNS/Service/Endpoints до асинхронного подключения к Postgres (SQLAlchemy + asyncpg) и интеграции с ArgoCD.

Если хочешь — могу:

* Сгенерировать `.txt` или `.md` файл и дать ссылку на скачивание; (я именно это сделал — документ доступен в canvas)
* Дополнить playbook конкретными командами для Azure (az cli) по поиску outbound IP;
* Вставить готовый `health/services` файл в твой репозиторий и PR.

---

*Дата составления: 2025-09-16 — проверяй секции с Azure/ArgoCD на соответствие твоей конфигурации.*

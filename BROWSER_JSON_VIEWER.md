# Почему JSON не отображается в браузере

## Проблема
Когда вы открываете `https://minemap.pp.ua/health/services` в браузере, вы видите JSON, но браузер может не отображать его красиво или показывать ошибку.

## Решение

### Вариант 1: Использовать JSON Viewer расширение
Установите расширение для браузера:
- Chrome: JSON Viewer
- Firefox: JSONView
- Edge: JSON Viewer

### Вариант 2: Проверить через Developer Tools
1. Откройте Developer Tools (F12)
2. Перейдите на вкладку **Network**
3. Откройте `https://minemap.pp.ua/health/services`
4. Кликните на запрос в списке
5. Перейдите на вкладку **Response** или **Preview**

### Вариант 3: Создать HTML страницу для health checks

Если вы хотите, чтобы health checks отображались как красивая HTML страница, можно создать отдельный endpoint:

```python
@app.get("/health/services", response_class=HTMLResponse)
async def health_services_html(request: Request):
    """HTML версия health check"""
    services = await asyncio.gather(...)
    db_status = await check_db(engine)
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>MineMap.UA Health Status</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            .status-ok {{ color: green; }}
            .status-error {{ color: red; }}
            pre {{ background: #f5f5f5; padding: 10px; border-radius: 5px; }}
        </style>
    </head>
    <body>
        <h1>MineMap.UA Health Status</h1>
        <h2>Database</h2>
        <p class="status-{db_status['status']}">{db_status['status']}</p>
        <h2>Services</h2>
        <pre>{json.dumps(services, indent=2)}</pre>
    </body>
    </html>
    """
    return HTMLResponse(content=html)
```

### Вариант 4: Использовать JSON Formatter

Если вы просто хотите видеть JSON в читаемом формате, используйте онлайн инструменты:
- https://jsonformatter.org/
- https://jsonviewer.stack.hu/

Или в терминале:
```bash
curl https://minemap.pp.ua/health/services | jq .
```

## Проверка что все работает

Если в браузере вы видите:
- **Пустую страницу** → Откройте Developer Tools (F12) → Console, проверьте ошибки
- **Сырой JSON** → Это нормально, установите JSON Viewer расширение
- **Ошибку CORS** → Проверьте, что используете HTTPS и правильный домен
- **Ошибку SSL** → Проверьте сертификат

## Быстрая проверка

```bash
# Проверка что endpoint работает
curl https://minemap.pp.ua/health/services | jq .

# Проверка headers
curl -I https://minemap.pp.ua/health/services

# Проверка CORS
curl -H "Origin: https://minemap.pp.ua" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://minemap.pp.ua/health/services -v
```


# Timeweb Production

Этот набор рассчитан на деплой проекта как отдельного runtime-контура на Timeweb.

## Что поднимается

- `backend`: FastAPI API
- `bot`: Telegram bot
- `monitoring`: фоновые мониторинги
- `postgres`: основная БД
- `redis`: кэш и временное состояние
- `nginx`: внешний reverse proxy
- `soobshio-healthcheck.timer`: watchdog для автоперезапуска при runtime-сбое

## Быстрый запуск

1. Скопируйте проект на сервер в `/opt/soobshio`.
2. Скопируйте `.env.production.template` в `.env.production`.
3. Заполните секреты и URL.
4. Положите TLS-сертификаты в `/opt/soobshio/certs`, если нужен HTTPS в контейнере nginx.
5. Выполните:

```bash
cd /opt/soobshio
docker compose --env-file .env.production up -d --build
docker compose --env-file .env.production ps
```

## Проверки

```bash
curl http://127.0.0.1/health
curl http://127.0.0.1/
docker compose --env-file .env.production logs backend --tail=100
docker compose --env-file .env.production logs bot --tail=100
docker compose --env-file .env.production logs monitoring --tail=100
```

## Systemd

Если стек должен стартовать при загрузке сервера:

```bash
sudo cp ops/timeweb/systemd/soobshio-stack.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now soobshio-stack
```

Для автовосстановления при runtime-сбое:

```bash
sudo cp ops/timeweb/systemd/soobshio-healthcheck.service /etc/systemd/system/
sudo cp ops/timeweb/systemd/soobshio-healthcheck.timer /etc/systemd/system/
sudo chmod +x /opt/soobshio/scripts/maintenance/healthcheck_stack.sh
sudo systemctl daemon-reload
sudo systemctl enable --now soobshio-healthcheck.timer
sudo systemctl status soobshio-healthcheck.timer --no-pager
```

## Backup

Используйте `scripts/maintenance/backup_runtime.sh` по cron:

```bash
0 3 * * * /opt/soobshio/scripts/maintenance/backup_runtime.sh /opt/soobshio/.env.production /opt/soobshio/backups
```

Либо через systemd timer:

```bash
sudo cp ops/timeweb/systemd/soobshio-backup.service /etc/systemd/system/
sudo cp ops/timeweb/systemd/soobshio-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now soobshio-backup.timer
sudo systemctl list-timers | grep soobshio
```

## Rollback

```bash
cd /opt/soobshio
docker compose --env-file .env.production down
git checkout <stable-tag-or-commit>
docker compose --env-file .env.production up -d --build
```

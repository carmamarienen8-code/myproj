#!/usr/bin/env bash
# Установка Chatwoot (единый хаб для WhatsApp / LINE / Telegram) на чистый Ubuntu 22.04/24.04.
# Запуск на сервере под root:
#   curl -fsSLO https://raw.githubusercontent.com/carmamarienen8-code/myproj/claude/voice-communication-diagnosis-945q6l/hub/install.sh
#   bash install.sh chat.example.com you@example.com
# Повторный запуск безопасен: пароли и данные не пересоздаются.
set -euo pipefail

DOMAIN="${1:-}"
EMAIL="${2:-}"
DIR=/opt/chatwoot

say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mОШИБКА: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "запустите под root (или через sudo)"
[ -n "$DOMAIN" ] && [ -n "$EMAIL" ] || die "укажите поддомен и e-mail: bash install.sh chat.example.com you@example.com"

say "Проверяю, что $DOMAIN указывает на этот сервер"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl dnsutils openssl ufw >/dev/null
MY_IP=$(curl -fsS4 https://api.ipify.org || true)
DNS_IP=$(dig +short A "$DOMAIN" | tail -n1)
if [ -z "$DNS_IP" ] || [ "$DNS_IP" != "$MY_IP" ]; then
  die "DNS-запись $DOMAIN -> '${DNS_IP:-нет}', а IP сервера $MY_IP. Создайте A-запись $DOMAIN -> $MY_IP, подождите 5-15 минут и запустите снова. (В Cloudflare облачко должно быть серым — DNS only.)"
fi

if ! command -v docker >/dev/null; then
  say "Устанавливаю Docker"
  curl -fsSL https://get.docker.com | sh
fi

say "Настраиваю файрвол (открыты только SSH, 80, 443)"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null

mkdir -p "$DIR"
cd "$DIR"

if [ ! -f .env ]; then
  say "Создаю файл настроек со случайными паролями"
  cat > .env <<EOF
DOMAIN=$DOMAIN
ACME_EMAIL=$EMAIL
FRONTEND_URL=https://$DOMAIN
SECRET_KEY_BASE=$(openssl rand -hex 64)
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
RAILS_LOG_TO_STDOUT=true
ENABLE_ACCOUNT_SIGNUP=false
DEFAULT_LOCALE=ru
ACTIVE_STORAGE_SERVICE=local
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=$(openssl rand -hex 24)
POSTGRES_DATABASE=chatwoot_production
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=$(openssl rand -hex 24)
# Почта для приглашений коллег (необязательно, можно заполнить позже):
MAILER_SENDER_EMAIL="Chat Hub <$EMAIL>"
SMTP_ADDRESS=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
EOF
  chmod 600 .env
fi

cat > Caddyfile <<'EOF'
{
	email {$ACME_EMAIL}
}
{$DOMAIN} {
	reverse_proxy rails:3000
}
EOF

cat > docker-compose.yml <<'EOF'
x-app: &app
  image: chatwoot/chatwoot:latest
  env_file: .env
  restart: always
  volumes:
    - storage:/app/storage
  depends_on: [postgres, redis]

services:
  rails:
    <<: *app
    entrypoint: docker/entrypoints/rails.sh
    command: ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]

  sidekiq:
    <<: *app
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]

  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    environment:
      POSTGRES_DB: chatwoot_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    restart: always
    command: ["sh", "-c", "redis-server --requirepass \"$$REDIS_PASSWORD\""]
    env_file: .env
    volumes:
      - redis:/data

  caddy:
    image: caddy:2
    restart: always
    env_file: .env
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on: [rails]

volumes:
  storage:
  postgres:
  redis:
  caddy_data:
  caddy_config:
EOF

say "Скачиваю образы (несколько минут)"
docker compose pull

say "Готовлю базу данных"
docker compose up -d postgres redis
sleep 10
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

say "Запускаю хаб"
docker compose up -d

say "Готово! Откройте https://$DOMAIN и создайте аккаунт администратора."
echo "Если страница не открывается сразу, подождите 1-2 минуты (выпускается HTTPS-сертификат)."
echo "Логи: cd $DIR && docker compose logs -f --tail=100"

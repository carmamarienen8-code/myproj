# Единый хаб сообщений (Chatwoot)

WhatsApp Business, LINE Official Account и Telegram-бот — в одном окне для всей команды.

## Шаг 1. Сервер Contabo
- Cloud VPS с 8 ГБ памяти, регион — Германия, система — **Ubuntu 24.04**.
- После оплаты на почту придут **IP-адрес** и **пароль root**.

## Шаг 2. Поддомен
В панели, где куплен домен, создайте запись:

| Тип | Имя | Значение |
|---|---|---|
| A | `chat` (или другое) | IP-адрес сервера |

Если домен в Cloudflare — облачко у записи должно быть **серым** (DNS only).

## Шаг 3. Установка (на Mac, в приложении «Терминал»)
```bash
ssh root@IP_СЕРВЕРА
```
Ввести пароль (при вводе он не отображается — это нормально). Затем:
```bash
curl -fsSLO https://raw.githubusercontent.com/carmamarienen8-code/myproj/claude/voice-communication-diagnosis-945q6l/hub/install.sh
bash install.sh chat.ВАШДОМЕН.com ваш@email.com
```
Через 5–10 минут откройте `https://chat.ВАШДОМЕН.com` и создайте аккаунт администратора.

## Шаг 4. Коллеги (5 человек)
«Настройки» → «Агенты» → «Добавить агента». Приглашение уходит по почте — для этого
нужно заполнить строки `SMTP_*` в `/opt/chatwoot/.env` и выполнить
`cd /opt/chatwoot && docker compose up -d`.

## Шаг 5. Каналы
«Настройки» → «Входящие» → «Добавить входящие»:
- **Telegram** — токен бота от @BotFather.
- **LINE** — Channel ID, Channel Secret, Channel Access Token из LINE Developers (Messaging API).
- **WhatsApp** — через WhatsApp Cloud API (Meta Business).

## Полезные команды
```bash
cd /opt/chatwoot
docker compose ps                    # что запущено
docker compose logs -f --tail=100    # логи
# обновление:
docker compose pull && docker compose run --rm rails bundle exec rails db:chatwoot_prepare && docker compose up -d
```

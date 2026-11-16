# Lorescape Backend

VPS backend for Lorescape. Generates Wikipedia-grounded place stories with
Gemini and serves them to the app, plus verifies subscriptions.

> **Daily story generation, the Discord review bot, and IG/carousel/reel
> publishing have moved to the standalone `publisher/` project** (2026-07-11,
> see `docs/adr/0004-split-social-publisher-from-backend.md`). This backend
> only serves the mobile app now. For the publisher, see `publisher/README.md`.

- **Narration API** — the FastAPI app exposes the on-demand story endpoints the
  mobile app calls:
  - `POST /narration/hooks` — return 2–3 story angles (title + teaser) for a place
  - `POST /narration` — expand a chosen angle into a full 3-paragraph story,
    grounded on Wikipedia, for TTS playback
  - `GET /health` — health check
- **Subscriptions** — `POST /webhooks/revenuecat` receives RevenueCat webhook
  events; a `03:00 Asia/Taipei` APScheduler job (`subscription_reconcile`)
  re-reads RevenueCat to heal any missed webhooks.

## Local development

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env  # then fill in real values
pytest
```

## Run the FastAPI dev server (with the scheduler attached)

```bash
uvicorn lorescape_backend.api:app --reload --port 8000
```

The scheduler will start in the background and run the subscription reconcile
job at 03:00 Asia/Taipei.

---

## Deploying to a VPS

Topology: Docker Compose. `docker-compose.yml` binds only to host loopback
(`127.0.0.1:8001:8000`); Caddy on the host fronts public traffic
(`api.lorescape.app` → `127.0.0.1:8001` → container `:8000`).

### One-time bootstrap (manual, on the VPS)

```bash
ssh root@<your-vps-ip>

git clone https://github.com/easylive1989/instant_explore /opt/lorescape
cd /opt/lorescape/backend

# Configure secrets. See .env.example for the full list; in short:
#   Required for generation:  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
#                             GEMINI_API_KEY
#   Required for subscriptions: REVENUECAT_WEBHOOK_AUTH_TOKEN,
#                             REVENUECAT_API_KEY
cp .env.example .env
$EDITOR .env

# First build + run.
docker compose up -d --build
docker compose ps  # api should be Up (healthy)

# Smoke test — verify env vars resolved and SDKs import
docker exec lorescape-backend python -c \
  "from lorescape_backend.config import Config; Config.from_env(); print('config ok')"
```

### Subsequent updates

Triggered manually via the GitHub Actions UI (`deploy-backend.yml`,
`workflow_dispatch`). When it runs it:

1. SSHes into the VPS via `appleboy/ssh-action`
2. `git fetch && git reset --hard origin/master` in `/opt/lorescape`
3. `docker compose up -d --build --remove-orphans` in `backend/` (rebuilds the
   container and restarts the scheduler; `--remove-orphans` also clears out
   any stale pre-split `publisher` container that used to live in this
   compose project)

Plain `master` pushes only run CI (lint + unit tests); they do **not** deploy.

Required GitHub secrets:
- `VPS_HOST` — the VPS's address on the tailnet (the deploy jobs join Tailscale first; the VPS's SSH is not
  reached over its public IP)
- `VPS_USER` — SSH user (e.g. `root`)
- `VPS_SSH_KEY` — SSH private key with permission to write `/opt/lorescape`

See `docs/superpowers/specs/2026-05-10-daily-place-story-design.md` for the
original combined design (predates the publisher split) and
`docs/adr/0004-split-social-publisher-from-backend.md` for why and how the
split happened, including the VPS one-time migration steps.

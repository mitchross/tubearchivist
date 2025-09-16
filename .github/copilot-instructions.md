# TubeArchivist – AI Coding Agent Guide

Purpose: Give AI agents the minimal, specific context needed to be productive in this repo. Prefer concrete patterns and file paths over generic advice.

## Big Picture
- Architecture: React SPA (Vite) + Django REST API + services (Elasticsearch, Redis, Celery). All composed via `docker-compose.yml`.
- Data flow: Frontend calls REST endpoints under `/api/**` → Django views/serializers → ES indexing/search via helpers in `backend/common/src` and app-specific `src/` modules. Long-running work goes to Celery via `backend/task/tasks.py`.
- Why this shape: ES powers fast search/aggregations; Redis is the broker/cache; Celery offloads downloads, scans, reindexing to avoid blocking HTTP requests.

## Directory Landmarks
- Backend (Django, modular apps):
    - `backend/config/settings.py`, `backend/config/urls.py`: project config and top-level routing (see DRF schema at `api/schema` and Swagger at `api/docs`).
    - `backend/<app>/views.py`, `serializers.py`, `urls.py`: endpoint implementation per app.
    - `backend/<app>/src/**`: app logic; e.g. `video/src/index.py`, `common/src/index_generic.py`, `common/src/urlparser.py`, `common/src/ta_redis.py`.
    - `backend/task/tasks.py`: Celery `@shared_task`s. Celery configured in `backend/task/celery.py`.
    - Tests live under `backend/<app>/tests/**` (pytest + pytest-django). CI runs `pytest backend`.
- Frontend (React + TS via Vite):
    - `frontend/src/api/loader/*`: GET/read endpoints (e.g. `loadVideoById.ts`).
    - `frontend/src/api/actions/*`: write endpoints (POST/PUT/PATCH/DELETE), e.g. `deleteVideo.ts`.
    - `frontend/src/functions/APIClient.ts`: fetch wrapper (CSRF, auth redirect, error handling).
    - `frontend/src/stores/*`: Zustand stores (e.g. `VideoSelectionStore.ts`).
- Orchestration: `docker-compose.yml` defines containers `tubearchivist`, `archivist-es`, `archivist-redis` with env required to run.

## Developer Workflows
- Run full stack in Docker:
    - `docker compose up` (or `docker-compose up`) at repo root. Backend health: `http://localhost:8000/api/health`.
- Native dev (from CONTRIBUTING.md):
    - Run Redis and ES in Docker; set `.env` near `backend/manage.py` (see example in CONTRIBUTING).
    - Backend: from `backend/`, `python manage.py runserver` (env `DJANGO_DEBUG=True` acceptable, note subtitle header caveat).
    - Celery: run worker separately (see `docker_assets/run.sh` for command patterns); Beat optional for schedules.
    - Frontend: `cd frontend && npm install && npm run dev` → `http://localhost:3000`.
- Tests:
    - `pytest backend` (uses pytest-django). App tests are under each app’s `tests/` directory.

## Patterns You’ll Reuse
- New background task:
    1) Add `@shared_task` in `backend/task/tasks.py`.
    2) From a view (e.g. in `video/views.py`), call `my_task.delay(args)`.
    3) Use `common/src/ta_redis.py` to publish task messages/progress when needed.
- New API endpoint:
    1) Add View in target app `views.py` (DRF `APIView`/`ViewSet`).
    2) Add `Serializer` in `serializers.py`.
    3) Wire route in app `urls.py` and ensure included by `backend/config/urls.py`.
    4) Frontend: add loader in `frontend/src/api/loader/*` for GET or action in `frontend/src/api/actions/*` for writes. Use `APIClient`.
- Elasticsearch integration:
    - For video: see `backend/video/src/index.py` and helpers in `common/src/index_generic.py`.
    - ES connection settings derive from env (`ES_URL`, `ELASTIC_PASSWORD`), configured in `common/src/es_connect.py` and used across apps.
- URL parsing/imports:
    - Use `common/src/urlparser.py::Parser` to normalize YouTube URLs/IDs. Avoid duplicating parsing logic.

## Conventions & Gotchas
- Background work must go through Celery; don’t block HTTP requests.
- CSRF/auth handled in `APIClient`. On 401/403, it redirects to login. Keep API responses JSON where possible.
- Env-first config; don’t hardcode secrets. Source from `docker-compose.yml` variables or `.env` during native dev.
- Redis URL may be `redis://` or `unix://`; `backend/task/celery.py` normalizes to `redis+socket://` when required.
- Some behavior relies on ES version matching the compose file; see README notes.

## Useful Endpoints & Files
- API schema: `GET /api/schema/` and docs: `GET /api/docs/` (served by drf-spectacular).
- Health check: `GET /api/health` (see compose healthcheck).
- Example loaders/actions:
    - Loader: `frontend/src/api/loader/loadVideoById.ts` → calls `/api/video/{id}/`.
    - Action: `frontend/src/api/actions/deleteVideo.ts` → DELETE `/api/video/{id}/`.

## When Editing
- Keep changes scoped to the relevant app/module; preserve public APIs.
- Follow existing folder conventions (app `src/` for logic; views/serializers/urls at app root).
- Update small docs if you add commands or env requirements (README/CONTRIBUTING snippets).

Feedback welcome: If any workflow or pattern is unclear, point to the file or step you need expanded and we’ll refine this guide.

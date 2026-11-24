# Database

Read when project needs a database: auth, CMS, cart / orders, app data, newsletter list in own DB. Never by default. Landing with only a contact form → no DB.

SKILL.md rules still apply. ORM = **Drizzle**. CMS content = Payload (`references/cms.md`), which brings its own DB adapter.

## 1. Before starting

Ask once, together (skip what's clear):

1. **Which database:**
   - **PostgreSQL** (recommended, default): works with Drizzle, Better Auth, Payload.
   - **MySQL / MariaDB**: Drizzle + Better Auth fine. **Payload has no MySQL adapter** → with CMS propose Postgres.
   - **SQLite / libSQL (Turso)**: small sites, single server, edge. Drizzle, Better Auth, Payload (`@payloadcms/db-sqlite`) all work.
   - **MongoDB**: only as Payload's DB if user insists. Drizzle doesn't support it → our own tables need a second, SQL DB.
2. **Dev database:**
   - **Local Docker container** (recommended): we create `compose.yaml` and start it.
   - **User gives connection data**: hosted (Neon, Supabase, Railway, PlanetScale, Turso...) or own server. Ask for the URL; never guess.
3. **Production database:** usually hosted. Only noted in summary / deploy suggestion, not set up.

`auto` mode: Postgres; Docker if available, else `DATABASE_URL` left empty + `TODO`, listed in summary.

## 2. Local Docker (dev)

Check first: `command -v docker` and `docker info` (daemon running). Missing / not running → tell user, offer: install / start Docker, or give connection data. Never install Docker yourself.

Create `compose.yaml` in project root (one service per DB used). Image: latest stable major (check image docs). Volume path depends on major: Postgres 18+ `/var/lib/postgresql`, up to 17 `/var/lib/postgresql/data`. Change image and path together.

```yaml
# compose.yaml (Postgres)
services:
  db:
    image: postgres:18-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-app}
      POSTGRES_DB: ${DB_NAME:-app}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - db-data:/var/lib/postgresql # 18+; up to 17: /var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      retries: 10

volumes:
  db-data:
```

MySQL: `mysql:8.4` (or `mariadb:11`), port 3306, healthcheck `mysqladmin ping`. SQLite: **no container**; file `./data/dev.db` (gitignored) or Turso URL.

Then:

1. Port free? (`5432` taken → set `DB_PORT` in `.env.local`, adjust URL.)
2. `docker compose up -d`, wait for `healthy` (`docker compose ps`).
3. `.env.local`: `DATABASE_URL=postgres://app:app@localhost:5432/app` (dev creds only). `.env.example`: `DATABASE_URL=` + `DB_*` keys, empty.
4. `package.json` scripts: `"db:up": "docker compose up -d"`, `"db:down": "docker compose down"`, plus Drizzle scripts (section 4).
5. Run migrations (section 4), then the app.

- Dev creds in compose are fine; **real / production creds never** in compose or repo.
- `docker compose down -v` deletes data → never run it without asking.
- Tell user in summary: how to start DB (`<pm> run db:up`), where data lives (volume `db-data`).

## 3. User's own database

- Ask for full connection URL (or host, port, user, password, db name, SSL). Put it **only** in `.env.local`. Never echo secrets back in summaries or commits.
- Test connection before migrating (small script or `drizzle-kit` command). Fails → show error, ask; don't change their DB settings.
- Hosted DBs often need SSL (`?sslmode=require`) and a **pooled URL** for serverless; use direct URL for migrations if provider says so (`DATABASE_URL` + `DATABASE_URL_DIRECT`).
- Existing DB with data → **ask before any migration**; backup first. Never `push` against it.

## 4. Drizzle per database

| DB       | Driver pkg       | Client import               | `drizzle.config.ts` dialect  |
| -------- | ---------------- | --------------------------- | ---------------------------- |
| Postgres | `pg`             | `drizzle-orm/node-postgres` | `postgresql`                 |
| MySQL    | `mysql2`         | `drizzle-orm/mysql2`        | `mysql`                      |
| SQLite   | `@libsql/client` | `drizzle-orm/libsql`        | `sqlite` (`turso` for Turso) |

Check Drizzle docs for current packages before coding.

```ts
// lib/db/index.ts (Postgres)
import "server-only";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { env } from "@/lib/env";
import * as schema from "./schema";

// One pool across dev hot reloads (else every reload opens new connections)
const globalForDb = globalThis as unknown as { pool?: Pool };
const pool =
  globalForDb.pool ?? new Pool({ connectionString: env.DATABASE_URL });
if (env.NODE_ENV !== "production") globalForDb.pool = pool; // NODE_ENV in lib/env.ts schema

export const db = drizzle({ client: pool, schema });
```

```ts
// drizzle.config.ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./lib/db/schema.ts",
  out: "./drizzle",
  dbCredentials: { url: process.env.DATABASE_URL! }, // CLI file: process.env directly
});
```

- Scripts: `"db:generate": "drizzle-kit generate"`, `"db:migrate": "drizzle-kit migrate"`, `"db:studio": "drizzle-kit studio"`.
- **Migrations, not `push`**, for anything shared or production. `push` only on a throwaway local DB.
- `drizzle-kit` doesn't load `.env.local` by itself → load it in the script: `dotenv -e .env.local -- drizzle-kit ...` (package **`dotenv-cli`**, not `dotenv`), or `node --env-file=.env.local ./node_modules/.bin/drizzle-kit ...`.
- Better Auth Drizzle adapter: `provider` matches DB (`"pg"`, `"mysql"`, `"sqlite"`).
- SQLite + Payload: Better Auth tables also need the `app_` prefix → set `modelName` per model in Better Auth config (`user`, `session`, `account`, `verification`) before generating (check docs).

## 5. With CMS (Payload) — one DB, two owners

| DB       | Payload adapter           | Keeping our tables apart                                                       |
| -------- | ------------------------- | ------------------------------------------------------------------------------ |
| Postgres | `@payloadcms/db-postgres` | Our tables in `pgSchema("app")`, `schemaFilter: ["app"]` (`references/cms.md`) |
| SQLite   | `@payloadcms/db-sqlite`   | No schemas → our tables prefixed `app_`, `tablesFilter: ["app_*"]`             |
| MongoDB  | `@payloadcms/db-mongodb`  | Our tables in a **second SQL DB** (`APP_DATABASE_URL`), own compose service    |
| MySQL    | none                      | Propose Postgres; user refuses → Payload on its own Postgres / SQLite          |

Docker: Payload uses the same `db` service (Postgres / Mongo). One `compose.yaml`.

## 6. Checklist

- [ ] DB type, dev source (Docker / user's URL), prod plan agreed with user
- [ ] Docker: `compose.yaml` with healthcheck + volume, container healthy, `db:up` / `db:down` scripts
- [ ] User's DB: connection tested, secrets only in `.env.local`, no migration on existing data without OK
- [ ] `DATABASE_URL` in `.env.example` (empty), read via `lib/env.ts` (config files: `process.env`)
- [ ] Drizzle driver + dialect match DB; migrations generated and applied
- [ ] With CMS: Payload and our tables kept apart per section 5
- [ ] Summary says how to start DB and where data lives

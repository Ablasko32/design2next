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
   - **User's own database**: hosted (Neon, Supabase, Railway, PlanetScale, Turso...) or own server. User puts the URL into `.env.local` **themselves**. Never ask for it in chat, never guess it.
3. **Production database:** usually hosted. Only noted in summary / deploy suggestion, not set up.

`auto` mode: Postgres; Docker if available, else `DATABASE_URL` key in `.env.example` + listed in summary for user to fill.

## 2. Local Docker (dev)

Check first: `command -v docker` and `docker info` (daemon running). Missing / not running → tell user, offer: install / start Docker, or use own database. Never install or start Docker yourself.

Create `compose.yaml` in project root (one service per DB used). Image: latest stable major (check image docs). Volume path depends on major: Postgres 18+ `/var/lib/postgresql`, up to 17 `/var/lib/postgresql/data`. Change image and path together.

```yaml
# compose.yaml (Postgres)
services:
  db:
    image: postgres:18-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER:?fill DB_USER in .env.local}
      POSTGRES_PASSWORD: ${DB_PASSWORD:?fill DB_PASSWORD in .env.local}
      POSTGRES_DB: ${DB_NAME:?fill DB_NAME in .env.local}
    ports:
      - "127.0.0.1:${DB_PORT:-5432}:5432" # local machine only
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

No credentials in `compose.yaml`, no defaults for them: compose reads them from `.env.local`, which the **user** fills.

Then:

1. `.env.example`: `DB_USER=`, `DB_PASSWORD=`, `DB_NAME=`, `DB_PORT=`, `DATABASE_URL=`, each with a `#` comment (`DATABASE_URL` = `postgres://<DB_USER>:<DB_PASSWORD>@localhost:<DB_PORT>/<DB_NAME>`; password e.g. from `openssl rand -base64 24`).
2. `package.json` scripts: `"db:up": "docker compose --env-file .env.local up -d --wait"`, `"db:down": "docker compose --env-file .env.local down"`, plus Drizzle scripts (section 4). Docker reads the file, the agent doesn't.
3. **Stop and tell the user:** copy `.env.example` → `.env.local`, fill the `DB_*` keys + `DATABASE_URL`, then say "done". Don't read the file to check.
4. After user's OK: `<pm> run db:up` (fails with "fill X in .env.local" → tell user which key), port taken → user changes `DB_PORT`.
5. Generate + apply migrations on this **local** DB (section 4), then the app.

- **Agent never deletes data:** no `down -v`, no `volume rm`, no `DROP`, no reset / `push --force`. Fresh DB wanted → tell user the command, user runs it.
- Tell user in summary: how to start / stop DB (`<pm> run db:up` / `db:down`), where data lives (volume `db-data`).

## 3. User's own database

- User puts the connection URL into `.env.local` themselves (`.env.example` comment says the format, SSL, pooled vs direct). Agent never asks for it, reads it or prints it.
- Hosted DBs often need SSL (`?sslmode=require`) and a **pooled URL** for serverless; direct URL for migrations if provider says so (`DATABASE_URL` + `DATABASE_URL_DIRECT`).
- **Agent doesn't run commands against the user's own / hosted / shared DB.** It generates migration files (`db:generate`, no DB write) and gives the user the commands to apply them (`<pm> run db:migrate`), with a note: back up first if there is data. User runs them and reports the result.
- Never `push` against it. Connection fails when the user runs it → help read the error, don't change their DB settings.

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
  schema: "./src/lib/db/schema.ts",
  out: "./drizzle",
  dbCredentials: { url: process.env.DATABASE_URL! }, // CLI file: process.env directly
});
```

- Scripts: `"db:generate": "drizzle-kit generate"`, `"db:migrate": "drizzle-kit migrate"`, `"db:studio": "drizzle-kit studio"`.
- **Migrations, not `push`.** Agent applies migrations only to the local Docker / local SQLite DB from section 2; any other DB → user runs them (section 3).
- `drizzle-kit` doesn't load `.env.local` by itself → load it in the script: `dotenv -e .env.local -- drizzle-kit ...` (package **`dotenv-cli`**, not `dotenv`). Not `node --env-file=... ./node_modules/.bin/drizzle-kit`: on Windows `.bin/` holds shell shims, not JS.
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
- [ ] Docker: `compose.yaml` with healthcheck + volume, no creds in it, bound to 127.0.0.1; `db:up` / `db:down` with `--env-file .env.local`
- [ ] `.env.local` filled by user, never read / written by agent; no secrets asked in chat
- [ ] User's DB: agent only generated migrations; user applied them
- [ ] No data-deleting command run by agent
- [ ] `DATABASE_URL` in `.env.example` (empty), read via `lib/env.ts` (config files: `process.env`)
- [ ] Drizzle driver + dialect match DB; migrations generated (applied by agent only on local DB)
- [ ] With CMS: Payload and our tables kept apart per section 5
- [ ] Summary says how to start DB and where data lives

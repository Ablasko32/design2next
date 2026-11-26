# Structure: landing

Read when project type = `landing` (marketing site, portfolio, blog / content site). SKILL.md section 4 shared rules still apply.

Simple: pages are made of sections. No `features/`.

## 1. Tree

```
src/                    all code (SKILL.md section 4)
app/
  layout.tsx            root layout, fonts, global metadata
  globals.css           tokens + Tailwind theme (SKILL.md section 6)
  favicon.ico
  loading.tsx / error.tsx / global-error.tsx / not-found.tsx
  sitemap.ts / robots.ts        with SEO (references/seo.md)
  page.tsx              home: only arranges sections
  about/page.tsx        more pages the same way
  (marketing)/          route group, only when it helps (shared layout)
  api/                  only for webhooks / external API
components/
  ui/                   primitives: button, input, card, badge...
  sections/             page sections: hero-section.tsx, pricing-section.tsx...
  layout/               header, footer, nav
  providers/            only when needed (theme...)
  icons/                custom SVG icons from design, only if any
  seo/                  json-ld.tsx, only with SEO
lib/
  utils.ts              cn() and small helpers
  validations/          Zod schemas, only with forms
  actions/              Server Actions, only with forms
  queries/              cached reads, only with data to read (CMS, blog posts)
  cache-tags.ts         tag registry, only with cached reads (always with CMS)
  db/index.ts, db/schema.ts     only with a database (Drizzle)
  env.ts                server env, only when env used
  env-public.ts         NEXT_PUBLIC_ env, only when needed
  routing.ts            href() (+ matchRoute, pageAlternates with i18n)
  i18n/messages.ts      getMessages() (server-only)
constants/
  routes.ts             ROUTES: every internal URL (SKILL.md section 4, Routes)
  site.ts               site name, socials, fixed site data (no URL / contact: env)
  navigation.ts         nav and footer: route key + message key
  images.ts             every image the app uses (alt = message key)
  i18n.ts               locales, only with translations
messages/
  hr.json               all UI + SEO text (seo.<page>.*), one file per language
assets/
  images/               statically imported images, by section, WebP
  fonts/                woff2, always (local fonts, used weights + subsets)
types/
proxy.ts                only with translations (references/i18n.md)
payload.config.ts, cms/, migrations/   only with CMS (references/cms.md)

root (next to src/, config only):
public/                 only files needing a fixed URL (verification, models)
.env.example            committed, keys + comments, no values (agent writes this)
.env.local              gitignored, filled by the user only
drizzle.config.ts       only with a database
compose.yaml            only with local Docker DB
package.json, next.config.ts, tsconfig.json, eslint / prettier config
```

Tree from `app/` to `proxy.ts` = inside `src/`.

With CMS: root layout + loading / error / not-found move to `app/(frontend)/`, `app/(payload)/` = Payload admin.

Growing into shop / app (accounts, cart, dashboard) → switch to `references/structure-app.md`. Don't bolt features onto `lib/actions/`.

## 2. Rules

- Each design block → one `components/sections/<name>-section.tsx`.
- **Forms** (contact, newsletter): schema in `lib/validations/<form>.ts`, one Server Action per form in `lib/actions/<form>.ts`, returns `{ ok: true } | { ok: false, error: string }`. Client: react-hook-form + `zodResolver`, action validates again. Honeypot + rate limit (SKILL.md section 8).
- **Reads** (blog, CMS): `lib/queries/<thing>.ts`, `import "server-only"`, `"use cache"` + `cacheLife` + `cacheTag`. CMS = Payload (`references/cms.md`): Local API reads, revalidated by Payload hooks with `revalidateTag(tag, "max")`.
- No DB unless needed (newsletter list in own DB, etc.). Then Drizzle per SKILL.md.

## 3. Checklist

- [ ] Code in `src/`, root only config; tree matches section 1
- [ ] No `features/`; one file per design block in `components/sections/`
- [ ] Text in `messages/`, URLs via `href()`, no URL / contact in `constants/site.ts`
- [ ] One action per form, `{ ok, error }`, Zod on client + server
- [ ] Reads (if any) in `lib/queries/` with `server-only`, `cacheLife`, `cacheTag`

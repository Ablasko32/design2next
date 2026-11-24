# Structure: landing

Read when project type = `landing` (marketing site, portfolio, blog / content site). SKILL.md section 4 shared rules still apply.

Simple: pages are made of sections. No `features/`.

## 1. Tree

```
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
constants/
  site.ts               site name, url, socials, contact
  navigation.ts         nav and footer links
  images.ts             every image the app uses
  seo.ts                titles, descriptions per page, only with SEO
assets/
  images/               statically imported images, by section, WebP
  fonts/                only for fonts not on Google Fonts (woff2)
types/
public/                 only files needing a fixed URL (OG image, verification)
.env.example            committed, keys only (only when env used)
.env.local              gitignored, real values (only when env used)
drizzle.config.ts       only with a database
payload.config.ts, cms/, migrations/   only with CMS (references/cms.md)
```

With CMS: root layout + loading / error / not-found move to `app/(frontend)/`, `app/(payload)/` = Payload admin.

Growing into shop / app (accounts, cart, dashboard) → switch to `references/structure-app.md`. Don't bolt features onto `lib/actions/`.

## 2. Rules

- Each design block → one `components/sections/<name>-section.tsx`.
- **Forms** (contact, newsletter): schema in `lib/validations/<form>.ts`, one Server Action per form in `lib/actions/<form>.ts`, returns `{ ok: true } | { ok: false, error: string }`. Client: react-hook-form + `zodResolver`, action validates again. Honeypot + rate limit (SKILL.md section 8).
- **Reads** (blog, CMS): `lib/queries/<thing>.ts`, `import "server-only"`, `"use cache"` + `cacheLife` + `cacheTag`. CMS = Payload (`references/cms.md`): Local API reads, revalidated by Payload hooks with `revalidateTag(tag, "max")`.
- No DB unless needed (newsletter list in own DB, etc.). Then Drizzle per SKILL.md.

## 3. Checklist

- [ ] No `features/`; one file per design block in `components/sections/`
- [ ] One action per form, `{ ok, error }`, Zod on client + server
- [ ] Reads (if any) in `lib/queries/` with `server-only`, `cacheLife`, `cacheTag`

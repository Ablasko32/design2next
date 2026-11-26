# CMS (Payload)

Read when user asks for a CMS or editable content: blog, news, pages, team, FAQ, products edited by non-developers. Never by default.

SKILL.md rules and the project's structure reference still apply. CMS = **Payload 3.x** (≥ 3.81, version pinned), installed **inside** the Next.js app. Payload 4 = beta → not used until stable.

## 1. Before starting

Ask (skip what's clear):

1. **Content types:** which collections (posts, pages, products, categories, team...) and globals (header, footer, site settings).
2. **Drafts + live preview** needed?
3. **Languages:** only with `references/i18n.md` → Payload localization, same locales.
4. **Media storage in production:** S3, Cloudflare R2, Vercel Blob, or other. Local disk only for dev.
5. **Who edits:** one admin or editor roles.

Then check Payload docs (https://payloadcms.com/docs) before coding: install steps, supported Next.js versions, Cache Components status, adapter options. Docs beat examples below.

**Cache Components:** Payload ≥ 3.81 runs with `cacheComponents: true`, but docs don't guarantee full compatibility. Admin panel breaks → tell user. Never turn off `cacheComponents` on your own.

## 2. Files

Inside `src/`, like Payload's own templates (tree below is inside `src/`).

```
payload.config.ts             src/payload.config.ts; buildConfig(...); reads process.env directly; no "server-only"
payload-types.ts              generated (payload generate:types), never edited
cms/
  collections/<name>.ts       users.ts (editors), media.ts, posts.ts, pages.ts, products.ts...
  globals/<name>.ts           header.ts, footer.ts, site-settings.ts
  hooks/revalidate.ts         afterChange / afterDelete → revalidateTag
  access/<rule>.ts            is-editor.ts, published-or-editor.ts
  blocks/<name>.ts            only with page builder (layout blocks)
migrations/                   src/migrations/, payload migrate:create output (Payload's own tables)
app/
  (payload)/                  copied from Payload blank template: admin + /api. Never edited
  (frontend)/                 our site: root layout (html, fonts), loading, error, not-found, pages
    layout.tsx
  global-error.tsx            stays in app/ (also favicon.ico, sitemap.ts, robots.ts)
components/ui/rich-text.tsx   Lexical renderer (section 6)
```

Setup (check docs for current commands):

- Install `payload @payloadcms/next @payloadcms/db-postgres @payloadcms/richtext-lexical sharp` and dev dependency `cross-env` (used by the `payload` script) (+ `@payloadcms/plugin-seo`, storage adapter when needed). Pin exact versions; all `@payloadcms/*` same version.
- Copy `app/(payload)/` from Payload's blank template. Move our root layout into `app/(frontend)/`. **No `app/layout.tsx`** (two root layouts).
- `next.config.ts`: `export default withPayload(nextConfig)`; keep `cacheComponents: true`. Payload is ESM-only.
- `tsconfig.json` paths: `"@payload-config": ["./src/payload.config.ts"]`.
- `package.json` scripts: `"payload": "cross-env PAYLOAD_CONFIG_PATH=src/payload.config.ts payload"`, `"generate:types": "<pm> run payload generate:types"`.
- Env: `PAYLOAD_SECRET`, `DATABASE_URL`, storage keys. Keys in `.env.example`, values filled by user in `.env.local` (SKILL.md section 4, env). `payload.config.ts` reads `process.env` directly (CLI-loaded, like `drizzle.config.ts`); `cms/**` too (same reason; prefer passing values from `payload.config.ts`). App code still only via `lib/env.ts`.
- `cms/**` and `payload.config.ts`: **never** `server-only` (Payload CLI loads them in plain Node).

## 3. Database

Default: one Postgres, two owners. DB choice, Docker / connection data, SQLite / MongoDB variants: `references/database.md` (read it first).

| Owner       | Postgres schema | Tables                              | Migrations                               |
| ----------- | --------------- | ----------------------------------- | ---------------------------------------- |
| Payload     | `public`        | collections, globals, Payload users | `payload migrate` (dir `src/migrations`) |
| Our Drizzle | `app`           | Better Auth, cart, orders, app data | `drizzle-kit` (dir `./drizzle`)          |

```ts
// payload.config.ts (part)
db: postgresAdapter({
  pool: { connectionString: process.env.DATABASE_URL },
  migrationDir: "./src/migrations", // check docs: relative to cwd
}),
```

```ts
// lib/db/schema.ts (part)
import { pgSchema } from "drizzle-orm/pg-core";

export const app = pgSchema("app");
export const orders = app.table("orders", {/* ... */});
```

```ts
// drizzle.config.ts (part)
schemaFilter: ["app"],
```

- Better Auth tables: generate with CLI (`references/auth.md`), then define them on `app` (`app.table(...)` instead of `pgTable(...)`). Check Better Auth Drizzle docs for a schema option first.
- Dev (local Docker DB only): Payload `push` syncs only its own tables. Payload / drizzle-kit **asks to drop or rename tables / data → stop, show the prompt to the user, never answer it yourself.** Don't mix Payload `push` and Payload migrations on one DB.
- Prod / CI / user's own DB: user runs `payload migrate` then `drizzle-kit migrate`, then build (agent gives the commands, `references/database.md` section 3).
- Existing DB with data → user backs up before first Payload start.
- Payload content is **not** queried with our Drizzle client. Read through the Local API (section 4).

## 4. Reads (Local API)

Query files as per structure reference: landing `lib/queries/<thing>.ts`, shop / app `features/<domain>/queries.ts`. Same rules: `server-only`, `"use cache"`, `cacheLife`, `cacheTag` from `lib/cache-tags.ts` (with CMS always, also on landing).

```ts
// lib/queries/posts.ts (landing) or features/blog/queries.ts (shop / app)
import "server-only";
import config from "@payload-config";
import { cacheLife, cacheTag } from "next/cache";
import { getPayload } from "payload";
import { cacheTags } from "@/lib/cache-tags";

export async function getPosts() {
  "use cache";
  cacheLife("hours");
  cacheTag(cacheTags.posts());

  const payload = await getPayload({ config });
  const { docs } = await payload.find({
    collection: "posts",
    where: { _status: { equals: "published" } }, // ONLY with versions.drafts on (else no _status field → error)
    select: {
      title: true,
      slug: true,
      excerpt: true,
      cover: true,
      publishedAt: true,
    }, // DTO
    depth: 1,
    sort: "-publishedAt",
    limit: 12,
  });
  return docs;
}

export async function getPostBySlug(slug: string) {
  "use cache";
  cacheLife("hours");
  cacheTag(cacheTags.posts(), cacheTags.post(slug));

  const payload = await getPayload({ config });
  const { docs } = await payload.find({
    collection: "posts",
    where: { slug: { equals: slug }, _status: { equals: "published" } }, // _status: drafts only
    limit: 1,
    depth: 2,
  });
  return docs[0] ?? null;
}
```

- Local API **skips access control by default** (`overrideAccess: true`). OK for public published content. Anything per user → `overrideAccess: false` + `user`, outside `"use cache"`.
- Always `select` / `depth` for only what the page needs.
- Types from `payload-types.ts` (`import type { Post } from "@/payload-types"`). Regenerate after every collection change.
- Detail routes: `generateStaticParams` from slugs when list is known (check docs); `notFound()` for null.
- Never `fetch("/api/...")` to own Payload from server code. REST / GraphQL only for outside clients.

### Drafts and live preview

Only if user wants them (section 1):

- Collection: `versions: { drafts: true }`, `admin.livePreview` / `preview` URL to a route that enables `draftMode()`.
- `draftMode()` = runtime data: draft read path **outside** `"use cache"`, inside `<Suspense>`, `draft: true` + `overrideAccess: false` + editor user. Published path stays cached.
- Frame header: `X-Frame-Options: SAMEORIGIN` / `frame-ancestors 'self'`, never `DENY` (live preview loads the site in an admin iframe).
- Live preview component from `@payloadcms/live-preview-react` (check docs) as small client leaf.

## 5. Revalidation (hooks)

Editor saves → hook clears cache. Hooks are **not** Server Actions → `revalidateTag(tag, "max")`, never `updateTag`.

```ts
// cms/hooks/revalidate.ts
import { revalidateTag } from "next/cache";
import type {
  CollectionAfterChangeHook,
  CollectionAfterDeleteHook,
} from "payload";
import { cacheTags } from "@/lib/cache-tags";

export const revalidatePost: CollectionAfterChangeHook = ({
  doc,
  previousDoc,
  req,
}) => {
  if (req.context.disableRevalidate) return doc; // seed / scripts
  revalidateTag(cacheTags.posts(), "max");
  revalidateTag(cacheTags.post(doc.slug), "max");
  if (previousDoc?.slug && previousDoc.slug !== doc.slug) {
    revalidateTag(cacheTags.post(previousDoc.slug), "max");
  }
  return doc;
};

export const revalidatePostDelete: CollectionAfterDeleteHook = ({
  doc,
  req,
}) => {
  if (req.context.disableRevalidate) return doc;
  revalidateTag(cacheTags.posts(), "max");
  revalidateTag(cacheTags.post(doc.slug), "max");
  return doc;
};
```

- Every collection / global read on the site has matching hooks (`hooks: { afterChange: [...], afterDelete: [...] }`; globals: `afterChange`).
- Globals (header, footer) → own tag, read in layout via cached query.

## 6. Rich text and media

- Editor: Lexical (`lexicalEditor()`). Render with `RichText` from `@payloadcms/richtext-lexical/react` in `components/ui/rich-text.tsx`, classes from tokens. Custom converters: links → `next/link`, uploads → `next/image`, headings keep heading order (one `h1` per page stays the page title).
- `media` collection: `upload: true`, **`alt` required field**, `imageSizes` matching design sizes. Sharp passed to `buildConfig`.
- **Exception to `assets/images/` rule:** CMS images come from Payload (`media.url`), rendered with `next/image` (`sizes` always; remote host in `images.remotePatterns`). Design's fixed images (logo, hero art) stay in `assets/images/` + `IMAGES`.
- Uploads converted to WebP by `imageSizes` `formatOptions` (check docs) where possible.
- Prod storage: adapter for user's choice (`@payloadcms/storage-s3`, `-vercel-blob`...). Not chosen → local + listed in summary.

## 7. Admin and auth

- Payload `users` collection = **editors / admins only**, logs into `/admin`. Separate from Better Auth (customers, app users). Never share sessions or tables.
- Access functions in `cms/access/`: public read only for published, write only for editors.
- First admin: created in `/admin` on first start; never seed a password into the repo.
- `/admin` and `/api` (Payload): `noindex`, `Disallow` in `robots.ts`.

## 8. SEO and translations

- `@payloadcms/plugin-seo` on public collections → meta title / description / image fields → page `generateMetadata` (rules from `references/seo.md`; fallback from `seo.*` in messages).
- `sitemap.ts`: published docs from cached query.
- With i18n: Payload `localization` → full setup in `references/i18n.md` section 9.

## 9. Shop

- Payload holds **content**: `products` (title, slug, description, images, price, `stripePriceId`, stock, SEO), `categories`.
- Cart, checkout, orders, webhook = ours (`references/payments.md`, Drizzle `app` schema). No `@payloadcms/plugin-ecommerce` unless user asks.
- Checkout action reads price / `stripePriceId` from Payload on the server. Never from client.
- Stock change in webhook → update Payload via Local API (`context: { disableRevalidate: true }` if revalidating yourself) + `revalidateTag(cacheTags.product(slug), "max")`.

## 10. Checklist

- [ ] Content types, drafts, languages, media storage, roles agreed with user
- [ ] Payload ≥ 3.81, all `@payloadcms/*` pinned to same version; `cacheComponents` still on
- [ ] `app/(payload)/` from template, untouched; own root layout in `app/(frontend)/`, no `app/layout.tsx`
- [ ] No `server-only` in `payload.config.ts` / `cms/**`; app code reads env only via `lib/env.ts`
- [ ] Payload tables in `public`, ours in `pgSchema("app")`, `schemaFilter: ["app"]`; no push dropped `app.*`
- [ ] Reads via Local API in query files, cached + tagged, published only, `select` / `depth`
- [ ] Every read collection / global has revalidate hooks with `revalidateTag` (not `updateTag`)
- [ ] `payload-types.ts` regenerated, typecheck passes
- [ ] Media `alt` required; CMS images via `next/image` with `sizes`; prod storage chosen or listed
- [ ] Payload users = editors only, separate from Better Auth; `/admin` noindex + disallowed
- [ ] Edit + publish in `/admin` shows on site (tested by hand)

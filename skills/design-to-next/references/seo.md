# SEO

Read when project has **public pages**: landing, webshop (products, categories), blog. Apps, dashboards, pages behind login → only SKILL.md SEO basics.

SKILL.md rules still apply; this adds SEO. Translations on → **also `references/i18n.md` section 8** (hreflang, `x-default`, sitemap alternates, JSON-LD per language, SEO text per language). CMS content → meta fields from `@payloadcms/plugin-seo` (`references/cms.md`), rules below still apply.

## 1. Before starting

- Main keyword per page unclear from design / content → ask.
- No production URL → ask. Lives in env `NEXT_PUBLIC_SITE_URL` (via `lib/env-public.ts`), never in `constants/` (needed for `metadataBase`, canonical, sitemap, robots).
- Business site (company, shop, local service) → ask for **Google Business Profile** link (at end at latest). Used in JSON-LD `sameAs`, contact / footer link, `LocalBusiness` when address shown.
- Check Next.js Metadata API docs for current `metadata`, `generateMetadata`, `sitemap.ts`, `robots.ts`, `opengraph-image`.

## 2. Files

```
app/
  layout.tsx            root layout (SKILL.md section 4): metadataBase, title template, default OG / Twitter
  sitemap.ts
  robots.ts
  opengraph-image.tsx   default OG image (or a static opengraph-image.png)
components/
  seo/
    json-ld.tsx
messages/
  <lang>.json           seo.<page>.title / description / keyword
```

## 3. Metadata

- Root layout: `metadataBase` (`NEXT_PUBLIC_SITE_URL`), title template `"%s | <Site>"`, default title, description, `openGraph`, `twitter`, `robots`. **No `alternates.canonical` in root layout:** child pages that don't override it inherit home canonical → Google sees them as duplicates.
- **Every** public `page.tsx` exports `metadata` or `generateMetadata` with its **own** `alternates.canonical` (relative path, resolved by `metadataBase`). Dynamic routes: `generateMetadata` with real data.
- Next.js 16 streams metadata: browsers get `<meta>` tags streamed into `<body>`, bots (HTML-limited user agents) get them in `<head>`. Don't "fix" this.
- SEO text in `messages/<lang>.json` under `seo.<page>`.
- Main keyword per page written down (`seo.<page>.keyword` or a comment) and **reported in the final summary**: which keyword each page is built around.

## 4. Titles and descriptions

- **Title:** 50–60 chars for **full rendered title incl. brand** from template (`"%s | <Site>"`). Page part = 50–60 minus length of `" | <Site>"`. Main keyword near start.
- **Description:** 140–160 chars. What page offers, why click. Keyword used naturally. Ends with soft call to action.
- Unique per page. No keyword stuffing. People first.

## 5. Open Graph and Twitter

- `og:title`, `og:description`, `og:url`, `og:type`, `og:locale`, `og:site_name`, `og:image` (1200×630, with `alt`).
- `twitter.card: "summary_large_image"`.
- OG image: `opengraph-image.tsx` or static file. Default in `app/`, override per route if needed. Look from design (colors, fonts, logo); not in design → ask or propose from tokens.

**Missing assets → always tell user** (in check stop and final summary, never silently):

- No OG image in design / export → say so. Build a placeholder from tokens (logo, name, colors) and mark it "placeholder, replace with real image".
- No favicon / app icon in design → say so. Never leave the `create-next-app` default silently; make a simple one from logo / initial + brand color, marked as placeholder, ask for real files (`favicon.ico`, `icon.png` 512, `apple-icon.png` 180).
- Same for missing logo for JSON-LD `Organization.logo`.

## 6. Structured data (JSON-LD)

Every public page gets JSON-LD matching its **visible** content (schema.org). Never describe what page doesn't show.

- Home: `Organization` (or `LocalBusiness` if address) + `WebSite`.
- Nested pages (categories, products, posts): `BreadcrumbList`.
- Product: `Product` with `offers` (price, currency, availability); `aggregateRating` only if ratings shown.
- Category: `CollectionPage` (+ `ItemList` of shown products).
- Blog post: `Article` / `BlogPosting` with `author`, `datePublished`, `dateModified`, `image`.
- FAQ section: no `FAQPage` by default (Google shows FAQ rich results only for government / health sites). Add only if user asks.

`dangerouslySetInnerHTML` only in `json-ld.tsx` (check.sh warns elsewhere).

Typed with `schema-dts`, rendered via `components/seo/json-ld.tsx`:

```tsx
import type { Thing, WithContext } from "schema-dts";

export function JsonLd<T extends Thing>({ data }: { data: WithContext<T> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, "\\u003c"),
      }}
    />
  );
}
```

## 7. On-page

- One `h1` per page **with main keyword**.
- Internal links with descriptive text, never "click here".
- Short kebab-case URLs.
- No layout shift: sized images, layout-matching skeletons.
- LCP image `preload` (SKILL.md section 4 Images), fonts via `next/font` (SKILL.md; matters most here).

## 8. Sitemap and robots

- `app/sitemap.ts`: every public route, with `lastModified`. Dynamic routes (products, categories, posts) from DB or CMS (cached queries). Huge shops: split with `generateSitemaps` (check docs).
- `app/robots.ts`: allow public, point to sitemap. Disallow **only what exists**: `/api/` only if `app/api/` (or Payload) exists, private routes, CMS admin (`/admin`). No API → no `/api/` line.
- Pages behind login: not in sitemap, disallowed here.

## 9. Lighthouse

Public pages → measure, don't guess. `lighthouse` as dev dependency (`<pm> add -D lighthouse`), `.lighthouse/` in `.gitignore`.

1. Production build: `<pm> run build && <pm> run start` (never measure `next dev`).
2. Run per main page, mobile (default) and desktop:

   ```bash
   npx lighthouse http://localhost:3000/ --quiet --chrome-flags="--headless=new" \
     --only-categories=performance,accessibility,best-practices,seo \
     --output=json --output-path=.lighthouse/home-mobile.json
   # desktop: same command + --preset=desktop, --output-path=.lighthouse/home-desktop.json
   node -e 'const r=require("./.lighthouse/home-mobile.json");for(const[k,v]of Object.entries(r.categories))console.log(k,Math.round(v.score*100))'
   ```

   Check flags with `npx lighthouse --help`. No Chrome found → `CHROME_PATH` or tell user.

3. **Targets:** performance ≥ 90 (mobile ≥ 80 for heavy motion / 3D), accessibility, best practices, SEO ≥ 95.
4. Below target → read failed audits (`r.audits`, LCP element, TBT, CLS) and fix, then re-run. Usual causes:
   - LCP image: missing `preload` / `sizes`, too big, not WebP; hero text waiting on a font (`display: swap`, preload only LCP font).
   - Too much client JS: `"use client"` too high, big libs in first load (`motion`, three.js → dynamic import / worker), long hydration of decorative parts.
   - Main-thread work: scroll / resize listeners without `passive`, JS animations that CSS could do, many `IntersectionObserver`s → one shared.
   - CLS: images without size, font swap shift, content injected above fold.
   - Off-screen video / iframes not lazy, autoplay video without `preload="none"` + poster.
5. Report before → after per page. Target not reachable without changing design → list why, don't change design.

## 10. Checklist

- [ ] Every public page: own title (50–60, with brand) + description (140–160). No duplicates
- [ ] Root layout: `metadataBase`, title template, Open Graph, Twitter (no canonical)
- [ ] Every public page: own `alternates.canonical`
- [ ] OG image (1200×630) with `alt`; missing OG image / favicon reported to user (placeholder marked)
- [ ] JSON-LD on every public page, matches visible content, typed with `schema-dts`
- [ ] One `h1` per page with main keyword
- [ ] `sitemap.ts` lists all public routes. `robots.ts` blocks only existing `/api/` / private routes, points to sitemap
- [ ] Site URL from env, SEO text in messages
- [ ] Lighthouse run on production build, targets met or reason listed
- [ ] Main keyword per page reported; Google Business link asked (business site)
- [ ] Private pages (if any): `noindex`, not in sitemap, disallowed in `robots.ts`

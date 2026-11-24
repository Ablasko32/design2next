# SEO

Read when project has **public pages**: landing, webshop (products, categories), blog. Apps, dashboards, pages behind login → only SKILL.md SEO basics.

SKILL.md rules still apply; this adds SEO. Translations on → also SEO part of `references/i18n.md`. CMS content → meta fields from `@payloadcms/plugin-seo` (`references/cms.md`), rules below still apply.

## 1. Before starting

- Main keyword per page unclear from design / content → ask.
- No production URL in `constants/site.ts` → ask (needed for `metadataBase`, canonical, sitemap).
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
constants/
  seo.ts                titles, descriptions, keywords per page
```

## 3. Metadata

- Root layout: `metadataBase` (url from `constants/site.ts`), title template `"%s | <Site>"`, default title, description, `openGraph`, `twitter`, `robots`, `alternates.canonical`.
- **Every** public `page.tsx` exports `metadata` or `generateMetadata`. Dynamic routes: `generateMetadata` with real data.
- SEO text in `constants/seo.ts` (dictionary when translations on).

## 4. Titles and descriptions

- **Title:** 50–60 chars for **full rendered title incl. brand** from template (`"%s | <Site>"`). Page part = 50–60 minus length of `" | <Site>"`. Main keyword near start.
- **Description:** 140–160 chars. What page offers, why click. Keyword used naturally. Ends with soft call to action.
- Unique per page. No keyword stuffing. People first.

## 5. Open Graph and Twitter

- `og:title`, `og:description`, `og:url`, `og:type`, `og:locale`, `og:site_name`, `og:image` (1200×630, with `alt`).
- `twitter.card: "summary_large_image"`.
- OG image: `opengraph-image.tsx` or static file. Default in `app/`, override per route if needed. Look from design (colors, fonts, logo); not in design → ask or propose from tokens.

## 6. Structured data (JSON-LD)

Every public page gets JSON-LD matching its **visible** content (schema.org). Never describe what page doesn't show.

- Home: `Organization` (or `LocalBusiness` if address) + `WebSite`.
- FAQ section: `FAQPage`.
- Nested pages (categories, products, posts): `BreadcrumbList`.
- Product: `Product` with `offers` (price, currency, availability); `aggregateRating` only if ratings shown.
- Category: `CollectionPage` (+ `ItemList` of shown products).
- Blog post: `Article` / `BlogPosting` with `author`, `datePublished`, `dateModified`, `image`.

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
- LCP image `priority`, fonts via `next/font` (SKILL.md; matters most here).

## 8. Sitemap and robots

- `app/sitemap.ts`: every public route, with `lastModified`. Dynamic routes (products, categories, posts) from DB or CMS (cached queries). Huge shops: split with `generateSitemaps` (check docs).
- `app/robots.ts`: allow public, disallow `/api/`, private routes and CMS admin (`/admin`), point to sitemap.
- Pages behind login: not in sitemap, disallowed here.

## 9. Checklist

- [ ] Every public page: own title (50–60, with brand) + description (140–160). No duplicates
- [ ] Root layout: `metadataBase`, title template, Open Graph, Twitter, canonical
- [ ] OG image (1200×630) with `alt`
- [ ] JSON-LD on every public page, matches visible content, typed with `schema-dts`
- [ ] One `h1` per page with main keyword
- [ ] `sitemap.ts` lists all public routes. `robots.ts` blocks `/api/` + private routes, points to sitemap
- [ ] Private pages (if any): `noindex`, not in sitemap, disallowed in `robots.ts`

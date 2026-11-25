---
name: design-to-next
description: Rules for building Next.js projects (landing pages, webshops, apps) and for turning a design into Next.js code. Use this skill whenever creating a new Next.js project, adding pages, components or sections to one, translating a design into Next.js (Claude Design or other HTML/CSS artifact or export, Open Design, Figma, mockup, screenshot), or setting up styling, tokens, fonts, images, icons, forms, email, database, auth (Better Auth), payments (Stripe), CMS (Payload), SEO, translations, dark mode, cookies / GDPR or legal pages in a Next.js app.
argument-hint: "[auto|check] [landing|shop|app] <design: claude.ai artifact URL, file or folder path> [extra context...]"
license: MIT
metadata:
  author: Antonio Blašković
  version: 1.0.0
---

# Design to Next.js

Fixed stack and structure for every Next.js project. Follow unless user says otherwise.

## Run modes and input

Arguments: `$ARGUMENTS`

Format: `[auto|check] [landing|shop|app] <design> [extra context...]`. Mode and type optional, any order before design.

- **`<design>`**: claude.ai artifact URL (Claude Design or any HTML artifact), local file (`.html`, image, PDF) or folder (HTML/CSS export). Read per `references/design-input.md`. None given → ask. (Only applying rules to existing code → no design needed.)
- **Mode**: default **`check`**.
- **Type**: `landing`, `shop` or `app`. See "Project type" below.
- **Extra context**: free text after design = user's notes (pages, features, services, wishes). Counts as user instructions: beats `auto` defaults.

| Mode    | What happens                                                                                                                                                                                                                                                                                     |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `check` | Build **one small slice first**: setup, tokens, fonts, **hero** (+ header if design shows them together). Run it, screenshot all sizes, show what was built and what is open, then **stop and ask to continue**. Build the rest only after yes. Make checkpoint change requests before going on. |
| `auto`  | Build everything, no stops. Answer usual questions with defaults below; list every assumption in final summary. Stop only if impossible to go on (design missing / unreadable).                                                                                                                  |

`auto` defaults instead of asking:

- Icons: `lucide-react`, unless design shows another set.
- Wide screens: no own layout.
- Dark mode / translations: only if design clearly shows them.
- Email: build form + Server Action; sending = clearly marked `TODO`; service choice listed in summary.
- Font not on Google Fonts, no file in export: system font stack as placeholder, listed. Never another named font.
- EU legal: GDPR issues and needed pages **listed**, not built.
- Missing copy / images: keep as in design, list placeholders.
- CMS: only if user asked. Media storage: local + listed in summary.
- Database: PostgreSQL in local Docker; no Docker → empty `DATABASE_URL` + `TODO`, listed.

User's explicit instructions beat these defaults.

## Project type

Decide **before any code**. Type picks the folder structure.

| Type      | What                                                 | Structure (read exactly one)      | Usually also                                            |
| --------- | ---------------------------------------------------- | --------------------------------- | ------------------------------------------------------- |
| `landing` | Marketing site, portfolio, blog / content site       | `references/structure-landing.md` | SEO, EU legal, CMS (blog)                               |
| `shop`    | Webshop: catalog, cart, checkout                     | `references/structure-app.md`     | SEO, payments, auth, database, EU legal, CMS (products) |
| `app`     | SaaS, dashboard, admin, portal: accounts, data, CRUD | `references/structure-app.md`     | auth, database                                          |

- Type in arguments → use it.
- Else infer from design + extra context: cart, prices, checkout → `shop`; sign-in, dashboard, tables, CRUD forms → `app`; else `landing`.
- Unclear → ask. `auto`: pick by design, list in summary.
- Existing project: follow its structure (`features/` → app, `components/sections/` only → landing). Landing growing into shop / app → ask before restructuring.

## Optional features (references)

Design job → always read `references/design-input.md`.

Features below are **off by default**. Read the reference only when needed; follow it on top of this file. Auth, payments (with orders) and CMS need a database → also `references/database.md`.

| Feature      | When                                                                         | Read                      |
| ------------ | ---------------------------------------------------------------------------- | ------------------------- |
| Dark mode    | Design has dark version, or user asks                                        | `references/dark-mode.md` |
| Translations | User asks, or design shows language switcher / several languages             | `references/i18n.md`      |
| SEO          | Public pages: landing, webshop, blog                                         | `references/seo.md`       |
| Database     | Data must be stored (auth, CMS, orders, app data)                            | `references/database.md`  |
| Auth         | Sign-in needed (accounts, dashboard, admin)                                  | `references/auth.md`      |
| Payments     | Takes payments (webshop, paid plans)                                         | `references/payments.md`  |
| EU legal     | Site run from / targets EU (ask once if unclear)                             | `references/legal-eu.md`  |
| CMS          | User asks for CMS / content edited by non-developers (blog, pages, products) | `references/cms.md`       |

Design hints at a feature (theme toggle, language switcher) but user never mentioned it → ask before adding.

## 1. Next.js docs first

- Always **latest Next.js**. No APIs from memory.
- Before any Next.js API (caching, metadata, routing, actions, config, special files), check docs:
  1. Bundled: `node_modules/next/dist/docs/`
  2. Else: https://nextjs.org/docs
- Docs and skill disagree → docs win. Tell user.

## 2. Design = source of truth

- Build what design shows: colors, spacing, sizes, fonts, layout, copy.
- **Never "fix" the design** (low contrast, odd spacing, unusual pattern). No own changes to colors, sizes, layout.
- Real problem? Build as designed, **tell user** at end. User decides.
- Fill gaps only where design shows nothing (hover, focus, loading, error, tablet size). Derive from existing tokens.

## 3. Stack

| Area          | Choice                                                                           |
| ------------- | -------------------------------------------------------------------------------- |
| Framework     | Next.js latest, App Router only                                                  |
| Language      | TypeScript, `strict: true`                                                       |
| Styling       | Tailwind CSS latest (v4, CSS-first config)                                       |
| Caching       | Cache Components (`cacheComponents: true`)                                       |
| Class merge   | `cn()` = `clsx` + `tailwind-merge`                                               |
| Variants      | `class-variance-authority` (cva)                                                 |
| Fonts         | `next/font`, always. `next/font/google` whenever font is there                   |
| Images        | `next/image`, always. Files as WebP                                              |
| Icons         | Ask user (section 7, Icons)                                                      |
| Animation     | CSS first. `motion` only when CSS can't                                          |
| Forms         | react-hook-form + Zod (`@hookform/resolvers`)                                    |
| Mutations     | Server Actions                                                                   |
| Database      | PostgreSQL default (MySQL, SQLite, Mongo for Payload) → `references/database.md` |
| ORM           | Drizzle, only with a database                                                    |
| Email         | Only when a form needs it. Ask which service (section 8)                         |
| Auth          | Better Auth, only when needed → `references/auth.md`                             |
| Payments      | Stripe, only when needed → `references/payments.md`                              |
| CMS           | Payload 3.x (≥ 3.81), only when needed → `references/cms.md`                     |
| Tests         | None, unless user asks                                                           |
| Lint / format | ESLint + Prettier                                                                |
| UI library    | Own components in `components/ui/`. shadcn/ui **only if user asks**              |
| Dark mode     | Only if design has it / user asks → `references/dark-mode.md`                    |
| Translations  | Only if several languages → `references/i18n.md`                                 |

### Package manager

Use project's (lockfile). New project: first installed of `pnpm` → `bun` → `npm` (`command -v`).

### New project

Run `<pm> create next-app@latest --help` first (flags change). Then run **non-interactively** (shell can't answer prompts):

```bash
<pm> create next-app@latest <name> --ts --tailwind --app --eslint --no-src-dir --import-alias "@/*" --yes
```

`--help` shows more prompts (bundler, React Compiler...) → pass a flag for each. Then set `cacheComponents: true` in `next.config.ts`.

### Lint and format

- Existing ESLint / Prettier config: follow it, don't replace.
- None: add Prettier + `prettier-plugin-tailwindcss` + `eslint-config-prettier` next to `create-next-app` ESLint.
- Tailwind v4 has no `tailwind.config.js`. Point the Prettier plugin at the CSS, else it won't know custom classes (`text-heading-xl`, `tablet:`):

  ```json
  {
    "plugins": ["prettier-plugin-tailwindcss"],
    "tailwindStylesheet": "./app/globals.css"
  }
  ```

- `package.json` scripts: `lint`, `format` (`prettier --write .`), `format:check` (`prettier --check .`), `typecheck` (`tsc --noEmit`).
- Prettier ignores build output: `.next/` in `.gitignore` (Prettier 3 reads it) or `.prettierignore`.

### shadcn/ui

- Not installed by default.
- User asks: init into `components/ui/`, map its CSS vars to section 6 tokens. Never two token sets.
- Generated components use `sm:` / `md:` / `lg:` → replace with `tablet:` / `desktop:` (section 6) right after adding each one. `check.sh` errors on default breakpoints.

### Security headers

- `next.config.ts` `headers()` for all routes: `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY` (or CSP `frame-ancestors 'none'`; with Payload live preview `SAMEORIGIN` / `'self'`, admin shows the site in an iframe), `Permissions-Policy` (turn off camera, microphone, geolocation unless used), `Strict-Transport-Security` (production).
- CSP: static policy only if user asks. **No per-request nonce CSP by default:** it needs dynamic rendering of every page and breaks `cacheComponents` / static output.
- `images.remotePatterns`: exact hostnames only, never `hostname: "**"`. No `dangerouslyAllowSVG: true` unless `contentSecurityPolicy` is set with it.

## 4. Folder structure

**Full tree = structure reference of the project type** (see "Project type"): `references/structure-landing.md` or `references/structure-app.md`. Read it before creating folders. Rules below apply to both.

Rules:

- **No `src/`.** `app/` = **routing files only**. Everything else outside (`components/`, `lib/`, `constants/`, `assets/`, `types/`, `features/` for shop / app, `cms/` with CMS).
- **Root layout** (`<html>`, fonts, providers, global metadata) = `app/layout.tsx`. With i18n: `app/[lang]/layout.tsx`. With CMS (Payload): `app/(frontend)/layout.tsx` (+ `[lang]/`), and `app/(payload)/` copied from template, never edited (`references/cms.md`). "Root layout" in this skill and its references means this file.
- **Don't scaffold unused things.** "Only when" items exist only when needed. Landing without DB → no `lib/db/`, no `drizzle.config.ts`, no Drizzle packages.
- File names **kebab-case** (`hero-section.tsx`). Components PascalCase.
- Route groups `(name)` only for shared layout / separation. Not by habit.
- One component per file. Named exports; `default` only where Next.js requires (`page`, `layout`...).
- Import via `@/`.

### Loading and error files

Next to the root layout (section 4) always:

- `loading.tsx`: general skeleton from tokens. Not a lone spinner.
- `error.tsx`: `"use client"`. Short message, retry button, logs error. Never shows raw error.
- `global-error.tsx`: `"use client"`, own `<html>` and `<body>`. Always directly in `app/`.
- `not-found.tsx`: 404 + link home. Root layout not in `app/` (i18n, CMS): `not-found.tsx` next to it, not `app/not-found.tsx` (that needs `app/layout.tsx`); global 404 for several root layouts = `app/global-not-found.tsx` (check docs).

`favicon.ico`, `sitemap.ts`, `robots.ts` always directly in `app/` (Next.js serves them only from there).

Route / group gets **own** `loading.tsx` / `error.tsx` only if needed: async / dynamic parts with a different skeleton, or a different error message. Errors bubble to nearest boundary; root covers the rest.

### Constants

- No hardcoded links, site data, image paths in components. They live in `constants/`.
- Plain typed objects, `as const`.

### Images

No image path in components. Every image in `constants/images.ts`; components use it by key. (CMS-managed images come from Payload media instead: `references/cms.md`.)

Files in `assets/images/<section>/`, **not** `public/`. Static import from `public/` is served twice (`/images/...` and `/_next/static/...`). `public/` only for fixed-URL files.

```ts
// constants/images.ts
import heroMain from "@/assets/images/hero/main.webp";

export const IMAGES = {
  hero: {
    main: { src: heroMain, alt: "Living room with Modula furniture" },
  },
} as const;
```

```tsx
<Image {...IMAGES.hero.main} preload sizes="100vw" />
```

- **Always WebP.** Convert any PNG / JPG / GIF / TIFF before use: `node <this skill's dir>/scripts/to-webp.mjs assets/images --replace` from project root. Exceptions: SVG stays SVG; animated GIF kept (or video); OG images and icons in `app/` / `public/` stay PNG / JPG.
- Static imports → Next.js knows width, height, blur placeholder.
- Remote images: also in `IMAGES`, with `width` / `height`. Host in `images.remotePatterns` (exact hostname, never `"**"`).
- `alt` always in the constant. Decorative: `alt: ""`.
- Always `next/image` with `sizes`. **No `priority`** (deprecated since Next.js 16). Known LCP image (hero): `preload`. LCP image that changes with viewport: `loading="eager"` + `fetchPriority="high"` on each candidate, no `preload`. Never `preload` together with `loading` / `fetchPriority`.

### Environment variables

Only when needed:

- `.env.example` (all keys, no values, committed) + `.env.local` (real values). `.gitignore` covers `.env*.local`.
- `UPPER_SNAKE_CASE`, one per line, no quotes unless spaces. Group with `#` comments.
- `NEXT_PUBLIC_` only for values the browser needs. Never secrets.
- Validate with Zod. Server vars in `lib/env.ts` (`server-only`), public in `lib/env-public.ts`. No `process.env` elsewhere in app code.
- Exception: CLI-run files (`drizzle.config.ts`, `next.config.ts`, `payload.config.ts`, `cms/**`) read `process.env` directly. Never import `lib/env.ts` there (`server-only` throws outside Next.js).

```bash
# .env.example
# Database
DATABASE_URL=

# Analytics
NEXT_PUBLIC_ANALYTICS_ID=
```

## 5. Server and client

- Server Components by default.
- `"use client"` only on small leaf components needing state, effects, browser APIs. Not on pages / sections if avoidable.
- **Always wrap dynamic / async parts in `<Suspense>`** with a layout-matching skeleton.
- Cache Components:
  - Reads in query files (location per structure reference) with `"use cache"`.
  - Every cached function sets `cacheLife(...)` and `cacheTag(...)`. Shop / app: tags only from `lib/cache-tags.ts`.
  - After a write: `updateTag` in Server Actions, `revalidateTag(tag, "max")` in route handlers / webhooks (check docs).
  - Runtime data (`cookies()`, `headers()`, `searchParams`, `params`, session) outside cached scope, inside `<Suspense>`.
- `import "server-only";` atop `lib/db/index.ts`, every query file, `lib/env.ts`, `lib/stripe.ts`, session and action helpers (shop / app), any other secret file.
- **Never** in files CLI tools load in plain Node (it throws there): `lib/db/schema.ts` (drizzle-kit), `drizzle.config.ts`, `lib/auth.ts` (Better Auth CLI, see `references/auth.md`), `payload.config.ts` and `cms/**` (Payload CLI).
- Route handlers (`app/api/.../route.ts`) **only** for webhooks, third-party callbacks, public API. Reads = Server Components, writes = Server Actions.

## 6. Styling and tokens (`app/globals.css`)

Token flow, always this order:

**primitive vars in `:root` → semantic tokens in `@theme` → components → sections → pages**

- Every raw value (colors, font sizes, radii, shadows, spacing, durations) = CSS var in `:root`.
- `@theme` maps them to **semantic** names. Components use semantic utilities only.
- No raw hex / px / arbitrary values for **design values**: colors, typography (size, line height, letter spacing, weight, font), radii, shadows, base spacing / layout tokens. (`text-[#123]`, `text-[17px]`, `rounded-[10px]` not allowed.) Missing value → add token.
- One-off **layout geometry** may be arbitrary: `grid-cols-[2fr_1fr]`, `aspect-[4/5]`, `max-w-[38ch]`, a decorative `top-[…]`. No tokens for these.

### Building `globals.css`

Read `references/tokens.md` before writing / changing `app/globals.css`: reading tokens from design, naming, full example, adding tokens later.

### Responsive

- **Mobile first, always.** Base classes = mobile.
- Only `tablet:` and `desktop:`. Default Tailwind breakpoints removed.
- Check ~375px, ~768px, ~1280px.
- **Wide screens (1440px+):** ask user at start if they need own layout. Only if yes: add `wide:` breakpoint (value from design / user), check that size too.

### Animation

- CSS transitions / `@keyframes` first.
- `motion` only where CSS is weak: layout, exit, gestures, scroll-linked.
- Respect `prefers-reduced-motion`: non-essential animation off or reduced (`motion-safe:` / `motion-reduce:`, or `useReducedMotion`).

### Accessibility

Invisible in the design, so always added:

- Visible keyboard focus on every interactive element (`focus-visible:` from tokens).
- Icon-only buttons / links: `aria-label`. Decorative icons: `aria-hidden="true"`.
- Form fields: `<label>` (visually hidden if design shows none), errors via `aria-describedby`.
- Real `button` / `a`, no clickable `div`s.
- Semantic HTML: `header`, `main`, `section`, `nav`, `footer`.
- Low contrast in design **not** changed: build as designed, list for user (section 2).

### Dark mode

Not by default. When needed: `references/dark-mode.md`.

## 7. Components

- `components/ui/` = small, generic, token-only primitives. No business text.
- `components/sections/` = built from `ui/`. Content from props or `constants/`.
- Shop / app: domain UI in `features/<domain>/components/`, built from `ui/`.
- Pages only arrange sections / feature components. No styling in `page.tsx` beyond layout.
- Every component takes `className`, merges with `cn()`.
- Fonts: `next/font` in root layout, exposed as CSS vars (`--font-body`, `--font-heading`).
  - On Google Fonts → `next/font/google`, always (self-hosts, no request to Google). Only weights / styles the design uses.
  - Not on Google Fonts → `next/font/local`, woff2 in `assets/fonts/`. No file / license info → ask. Never swap fonts silently.

`lib/utils.ts`:

```ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Icons

Ask at start which set, unless design already shows one (class names, known shapes). Propose:

- **`lucide-react`** (recommended: large, consistent stroke, tree-shakes)
- `@heroicons/react` (Tailwind's set, outline + solid)
- `@phosphor-icons/react` (several weights, softer designs)
- `@tabler/icons-react` (very large, stroke)
- `@radix-ui/react-icons` (small, 15px grid, minimal UI)

Rules:

- One set per project. Custom design icons (logo, brand shapes) = SVG components in `components/icons/`.
- Size / color via classes (`size-5`, `text-muted`), never hardcoded in SVG. `currentColor` for fill / stroke.
- Decorative: `aria-hidden="true"`; icon-only buttons: `aria-label`.

### Variants with cva

Component with more than one look → `cva`, classic names:

- `variant`: `primary`, `secondary`, `outline`, `ghost`, `link`, `destructive` (only those in design)
- `size`: `sm`, `md`, `lg` (`xl` / `icon` only if in design)
- Always `defaultVariants`.
- Export variants function (`buttonVariants`) so links can look like buttons.

Pattern (classes from design tokens):

```tsx
// components/ui/button.tsx
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

export const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-primary text-on-primary hover:bg-primary-hover",
        secondary: "bg-elevated text-fg hover:bg-border",
        outline: "border border-border text-fg hover:bg-elevated",
        ghost: "text-fg hover:bg-elevated",
      },
      size: {
        sm: "h-9 px-3 text-body-sm",
        md: "h-11 px-5 text-body-md",
        lg: "h-13 px-7 text-body-lg",
      },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);

type ButtonProps = React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants>;

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}
```

## 8. Forms and data

- Zod schemas shared client + server (landing: `lib/validations/`; shop / app: `features/<domain>/schemas.ts`).
- Client: react-hook-form + `zodResolver`. Server Action validates again with Zod.
- **Landing:** keep server simple. One Server Action per form (contact, newsletter) in `lib/actions/`, returns `{ ok, error }`. Details: `references/structure-landing.md`.
- **Shop / app:** actions in `features/<domain>/actions.ts`, always through `authAction` / `publicAction` helper (session + Zod + safe errors), `updateTag` after writes. Details: `references/structure-app.md`.
- **Email:** form must send mail (contact, newsletter, auth) → **ask which service before building**. Propose: Resend (simple API, React Email), Postmark, Brevo (also newsletters), Mailchimp (newsletter only), user's SMTP. Keys only via `lib/env.ts`. Send in Server Action, never client.
- **Spam:** every public form gets honeypot + simple rate limit in action. In-memory `new Map()` limit doesn't work on serverless (each instance own memory, reset on cold start) → Upstash Redis / DB table, or a `// TODO: rate limit store` when host unknown. Captcha (e.g. Cloudflare Turnstile) only if user asks or spam is known.
- **Personal data:** EU-facing → `references/legal-eu.md` (privacy notice, opt-in).
- DB only when needed (`references/database.md`: which DB, local Docker or user's connection data). Then Drizzle only, never from client components.

## 9. SEO basics

Full SEO (descriptions, OG, JSON-LD, sitemap, robots) = **public pages** (landing, webshop products / categories, blog) → `references/seo.md`. Apps / dashboards get only these basics (every project gets them):

- Root layout: title template `"%s | <Site>"` + default title. Every `page.tsx` sets own `title`.
- Correct `<html lang="...">`.
- One `h1` per page. Headings in order (`h2` → `h3`); tag by structure, look by class.
- Internal links via `next/link`.
- `app/favicon.ico` always. `icon`, `apple-icon`, `manifest.ts` only if user wants.
- Pages behind login (dashboard, account, admin, checkout): `robots: { index: false, follow: false }`, once in route group `layout.tsx`.

## 10. Design → Next.js workflow

1. **Read design.** Per `references/design-input.md` (artifact, export, Figma, screenshot). List colors, type sizes, radii, shadows, spacing, fonts, sections. Decide project type, read its structure reference. Ask open questions now: type (if unclear), icon set, wide screens, email service, EU / legal, optional features.
2. **Tokens.** Read `references/tokens.md`. Into `:root`, map in `@theme`.
3. **UI components.** `components/ui/` primitives, tokens only.
4. **Sections / features.** Each marketing block → `components/sections/<name>-section.tsx`. Shop / app screens → `features/<domain>/` (schemas, queries, actions, components).
5. **Pages.** Compose sections / feature components in `app/.../page.tsx`, add title. Public pages: full SEO per `references/seo.md`.
6. **Responsive.** Mobile first, then `tablet:`, then `desktop:`.
   - **`check` mode checkpoint:** first pass does steps 2–6 only for setup, tokens, fonts, hero (+ header if shown with it). Run step 7 for that slice, then stop: show screenshots, list built / assumed / open, ask to continue. Remaining sections only after yes.
7. **Check.** Run app, open with available browser tool (Claude in Chrome, or Playwright if set up), screenshot three sizes (+ wide if asked), compare with design.
8. **Finish.** From project root run `bash <this skill's dir>/scripts/check.sh --build`. Fix every ERROR, look at every WARN. Then checklist below for what the script can't check.
9. **Summary for user.** End with:
   - design problems noticed (built as designed)
   - gaps filled with own proposals (states, sizes, copy, estimated values)
   - open GDPR / legal items (if EU)
   - failed or skipped checklist items
   - **Deploy suggestion** (comment only, nothing set up), by what was built. E.g. Vercel: full Next.js features, least setup (Cache Components, Server Actions, ISR, images). Cloudflare (Workers via OpenNext): fast, cheap landing, or user already on Cloudflare. Heroku, Railway, Fly.io, VPS: long-running Node server, or app + DB together. Note pre-deploy checks: env vars, production DB + migrations, production URL, Stripe / Better Auth production keys and webhook URLs.

## 11. Final checklist

No "done" until every item is checked. Report failed / skipped items.

`scripts/check.sh` covers most structure, token, client/server, image, env, SEO-basics items, and runs typecheck, lint, format:check (+ build with `--build`). Its clean run is the proof for those items; don't tick them without it. Rest (design match, console, Suspense fallbacks, text quality) by hand.

**Design**

- [ ] Matches design at mobile, tablet, desktop (checked in browser)
- [ ] Nothing in design changed on my own
- [ ] Noticed design problems listed for user

**Tokens and styling**

- [ ] All raw values in `:root`, mapped in `@theme`
- [ ] No raw colors, typography, radii, shadows, base spacing in components. Arbitrary values only for one-off layout geometry
- [ ] Only `tablet:` / `desktop:` (+ `wide:` if asked), mobile first
- [ ] Animations in CSS, `motion` only where needed, `prefers-reduced-motion` respected
- [ ] Dark mode / translations only if needed; if added, their reference checklist passes

**Structure**

- [ ] Project type decided; its structure reference checklist passes
- [ ] No `src/`. `app/` only routing files
- [ ] Kebab-case files, `@/` imports
- [ ] Next to root layout: `loading.tsx`, `error.tsx`, `not-found.tsx`. Directly in `app/`: `global-error.tsx`, `favicon.ico`
- [ ] Route-level `loading.tsx` / `error.tsx` only where needed
- [ ] Nothing unused scaffolded (DB, actions, queries, env)
- [ ] Multi-look components use `cva` with `defaultVariants`
- [ ] Every component takes `className`, uses `cn()`

**Constants, images, fonts, icons**

- [ ] No hardcoded links, site data, image paths in components
- [ ] Every image in `assets/images/`, in `IMAGES` with `alt`, via `next/image`
- [ ] Images WebP (except SVG, animated GIF, OG / icons)
- [ ] LCP image `preload` (or `loading="eager"` + `fetchPriority="high"`), no `priority`. Fonts via `next/font`, Google Fonts when available
- [ ] One icon set, agreed with user

**Accessibility**

- [ ] Visible focus, `aria-label` on icon-only controls, labels on fields
- [ ] Low contrast / other a11y issues in design listed, not changed

**Server, data, forms**

- [ ] `"use client"` only on leaves
- [ ] Async parts in `<Suspense>` with matching fallback
- [ ] Cached reads: `"use cache"`, `cacheLife`, `cacheTag`. Writes: `updateTag` in actions, `revalidateTag` in route handlers
- [ ] `server-only` on DB client, query files, server env, session, secret files. Not on `lib/db/schema.ts` / `lib/auth.ts` / `payload.config.ts` / `cms/**`
- [ ] Forms: react-hook-form + Zod on client, Zod again in action
- [ ] DB (if any) only via Drizzle, never from client components
- [ ] Route handlers only for webhooks / external API
- [ ] Public forms: honeypot + rate limit with a store that works on the host

**Env**

- [ ] `.env.example` + `.env.local` if env used, `.env*.local` gitignored
- [ ] Env only via `lib/env.ts` / `lib/env-public.ts`. No secret with `NEXT_PUBLIC_`
- [ ] Security headers in `next.config.ts`. `remotePatterns` with exact hosts

**SEO**

- [ ] Title template in root layout, own title per page
- [ ] One `h1` per page, headings in order, `lang` on `<html>`
- [ ] Pages behind login `noindex`
- [ ] Public pages: `references/seo.md` checklist passes

**Quality**

- [ ] `typecheck`, `lint`, `format:check` pass
- [ ] `build` passes, no errors / warnings
- [ ] No browser console errors

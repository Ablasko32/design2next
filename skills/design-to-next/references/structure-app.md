# Structure: app and shop (feature-first)

Read when project type = `app` (SaaS, dashboard, admin, portal) or `shop` (webshop). SKILL.md section 4 shared rules still apply.

Code grouped by **domain** (`features/<domain>/`), not by kind. `app/` only routes: pages arrange feature components and `<Suspense>` boundaries.

Examples below: Drizzle (Postgres) + Better Auth. Check current Next.js, Drizzle and Better Auth docs before coding (SKILL.md section 1); APIs named here (`updateTag`, `revalidateTag`, `unstable_rethrow`, `cacheLife`) can change.

## 1. Tree

```
src/                    all code (SKILL.md section 4); tree from app/ to proxy.ts is inside it
app/
  layout.tsx            root layout, fonts, global metadata
  globals.css           tokens + Tailwind theme (SKILL.md section 6)
  favicon.ico
  loading.tsx / error.tsx / global-error.tsx / not-found.tsx
  sitemap.ts / robots.ts        public pages with SEO (references/seo.md)
  (marketing)/          public pages (home, pricing): components/sections, full SEO
  (auth)/               sign-in, sign-up, reset (references/auth.md)
  (app)/                private routes: layout = noindex + session check
    projects/           example domain
      page.tsx          list + filters
      new/page.tsx      create
      [id]/page.tsx     detail
      [id]/edit/page.tsx
  (shop)/               shop only: products/, products/[slug]/, cart/, checkout/
  api/
    auth/[...all]/route.ts      Better Auth handler
    webhooks/stripe/route.ts    only with payments
features/
  <domain>/             projects, products, orders, cart, checkout, billing...
    queries.ts          all reads: "server-only", "use cache", DTOs
    actions.ts          all writes: "use server", via action helper, updateTag
    schemas.ts          Zod schemas + inferred types (shared client + server)
    components/         UI of this domain only (project-table.tsx, project-form.tsx)
  auth/
    session.ts          getSession (React cache), requireUser, requireOrg
components/
  ui/                   shared primitives (button, input, table, dialog...)
  layout/               app shell: header, sidebar, footer, nav
  sections/             marketing page sections only
  providers/, icons/, seo/      only when needed
lib/
  db/index.ts           Drizzle client ("server-only")
  db/schema.ts          ONE schema file, incl. Better Auth tables (CLI output)
  cache-tags.ts         central tag registry
  action-helpers.ts     authAction / publicAction wrappers
  auth.ts, auth-client.ts       references/auth.md
  stripe.ts             references/payments.md
  utils.ts              cn() and small helpers
  routing.ts            href() (+ matchRoute, pageAlternates with i18n)
  i18n/messages.ts      getMessages() (server-only)
  env.ts                server env
  env-public.ts         NEXT_PUBLIC_ env, only when needed
constants/
  routes.ts             ROUTES: every internal URL, also dynamic (project: "/projects/[id]")
  site.ts               site name, socials, fixed site data (no URL / contact: env)
  navigation.ts         nav: route key + message key
  images.ts             every image the app uses (alt = message key)
  i18n.ts               locales, only with translations
messages/
  hr.json               all UI text, error keys → text, SEO text for public pages
assets/
  images/               statically imported images, by section, WebP
  fonts/                woff2, always (local fonts, used weights + subsets)
types/
proxy.ts                only with translations / optimistic auth redirect
payload.config.ts, cms/, migrations/   only with CMS (references/cms.md)

root (next to src/, config only):
public/                 only files needing a fixed URL
.env.example            committed, keys + comments, no values (agent writes this)
.env.local              gitignored, filled by the user only
drizzle.config.ts, drizzle/     with a database
compose.yaml            local Docker DB
package.json, next.config.ts, tsconfig.json, eslint / prettier config
```

With CMS: root layout + loading / error / not-found move to `app/(frontend)/` (route groups above live inside it), `app/(payload)/` = Payload admin. Our Drizzle tables then kept apart from Payload's (Postgres: `pgSchema("app")`; other DBs: `references/database.md` section 5).

- **No `lib/queries/`, `lib/actions/`, `lib/validations/`** in this type. They live in features.
- Feature file grows past ~300 lines → folder (`queries/list.ts`, `queries/detail.ts`), same rules per file.
- **DB schema stays in `lib/db/schema.ts`** (Better Auth CLI writes there, `drizzle.config.ts` points there). Many tables → `lib/db/schema/` folder + `index.ts` re-export; point `drizzle.config.ts` and Better Auth CLI `--output` at it. Never `server-only` in schema files.
- **Feature boundaries:** a feature may import another feature's `queries.ts`, `actions.ts`, `schemas.ts`. Not its `components/` (shared UI → `components/ui/`) and not its private helpers.

## 2. Cache tags

No tag strings in queries / actions. All in one file:

```ts
// lib/cache-tags.ts
export const cacheTags = {
  products: () => "products",
  product: (id: string) => `product:${id}`,
  userProjects: (userId: string) => `projects:user:${userId}`,
  project: (id: string) => `project:${id}`,
  orgSettings: (orgId: string) => `org:${orgId}:settings`,
} as const;
```

Reads: `cacheTag(cacheTags.project(id))`. Writes: `updateTag(cacheTags.project(id))`.

- **`updateTag`** = only in Server Actions (user sees own write at once).
- **`revalidateTag(tag, "max")`** = route handlers (Stripe / CMS webhooks), background jobs.

## 3. Session and queries

```ts
// features/auth/session.ts
import "server-only";
import { cache } from "react";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { href } from "@/lib/routing";

// One session lookup per request, however many components ask
export const getSession = cache(async () =>
  auth.api.getSession({ headers: await headers() }),
);

// Pages and queries: no session → sign-in
export async function requireUser() {
  const session = await getSession();
  if (!session) redirect(href("signIn"));
  return session.user;
}
```

With orgs (Better Auth `organization` plugin, only if app has teams / tenants): add `requireOrg()` returning `session.session.activeOrganizationId` (no org → redirect to org picker). Tenant id = `orgId` everywhere below instead of `userId`.

Queries:

```ts
// features/projects/queries.ts
import "server-only";
import { and, desc, eq, ilike } from "drizzle-orm";
import { cacheLife, cacheTag } from "next/cache";
import { requireUser } from "@/features/auth/session";
import { cacheTags } from "@/lib/cache-tags";
import { db } from "@/lib/db";
import { projects } from "@/lib/db/schema";
import type { ProjectFilters } from "./schemas";

// User text in LIKE: escape wildcards, else "%" / "_" match everything
const escapeLike = (v: string) => v.replace(/[\\%_]/g, (c) => `\\${c}`);

// DTO: only columns UI needs, never whole rows
const projectColumns = {
  id: projects.id,
  name: projects.name,
  status: projects.status,
  description: projects.description,
};

// List with filters: dynamic (filter combos vary), runs inside <Suspense>
export async function getProjects(filters: ProjectFilters) {
  const user = await requireUser();
  return db
    .select(projectColumns)
    .from(projects)
    .where(
      and(
        eq(projects.userId, user.id), // always filter by tenant
        filters.status ? eq(projects.status, filters.status) : undefined,
        filters.q
          ? ilike(projects.name, `%${escapeLike(filters.q)}%`)
          : undefined,
      ),
    )
    .orderBy(desc(projects.createdAt));
}

// Detail: auth first, then cached read keyed by (tenant, id)
export async function getProject(id: string) {
  const user = await requireUser();
  return getCachedProject(user.id, id);
}

async function getCachedProject(userId: string, id: string) {
  "use cache";
  cacheLife("hours");
  cacheTag(cacheTags.userProjects(userId), cacheTags.project(id));

  const [row] = await db
    .select(projectColumns)
    .from(projects)
    .where(and(eq(projects.id, id), eq(projects.userId, userId)))
    .limit(1);
  return row ?? null;
}

export type Project = NonNullable<Awaited<ReturnType<typeof getProject>>>;
```

Rules:

- **Public data** (catalog, pricing, blog): `"use cache"` directly, args = cache key.
- **Private data:** exported function checks session, then calls non-exported cached function with tenant id. **Never** `cookies()` / `headers()` / `getSession()` inside `"use cache"`. (`"use cache: private"` exists for per-user caching; check docs, not default.)
- Tenant filter (`userId` / `orgId`) in **every** where: reads, updates, deletes.
- User text in `like` / `ilike`: escape `\`, `%`, `_` first (`escapeLike`).
- Auth checked in every query and action, never only in layout or `proxy.ts`. Layouts don't re-render on every navigation; Server Action = public POST endpoint.
- Client components may `import type { Project }` from `queries.ts` (type-only import is erased). Never value imports.

## 4. Actions

No hand-written session + Zod + try/catch in every action.

```ts
// lib/action-helpers.ts
import "server-only";
import { unstable_rethrow } from "next/navigation";
import type { z } from "zod";
import { getSession } from "@/features/auth/session";

export type ActionResult<T = void> =
  { ok: true; data: T } | { ok: false; error: string };

// Expected failure with a safe message key (not found, forbidden, conflict)
export class ActionError extends Error {}

type User = NonNullable<Awaited<ReturnType<typeof getSession>>>["user"];

export function authAction<S extends z.ZodType, T>(
  schema: S,
  handler: (input: z.output<S>, user: User) => Promise<T>,
) {
  return async (raw: z.input<S>): Promise<ActionResult<T>> => {
    const session = await getSession();
    if (!session) return { ok: false, error: "unauthorized" };

    const parsed = schema.safeParse(raw);
    if (!parsed.success) {
      return {
        ok: false,
        error: parsed.error.issues[0]?.message ?? "invalid_input",
      };
    }

    try {
      return { ok: true, data: await handler(parsed.data, session.user) };
    } catch (e) {
      unstable_rethrow(e); // let redirect() / notFound() through
      if (e instanceof ActionError) return { ok: false, error: e.message };
      console.error(e);
      return { ok: false, error: "server_error" }; // never raw errors to client
    }
  };
}
```

- `publicAction(schema, handler)`: same without session (guest cart, newsletter). Public forms: honeypot + rate limit (SKILL.md section 8).
- Roles: `authAction` variant or check `user.role` first line of handler.
- Error strings = keys; UI maps to text (text in messages).

Schemas:

```ts
// features/projects/schemas.ts
import { z } from "zod";

export const projectStatus = ["active", "archived"] as const;

export const projectSchema = z.object({
  name: z.string().trim().min(2, "Name needs at least 2 characters."),
  status: z.enum(projectStatus),
  description: z.string().trim().max(500),
});
export type ProjectInput = z.infer<typeof projectSchema>;

// searchParams are untrusted: parse, bad values → ignored
export const projectFiltersSchema = z.object({
  q: z.string().trim().max(100).optional().catch(undefined),
  status: z.enum(projectStatus).optional().catch(undefined),
});
export type ProjectFilters = z.infer<typeof projectFiltersSchema>;
```

Actions:

```ts
// features/projects/actions.ts
"use server";

import { and, eq } from "drizzle-orm";
import { updateTag } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { ActionError, authAction } from "@/lib/action-helpers";
import { cacheTags } from "@/lib/cache-tags";
import { db } from "@/lib/db";
import { projects } from "@/lib/db/schema";
import { href } from "@/lib/routing";
import { projectSchema } from "./schemas";

export const createProject = authAction(projectSchema, async (input, user) => {
  const [row] = await db
    .insert(projects)
    .values({ ...input, userId: user.id })
    .returning({ id: projects.id });
  updateTag(cacheTags.userProjects(user.id));
  redirect(href("project", { params: { id: row.id } })); // after updateTag; helper rethrows it
});

export const updateProject = authAction(
  projectSchema.extend({ id: z.string() }),
  async ({ id, ...input }, user) => {
    const [row] = await db
      .update(projects)
      .set(input)
      .where(and(eq(projects.id, id), eq(projects.userId, user.id)))
      .returning({ id: projects.id });
    if (!row) throw new ActionError("not_found"); // other tenant's or missing id
    updateTag(cacheTags.userProjects(user.id));
    updateTag(cacheTags.project(id));
    redirect(href("project", { params: { id } }));
  },
);

export const deleteProject = authAction(
  z.object({ id: z.string() }),
  async ({ id }, user) => {
    const [row] = await db
      .delete(projects)
      .where(and(eq(projects.id, id), eq(projects.userId, user.id)))
      .returning({ id: projects.id });
    if (!row) throw new ActionError("not_found");
    updateTag(cacheTags.userProjects(user.id));
    updateTag(cacheTags.project(id));
    redirect(href("projects"));
  },
);
```

- `"use server"` file exports only actions. Helpers / constants elsewhere.
- URLs only via `href()` from `constants/routes.ts` (SKILL.md section 4, Routes). With i18n pass the user's locale: `href("project", { locale, params: { id } })`.
- Update / delete check the row was hit (`.returning()`), else `ActionError("not_found")`. MySQL has no `.returning()` → check affected rows.
- Every write ends with `updateTag` for list + item tags it touched.

## 5. Forms (react-hook-form + helper)

One form for create and edit. `project` prop → edit + prefill; none → create. RHF keeps values on server error (no React 19 form-reset problem).

```tsx
// features/projects/components/project-form.tsx
"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { createProject, updateProject } from "../actions";
import type { Project } from "../queries";
import { projectSchema, type ProjectInput } from "../schemas";

export function ProjectForm({ project }: { project?: Project }) {
  const [serverError, setServerError] = useState<string>();
  const form = useForm<ProjectInput>({
    resolver: zodResolver(projectSchema),
    defaultValues: {
      name: project?.name ?? "",
      status: project?.status ?? "active",
      description: project?.description ?? "",
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    setServerError(undefined);
    const res = project
      ? await updateProject({ ...values, id: project.id })
      : await createProject(values);
    // success = server redirect; then res can be undefined on the client
    if (res && !res.ok) setServerError(res.error);
  });

  // fields with <label>, errors via aria-describedby (SKILL.md section 6),
  // submit disabled while form.formState.isSubmitting
}
```

Small no-input actions (delete, toggle): button with `useTransition` → `startTransition(async () => { const res = await deleteProject({ id }); ... })`. Destructive → confirm in own dialog component, never `window.confirm`.

## 6. Pages and Suspense

With Cache Components, `params`, `searchParams`, session and dynamic queries are runtime data: page shell renders at once, data parts inside `<Suspense>`. Don't `await params` at page top; pass promise down.

```tsx
// app/(app)/projects/page.tsx
import { Suspense } from "react";
import { ProjectFilters } from "@/features/projects/components/project-filters";
import { ProjectFiltersSkeleton } from "@/features/projects/components/project-filters-skeleton";
import { ProjectList } from "@/features/projects/components/project-list";
import { ProjectListSkeleton } from "@/features/projects/components/project-list-skeleton";

export const metadata = { title: "Projects" };

export default function ProjectsPage({ searchParams }: PageProps<"/projects">) {
  return (
    <div className="grid gap-6">
      {/* client: useSearchParams() + router.replace */}
      <Suspense fallback={<ProjectFiltersSkeleton />}>
        <ProjectFilters />
      </Suspense>
      {/* server: awaits searchParams, parses with projectFiltersSchema, calls getProjects() */}
      <Suspense fallback={<ProjectListSkeleton />}>
        <ProjectList searchParams={searchParams} />
      </Suspense>
    </div>
  );
}
```

- **Streaming per section** (dashboard): each block own async server component + own `<Suspense>` with matching skeleton. Default.
- **`Promise.all`** inside one component only when data must show together. Never `await a; await b;` for independent data.
- Detail / edit pages: async child awaits `params`, calls `getProject(id)`, `notFound()` if null. Edit page reuses detail's cache entry.
- **Filters in URL** (`?q=&status=`): client filter component uses `useSearchParams` + `router.replace` in `useTransition`, debounce text input ~300ms. Back button and shared links work; server re-renders list.
- `PageProps<"/route">` helper types: check docs; else type `params` / `searchParams` as `Promise<...>`.
- Async server components that render feature data live in `features/<domain>/components/` (not `app/`).

## 7. Shop part

Shop = public catalog + cart + checkout (+ customer accounts). Also read `references/payments.md`, `references/seo.md`, and usually `references/auth.md`, `references/legal-eu.md`.

```
features/
  products/     public catalog: "use cache" by slug / category, cacheTags.products(), full SEO, JSON-LD Product.
                With CMS: products / categories are Payload collections, read via Local API (references/cms.md)
  cart/         cart id in httpOnly cookie, rows in DB; reads dynamic (cookie) inside <Suspense>
  checkout/     Stripe Checkout action (references/payments.md)
  orders/       written only by Stripe webhook; customer reads via requireUser
```

- Catalog pages static-friendly: cached queries, `generateStaticParams` for product / category pages when the list is known (check docs).
- Cart badge in header = small async component in `<Suspense>` (reads cookie), rest of header static.
- Cart actions = `publicAction` (guest) or `authAction` (account). Prices **never** from client: look up on server.
- Stock / price changes from admin action → `updateTag`; from Stripe / CMS webhook → `revalidateTag(tag, "max")`.

## 8. Checklist

- [ ] Code in `src/`, root only config; tree matches section 1
- [ ] No `lib/queries/`, `lib/actions/`, `lib/validations/`; domain code in `features/<domain>/`
- [ ] URLs (links, `redirect()`) only via `href()`; text in `messages/`
- [ ] `app/` only routes; pages arrange feature components + `<Suspense>`
- [ ] Features import other features only via `queries` / `actions` / `schemas`
- [ ] All tags from `lib/cache-tags.ts`; `updateTag` only in actions, `revalidateTag` in route handlers
- [ ] `server-only` on every `queries.ts`, `session.ts`, `action-helpers.ts`
- [ ] Private reads: session outside `"use cache"`, tenant id as argument
- [ ] Tenant filter in every read, update, delete
- [ ] Queries return DTOs (selected columns), not whole rows
- [ ] All actions via `authAction` / `publicAction`; `redirect` after `updateTag`
- [ ] searchParams parsed with Zod before use
- [ ] Forms: react-hook-form + `zodResolver`, same schema in action; create + edit share one form
- [ ] Shop: prices from server, catalog cached + SEO, cart reads in `<Suspense>`

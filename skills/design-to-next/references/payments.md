# Payments (Stripe)

Read when project takes payments: webshop, paid plans, deposits, donations. Never by default.

SKILL.md rules still apply. Orders / processed events stored → `references/database.md`. Webshop usually also needs `references/auth.md` (customer accounts) and, selling in EU, `references/legal-eu.md` (terms, withdrawal, VAT).

## 1. Before starting

Ask (skip what's clear):

1. **What's sold:** one-off, subscriptions, or both.
2. **Checkout type:** Stripe Checkout (hosted, recommended) or embedded / Elements (only if design shows custom payment form).
3. **Where products / prices live:** Stripe (Products / Prices), our DB, or Payload CMS (`references/cms.md`), each with a Stripe price id per product.
4. **Currency, tax** (Stripe Tax or fixed VAT), **shipping**, **guest checkout** or account required.

Check Stripe docs (https://docs.stripe.com) and `stripe` Node SDK for current API before coding. **Test mode** until user says otherwise.

## 2. Files

```
lib/
  stripe.ts                       server Stripe client, "server-only"
features/                         (references/structure-app.md)
  checkout/actions.ts             Server Action: create Checkout Session, redirect
  products/queries.ts             cached product reads ("use cache", cacheTag(cacheTags.products()))
  orders/queries.ts               customer order reads (requireUser)
app/
  api/webhooks/stripe/route.ts    webhook (allowed: third-party callback)
  (shop)/checkout/success/page.tsx
  (shop)/checkout/cancel/page.tsx
```

Env (via `lib/env.ts` / `lib/env-public.ts`):

```bash
# Stripe
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=   # only with embedded checkout / Elements
```

## 3. Rules

- **Never take prices from client.** Checkout action (`publicAction` / `authAction`) gets product ids + quantities, looks up prices on server (Stripe, DB or Payload).
- **Fulfil orders only in webhook** (`checkout.session.completed`, + subscription events if needed). Success page = thank-you, reads session for display only; never marks anything paid.
- Webhook route:
  - Reads **raw body** (`await request.text()`), verifies with `stripe.webhooks.constructEvent` + `STRIPE_WEBHOOK_SECRET`. Bad signature → 400.
  - **Idempotent**: store processed event ids (or check order status) so repeats do nothing.
  - Returns 2xx fast. After writes, `revalidateTag(cacheTags..., "max")` for matching tags (stock, orders). **Not `updateTag`**: that works only in Server Actions (check docs).
- Customer: create / reuse one Stripe Customer per user (`stripeCustomerId` on user) when auth on.
- Subscriptions: access from status **stored by webhook**, not a Stripe call per request.
- Prices on page: `Intl.NumberFormat` with currency; EU consumers → **with VAT**.
- Local testing: Stripe CLI `stripe listen --forward-to localhost:3000/api/webhooks/stripe`. Give user the command; never commit its secret.

## 4. Checklist

- [ ] Product type, checkout type, price source, currency, tax, shipping agreed with user
- [ ] `lib/stripe.ts` has `server-only`, keys only via env files
- [ ] Prices looked up on server, never from client
- [ ] Webhook verifies signature on raw body, idempotent, `revalidateTag` (not `updateTag`)
- [ ] Fulfilment only in webhook, success page display only
- [ ] Test-mode payment, cancel, failed card tested by hand (card `4000 0000 0000 0002`)
- [ ] Prices with currency (+ VAT for EU consumers)

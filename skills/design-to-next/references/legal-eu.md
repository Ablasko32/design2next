# EU legal: GDPR, cookies, legal pages

Read when site is run from or targets the EU. Unclear → ask once at start.

Claude is no lawyer. All here = **proposal to user**: list what applies, build technical parts, mark every legal text as a draft the user must get checked. Never present generated legal text as final.

## 1. GDPR issues to look for

Go through project, list each that applies + short fix note:

- **Forms with personal data** (contact, newsletter, sign-up, checkout): short notice by submit button, link to privacy policy. Newsletter: explicit opt-in (unticked checkbox) + double opt-in via email service.
- **Third parties receiving data:** email service, analytics, hosting, payment, maps, chat widgets. Each goes in privacy policy. US services → tell user (data leaves EU).
- **Cookie-setting embeds:** YouTube (`youtube-nocookie.com` + click-to-load), Google Maps (click-to-load or static image), social widgets. Load only after consent or click.
- **Fonts:** `next/font` self-hosts Google Fonts, no request to Google. Never `<link>` to `fonts.googleapis.com`.
- **Analytics:** section 3.
- **Data in our DB:** what, how long, how users request deletion. Tell user it belongs in privacy policy.
- **Logs / error tracking** storing IPs or emails: mention.

## 2. Pages

Propose each that applies; build only after user agrees. Content from user (or their generator / lawyer). Claude draft → marked as draft for review.

| Page | When | Notes |
| --- | --- | --- |
| Privacy policy (`/privacy`) | Any personal data processed (forms, analytics, accounts, orders) | Who, what data, why, legal basis, processors, retention, user rights, contact |
| Cookie policy (`/cookies`) | Any non-essential cookie / similar storage | Cookie list; Cookiebot can generate it from its declaration |
| Impressum / legal notice (`/impressum`) | Business site. Required in some EU countries (e.g. Germany, Austria); most EU e-commerce laws require provider details somewhere | Company name, address, registration no., VAT id, contact, responsible person |
| Terms and conditions | Webshop, paid service, accounts | Webshop: delivery, payment, 14-day withdrawal right, complaints |

- Links in footer (`constants/navigation.ts`).
- Public pages with own title + description (`references/seo.md`); `noindex` usually **not** needed.
- Text from user. None → ask whether to draft; mark draft clearly in page and final summary.

## 3. Cookies and consent

- **Strictly necessary** (session, cart, CSRF, language choice, consent itself): no consent needed.
- **Analytics / marketing**: consent **before** they're set.
- Banner needed → propose **Cookiebot**. Load in `app/layout.tsx` via `next/script` before other third-party scripts, ID from `lib/env-public.ts` (`NEXT_PUBLIC_COOKIEBOT_ID`). Third-party scripts blocked until consent (Cookiebot auto-blocking or `data-cookieconsent` per script). Check Cookiebot docs for current setup.
- User wants only simple analytics → mention **cookieless** analytics, usually no banner needed (still in privacy policy). User decides.
- Banner look = Cookiebot's. Design has a banner → tell user to match its style in Cookiebot admin.
- Nothing non-essential → no banner. Never "just in case".

## 4. Checklist

- [ ] Asked if site is EU-based / EU-facing
- [ ] GDPR issues listed (forms, third parties, embeds, analytics, stored data)
- [ ] Needed legal pages proposed; built only after OK; drafts marked
- [ ] Legal links in footer
- [ ] Forms have privacy notice + link; newsletter explicit opt-in
- [ ] No non-essential cookie / third-party script before consent (browser: Application → Cookies, Network)
- [ ] Embeds click-to-load / nocookie
- [ ] No request to `fonts.googleapis.com` / `fonts.gstatic.com`

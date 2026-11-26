#!/usr/bin/env node
// Checks the multi-language SEO of a running site (references/i18n.md section 8).
// Run against a production build:  <pm> run build && <pm> run start
//   node <skill-dir>/scripts/check-i18n-seo.mjs [base-url] [sitemap-path]
//   defaults: http://localhost:3000  /sitemap.xml (else Sitemap: lines from /robots.txt)
//   Sitemap index (generateSitemaps) → every child sitemap is read.
//
// Per URL in the sitemap(s):
//   - answers 200 directly (no redirect)
//   - <link rel="canonical"> = its own URL
//   - <html lang> matches its hreflang
//   - hreflang links in HTML = sitemap alternates, include x-default
//   - every alternate links back (reciprocal) and is itself in the sitemap
// Plus: default locale with prefix (/<default>/...) redirects 308 to the unprefixed URL.
// Exit code 1 on any ERROR.

const base = (process.argv[2] || "http://localhost:3000").replace(/\/$/, "");
const sitemapArg = process.argv[3] || null;
// Bot user agent: Next.js puts metadata into <head> for bots (browsers get it streamed).
const UA =
  "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)";

let errors = 0;
const err = (m) => {
  console.log(`ERROR ${m}`);
  errors++;
};
const ok = (m) => console.log(`ok    ${m}`);

// Sitemap may list the production domain: map it onto base for fetching.
let siteOrigin = null;
const toLocal = (u) => (siteOrigin ? u.replace(siteOrigin, base) : u);
const norm = (u) => u.replace(/\/$/, "") || u;
// One normal form for every URL (sitemap and page side): resolves, percent-encodes non-ASCII, lowercases host
const canon = (u) => norm(new URL(u, siteOrigin).href);

// Network failure → ERROR line with the URL, never an unhandled crash
async function get(url, redirect = "manual") {
  try {
    return await fetch(toLocal(url), {
      redirect,
      headers: { "user-agent": UA },
    });
  } catch (e) {
    err(`${url}: request failed (${e.cause?.code || e.message})`);
    return null;
  }
}

function attr(tag, name) {
  const m = tag.match(new RegExp(`${name}\\s*=\\s*["']([^"']*)["']`, "i"));
  return m ? m[1] : null;
}

function headLinks(html) {
  const links = [...html.matchAll(/<link\b[^>]*>/gi)].map((m) => m[0]);
  const canonical = links.find((l) => /rel=["']canonical["']/i.test(l));
  const alternates = {};
  for (const l of links) {
    if (!/rel=["']alternate["']/i.test(l)) continue;
    const lang = attr(l, "hreflang");
    const h = attr(l, "href");
    if (lang && h) alternates[lang] = decode(h);
  }
  const ch = canonical ? attr(canonical, "href") : null;
  return { canonical: ch ? decode(ch) : null, alternates };
}

function decode(s) {
  return s.replace(/&amp;/g, "&");
}

// Any absolute sitemap URL (maybe production domain) → same path on base
const onBase = (u) => {
  const url = new URL(u, base);
  return `${base}${url.pathname}${url.search}`;
};
const fetchText = async (u) => {
  const r = await fetch(onBase(u)).catch(() => null);
  return r && r.ok ? r.text() : null;
};

// Sitemap sources: argument, /sitemap.xml, else Sitemap: lines in robots.txt
let roots = sitemapArg ? [sitemapArg] : ["/sitemap.xml"];
if (!sitemapArg && !(await fetchText("/sitemap.xml"))) {
  const robots = (await fetchText("/robots.txt")) || "";
  roots = [...robots.matchAll(/^\s*sitemap:\s*(\S+)/gim)].map((m) => m[1]);
}
if (roots.length === 0) {
  console.log(
    `ERROR no sitemap at ${base}/sitemap.xml or in robots.txt (is the production server running?)`,
  );
  process.exit(1);
}

const entries = [];
const seen = new Set();
async function readSitemap(u) {
  if (seen.has(onBase(u))) return;
  seen.add(onBase(u));
  const xml = await fetchText(u);
  if (xml == null) return err(`sitemap ${u} not reachable`);
  if (/<sitemapindex\b/i.test(xml)) {
    for (const [, body] of xml.matchAll(/<sitemap>([\s\S]*?)<\/sitemap>/g)) {
      const loc = body.match(/<loc>([^<]+)<\/loc>/);
      if (loc) await readSitemap(decode(loc[1].trim()));
      else err(`sitemap index ${u}: <sitemap> without <loc>`);
    }
    return;
  }
  for (const [, body] of xml.matchAll(/<url>([\s\S]*?)<\/url>/g)) {
    const locMatch = body.match(/<loc>([^<]+)<\/loc>/);
    if (!locMatch) {
      err(`sitemap ${u}: <url> without <loc>`);
      continue;
    }
    const loc = decode(locMatch[1].trim());
    const alternates = {};
    for (const m of body.matchAll(/<xhtml:link\b[^>]*>/g)) {
      const lang = attr(m[0], "hreflang");
      const linkHref = attr(m[0], "href");
      if (!lang || !linkHref) {
        err(`${loc}: sitemap <xhtml:link> without hreflang or href`);
        continue;
      }
      alternates[lang] = decode(linkHref);
    }
    entries.push({ loc, alternates });
  }
}
for (const r of roots) await readSitemap(r);

if (entries.length === 0) {
  err("sitemap has no <url> entries");
  process.exit(1);
}
siteOrigin = new URL(entries[0].loc).origin;
ok(`sitemap: ${entries.length} URLs (site origin ${siteOrigin})`);

const inSitemap = new Set(entries.map((e) => canon(e.loc)));
const pages = new Map(); // loc -> { lang, canonical, alternates }

// Default locale = the hreflang whose URL x-default points to (taken from the sitemap)
let defaultLocale = null;
for (const { alternates: a } of entries) {
  if (!a["x-default"]) continue;
  const xd = canon(a["x-default"]);
  defaultLocale =
    Object.entries(a).find(
      ([k, v]) => k !== "x-default" && canon(v) === xd,
    )?.[0] ?? null;
  if (defaultLocale) break;
}
if (!defaultLocale)
  err("no x-default pointing to a language version anywhere in the sitemap");
else ok(`default locale (x-default): ${defaultLocale}`);
// x-default required only where a default-language version exists (references/i18n.md: pageAlternates)
const needsXDefault = (alts) => defaultLocale != null && defaultLocale in alts;

for (const { loc, alternates: smAlt } of entries) {
  const r = await get(loc);
  if (!r) continue;
  if (r.status !== 200) {
    err(
      `${loc} -> ${r.status}${r.headers.get("location") ? ` (to ${r.headers.get("location")})` : ""}: sitemap / hreflang URLs must answer 200 directly`,
    );
    continue;
  }
  const html = await r.text();
  const lang =
    (html.match(/<html\b[^>]*\blang=["']([^"']+)["']/i) || [])[1] || null;
  const { canonical, alternates } = headLinks(html);
  pages.set(canon(loc), { lang, canonical, alternates });

  if (!canonical) err(`${loc}: no canonical`);
  else if (canon(canonical) !== canon(loc))
    err(`${loc}: canonical points to ${canonical}`);

  if (Object.keys(smAlt).length === 0) err(`${loc}: no alternates in sitemap`);
  if (needsXDefault(smAlt) && !smAlt["x-default"])
    err(`${loc}: sitemap alternates without x-default`);
  if (needsXDefault(alternates) && !alternates["x-default"])
    err(`${loc}: page hreflang without x-default`);
  if (!needsXDefault(alternates) && alternates["x-default"])
    err(
      `${loc}: x-default set but no ${defaultLocale} version (x-default must point to the default language)`,
    );

  const self = Object.entries(alternates).find(
    ([k, v]) => k !== "x-default" && canon(v) === canon(loc),
  );
  if (!lang) err(`${loc}: <html> without lang`);
  if (!self) err(`${loc}: hreflang set does not include the page itself`);
  else if (
    lang &&
    self[0].toLowerCase().split("-")[0] !== lang.toLowerCase().split("-")[0]
  )
    err(`${loc}: <html lang="${lang}"> but hreflang says ${self[0]}`);

  const a = JSON.stringify(
    Object.fromEntries(
      Object.entries(alternates)
        .map(([k, v]) => [k, canon(v)])
        .sort(),
    ),
  );
  const b = JSON.stringify(
    Object.fromEntries(
      Object.entries(smAlt)
        .map(([k, v]) => [k, canon(v)])
        .sort(),
    ),
  );
  if (a !== b)
    err(
      `${loc}: page hreflang differs from sitemap alternates\n  page:    ${a}\n  sitemap: ${b}`,
    );

  for (const [k, v] of Object.entries(alternates)) {
    if (!inSitemap.has(canon(v)))
      err(`${loc}: hreflang ${k} -> ${v} not in sitemap`);
  }
}

// Reciprocal: A lists B => B lists A
for (const [loc, p] of pages) {
  for (const [k, v] of Object.entries(p.alternates)) {
    if (k === "x-default") continue;
    const target = pages.get(canon(v));
    if (!target) continue;
    const back = Object.values(target.alternates).some((u) => canon(u) === loc);
    if (!back)
      err(
        `${loc} -> ${k} ${v} does not link back (hreflang must be reciprocal)`,
      );
  }
}

// Default locale must not exist with its prefix
if (defaultLocale) {
  const sample = [...pages.keys()].find((u) => {
    const p = pages.get(u);
    return Object.entries(p.alternates).some(
      ([k, v]) => k === defaultLocale && canon(v) === u,
    );
  });
  if (sample) {
    const path = new URL(sample).pathname;
    const prefixed = `${siteOrigin}/${defaultLocale}${path === "/" ? "" : path}`;
    const r = await get(prefixed);
    const loc = r?.headers.get("location");
    if (!r) {
      // request failed, already reported
    } else if (
      r.status === 308 &&
      loc &&
      norm(new URL(loc, siteOrigin).pathname) === norm(path)
    )
      ok(`/${defaultLocale}${path === "/" ? "" : path} -> 308 ${path}`);
    else
      err(
        `/${defaultLocale}${path === "/" ? "" : path} answers ${r.status}${loc ? ` -> ${loc}` : ""} (expected 308 to ${path}: duplicate URL)`,
      );
  }
}

if (errors === 0)
  ok(
    `${pages.size} pages: 200, self canonical, <html lang>, hreflang = sitemap, x-default, reciprocal`,
  );
console.log(`\n== Result: ${errors} error(s)`);
process.exit(errors ? 1 : 0);

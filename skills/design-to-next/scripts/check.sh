#!/usr/bin/env bash
# Automated part of the design-to-next final checklist.
# Run from the Next.js project root:
#   bash <skill-dir>/scripts/check.sh           static checks + typecheck, lint, format:check
#   bash <skill-dir>/scripts/check.sh --build   also runs the production build
#   bash <skill-dir>/scripts/check.sh --fast    static checks only
#
# ERROR = rule from the skill is broken. WARN = probably broken, look at it.
# Exit code is 1 if there is at least one ERROR or a failing command.

set -uo pipefail

MODE="default"
case "${1:-}" in
  --build) MODE="build" ;;
  --fast) MODE="fast" ;;
  "") ;;
  *) echo "Unknown option: $1"; exit 2 ;;
esac

if [[ ! -f package.json ]]; then
  echo "Run this from the project root (no package.json here)."
  exit 2
fi

errors=0
warnings=0

if [[ -t 1 ]]; then
  RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'; DIM=$'\e[2m'; RST=$'\e[0m'
else
  RED=""; YEL=""; GRN=""; DIM=""; RST=""
fi

err()  { echo "${RED}ERROR${RST} $1"; [[ -n "${2:-}" ]] && echo "$2" | sed "s/^/  ${DIM}/;s/\$/${RST}/"; errors=$((errors + 1)); }
warn() { echo "${YEL}WARN ${RST} $1"; [[ -n "${2:-}" ]] && echo "$2" | sed "s/^/  ${DIM}/;s/\$/${RST}/"; warnings=$((warnings + 1)); }
ok()   { echo "${GRN}ok   ${RST} $1"; }

# Source dirs that exist
DIRS=()
for d in app components features cms lib constants types; do [[ -d "$d" ]] && DIRS+=("$d"); done
if (( ${#DIRS[@]} == 0 )); then
  echo "${RED}ERROR${RST} no source folders yet (app/, components/, lib/...). Nothing to check."
  exit 1
fi

# grep over TS/TSX source. Usage: src_grep <regex> [dirs...]
src_grep() {
  local re="$1"; shift
  local targets=("$@")
  [[ ${#targets[@]} -eq 0 ]] && targets=("${DIRS[@]}")
  [[ ${#targets[@]} -eq 0 ]] && return 0
  grep -rnE --include='*.ts' --include='*.tsx' --exclude-dir='(payload)' "$re" "${targets[@]}" 2>/dev/null
}

# Portable `xargs -r`: run "$@" with stdin lines as args, skip if none (BSD/macOS xargs has no -r; bash 3.2 has no mapfile)
xargs_r() {
  local args=() line
  while IFS= read -r line; do [[ -n "$line" ]] && args+=("$line"); done
  (( ${#args[@]} )) || return 0
  "$@" "${args[@]}"
}

# Payload CMS: app/(payload)/ is copied from Payload's template and never edited -> skipped by checks
HAS_PAYLOAD=""; [[ -f payload.config.ts ]] && HAS_PAYLOAD=1

# Check helper: run grep, report if anything matched
check() {
  local level="$1" msg="$2" out="$3" okmsg="$4"
  if [[ -n "$out" ]]; then
    if [[ "$level" == "err" ]]; then err "$msg" "$out"; else warn "$msg" "$out"; fi
  else
    ok "$okmsg"
  fi
}

echo "== Structure"

[[ -d src ]] && err "src/ folder exists (skill: no src/)" || ok "no src/"

# Root layout(s) (SKILL.md section 4): app/layout.tsx with <html>; else every app/[lang]/, app/(group)/,
# app/(group)/[lang]/ layout that renders <html> (i18n, Payload, several root layouts)
ROOT_LAYOUTS=()
if [[ -f app/layout.tsx ]] && grep -q "<html" app/layout.tsx; then
  ROOT_LAYOUTS=(app/layout.tsx)
else
  for c in app/\[*\]/layout.tsx app/\(*\)/layout.tsx app/\(*\)/\[*\]/layout.tsx; do
    [[ -f "$c" && "$c" != app/\(payload\)/* ]] || continue
    grep -q "<html" "$c" && ROOT_LAYOUTS+=("$c")
  done
fi

if (( ${#ROOT_LAYOUTS[@]} == 0 )); then
  err "no root layout with <html> (app/layout.tsx, app/[lang]/, or app/(frontend)/ with CMS)"
fi
for rl in ${ROOT_LAYOUTS[@]+"${ROOT_LAYOUTS[@]}"}; do
  rd="${rl%/layout.tsx}"
  ok "root layout: $rl"
  for name in loading.tsx error.tsx not-found.tsx; do
    if [[ -e "$rd/$name" ]]; then ok "$rd/$name"
    elif [[ "$name" == not-found.tsx && -e app/not-found.tsx && -f app/layout.tsx ]]; then ok "app/not-found.tsx"
    elif [[ "$name" == not-found.tsx && -e app/global-not-found.tsx ]]; then ok "app/global-not-found.tsx"   # several root layouts
    else err "missing $rd/$name (next to root layout)"; fi
  done
done
# Next.js serves these only from the top of app/
for f in app/global-error.tsx app/favicon.ico; do
  [[ -e "$f" ]] && ok "$f" || err "missing $f"
done

bad_names=""
bad_names=$(find "${DIRS[@]}" -path 'app/(payload)' -prune -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.css' \) -print 2>/dev/null \
  | awk -F/ '{print $0" "$NF}' \
  | awk '$2 !~ /^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+)+$/ {print $1}')
check err "file names not kebab-case" "$bad_names" "file names kebab-case"

if [[ -d app ]]; then
  non_route=$(find app -path 'app/(payload)' -prune -o -type f \( -name '*.ts' -o -name '*.tsx' \) -print 2>/dev/null \
    | grep -vE '/(page|layout|template|loading|error|global-error|not-found|forbidden|unauthorized|default|route|sitemap|robots|manifest|icon|apple-icon|opengraph-image|twitter-image)\.(ts|tsx)$' \
    | grep -vE '\.d\.ts$')
  check err "non-routing files inside app/ (move to components/ or lib/)" "$non_route" "app/ has only routing files"
fi

echo
echo "== Tokens and styling"

# UI code: components/, app/, features/ (shop / app domain components)
COMP=(); for d in components app features; do [[ -d "$d" ]] && COMP+=("$d"); done
# grep only UI folders; none yet -> no output (never falls back to lib/, constants/...)
comp_grep() { (( ${#COMP[@]} )) || return 0; src_grep "$1" "${COMP[@]}"; }

out=$(comp_grep '(bg|text|border|fill|stroke|ring|outline|decoration|from|via|to|shadow|accent|caret|divide|placeholder)-\[(#|rgb|hsl|oklch|color)')
check err "arbitrary color values in components (add a token)" "$out" "no arbitrary colors"

out=$(comp_grep '#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b["'"'"' ;)]')
check warn "hex values in TS/TSX (colors belong in globals.css)" "$out" "no hex in components"

out=$(comp_grep '(text|leading|tracking|font|rounded(-[trblse]{1,2})?|shadow|p[xytrblse]?|m[xytrblse]?|gap(-[xy])?|space-[xy])-\[[0-9.]+(px|rem|em)\]')
check err "arbitrary typography / radius / spacing values (add a token)" "$out" "no arbitrary design values"

# any utility after the prefix (also range variants max-md:, min-lg:): md:flex, md:-mt-4, lg:!hidden, md:[&>*]:..., md:@container; also dark:md:flex
out=$(comp_grep '(^|[ :"'"'"'`])(max-|min-)?(sm|md|lg|xl|2xl):[][!@a-z-]')
check err "default Tailwind breakpoints used (only tablet: / desktop:)" "$out" "only tablet: / desktop: breakpoints"

out=$(src_grep "from ['\"]motion|from ['\"]framer-motion" )
[[ -n "$out" ]] && warn "motion is used: make sure CSS could not do it" "$out" || ok "no motion"

out=$(grep -rnE --exclude-dir='(payload)' --include='*.ts' --include='*.tsx' --include='*.css' 'fonts\.(googleapis|gstatic)\.com' "${DIRS[@]}" 2>/dev/null)
check err "Google Fonts loaded from Google (use next/font/google)" "$out" "no direct Google Fonts requests"

echo
echo "== Server and client"

out=$(grep -rlE --exclude-dir='(payload)' --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" app components/sections components/layout 2>/dev/null \
  | grep -vE '(^|/)(error|global-error)\.tsx$')
check warn "\"use client\" on a page, layout or section (keep it on leaf components)" "$out" "\"use client\" only on leaves"

# Server Actions live in actions.ts files ("use server" at top), never inline in components
out=$(grep -rnE --exclude-dir='(payload)' --include='*.tsx' "['\"]use server['\"]" "${DIRS[@]}" 2>/dev/null)
check warn "\"use server\" in a .tsx file (inline action: move it to an actions.ts file)" "$out" "no inline Server Actions in .tsx"

out=$(src_grep 'dangerouslySetInnerHTML' | grep -v '^components/seo/json-ld\.tsx:')
check warn "dangerouslySetInnerHTML outside components/seo/json-ld.tsx (XSS risk)" "$out" "dangerouslySetInnerHTML only in json-ld.tsx"

# Query files: lib/queries/** (landing) and features/*/queries.ts | features/*/queries/** (shop / app)
query_files() {
  [[ -d lib/queries ]] && find lib/queries -type f \( -name '*.ts' -o -name '*.tsx' \)
  [[ -d features ]] && find features -type f | grep -E '^features/[^/]+/queries(\.ts|/.+\.tsx?)$'
}

server_files=()
while IFS= read -r f; do [[ -n "$f" ]] && server_files+=("$f"); done < <(query_files)
for f in lib/db/index.ts lib/env.ts lib/stripe.ts lib/action-helpers.ts features/auth/session.ts; do [[ -f "$f" ]] && server_files+=("$f"); done
missing=""
for f in ${server_files[@]+"${server_files[@]}"}; do
  grep -qE "^import ['\"]server-only['\"]" "$f" || missing+="$f"$'\n'
done
check err "missing import \"server-only\"" "${missing%$'\n'}" "server-only where needed"

# Files loaded by CLI tools in plain Node must NOT import server-only (it throws there)
cli_bad=""
cli_files=(lib/db/schema.ts lib/auth.ts drizzle.config.ts)
[[ -d lib/db/schema ]] && while IFS= read -r f; do cli_files+=("$f"); done < <(find lib/db/schema -type f -name '*.ts')
for f in "${cli_files[@]}"; do
  [[ -f "$f" ]] && grep -qE "^import ['\"]server-only['\"]" "$f" && cli_bad+="$f"$'\n'
done
[[ -f drizzle.config.ts ]] && grep -qE "from ['\"]@/lib/env['\"]|from ['\"]\./lib/env['\"]" drizzle.config.ts && cli_bad+="drizzle.config.ts (imports lib/env.ts)"$'\n'
check err "server-only in a file loaded by drizzle-kit / Better Auth CLI (breaks the CLI)" "${cli_bad%$'\n'}" "CLI-loaded files without server-only"

if [[ -d lib/queries || -d features ]]; then
  nocache=""
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    grep -q "use cache" "$f" || continue
    grep -q "cacheLife" "$f" && grep -q "cacheTag" "$f" || nocache+="$f"$'\n'
  done < <(query_files)
  check err "\"use cache\" without cacheLife / cacheTag" "${nocache%$'\n'}" "cached reads have cacheLife + cacheTag"
fi

if [[ ( -d features || -d lib/queries ) ]] && ! command -v perl >/dev/null; then
  err "perl not found: can't check client components for server query imports (install perl)"
elif [[ -d features || -d lib/queries ]]; then
  # Client components may only `import type { ... }` from queries / session / action helpers.
  # One import statement at a time: default/namespace part on one line, optional { ... } may span lines.
  out=$(grep -rlE --exclude-dir='(payload)' --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" "${DIRS[@]}" 2>/dev/null \
    | xargs_r perl -0777 -ne 'my $p = q{(?:@/features/[^"\x27]+/queries|@/lib/queries|\.\.?/(?:[^"\x27]*/)?queries|@/features/auth/session|@/lib/action-helpers)}; while (m#^(?:import[ \t]+(?!type\b)(?:[\w\$]+[ \t]*,?\s*)?(?:\*[ \t]+as[ \t]+\w+[ \t]*)?(?:\{[^}]*\})?|export[ \t]+(?!type\b)(?:\*(?:[ \t]+as[ \t]+\w+)?|\{[^}]*\}))[ \t]*from[ \t]+["\x27]($p(?:/[^"\x27]*)?)["\x27]#mg) { print "$ARGV: import from $1\n" }')   # no 2>/dev/null: a perl error must show
  check err "client component imports server query / session code (only \"import type { ... }\" allowed; inline { type X } stays in the bundle with verbatimModuleSyntax)" "$out" "no server queries in client components"
fi

if [[ -d features ]]; then
  out=$(find features -type f 2>/dev/null | grep -E '^features/[^/]+/(queries|actions)(\.ts|/.+\.tsx?)$' \
    | xargs_r grep -lE "^['\"]use client['\"]" 2>/dev/null)
  check err "\"use client\" in a feature queries / actions file" "$out" "feature queries / actions are server code"

  mixed=""
  for d in lib/queries lib/actions lib/validations; do [[ -d "$d" ]] && mixed+="$d"$'\n'; done
  check warn "mixed structure: features/ next to lib/queries|actions|validations (shop / app: domain code in features/<domain>/)" "${mixed%$'\n'}" "no mixed lib/queries|actions|validations next to features/"
fi

# updateTag only works in Server Actions
out=$(find app -path 'app/(payload)' -prune -o -type f -name 'route.*' -print 2>/dev/null | xargs_r grep -nHE "\bupdateTag\(" 2>/dev/null)
check err "updateTag in a route handler (use revalidateTag(tag, \"max\"))" "$out" "no updateTag in route handlers"

# Central tag registry: no string literal tags once lib/cache-tags.ts exists
if [[ -f lib/cache-tags.ts ]]; then
  out=$(src_grep "\b(cacheTag|updateTag|revalidateTag)\([[:space:]]*['\"\`]" | grep -v '^lib/cache-tags.ts:')
  check warn "string literal cache tag (use cacheTags from lib/cache-tags.ts)" "$out" "cache tags from lib/cache-tags.ts"
fi

out=$(grep -rlE --exclude-dir='(payload)' --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" "${DIRS[@]}" 2>/dev/null \
  | xargs_r grep -lE "from ['\"](@/lib/db|drizzle-orm)" 2>/dev/null)
check err "DB imported in a client component" "$out" "no DB in client components"

out=$(grep -rlE --exclude-dir='(payload)' --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" "${DIRS[@]}" 2>/dev/null \
  | xargs_r grep -lE "from ['\"](@/lib/auth['\"]|@/lib/stripe|stripe['\"])" 2>/dev/null)
check err "server auth / Stripe imported in a client component (use lib/auth-client.ts)" "$out" "no server auth / Stripe in client components"

while IFS= read -r f; do
  grep -q "constructEvent" "$f" && ok "Stripe webhook verifies the signature ($f)" \
    || err "Stripe webhook does not verify the signature with constructEvent" "$f"
  grep -qE "request\.json\(\)|req\.json\(\)" "$f" && err "Stripe webhook reads JSON body (needs raw text for the signature)" "$f"
done < <(find app -path '*webhooks*stripe*' -name 'route.ts' 2>/dev/null)

if [[ -n "$HAS_PAYLOAD" ]]; then
  echo
  echo "== Payload CMS"

  # payload.config.ts and cms/** are loaded by the Payload CLI in plain Node
  bad=""
  grep -qE "^import ['\"]server-only['\"]" payload.config.ts && bad+="payload.config.ts"$'\n'
  [[ -d cms ]] && bad+=$(grep -rlE "^import ['\"]server-only['\"]" cms 2>/dev/null)
  [[ -d cms ]] && bad+=$'\n'$(grep -rlE "from ['\"](@/lib/env|(\.\./)+lib/env)(-public)?['\"]" cms 2>/dev/null | sed 's/$/ (imports lib\/env*, which is server-only)/')
  grep -qE "from ['\"](@/lib/env|\./lib/env)['\"]" payload.config.ts && bad+=$'\n'"payload.config.ts (imports lib/env.ts)"
  bad=$(echo "$bad" | sed '/^$/d')
  check err "server-only in a file loaded by the Payload CLI (payload.config.ts, cms/)" "$bad" "Payload CLI files without server-only"

  out=$([[ -d cms ]] && grep -rnE "\bupdateTag\(" cms 2>/dev/null)
  check err "updateTag in a Payload hook (hooks are not Server Actions: revalidateTag(tag, \"max\"))" "$out" "Payload hooks use revalidateTag"

  [[ -d "app/(payload)" ]] && ok "app/(payload)/ present" || err "payload.config.ts but no app/(payload)/ (copy it from Payload's blank template)"
  [[ -f app/layout.tsx ]] && err "app/layout.tsx next to Payload (move own root layout into app/(frontend)/)" || ok "own root layout in a route group"

  # Our Drizzle tables kept apart from Payload's (references/database.md section 5)
  if [[ -f drizzle.config.ts ]] && ! grep -q "db-mongodb" payload.config.ts; then   # Mongo: our tables in a separate SQL DB
    if grep -qE "dialect:[[:space:]]*['\"]postgresql" drizzle.config.ts; then
      grep -q "schemaFilter" drizzle.config.ts && ok "drizzle.config.ts has schemaFilter" \
        || warn "Postgres + Payload: drizzle.config.ts without schemaFilter (own tables in pgSchema(\"app\"), schemaFilter: [\"app\"])"
    elif grep -qE "dialect:[[:space:]]*['\"](sqlite|turso)" drizzle.config.ts; then
      grep -q "tablesFilter" drizzle.config.ts && ok "drizzle.config.ts has tablesFilter" \
        || warn "SQLite + Payload: drizzle.config.ts without tablesFilter (own tables prefixed app_, tablesFilter: [\"app_*\"])"
    fi
  fi
fi

echo
echo "== Constants, images, env"

out=$(comp_grep '<img[ >]')
check err "<img> used (use next/image)" "$out" "no <img>"

# Multi-line: Prettier puts each prop on its own line. (?:=>|[^>]) lets arrow functions in props through.
if (( ${#COMP[@]} )) && command -v perl >/dev/null; then
  out=$(find "${COMP[@]}" -path 'app/(payload)' -prune -o -type f -name '*.tsx' -print 2>/dev/null \
    | xargs_r perl -0777 -ne 'while (m#<Image\b(?:=>|[^>])*?\spriority\b#sg) { my $l = 1 + (substr($_, 0, $+[0]) =~ tr/\n//); print "$ARGV:$l\n" }')
else
  out=""
fi
check err "<Image priority> (deprecated since Next.js 16: preload, or loading=\"eager\" + fetchPriority=\"high\")" "$out" "no deprecated Image priority"

out=$(comp_grep '["'"'"'`][^"'"'"'`]*\.(png|jpe?g|webp|avif|gif|svg)["'"'"'`]' | grep -v 'opengraph-image\|apple-icon\|icon\.')
check err "image path in a component or page (put it in constants/images.ts or constants/site.ts, also for JSON-LD logos)" "$out" "no image paths in components"

if [[ -d assets/images ]]; then
  out=$(find assets/images -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \))
  check err "images not converted to WebP (run scripts/to-webp.mjs)" "$out" "images in assets/ are WebP"
fi

out=$(src_grep 'from ["'"'"']@/public/' )
check err "image imported from public/ (use assets/images/)" "$out" "no imports from public/"

out=$(comp_grep '(href|src)=["'"'"'](https?:|mailto:|tel:)')
check warn "hardcoded external link in a component (put it in constants/)" "$out" "no hardcoded external links"

out=$(src_grep 'process\.env' | grep -vE '^(lib/env(-public)?\.ts|cms/[^:]+):')   # cms/** is Payload CLI-loaded (no server-only)
check err "process.env outside lib/env.ts / lib/env-public.ts (and cms/)" "$out" "env read only through lib/env*"

if [[ -f lib/env.ts || -f lib/env-public.ts ]]; then
  [[ -f .env.example ]] && ok ".env.example exists" || err "env is used but .env.example is missing"
fi
# Database (references/database.md)
if [[ -d lib/db || -f drizzle.config.ts || -f payload.config.ts ]]; then
  if [[ -f .env.example ]]; then
    grep -qE '^(DATABASE_URL|DATABASE_URI)=' .env.example && ok "DATABASE_URL in .env.example" \
      || err "database used but DATABASE_URL missing in .env.example"
  elif [[ ! -f lib/env.ts && ! -f lib/env-public.ts ]]; then   # else reported once by the env block
    err "database used but .env.example is missing (DATABASE_URL=)"
  fi
  compose=$(ls compose.yaml compose.yml docker-compose.yml docker-compose.yaml 2>/dev/null | head -1)
  if [[ -n "$compose" ]]; then
    grep -q "healthcheck" "$compose" && ok "$compose has a healthcheck" || warn "$compose without healthcheck (wait for DB before migrating)"
    grep -qE '^volumes:' "$compose" && ok "$compose keeps data in a volume" || warn "$compose without named volume (data lost on recreate)"
  fi
  if [[ -f drizzle.config.ts ]] && grep -qE "dialect:[[:space:]]*['\"](sqlite|turso)" drizzle.config.ts && [[ -f .gitignore ]]; then
    grep -qE '(^|/)(data(/.*)?|[^ ]*\.db|[^ ]*\.sqlite3?)$' .gitignore && ok "SQLite files gitignored" || warn "SQLite DB file not in .gitignore (add data/ or *.db)"
  fi
fi

if [[ -f .gitignore ]] && ! grep -qE '^\.env(\*|\.\*|\*\.local|.*local)' .gitignore; then
  err ".gitignore does not cover .env*.local"
fi
if [[ -f .env.example ]] && grep -qE '^NEXT_PUBLIC_[A-Z_]*(SECRET|TOKEN|PASSWORD|PRIVATE)' .env.example; then
  err "secret-looking NEXT_PUBLIC_ var in .env.example" "$(grep -nE '^NEXT_PUBLIC_[A-Z_]*(SECRET|TOKEN|PASSWORD|PRIVATE)' .env.example)"
fi

NEXT_CONFIG=$(ls next.config.ts next.config.mts next.config.mjs next.config.js next.config.cjs 2>/dev/null | head -1)
[[ -z "$NEXT_CONFIG" ]] && warn "no next.config.* found (image host / security header checks skipped)"
if [[ -n "$NEXT_CONFIG" ]]; then
  # any * in a host: "**", "*.cdn.com", "**.amazonaws.com", also new URL("https://**.x.com/...")
  out=$(grep -nE "hostname:[[:space:]]*['\"][^'\"]*\*|new URL\([[:space:]]*['\"\`][a-z]+://[^/'\"\`]*\*" "$NEXT_CONFIG")
  check err "wildcard image host in $NEXT_CONFIG remotePatterns (list exact hostnames)" "$out" "remotePatterns without wildcard host"
  if grep -qE "dangerouslyAllowSVG:[[:space:]]*true" "$NEXT_CONFIG"; then
    grep -q "contentSecurityPolicy" "$NEXT_CONFIG" && ok "dangerouslyAllowSVG with contentSecurityPolicy" \
      || err "dangerouslyAllowSVG: true without images.contentSecurityPolicy in $NEXT_CONFIG"
  fi
  # header values may live in an imported constant (lib/, constants/)
  hdr_src=("$NEXT_CONFIG"); for d in lib constants; do [[ -d "$d" ]] && hdr_src+=("$d"); done
  missing_h=""
  grep -qE "headers[[:space:]]*(\(|:)" "$NEXT_CONFIG" || missing_h+="headers() in $NEXT_CONFIG"$'\n'
  for h in "X-Content-Type-Options" "Referrer-Policy" "X-Frame-Options|frame-ancestors" "Permissions-Policy" "Strict-Transport-Security"; do
    grep -rqE --include='*.ts' --include='*.mts' --include='*.mjs' --include='*.js' --include='*.cjs' "$h" "${hdr_src[@]}" 2>/dev/null || missing_h+="$h"$'\n'
  done
  check warn "security headers missing (SKILL.md section 3)" "${missing_h%$'\n'}" "security headers set"
fi

echo
echo "== SEO basics"

if [[ -d app ]]; then
  nometa=""
  while IFS= read -r f; do
    grep -qE 'export (const (metadata|generateMetadata)\b|(async )?function generateMetadata)' "$f" || nometa+="$f"$'\n'
  done < <(find app -path 'app/(payload)' -prune -o -type f -name 'page.tsx' -print)
  check err "page without metadata / generateMetadata" "${nometa%$'\n'}" "every page exports metadata"

  multi_h1=""
  while IFS= read -r f; do
    n=$(grep -oE '<h1[ >]' "$f" | wc -l)
    (( n > 1 )) && multi_h1+="$f ($n)"$'\n'
  done < <(find app components -path 'app/(payload)' -prune -o -type f -name '*.tsx' -print 2>/dev/null)
  check warn "more than one <h1> in a file" "${multi_h1%$'\n'}" "no file with several <h1>"

  for rl in ${ROOT_LAYOUTS[@]+"${ROOT_LAYOUTS[@]}"}; do
    grep -qE '<html[^>]*lang=' "$rl" && ok "lang on <html> ($rl)" || err "no lang on <html> in $rl"
  done
fi

if [[ "$MODE" != "fast" ]]; then
  echo
  echo "== Commands"

  if   [[ -f pnpm-lock.yaml ]]; then PM=pnpm
  elif [[ -f bun.lock || -f bun.lockb ]]; then PM=bun
  elif [[ -f yarn.lock ]]; then PM=yarn
  else PM=npm; fi

  has_script() { grep -qE "\"$1\"[[:space:]]*:" package.json; }

  run() {
    local name="$1"; shift
    echo "${DIM}\$ $*${RST}"
    local log; log=$(mktemp)
    if "$@" >"$log" 2>&1; then ok "$name"; else err "$name failed" "$(tail -30 "$log")"; fi
    rm -f "$log"
  }

  if has_script typecheck; then run typecheck $PM run typecheck; else err "no \"typecheck\" script in package.json"; fi
  if has_script lint; then run lint $PM run lint; else err "no \"lint\" script in package.json"; fi
  has_script format || err "no \"format\" script in package.json"
  if has_script "format:check"; then run "format:check" $PM run format:check; else err "no \"format:check\" script in package.json (prettier --check .)"; fi
  if [[ "$MODE" == "build" ]]; then run build $PM run build; fi
fi

echo
echo "== Result: $errors error(s), $warnings warning(s)"
echo "${DIM}Not checked here (do it by hand): design match in the browser, console errors, Suspense fallbacks, token flow in globals.css, SEO text quality, reference checklists.${RST}"
(( errors > 0 )) && exit 1 || exit 0

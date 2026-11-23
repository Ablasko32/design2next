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
for d in app components lib constants types; do [[ -d "$d" ]] && DIRS+=("$d"); done

# grep over TS/TSX source. Usage: src_grep <regex> [dirs...]
src_grep() {
  local re="$1"; shift
  local targets=("$@")
  [[ ${#targets[@]} -eq 0 ]] && targets=("${DIRS[@]}")
  [[ ${#targets[@]} -eq 0 ]] && return 0
  grep -rnE --include='*.ts' --include='*.tsx' "$re" "${targets[@]}" 2>/dev/null
}

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

for f in app/loading.tsx app/error.tsx app/global-error.tsx app/not-found.tsx app/favicon.ico; do
  # With i18n the root layout lives in app/[lang]/
  alt="${f/app\//app/[lang]/}"
  if [[ -e "$f" || ( "$f" != app/global-error.tsx && "$f" != app/favicon.ico && -e "$alt" ) ]]; then
    ok "$f"
  else
    err "missing $f"
  fi
done

bad_names=$(find "${DIRS[@]}" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.css' \) 2>/dev/null \
  | awk -F/ '{print $0" "$NF}' \
  | awk '$2 !~ /^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+)+$/ {print $1}')
check err "file names not kebab-case" "$bad_names" "file names kebab-case"

if [[ -d app ]]; then
  non_route=$(find app -type f \( -name '*.ts' -o -name '*.tsx' \) 2>/dev/null \
    | grep -vE '/(page|layout|template|loading|error|global-error|not-found|forbidden|unauthorized|default|route|sitemap|robots|manifest|icon|apple-icon|opengraph-image|twitter-image)\.(ts|tsx)$' \
    | grep -vE '\.d\.ts$')
  check err "non-routing files inside app/ (move to components/ or lib/)" "$non_route" "app/ has only routing files"
fi

echo
echo "== Tokens and styling"

COMP=(); [[ -d components ]] && COMP+=(components); [[ -d app ]] && COMP+=(app)

out=$(src_grep '(bg|text|border|fill|stroke|ring|outline|decoration|from|via|to|shadow|accent|caret|divide|placeholder)-\[(#|rgb|hsl|oklch|color)' "${COMP[@]}")
check err "arbitrary color values in components (add a token)" "$out" "no arbitrary colors"

out=$(src_grep '#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b["'"'"' ;)]' "${COMP[@]}")
check warn "hex values in TS/TSX (colors belong in globals.css)" "$out" "no hex in components"

out=$(src_grep '(text|leading|tracking|font|rounded(-[trblse]{1,2})?|shadow|p[xytrblse]?|m[xytrblse]?|gap(-[xy])?|space-[xy])-\[[0-9.]+(px|rem|em)\]' "${COMP[@]}")
check err "arbitrary typography / radius / spacing values (add a token)" "$out" "no arbitrary design values"

out=$(src_grep '(^|[ "'"'"'`])(sm|md|lg|xl|2xl):[a-z]' "${COMP[@]}")
check err "default Tailwind breakpoints used (only tablet: / desktop:)" "$out" "only tablet: / desktop: breakpoints"

out=$(src_grep "from ['\"]motion|from ['\"]framer-motion" )
[[ -n "$out" ]] && warn "motion is used: make sure CSS could not do it" "$out" || ok "no motion"

out=$(grep -rnE --include='*.ts' --include='*.tsx' --include='*.css' 'fonts\.(googleapis|gstatic)\.com' "${DIRS[@]}" 2>/dev/null)
check err "Google Fonts loaded from Google (use next/font/google)" "$out" "no direct Google Fonts requests"

echo
echo "== Server and client"

out=$(grep -rlE --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" app components/sections components/layout 2>/dev/null \
  | grep -vE '(^|/)(error|global-error)\.tsx$')
check warn "\"use client\" on a page, layout or section (keep it on leaf components)" "$out" "\"use client\" only on leaves"

server_files=()
[[ -d lib/queries ]] && while IFS= read -r f; do server_files+=("$f"); done < <(find lib/queries -type f \( -name '*.ts' -o -name '*.tsx' \))
for f in lib/db/index.ts lib/env.ts lib/stripe.ts; do [[ -f "$f" ]] && server_files+=("$f"); done
missing=""
for f in "${server_files[@]}"; do
  grep -qE "^import ['\"]server-only['\"]" "$f" || missing+="$f"$'\n'
done
check err "missing import \"server-only\"" "${missing%$'\n'}" "server-only where needed"

# Files loaded by CLI tools in plain Node must NOT import server-only (it throws there)
cli_bad=""
for f in lib/db/schema.ts lib/auth.ts drizzle.config.ts; do
  [[ -f "$f" ]] && grep -qE "^import ['\"]server-only['\"]" "$f" && cli_bad+="$f"$'\n'
done
[[ -f drizzle.config.ts ]] && grep -qE "from ['\"]@/lib/env['\"]|from ['\"]\./lib/env['\"]" drizzle.config.ts && cli_bad+="drizzle.config.ts (imports lib/env.ts)"$'\n'
check err "server-only in a file loaded by drizzle-kit / Better Auth CLI (breaks the CLI)" "${cli_bad%$'\n'}" "CLI-loaded files without server-only"

if [[ -d lib/queries ]]; then
  nocache=""
  while IFS= read -r f; do
    grep -q "use cache" "$f" || continue
    grep -q "cacheLife" "$f" && grep -q "cacheTag" "$f" || nocache+="$f"$'\n'
  done < <(find lib/queries -type f -name '*.ts')
  check err "\"use cache\" without cacheLife / cacheTag" "${nocache%$'\n'}" "cached reads have cacheLife + cacheTag"
fi

out=$(grep -rlE --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" "${DIRS[@]}" 2>/dev/null \
  | xargs -r grep -lE "from ['\"](@/lib/db|drizzle-orm)" 2>/dev/null)
check err "DB imported in a client component" "$out" "no DB in client components"

out=$(grep -rlE --include='*.tsx' --include='*.ts' "^['\"]use client['\"]" "${DIRS[@]}" 2>/dev/null \
  | xargs -r grep -lE "from ['\"](@/lib/auth['\"]|@/lib/stripe|stripe['\"])" 2>/dev/null)
check err "server auth / Stripe imported in a client component (use lib/auth-client.ts)" "$out" "no server auth / Stripe in client components"

while IFS= read -r f; do
  grep -q "constructEvent" "$f" && ok "Stripe webhook verifies the signature ($f)" \
    || err "Stripe webhook does not verify the signature with constructEvent" "$f"
  grep -qE "request\.json\(\)|req\.json\(\)" "$f" && err "Stripe webhook reads JSON body (needs raw text for the signature)" "$f"
done < <(find app -path '*webhooks*stripe*' -name 'route.ts' 2>/dev/null)

echo
echo "== Constants, images, env"

out=$(src_grep '<img[ >]' "${COMP[@]}")
check err "<img> used (use next/image)" "$out" "no <img>"

out=$(src_grep '["'"'"'`][^"'"'"'`]*\.(png|jpe?g|webp|avif|gif|svg)["'"'"'`]' components app | grep -v 'opengraph-image\|apple-icon\|icon\.')
check err "image path in a component or page (put it in constants/images.ts or constants/site.ts, also for JSON-LD logos)" "$out" "no image paths in components"

if [[ -d assets/images ]]; then
  out=$(find assets/images -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \))
  check err "images not converted to WebP (run scripts/to-webp.mjs)" "$out" "images in assets/ are WebP"
fi

out=$(src_grep 'from ["'"'"']@/public/' )
check err "image imported from public/ (use assets/images/)" "$out" "no imports from public/"

out=$(src_grep '(href|src)=["'"'"'](https?:|mailto:|tel:)' components app)
check warn "hardcoded external link in a component (put it in constants/)" "$out" "no hardcoded external links"

out=$(src_grep 'process\.env' | grep -vE '^lib/env(-public)?\.ts:')
check err "process.env outside lib/env.ts / lib/env-public.ts" "$out" "env read only through lib/env*"

if [[ -f lib/env.ts || -f lib/env-public.ts ]]; then
  [[ -f .env.example ]] && ok ".env.example exists" || err "env is used but .env.example is missing"
fi
if [[ -f .gitignore ]] && ! grep -qE '^\.env(\*|\.\*|\*\.local|.*local)' .gitignore; then
  err ".gitignore does not cover .env*.local"
fi
if [[ -f .env.example ]] && grep -qE '^NEXT_PUBLIC_[A-Z_]*(SECRET|TOKEN|PASSWORD|PRIVATE)' .env.example; then
  err "secret-looking NEXT_PUBLIC_ var in .env.example" "$(grep -nE '^NEXT_PUBLIC_[A-Z_]*(SECRET|TOKEN|PASSWORD|PRIVATE)' .env.example)"
fi

echo
echo "== SEO basics"

if [[ -d app ]]; then
  nometa=""
  while IFS= read -r f; do
    grep -qE 'export (const (metadata|generateMetadata)\b|(async )?function generateMetadata)' "$f" || nometa+="$f"$'\n'
  done < <(find app -type f -name 'page.tsx')
  check err "page without metadata / generateMetadata" "${nometa%$'\n'}" "every page exports metadata"

  multi_h1=""
  while IFS= read -r f; do
    n=$(grep -oE '<h1[ >]' "$f" | wc -l)
    (( n > 1 )) && multi_h1+="$f ($n)"$'\n'
  done < <(find app components -type f -name '*.tsx' 2>/dev/null)
  check warn "more than one <h1> in a file" "${multi_h1%$'\n'}" "no file with several <h1>"

  layout=$(ls app/layout.tsx app/\[*\]/layout.tsx 2>/dev/null | head -1)
  if [[ -n "$layout" ]]; then
    grep -qE '<html[^>]*lang=' "$layout" && ok "lang on <html>" || err "no lang on <html> in $layout"
  fi
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

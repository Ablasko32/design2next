# Dark mode

Read only when design has a dark version or user asks. Never by default.

SKILL.md rules still apply; this adds dark mode.

## 1. Before starting

- Dark colors from **design**. No dark version but user wants one → propose dark palette from existing tokens, get OK before building.
- Default unclear → ask: `system` (recommended), `light`, `dark`.
- Check `next-themes` docs for current API.

## 2. Setup

```bash
<pm> add next-themes
```

Provider as small client component:

```tsx
// components/providers/theme-provider.tsx
"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider
      attribute="data-theme"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
    >
      {children}
    </NextThemesProvider>
  );
}
```

Root layout (SKILL.md section 4): wrap `children`, add `suppressHydrationWarning` on `<html>` (next-themes sets attribute before hydration).

```tsx
<html lang="en" suppressHydrationWarning>
  <body>
    <ThemeProvider>{children}</ThemeProvider>
  </body>
</html>
```

## 3. Tokens

Override **only color primitives** in `:root`. `@theme` tokens and components unchanged.

```css
:root {
  color-scheme: light;
}

[data-theme="dark"] {
  color-scheme: dark; /* native scrollbars, form controls */
  --bg: #0f0f12;
  --elevated: #1a1a1f;
  --fg: #f5f5f7;
  --muted: #a1a1aa;
  --border: #2a2a31;
  /* ...every color primitive that changes */
}
```

- Shadows that fail on dark → dark override too (they're primitives).
- Images needing dark version: `dark` entry next to light one in `IMAGES`, switch with CSS (`hidden` / `dark:block`), not JS → no flash.

`dark:` variant only for rare cases tokens can't cover:

```css
@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));
```

Many `dark:` classes = missing token. Add the token.

## 4. Toggle

- Leaf `"use client"` in `components/ui/theme-toggle.tsx`.
- Theme unknown on server → `resolvedTheme` `undefined` on first render. Render **same-size** placeholder until mounted → no hydration mismatch, no layout shift.
- Icon-only button: `aria-label` names the action ("Switch to dark mode").
- Look / placement from design. Not in design → ask where.

```tsx
"use client";

import { useEffect, useState } from "react";
import { useTheme } from "next-themes";
import { cn } from "@/lib/utils";

export function ThemeToggle({ className }: { className?: string }) {
  const { resolvedTheme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  if (!mounted) return <span className={cn("size-9", className)} aria-hidden />;

  const next = resolvedTheme === "dark" ? "light" : "dark";
  return (
    <button
      type="button"
      onClick={() => setTheme(next)}
      aria-label={`Switch to ${next} mode`}
      className={cn("size-9 ...", className)}
    >
      {/* icon from the design */}
    </button>
  );
}
```

## 5. Don't

- Read theme from cookies on server. `cookies()` makes route dynamic, breaks caching.
- Keep second set of component classes for dark. Colors change via primitives only.
- Animate theme switch (`disableTransitionOnChange` stays on), unless design asks.

## 6. Checklist

- [ ] Dark colors from design (or user-approved)
- [ ] `next-themes` with `attribute="data-theme"`, `suppressHydrationWarning` on `<html>`
- [ ] Only color primitives (+ shadows if needed) overridden under `[data-theme="dark"]`, `color-scheme` set
- [ ] No wrong-theme flash on load, no hydration warning in console
- [ ] Toggle = leaf client component, same-size placeholder, `aria-label`
- [ ] Checked in browser, both themes, all sizes

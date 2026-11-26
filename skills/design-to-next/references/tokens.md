# Tokens and `src/app/globals.css`

Read when setting up / changing `src/app/globals.css`: start of every design → code job, and whenever a new token is needed.

Rules (token flow, what may be raw, breakpoints) are in SKILL.md section 6. This file shows how to build the file.

## 1. Reading tokens from the design

List every value before writing CSS:

- **Colors:** backgrounds, surfaces, text (main, muted), borders, brand / primary + hover, text on primary, states (success, warning, error) if shown.
- **Typography:** font families, then each text style as a set: size, line height, letter spacing, weight. Name by role (`heading-xl`, `body-md`), not size.
- **Radii, shadows, durations.**
- **Layout:** container width, gutter, section spacing.

Same value in many places → one primitive. Values 1px apart are usually one token: build as designed, list the inconsistency (SKILL.md section 2).

Fluid sizes (`clamp()`) only when design shows different mobile / desktop sizes. Else fixed value, or value changing at `tablet:` / `desktop:`.

### Type scale: short, by role

Text sizes = **one scale for the whole site**, about 6–12 steps. Never one token per component (`--text-reel-tabs`, `--text-faq-q`, `--text-demo-price` = wrong).

1. Collect every font size in the design (all sections, all sizes).
2. Group: values used in several places, values ≤ 1–2px apart, same role → one step.
3. Name steps by role: `display`, `h1`, `h2`, `h3`, `lead`, `body`, `sm`, `xs`, `micro` (+ `btn`, `nav` only if they differ from body / sm).
4. Responsive size change = same token, value changed at `tablet:` / `desktop:` in `:root` (or `clamp()`), not a second token.
5. Mockups inside the design (fake phone screen, UI demo, player): one container token (`--text-mock-base`) + `em` sizes inside, or scale steps. Not a token per label.
6. A size that fits no step and appears once → nearest step if ≤ 1–2px off, list it ("merged 13px → `sm` 14px"). Real outliers stay, listed.

Same for line height / tracking / weight: part of the step (`--text-h2--line-height`), not separate per component.

More than 12 steps after grouping → tell user the design has an inconsistent scale, list values.

## 2. Naming

- `:root` primitives: short, by role (`--bg`, `--fg`, `--primary`, `--fs-heading-xl`, `--r-md`, `--sh-md`, `--dur-base`).
- `@theme` semantic tokens: Tailwind namespace + role (`--color-primary`, `--text-heading-xl`, `--radius-md`). They become the utilities (`bg-primary`, `text-heading-xl`, `rounded-md`).
- Brand palette with shades (`--brand-50` … `--brand-900`): shades stay primitives; map only **roles** the design uses into `@theme`. Components never use shade numbers.

## 3. Example

**Pattern example, not a template.** Values and names come from the design. Keep structure, adapt rest.

```css
@import "tailwindcss";

/* 1. Primitives: all raw values */
:root {
  /* colors */
  --bg: #ffffff;
  --elevated: #f7f7f8;
  --fg: #111114;
  --muted: #6b6b76;
  --border: #e4e4e9;
  --primary: #4f46e5;
  --primary-hover: #4338ca;
  --on-primary: #ffffff;

  /* type scale */
  --fs-heading-xl: clamp(2.5rem, 5vw, 4rem);
  --fs-heading-lg: clamp(2rem, 4vw, 3rem);
  --fs-heading-md: 1.5rem;
  --fs-body-lg: 1.125rem;
  --fs-body-md: 1rem;
  --fs-body-sm: 0.875rem;

  /* radius / shadow / motion */
  --r-sm: 0.375rem;
  --r-md: 0.75rem;
  --r-lg: 1.25rem;
  --sh-sm: 0 1px 2px rgb(0 0 0 / 0.06);
  --sh-md: 0 8px 24px rgb(0 0 0 / 0.08);
  --dur-base: 250ms;

  /* layout */
  --container: 75rem;
  --gutter: 1rem;
}

/* 2a. Breakpoints: literal values, so plain @theme. Mobile is the base */
@theme {
  --breakpoint-*: initial;
  --breakpoint-tablet: 48rem; /* 768px */
  --breakpoint-desktop: 64rem; /* 1024px */
}

/* 2b. Semantic tokens -> Tailwind utilities (inline, because they use var()) */
@theme inline {
  /* colors -> bg-bg, bg-elevated, text-fg, bg-primary... */
  --color-bg: var(--bg);
  --color-elevated: var(--elevated);
  --color-fg: var(--fg);
  --color-muted: var(--muted);
  --color-border: var(--border);
  --color-primary: var(--primary);
  --color-primary-hover: var(--primary-hover);
  --color-on-primary: var(--on-primary);

  /* fonts (vars come from next/font) */
  --font-sans: var(--font-body);
  --font-display: var(--font-heading);

  /* typography -> text-heading-xl, text-body-md... */
  --text-heading-xl: var(--fs-heading-xl);
  --text-heading-xl--line-height: 1.05;
  --text-heading-xl--letter-spacing: -0.02em;
  --text-heading-xl--font-weight: 700;
  --text-heading-lg: var(--fs-heading-lg);
  --text-heading-lg--line-height: 1.1;
  --text-heading-lg--font-weight: 700;
  --text-heading-md: var(--fs-heading-md);
  --text-heading-md--line-height: 1.3;
  --text-heading-md--font-weight: 600;
  --text-body-lg: var(--fs-body-lg);
  --text-body-lg--line-height: 1.6;
  --text-body-md: var(--fs-body-md);
  --text-body-md--line-height: 1.6;
  --text-body-sm: var(--fs-body-sm);
  --text-body-sm--line-height: 1.5;

  /* radius -> rounded-sm/md/lg, shadow -> shadow-sm/md */
  --radius-sm: var(--r-sm);
  --radius-md: var(--r-md);
  --radius-lg: var(--r-lg);
  --shadow-sm: var(--sh-sm);
  --shadow-md: var(--sh-md);

  --default-transition-duration: var(--dur-base);
}

/* 3. Base */
@layer base {
  body {
    @apply bg-bg text-fg font-sans text-body-md antialiased;
  }
}

@utility container-page {
  margin-inline: auto;
  max-width: var(--container);
  padding-inline: var(--gutter);
}
```

## 4. Adding a token later

1. Raw value into `:root`.
2. Map in `@theme inline` under right namespace.
3. Use the utility. Never raw value in a component "just once".
4. Dark mode on → add dark value too (`references/dark-mode.md`).

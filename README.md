<div align="center">

<img src="github/design2next-cover.png" alt="Design 2 Next cover" width="100%" />

# Design 2 Next

### From design artifact to a thoughtful, production-minded Next.js project.

Turn Claude Design exports, HTML/CSS, Figma files, and screenshots into a clear plan—and then into structured Next.js code, without losing the design along the way.

[![MIT License](https://img.shields.io/badge/license-MIT-2ea44f.svg)](LICENCE)
[![Agent-agnostic skill](https://img.shields.io/badge/agent-agnostic-6e56cf.svg)](skills/design-to-next/SKILL.md)

</div>

---

Design 2 Next is an **opinionated, agent-agnostic skill** for building Next.js projects from designs. It gives your coding agent a consistent stack, a practical project structure, and a design-to-code workflow—from extracting design values to checking the finished build.

The skill uses the standard `SKILL.md` format, so its instructions are not tied to Claude Code or a specific model. Use it with any compatible coding agent that supports this skill format; setup steps and available integrations depend on the host agent.

It is opinionated about **how the project is built**, but selective about **what the project needs**: optional features and infrastructure stay out until the design or your requirements call for them.

## 🧭 The workflow

```text
Design input
    ↓
Read the design and identify its tokens, content, and open questions
    ↓
Build a structured Next.js app that follows the design
    ↓
Check responsiveness, accessibility, and project quality
```

## What you get

- **A design-first process.** Treats the design as the source of truth for its content, layout, and visual details. Exact exports are read as exact; screenshots are treated as estimates.
- **A consistent modern stack.** Next.js App Router, strict TypeScript, Tailwind CSS, and a deliberate approach to caching, components, fonts, images, forms, and data.
- **A maintainable structure.** Separates routes, reusable UI, page sections, constants, assets, and server-side code—without scaffolding folders or dependencies the project does not use.
- **Responsive, accessible implementation.** Starts mobile-first and includes practical guidance for keyboard focus, semantic HTML, labels, and reduced motion.
- **Useful guardrails.** Covers design tokens, image handling, environment variables, server/client boundaries, SEO, and project checks.
- **Optional playbooks.** Focused references for dark mode, translations, SEO, authentication, payments, and EU legal requirements. These stay off unless they're relevant.

## 🎨 Design inputs

| Input                                      | How the skill uses it                                                                  |
| ------------------------------------------ | -------------------------------------------------------------------------------------- |
| Claude Design or another HTML/CSS artifact | Reads the markup, styles, assets, fonts, and copy to capture exact values              |
| Local HTML/CSS export                      | Inspects the exported files and assets, then rebuilds them using the project structure |
| Figma                                      | Uses available design tooling; otherwise asks for an export or missing design values   |
| Screenshot, image, or PDF                  | Estimates visual values and calls out what is estimated or missing                     |

The design informs the implementation; exported markup is not copied wholesale. Repeated patterns become reusable components, and design values become tokens.

## Opinionated by design

The skill establishes clear defaults while keeping projects lean:

- **App Router, TypeScript, and Tailwind CSS** for the application foundation.
- **Server Components by default**; client code only where interaction needs it.
- **Design tokens first**; components use semantic tokens rather than scattered raw design values.
- **Purposeful structure** for routes, UI primitives, sections, shared constants, and assets.
- **`next/image` and WebP** for project imagery, with exceptions for formats that need to remain compatible.
- **CSS-first animation** and accessible interaction patterns.
- **Conditional infrastructure:** add a database, authentication, payments, email, dark mode, translations, or SEO only when the project calls for it.
- **Current Next.js documentation first** whenever an implementation depends on a Next.js API.

These are defaults for the coding agent to follow—not a claim that the skill generates or tests an entire app automatically.

## 🚀 Get started with Claude Code

### Option 1: install as a plugin (recommended)

In Claude Code (2.1.275 or later):

```text
/plugin install design-to-next --marketplace Ablasko32/design2next
```

Or add the marketplace first, then install:

```text
/plugin marketplace add Ablasko32/design2next
/plugin install design-to-next@design-to-next
```

Updates arrive through the marketplace.

### Option 2: copy the skill into a project

1. Clone this repository.
2. From the directory containing this README, copy the skill folder into your project's `.claude/skills/`:

   ```bash
   mkdir -p /path/to/your-next-project/.claude/skills
   cp -R skills/design-to-next /path/to/your-next-project/.claude/skills/
   ```

   Replace `/path/to/your-next-project` with your Next.js project's path.

### Use it

Run the skill with a mode and the design:

```text
/design-to-next [auto|check] <design>
```

When installed as a plugin, the command is `/design-to-next:design-to-next`.

`<design>` can be:

- a claude.ai artifact URL (Claude Design or any HTML artifact)
- a local HTML file, image or PDF
- a folder with an HTML/CSS export

| Mode              | What it does                                                                                                                                                                                                                       |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check` (default) | Builds a small first slice (setup, tokens, fonts and the hero), shows you screenshots at mobile, tablet and desktop, and **asks before building the rest**. Best for a new design: you catch wrong fonts, colors or spacing early. |
| `auto`            | Builds the whole project without stopping. Open questions (icon set, email service, missing fonts...) are answered with sensible defaults, and every assumption is listed in the final summary.                                    |

Examples:

```text
/design-to-next https://claude.ai/artifact/…
/design-to-next auto ./design-export
/design-to-next check ./mockups/home.png
```

You can also just ask in plain words, for example:

> Use the Design 2 Next skill to turn this design into a responsive Next.js landing page. First inspect the design and tell me what you found.

The skill's instructions and supporting references are in [`skills/design-to-next/`](skills/design-to-next/).

## 🛠️ Scripts

The skill ships two helper scripts. The agent runs them from the root of your Next.js project; you can run them yourself too.

| Script                                                     | What it does                                                                                                                                                                                                                                                                                                                   | Needs                                     |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| [`check.sh`](skills/design-to-next/scripts/check.sh)       | Checks most of the final checklist automatically: structure, tokens, client/server boundaries, images, env, SEO basics, auth and Stripe safety. Then runs the `typecheck`, `lint` and `format:check` scripts. `--fast` skips the commands, `--build` also runs the build. Exits with `1` on any error, so it also works in CI. | bash, the project's package manager       |
| [`to-webp.mjs`](skills/design-to-next/scripts/to-webp.mjs) | Converts PNG / JPG / GIF / TIFF images to WebP (default folder `assets/images`). Keeps SVG, animated GIFs and files in `app/` / `public/`. `--replace` deletes the originals.                                                                                                                                                  | Node.js, `sharp` (installed with Next.js) |

```bash
bash .claude/skills/design-to-next/scripts/check.sh --build
node .claude/skills/design-to-next/scripts/to-webp.mjs assets/images --replace
```

The checks are line-based heuristics: they catch the common mistakes, not every one. Design match, console errors and content quality are still checked by hand.

## 📚 Project playbooks

The core skill is supported by focused references:

- [`design-input.md`](skills/design-to-next/references/design-input.md) — reading exports, Figma, and screenshots
- [`tokens.md`](skills/design-to-next/references/tokens.md) — extracting and organizing design tokens
- [`seo.md`](skills/design-to-next/references/seo.md) — public-page SEO
- [`auth.md`](skills/design-to-next/references/auth.md) — authentication
- [`payments.md`](skills/design-to-next/references/payments.md) — Stripe payments
- [`i18n.md`](skills/design-to-next/references/i18n.md) — translations
- [`dark-mode.md`](skills/design-to-next/references/dark-mode.md) — dark mode
- [`legal-eu.md`](skills/design-to-next/references/legal-eu.md) — EU privacy and legal considerations

## ⚖️ License

**Design 2 Next** is available under the [MIT License](LICENCE).

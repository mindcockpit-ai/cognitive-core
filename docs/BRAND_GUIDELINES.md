# cognitive-core Brand Guidelines

Brand identity for cognitive-core and [multivac42.ai](https://multivac42.ai). Reference for all visual assets, marketing pages, and documentation.

## Color Palette

### Core Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `slate-950` | `#020617` | Primary background |
| `slate-900` | `#0f172a` | Secondary background, favicon bg |
| `slate-800` | `#1e293b` | Borders, card backgrounds |
| `slate-700` | `#334155` | Mid-tone accents |
| `slate-500` | `#64748b` | Muted text |
| `slate-400` | `#94a3b8` | Secondary text |
| `slate-300` | `#cbd5e1` | Light text |
| `slate-200` | `#e2e8f0` | Body text (primary) |

### Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `sky-300` | `#7dd3fc` | Light accents, terminal output |
| `sky-400` | `#38bdf8` | **Primary accent** — buttons, icons, glows, links |
| `sky-500` | `#0ea5e9` | Hover states, button backgrounds |

### Gradient

The signature gradient represents cognitive expansion — from sky (practical) through indigo (analytical) to purple (creative):

```css
background: linear-gradient(135deg, #38bdf8 0%, #818cf8 50%, #c084fc 100%);
```

| Stop | Hex | Color |
|------|-----|-------|
| 0% | `#38bdf8` | Sky |
| 50% | `#818cf8` | Indigo |
| 100% | `#c084fc` | Purple |

Used for: hero text, OG image text, decorative accents.

### Semantic Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Green | `#22c55e` | Success, checkmarks |
| Yellow | `#eab308` | Warnings |
| Red | `#ef4444` | Errors |

### Card Glow Effect

```css
/* Default */
background: linear-gradient(135deg, rgba(56, 189, 248, 0.05), rgba(129, 140, 248, 0.05));
border: 1px solid rgba(56, 189, 248, 0.1);

/* Hover */
border-color: rgba(56, 189, 248, 0.3);
box-shadow: 0 0 20px rgba(56, 189, 248, 0.1);
```

## Typography

### Font Stack

```css
font-family: system-ui, -apple-system, sans-serif;
```

No external fonts. System fonts provide fast loading and native feel.

### Scale

| Element | Tailwind | Size | Weight |
|---------|----------|------|--------|
| Hero title (lg) | `text-7xl` | ~72px | `font-bold` |
| Hero title (sm) | `text-5xl` | ~48px | `font-bold` |
| Section heading | `text-3xl` / `text-4xl` | 30-36px | `font-bold` |
| Body large | `text-xl leading-relaxed` | 20px | normal |
| Body | `text-base` | 16px | normal |
| CTA text | `text-base` | 16px | `font-semibold` |
| Small | `text-sm` | 14px | normal |
| Tiny | `text-xs` | 12px | normal |

### Code / Terminal

```css
font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
```

Tailwind class: `font-mono`

## Spacing

| Token | Tailwind | Pixels | Usage |
|-------|----------|--------|-------|
| Horizontal padding | `px-6` | 24px | Default content padding |
| Section vertical | `py-20` | 80px | Section spacing |
| Hero top | `py-32` | 128px | Hero section |
| Component gap | `gap-6` | 24px | Between cards, items |
| Container max | `max-w-5xl` | 1024px | Content width |

## Border Radius

| Token | Tailwind | Usage |
|-------|----------|-------|
| Small | `rounded-lg` | Buttons, small components |
| Medium | `rounded-xl` | Cards |
| Large | `rounded-2xl` | Containers, sections |

## Brand Assets

### Visual Assets

| Asset | Path | Format | Dimensions |
|-------|------|--------|------------|
| Logo (SVG) | `docs/logo.svg` | SVG | 512×512 |
| Logo (PNG) | `docs/logo-256.png` | PNG | 256×256 |
| Favicon | multivac42.ai `public/favicon.svg` | SVG | 32×32 |
| Logo PNGs | multivac42.ai `public/logo-{128,256,512}.png` | PNG | Various |
| OG Image | multivac42.ai `public/og-image.svg` | SVG | 1200×630 |

### Logo Design

Nested concentric squares with a center dot and cardinal direction lines. Represents a cognitive framework — layered structure radiating outward from a core intelligence point.

- Background: `#020617` (slate-950) with rounded corners
- Outer square: sky→indigo→purple gradient stroke, 0.3 opacity
- Middle square: same gradient stroke, 0.6 opacity
- Inner square: `#38bdf8` (sky-400) solid stroke
- Center dot: `#38bdf8` (sky-400) solid fill
- Cardinal lines: sky-400, 50% opacity
- Diagonal lines: `#818cf8` (indigo), 25% opacity
- Node dots: sky-400 on edges, indigo on corners

### Favicon Design

Simplified version of the logo at 32×32. Same nested squares design with gradient strokes, center dot, cardinal lines, and corner nodes.

### OG Image Design

Dark background with subtle grid pattern, central radial glow, gradient text title, and stat boxes (agents, skills, languages, hooks).

## Terminal Branding (ASCII Art)

All terminal output uses the branded ASCII art from `core/brand.sh`. Source this file in any script, hook, skill, or agent for consistent branding.

### Full Banner (`_cc_banner`)

Used in: `install.sh`, `update.sh`, first-run experience.

```
    ┌─────────────────────────┐
    │   ┌─────────────────┐   │
    │   │   ┌─────────┐   │   │
    │   │   │   ┌─┐   │   │   │
    │───│───│───│•│───│───│───│
    │   │   │   └─┘   │   │   │
    │   │   └─────────┘   │   │
    │   └─────────────────┘   │
    └─────────────────────────┘
    c o g n i t i v e - c o r e  v1.0.0
    AI-native development framework
```

Box-drawing characters form nested squares mirroring the SVG logo. The center `•` represents the core node. Cardinal lines (`───`) extend through all layers representing cross-cutting framework capabilities.

### Compact Banner (`_cc_banner_compact`)

Used in: skill headers, agent startup, hook output, log prefixes.

```
◻ ◻ ◻ • cognitive-core v1.0.0
```

Three unicode squares (outer→inner) plus the center dot glyph. Minimal footprint, instant brand recognition.

### Section Divider (`_cc_divider`)

```
──── Section Name ────
```

### Status Symbols

| Symbol | Function | Meaning |
|--------|----------|---------|
| `[+]` | `_cc_info` | Success / progress (green) |
| `[!]` | `_cc_warn` | Warning (yellow) |
| `[x]` | `_cc_err` | Error (red, to stderr) |
| `===` | `_cc_header` | Section header (bold cyan) |

### Usage in Scripts

```bash
#!/bin/bash
source "$(dirname "$0")/core/brand.sh"

_cc_banner                         # full logo on startup
_cc_header "Installing hooks"
_cc_info "validate-bash.sh installed"
_cc_info "validate-read.sh installed"
_cc_divider "Summary"
_cc_info "Done. 8 hooks installed."
```

### Usage in Skills / Hooks

```bash
source "${CC_FRAMEWORK_DIR}/core/brand.sh"

_cc_banner_compact                 # one-liner for lighter output
_cc_divider "Workspace Scan"
_cc_info "Scanning 12 projects..."
```

### Color Mapping (ANSI)

| Brand Color | ANSI Code | Terminal | Used for |
|-------------|-----------|---------|----------|
| Sky-400 | `\033[0;36m` | Cyan | Logo, headers, dividers |
| Indigo | `\033[0;34m` | Blue | Compact banner squares |
| Purple | `\033[0;35m` | Purple | Version string, compact squares |
| Green | `\033[0;32m` | Green | `[+]` success |
| Yellow | `\033[0;33m` | Yellow | `[!]` warning |
| Red | `\033[0;31m` | Red | `[x]` error |

All colors are tty-aware — when output is piped or redirected, plain text is emitted for clean log files.

## Buttons

| Type | Style | Hover |
|------|-------|-------|
| Primary | `bg-sky-500 text-white shadow-sky-500/25` | Lighter sky |
| Secondary | `border-slate-700 text-slate-300` | `border-slate-600` |

## Navigation

- Fixed position, `z-50`
- `backdrop-blur-lg` with 50% opacity border
- Mobile: hamburger toggle, hidden on `sm+`

## Dark Theme Only

cognitive-core uses a single dark theme. No light mode variant. The dark aesthetic conveys technical sophistication and aligns with developer tooling conventions.

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| Astro | 5.3.0 | Static site generation |
| Tailwind CSS | 4.0.0 | Utility-first styling |
| TypeScript | strict | Type safety |

---

*Extracted from [multivac42.ai](https://multivac42.ai) implementation. Last updated: March 2026.*

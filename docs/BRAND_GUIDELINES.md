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

| Asset | Path | Format | Dimensions |
|-------|------|--------|------------|
| Favicon | `public/favicon.svg` | SVG | Square |
| OG Image | `public/og-image.svg` | SVG | 1200x630 |

### Favicon Design

Concentric circles with a center dot and cardinal direction lines. Represents a network node — cognitive-core as the center point with directional vectors.

- Background circle: `#0f172a` (slate-900)
- Strokes: `#38bdf8` (sky-400)
- Lines at 50% opacity for depth

### OG Image Design

Dark background with subtle grid pattern, central radial glow, gradient text title, and stat boxes (agents, skills, languages, hooks).

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

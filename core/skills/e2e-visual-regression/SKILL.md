---
name: e2e-visual-regression
description: "Playwright visual regression testing — baseline management, tolerance calibration, cross-platform strategies, failure debugging. Framework-agnostic patterns proven in production."
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "update | debug | calibrate | add <page>"
catalog_description: "Visual regression — baselines, tolerance, debugging, cross-platform."
---

# E2E Visual Regression — Playwright Screenshot Testing

Manage Playwright visual regression testing: baselines, comparison, debugging,
cross-platform strategies. Framework-agnostic — works with any web stack.

## Arguments

- `$ARGUMENTS`:
  - `update` — Update baselines after intentional UI changes
  - `debug` — Diagnose a failing visual test
  - `calibrate` — Tune tolerance settings for stability
  - `add <page>` — Add visual regression to a new page/workflow
  - (none) — Show status and run visual tests

## How Visual Regression Works

```
First Run:     Capture → Save as baseline           → PASS
Subsequent:    Capture → Compare against baseline    → PASS if diff ≤ threshold
After Change:  Capture → Compare against baseline    → FAIL if diff > threshold
                                                     → Update baseline if intentional
```

## Recommended Settings

```typescript
await expect(page).toHaveScreenshot('name.png', {
  maxDiffPixelRatio: 0.05,   // Max 5% of pixels may differ
  threshold: 0.3,             // Per-pixel color sensitivity (0-1)
  animations: 'disabled',     // Freeze CSS transitions for determinism
});
```

### Tolerance Guide

| Level | `maxDiffPixelRatio` | Use Case |
|-------|-------------------|----------|
| Strict | 0.01 (1%) | Static pages, no dynamic content |
| Standard | 0.03 (3%) | Pages with minor dynamic content (badges) |
| **Default** | **0.05 (5%)** | **Pages with timestamps, user-relative data** |
| Relaxed | 0.10 (10%) | Pages with charts, graphs, heavy animation |

### Why 5% Default (Not 1%)

| Noise Source | Pixel Impact | Frequency |
|-------------|-------------|-----------|
| Relative timestamps ("2h ago" → "3h ago") | 1-2% | Every run |
| Font anti-aliasing / sub-pixel rendering | 0.5-1% | Cross-platform |
| CSS animation mid-frame | 5-50% | Without `animations: disabled` |
| Chart/graph data-driven rendering | 2-10% | Data pages |

1% tolerance causes false failures on any page with dynamic content.

## Baseline Management

### Storage Location

```
test-file.spec.ts-snapshots/
  name-chromium-darwin.png          ← macOS baseline
  name-chromium-linux.png           ← Linux/CI baseline
  name-chromium-darwin-actual.png   ← only on failure
  name-chromium-darwin-diff.png     ← only on failure
```

Suffix: `<name>-<browser>-<os>.png`

### Update After Intentional UI Changes

```bash
# Update all baselines
npx playwright test e2e/visual/ --update-snapshots

# Update specific test
npx playwright test e2e/visual/specific.spec.ts --update-snapshots

# Commit new baselines
git add **/*-snapshots/*.png
git commit -m "test: update visual regression baselines after UI redesign"
```

### Cross-Platform Strategy

Different platforms render fonts and anti-aliasing differently. Options:

| Strategy | Pros | Cons |
|----------|------|------|
| Per-platform baselines (default) | Exact comparison | Must maintain multiple sets |
| Higher tolerance (0.10) | Single baseline | May miss real regressions |
| Docker-based CI | Consistent rendering | Setup complexity |
| Mask dynamic regions | Focused comparison | More test code |

## Before Screenshot Checklist

```typescript
// 1. Wait for SPECIFIC content (not just page load)
await expect(page.getByText('Expected Content')).toBeVisible({ timeout: 10_000 });

// 2. Wait for element count if expecting multiple items
await expect(page.locator('.card')).toHaveCount(3, { timeout: 10_000 });

// 3. Dismiss overlays (cookie consent, modals, notifications)
const overlay = page.getByText('Dismiss');
if (await overlay.isVisible({ timeout: 1_000 }).catch(() => false)) {
  await overlay.click();
  await page.waitForTimeout(300); // Wait for animation
}

// 4. Expand collapsed sections if needed
await page.getByText('Section Header').click();
await expect(page.getByText('Section Content')).toBeVisible();

// 5. Take screenshot
await expect(page).toHaveScreenshot('descriptive-name.png', {
  maxDiffPixelRatio: 0.05,
  threshold: 0.3,
  animations: 'disabled',
});
```

## Debugging Failures

### Common Failure Patterns

| Symptom | Cause | Fix |
|---------|-------|-----|
| Small diff (1-3%) in text | Timestamps, counters | Increase tolerance or use `page.clock` |
| Scattered tiny diffs | Font rendering | Increase `threshold`, pin browser version |
| Large diff in one area | Animation captured | `animations: 'disabled'`, explicit waits |
| Spinner in screenshot | Loading state captured | Wait for content, not just page load |
| Pass locally, fail CI | Platform rendering | Per-platform baselines or Docker |
| Diff only in header/footer | Dynamic elements (time, user) | Mask region or freeze clock |

### Debug Commands

```bash
# Run with HTML report (shows visual diffs)
npx playwright test e2e/visual/ --reporter=html
npx playwright show-report

# Run headed (watch test execute)
npx playwright test e2e/visual/ --headed

# Run with trace (step-by-step replay with screenshots)
npx playwright test e2e/visual/ --trace on

# Debug mode (pause at each step)
npx playwright test e2e/visual/ --debug

# Interactive UI mode (timeline, DOM inspector)
npx playwright test --ui
```

### Analyzing Failure Artifacts

On failure, Playwright creates three files in the snapshots directory:

| File | Contents |
|------|----------|
| `name-expected.png` | The baseline (what we expected) |
| `name-actual.png` | What was captured this run |
| `name-diff.png` | Pixel difference overlay (red = changed pixels) |

Open the HTML report (`npx playwright show-report`) for side-by-side comparison
with zoom and overlay toggle.

## Clock Control for Deterministic Timestamps

```typescript
// Freeze time for entire test
test.use({
  // This affects the page's Date constructor
});

// Or per-test:
await page.clock.setFixedTime(new Date('2026-03-10T12:00:00Z'));
await page.goto('/');
// All timestamps will show consistent values
```

## Masking Dynamic Regions

```typescript
await expect(page).toHaveScreenshot('page.png', {
  maxDiffPixelRatio: 0.05,
  mask: [
    page.locator('.timestamp'),  // Ignore timestamp areas
    page.locator('.user-avatar'), // Ignore user-specific content
  ],
});
```

## CI Integration

### GitHub Actions Example

```yaml
- name: Run visual regression tests
  run: |
    cd lts-portal
    npx playwright install chromium
    npx playwright test e2e/visual/
  env:
    CI: true

- name: Upload test artifacts on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: visual-regression-report
    path: lts-portal/test-results/
    retention-days: 7
```

### Baseline Commit Strategy

- Baselines are checked into git (they ARE the source of truth)
- Review baseline changes in PRs (GitHub renders PNG diffs)
- Never auto-update baselines in CI — always require human review
- Consider a separate `baseline-update` CI job that creates a PR

## Workflow

### On `update`

```bash
echo "Updating visual regression baselines..."
cd "$(git rev-parse --show-toplevel)" || exit 1

# Find Playwright config
CONFIG=$(find . -name "playwright.config.ts" -not -path "*/node_modules/*" | head -1)
if [ -z "$CONFIG" ]; then
  echo "No playwright.config.ts found"
  exit 1
fi

DIR=$(dirname "$CONFIG")
cd "$DIR"

# Run with update flag
npx playwright test e2e/visual/ --update-snapshots

echo "Baselines updated. Review changes with: git diff --stat"
echo "Commit with: git add **/*-snapshots/*.png"
```

### On `debug`

1. Check for recent failure artifacts (`*-actual.png`, `*-diff.png`)
2. Show the diff image path
3. Suggest tolerance adjustments based on diff percentage
4. Check for common causes (animations, loading states, timestamps)

### On `calibrate`

1. Run visual tests 5 times consecutively
2. Measure max pixel diff between runs
3. Recommend tolerance = measured max + 2% safety margin
4. Show which areas cause the most variance

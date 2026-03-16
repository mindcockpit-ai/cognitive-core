// Usage: node screenshot-element.mjs <url> <css-selector> <output-path>
import { chromium } from 'playwright';
const [url, selector, output] = process.argv.slice(2);
if (!url || !selector || !output) {
  console.error('Usage: node screenshot-element.mjs <url> <selector> <output>');
  process.exit(1);
}
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
await page.goto(url, { waitUntil: 'networkidle' });
const element = await page.locator(selector);
await element.screenshot({ path: output });
console.log(`Screenshot captured: ${output}`);
await browser.close();

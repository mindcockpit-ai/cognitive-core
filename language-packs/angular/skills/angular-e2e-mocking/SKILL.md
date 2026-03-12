---
name: angular-e2e-mocking
description: "Playwright E2E patterns for Angular apps with Keycloak/OAuth2 auth and REST API mocking. Two-layer auth bypass, HttpClient interceptor patterns, Angular Material selectors. Based on production patterns."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Angular E2E mocking — Keycloak bypass, REST API mocking, Angular Material selectors."
---

# Angular E2E Mocking — Keycloak + REST API + Angular Material

Playwright E2E patterns for Angular apps with Keycloak-protected routes, REST API
backends, and Angular Material UI components. Zero backend dependency, zero
production code changes.

## Architecture

```
Playwright Test
  ├── Auth Bypass
  │   ├── Layer 1: addInitScript()    → XHR/WebSocket patches (browser context)
  │   └── Layer 2: page.route()       → Network-level interception
  ├── REST API Mock
  │   └── page.route(**/api/**)       → URL pattern matching to JSON fixtures
  └── Fixtures
      └── e2e/fixtures/*.json         → Deterministic response data
```

---

## 1. Keycloak Auth Bypass (Two-Layer)

### Why Two Layers

keycloak-js v25 uses Authorization Code + PKCE. The Angular app typically initializes
Keycloak via `APP_INITIALIZER` or `provideKeycloak()` — the bypass must complete
BEFORE Angular bootstrap finishes, otherwise the app hangs.

The init flow involves:
- XHR calls (token exchange, cookie check) — intercepted by Layer 1
- Full-page redirects (auth endpoint) — intercepted by Layer 2
- localStorage read/write (nonce storage) — intercepted by Layer 1

Neither layer alone covers all paths.

### Layer 1: addInitScript (Browser Context)

Runs before any page scripts. Patches three browser APIs:

**XMLHttpRequest** — intercepts keycloak-js internal HTTP calls:
```javascript
const OriginalXHR = window.XMLHttpRequest;
window.XMLHttpRequest = function() {
  const xhr = new OriginalXHR();
  const originalOpen = xhr.open.bind(xhr);
  const originalSend = xhr.send.bind(xhr);

  let interceptUrl = '', shouldIntercept = false;

  xhr.open = function(method, url, ...rest) {
    interceptUrl = url.toString();
    shouldIntercept = KEYCLOAK_PATTERN.test(interceptUrl);
    return originalOpen(method, interceptUrl, ...rest);
  };

  xhr.send = function(body) {
    if (!shouldIntercept) return originalSend(body);
    setTimeout(() => {
      // Build response based on URL (token endpoint, cookie check, etc.)
      // Set readyState=4, status=200, responseText=JSON
      // Fire readystatechange + load events
    }, 0);
  };
  return xhr;
};
```

**WebSocket** — blocks subscription connections:
```javascript
const OriginalWebSocket = window.WebSocket;
window.WebSocket = function(url, protocols) {
  if (BLOCK_PATTERN.test(url)) {
    const ws = Object.create(OriginalWebSocket.prototype);
    Object.defineProperty(ws, 'readyState', { value: 3 }); // CLOSED
    ws.send = ws.close = ws.addEventListener = ws.removeEventListener = () => {};
    setTimeout(() => ws.onclose?.(new CloseEvent('close', { code: 1000 })), 10);
    return ws;
  }
  return new OriginalWebSocket(url, protocols);
};
```

**localStorage.getItem** — captures PKCE nonce:
```javascript
// CRITICAL: keycloak-js stores nonce in localStorage as kc-callback-{state}
// and reads+REMOVES it in parseCallback() BEFORE the token XHR fires.
// The token response ID token MUST include the same nonce.
let capturedNonce = null;
const originalGetItem = localStorage.getItem.bind(localStorage);
localStorage.getItem = function(key) {
  const value = originalGetItem(key);
  if (key?.startsWith('kc-callback-') && value) {
    try { capturedNonce = JSON.parse(value).nonce; } catch {}
  }
  return value;
};
```

### Layer 2: page.route (Network Level)

Handles full-page redirects that XHR patching cannot intercept.

| Endpoint | Response |
|----------|----------|
| `openid-connect/auth**` | 302 → `redirect_uri#state={state}&session_state=fake&code=fake` |
| `login-status-iframe.html**` | HTML: `postMessage('unchanged')` |
| `3p-cookies/**` | HTML: `parent.postMessage('supported', '*')` |
| `openid-connect/certs` | `{ keys: [] }` |
| `openid-connect/token` | Fake token response (backup for Layer 1) |
| `.well-known/openid-configuration` | OIDC discovery JSON |
| `{keycloak_host}/**` | Catch-all: empty HTML |

### Angular-Specific Auth Considerations

```typescript
// Angular apps using APP_INITIALIZER for Keycloak:
// The bypass must complete before Angular's bootstrap promise resolves.
// If it doesn't, the app shows a blank page because APP_INITIALIZER blocks rendering.

// Common Angular Keycloak setup:
export const appConfig: ApplicationConfig = {
  providers: [
    provideKeycloak({
      config: { url: 'https://keycloak.example.com', realm: 'my-realm', clientId: 'my-app' },
      initOptions: { onLoad: 'login-required', checkLoginIframe: false },
    }),
  ],
};

// The bypass intercepts ALL Keycloak URLs, so the init resolves immediately.
// checkLoginIframe: false avoids the iframe check — simplifies bypass.
```

### Fake JWT Requirements

```javascript
const payload = {
  exp: now + 3600, iat: now, auth_time: now,
  iss: realmUrl,              // Must match Keycloak realm URL
  sub: 'fake-user-id',
  typ: 'Bearer',              // 'ID' for id_token
  azp: 'client-id',           // Must match Keycloak client ID
  session_state: 'fake-session-state',
  nonce: capturedNonce,        // CRITICAL for ID token
  preferred_username: 'testuser@example.com',
  realm_access: { roles: ['user'] },
  resource_access: { 'client-id': { roles: ['admin', 'viewer'] } },
  scope: 'openid email profile',
};
```

### Auth Flow After Bypass

```
APP_INITIALIZER → provideKeycloak init({ onLoad: 'login-required' })
  → Layer 2 intercepts auth redirect → returns 302 with fake code
  → Page reloads with #state=...&code=... in fragment
  → keycloak-js parseCallback() → reads nonce from localStorage (Layer 1 captures it)
  → keycloak-js POSTs to token endpoint → Layer 1 XHR mock returns tokens with nonce
  → init() resolves → APP_INITIALIZER completes
  → Angular bootstraps → Router navigates → HttpClient calls begin
  → REST API mocks return fixture data
  → App renders
```

---

## 2. REST API Mocking

Angular typically uses REST APIs via `HttpClient`, not GraphQL. Mocking is simpler
than Apollo — URL pattern matching instead of operation-name routing.

### URL Pattern Matching

```typescript
// Setup mock routes BEFORE page.goto()
await page.route('**/api/users**', async (route) => {
  const url = new URL(route.request().url());
  const method = route.request().method();

  if (method === 'GET' && url.pathname === '/api/users') {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(fixtures.userList),
    });
    return;
  }

  if (method === 'GET' && url.pathname.match(/\/api\/users\/[\w-]+$/)) {
    const id = url.pathname.split('/').pop();
    const user = fixtures.users[id] || fixtures.users['default'];
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(user),
    });
    return;
  }

  if (method === 'POST') {
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({ id: 'new-user-e2e', ...JSON.parse(route.request().postData() || '{}') }),
    });
    return;
  }

  // Fallback
  await route.fulfill({ status: 404, body: '{"error":"Not found"}' });
});
```

### CORS Preflight Handler

```typescript
await page.route('**/api/**', async (route) => {
  if (route.request().method() === 'OPTIONS') {
    await route.fulfill({
      status: 204,
      headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'content-type, authorization',
      },
    });
    return;
  }
  await route.fallback(); // Chain to specific handlers
});
```

### Pagination Envelope Pattern

```typescript
// Angular apps often use envelope responses for paginated data
const paginatedResponse = {
  content: fixtures.items.slice(0, 10),
  page: {
    number: 0,
    size: 10,
    totalElements: fixtures.items.length,
    totalPages: Math.ceil(fixtures.items.length / 10),
  },
};

await page.route('**/api/items**', async (route) => {
  const url = new URL(route.request().url());
  const page = parseInt(url.searchParams.get('page') || '0');
  const size = parseInt(url.searchParams.get('size') || '10');

  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      content: fixtures.items.slice(page * size, (page + 1) * size),
      page: { number: page, size, totalElements: fixtures.items.length,
              totalPages: Math.ceil(fixtures.items.length / size) },
    }),
  });
});
```

---

## 3. Fixture Creation Checklist

- [ ] ALL fields from the API response included (check TypeScript interfaces)
- [ ] Deterministic IDs (`user-e2e-001`, `item-e2e-002`)
- [ ] Dates as ISO strings (`2026-01-15T10:30:00.000Z`)
- [ ] Enum values match backend exactly (e.g., `"ACTIVE"` not `"active"`)
- [ ] Pagination envelope structure matches backend format
- [ ] Nested objects fully populated (no partial objects)
- [ ] User permissions match test scenarios (admin vs viewer)
- [ ] Test incrementally — add one fixture, run, check console errors

---

## 4. Angular Material Component Selectors (Stability Ranked)

| Priority | Selector | Example | Notes |
|----------|----------|---------|-------|
| 1 | `formControlName` | `[formControlName="email"]` | Most stable for form fields |
| 2 | ARIA role + name | `getByRole('button', { name: 'Save' })` | Works for buttons, tabs, menus |
| 3 | `mat-*` element | `mat-row`, `mat-card`, `mat-dialog-container` | Angular Material custom elements |
| 4 | Text content | `getByText('Dashboard')` | Stable with fixture data |
| 5 | Input placeholder | `input[placeholder="Search"]` | For unstructured inputs |
| 6 | CSS class | `[class*="mat-mdc-"]` | **Avoid** — breaks between Material versions |

### Angular Material Pitfalls

| Issue | Cause | Solution |
|-------|-------|---------|
| `mat-select` click doesn't open | Overlay rendering | Use `locator('mat-select').click()` then `locator('mat-option')` |
| Dialog actions not clickable | Overlay z-index | Target `mat-dialog-actions button` specifically |
| Table rows empty | Async data loading | `await expect(locator('mat-row')).toHaveCount(expected)` |
| Autocomplete options not visible | Panel not opened | Type in input first, then wait for `mat-autocomplete-panel` |
| Snackbar assertion fails | Animation timing | Use `await expect(locator('mat-snack-bar-container')).toBeVisible()` |
| Sidenav content hidden | Drawer collapsed | Click hamburger menu or use `locator('mat-sidenav-content')` |
| Tab content not rendered | Lazy tab rendering | Click tab first, then assert on `mat-tab-body-active` |
| Stepper step not accessible | Linear stepper blocks | Complete previous steps first |

---

## 5. Test Structure Template

```typescript
import { test, expect } from '@playwright/test';
import { bypassAuth } from '../mocks/auth-bypass';
import { mockRestApi } from '../mocks/rest-api';

test.describe('User Management', () => {
  test('complete CRUD workflow', async ({ page }) => {
    // Setup (MUST be before page.goto)
    await bypassAuth(page);
    await mockRestApi(page);

    // Navigate
    await page.goto('/', { waitUntil: 'commit' });

    // Wait for Angular to bootstrap (APP_INITIALIZER completes)
    await page.waitForFunction(() => {
      const root = document.querySelector('app-root');
      return root && root.children.length > 0;
    }, { timeout: 30_000 });

    // Wait for router navigation
    await page.waitForURL('**/dashboard', { timeout: 10_000 });

    // Navigate to users
    await page.getByRole('link', { name: 'Users' }).click();
    await page.waitForURL('**/users');
    await expect(page.locator('mat-row')).toHaveCount(3);

    // Create new user
    await page.getByRole('button', { name: 'Add User' }).click();
    await expect(page.locator('mat-dialog-container')).toBeVisible();

    await page.locator('[formControlName="name"]').fill('Test User');
    await page.locator('[formControlName="email"]').fill('test@example.com');

    await page.locator('mat-select[formControlName="role"]').click();
    await page.locator('mat-option').filter({ hasText: 'Admin' }).click();

    await page.locator('mat-dialog-actions button').filter({ hasText: 'Save' }).click();

    // Verify created
    await expect(page.locator('mat-snack-bar-container')).toContainText('User created');
  });
});
```

---

## 6. Debugging Playbook

| Symptom | Likely Cause | Debug Action |
|---------|-------------|--------------|
| Blank page (no content) | APP_INITIALIZER auth failed | Check Layer 1/2 intercepts, verify Keycloak URL patterns |
| Blank page after auth | Angular failed to bootstrap | Add `page.on('pageerror')` listener, check console |
| `NullInjectorError` in console | Missing provider in test config | Check `provideHttpClient()` and service providers |
| Component renders but empty | REST API fixture missing fields | Compare fixture with TypeScript interface |
| Material component not interactive | Overlay not attached to DOM | Wait for `mat-*` panel/overlay to be visible |
| Router doesn't navigate | Guard/resolver blocking | Mock guard/resolver data in fixtures |
| Screenshot diff > threshold | Animations, timestamps, random data | Add `animations: 'disabled'`, use deterministic fixtures |
| `ExpressionChangedAfterItHasBeenChecked` | Change detection timing | Wrap async data in signals, use OnPush |
| Zone.js unhandled error | Async error absorbed by Zone | Check `page.on('pageerror')` and browser console |

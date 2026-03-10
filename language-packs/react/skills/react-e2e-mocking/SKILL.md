---
name: react-e2e-mocking
description: "Playwright E2E patterns for React apps with Keycloak auth and Apollo Client GraphQL. Two-layer auth bypass, operation-name routing, fixture creation rules, MUI selectors. Based on production PoC."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "React E2E mocking — Keycloak bypass, Apollo GraphQL fixtures, MUI selectors."
---

# React E2E Mocking — Keycloak + Apollo + MUI

Proven patterns from a production PoC: fully mocked Playwright E2E tests for a
React 18 / Keycloak / Apollo Client / MUI v5 application. Zero backend dependency,
zero production code changes.

## Architecture

```
Playwright Test
  ├── Auth Bypass
  │   ├── Layer 1: addInitScript()    → XHR/WebSocket patches (browser context)
  │   └── Layer 2: page.route()       → Network-level interception
  ├── GraphQL Mock
  │   └── page.route(**/api/graphql)  → Operation-name routing to JSON fixtures
  └── Fixtures
      └── e2e/fixtures/*.json         → Deterministic response data
```

---

## 1. Keycloak Auth Bypass (Two-Layer)

### Why Two Layers

keycloak-js v25 uses Authorization Code + PKCE. The init flow involves:
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

**WebSocket** — blocks graphql-ws/subscription connections:
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

**Route priority rule**: In Playwright, routes registered LAST have HIGHEST priority.
Register catch-all FIRST, specific routes AFTER.

| Endpoint | Response |
|----------|----------|
| `openid-connect/auth**` | 302 → `redirect_uri#state={state}&session_state=fake&code=fake` |
| `login-status-iframe.html**` | HTML: `postMessage('unchanged')` |
| `3p-cookies/**` | HTML: `parent.postMessage('supported', '*')` |
| `openid-connect/certs` | `{ keys: [] }` |
| `openid-connect/token` | Fake token response (backup for Layer 1) |
| `.well-known/openid-configuration` | OIDC discovery JSON |
| `{keycloak_host}/**` | Catch-all: empty HTML |

### Auth Redirect Pattern

```typescript
await page.route(`${realmUrl}/protocol/openid-connect/auth**`, async (route) => {
  const url = new URL(route.request().url());
  const redirectUri = url.searchParams.get('redirect_uri') || 'http://localhost:3000/';
  const state = url.searchParams.get('state') || 'fake-state';
  const fragment = `state=${state}&session_state=fake-session-state&code=fake-auth-code`;

  await route.fulfill({
    status: 302,
    headers: { Location: `${redirectUri.split('#')[0]}#${fragment}` }
  });
});
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
  preferred_username: 'user@example.com',
  realm_access: { roles: ['user'] },
  resource_access: { 'client-id': { roles: ['admin'] } },
  scope: 'openid email profile',
};
```

### Auth Flow After Bypass

```
keycloak.init({ onLoad: 'login-required' })
  → Layer 2 intercepts auth redirect → returns 302 with fake code
  → Page reloads with #state=...&code=... in fragment
  → keycloak-js calls parseCallback() → reads nonce from localStorage (Layer 1 captures it)
  → keycloak-js POSTs to token endpoint → Layer 1 XHR mock returns tokens with nonce
  → init() resolves → ReactKeycloakProvider fires 'onAuthSuccess'
  → App queries GET_ME → GraphQL mock returns user fixture
  → setAuthData() populates permission evaluator
  → initialized=true, userAuthData=non-null → App renders
```

---

## 2. Apollo GraphQL Mocking

### Operation-Name Routing

```typescript
await page.route('**/api/graphql', async (route) => {
  const body = route.request().postDataJSON();
  const operationName = body?.operationName;

  if (operationName && operationName in fixtures) {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: JSON.stringify(fixtures[operationName])
    });
    return;
  }

  // CRITICAL: Fallback must return valid GraphQL response
  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    headers: { 'access-control-allow-origin': '*' },
    body: JSON.stringify({ data: null })
  });
});
```

### CORS Preflight Handler

```typescript
await page.route('**/api/graphql', async (route) => {
  if (route.request().method() === 'OPTIONS') {
    await route.fulfill({
      status: 204,
      headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, OPTIONS',
        'access-control-allow-headers': 'content-type, authorization',
      }
    });
    return;
  }
  await route.fallback(); // Chain to main handler
});
```

### Apollo InMemoryCache Rules

| Rule | Why | Consequence If Violated |
|------|-----|------------------------|
| `__typename` at every object level | Cache normalization key | Silent cache corruption |
| ALL query fields present | Cache write completeness | Other queries break (cascade) |
| `_id` on entities | `dataIdFromObject` | Cache misses, duplicate renders |
| Enum values exact match | Code uses strict equality | UI shows wrong state |

**The cascade failure pattern**: Missing field in Query A → partial cache write →
Query B reads same entity from corrupted cache → blank page with NO visible error.

Example: Missing `UserMessagesCount.all` broke the machines list page.

### Background Operations

Apps fire background queries on every page load. Common ones to mock:

| Operation | Critical Fields |
|-----------|----------------|
| `SystemNotifications` | `items: [], page: { totalElements, totalPages, ... }` |
| `UserMessagesCount` | ALL count fields (unread, all, unreadErrors, ...) |
| `PropertiesPrecisionSettings` | `measurementProperties: [], modelProperties: [], defaults: []` |
| `TechnicalUnits` | `technicalUnits: []` |

**Discovery**: Run test, check console for `[graphql-mock] No fixture for operation: "X"`.

---

## 3. Fixture Creation Checklist

- [ ] `__typename` at EVERY object level
- [ ] ALL fields from the GraphQL query included
- [ ] Deterministic IDs (`entity-e2e-001`, `entity-e2e-002`)
- [ ] Check source for `!.` non-null assertions on nullable fields — provide values
- [ ] User state matches expected enum value (e.g., `"VALID"` not `"ACTIVE"`)
- [ ] Permissions use format expected by evaluator (shiro-trie: `accessLevel: "*"` for admin)
- [ ] `ownerId` matches `company._id` (mapped to `tenantId` internally)
- [ ] Test incrementally — add one fixture, run, check console errors

---

## 4. MUI Component Selectors (Stability Ranked)

| Priority | Selector | Example | Notes |
|----------|----------|---------|-------|
| 1 | ID attribute | `#machine_cell`, `#save_btn` | Most stable |
| 2 | ARIA role + name | `getByRole('tab', { name: 'Settings' })` | Works for MUI tabs, buttons |
| 3 | Text content | `getByText('Machine Name')` | Stable with fixture data |
| 4 | Input value | `input[value="Current Value"]` | For MUI TextField (no name attr) |
| 5 | Scoped element+ID | `button[id="menuItem"]` | When ID shared across elements |
| 6 | CSS class | `[class*="MuiButton"]` | **Avoid** — breaks between builds |

### MUI Pitfalls

| Issue | Cause | Solution |
|-------|-------|---------|
| `getByLabel()` gets span not input | MUI label structure | Use `input[value="..."]` |
| `input[name="field"]` fails | MUI TextField omits name | Use `input[value="..."]` |
| Strict mode: 2 elements same ID | FAB + drawer share ID | Scope: `button[id="..."]` |
| Form fields not visible | Accordion collapsed | Click section header to expand |
| Cookie consent blocks clicks | Overlay on top | Dismiss early: `getByText('I AGREE').click()` |

---

## 5. Test Structure Template

```typescript
import { test, expect } from '@playwright/test';
import { bypassAuth } from '../mocks/auth-bypass';
import { mockGraphQL } from '../mocks/graphql';

test.describe('Feature Workflow', () => {
  test('complete workflow', async ({ page }) => {
    // Setup (MUST be before page.goto)
    await bypassAuth(page);
    await mockGraphQL(page);

    // Navigate
    await page.goto('/', { waitUntil: 'commit' });
    await page.waitForURL(/expected-path/, { timeout: 30_000 });
    await expect(page.locator('#app-top-bar').first()).toBeVisible({ timeout: 20_000 });

    // Dismiss overlays
    const cookie = page.getByText('I AGREE');
    if (await cookie.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await cookie.click();
    }

    // Workflow steps + visual regression checkpoints
    await expect(page).toHaveScreenshot('checkpoint.png', {
      maxDiffPixelRatio: 0.05,
      threshold: 0.3,
      animations: 'disabled',
    });
  });
});
```

---

## 6. Debugging Playbook

| Symptom | Likely Cause | Debug Action |
|---------|-------------|--------------|
| Blank page after auth | Nonce mismatch in ID token | Check localStorage capture |
| Blank page after navigation | Missing fixture fields | Add `page.on('pageerror')` listener |
| Component crash (TypeError) | Non-null assertion on null field | Search source for `!.` on fixture nulls |
| Menu item not visible | Missing permission | Check `HasPermissions` component props |
| Screenshot diff > threshold | Timestamps, animations | Increase tolerance, add `animations: 'disabled'` |
| Unknown GraphQL operation | Background query not mocked | Check `[graphql-mock]` console logs |

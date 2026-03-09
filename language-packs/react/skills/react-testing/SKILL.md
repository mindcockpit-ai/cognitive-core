---
name: react-testing
description: "Modern React testing patterns with Vitest, React Testing Library, MSW v2, and Playwright. Covers component testing, hook testing, API mocking, and E2E patterns."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "React testing — Vitest, RTL, MSW, Playwright patterns."
---

# React Testing Patterns (2025-2026)

## Testing Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit/Integration | Vitest | Fast, TypeScript-native, Jest-compatible API |
| Component | React Testing Library | Behavior-driven, accessibility-first |
| API Mocking | MSW v2 | Network-level interception, reusable across layers |
| E2E | Playwright | Cross-browser, parallel, multi-tab |
| Coverage | v8 (via Vitest) | Built-in, fast |

## Vitest Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    css: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/**/*.test.*', 'src/**/*.spec.*', 'src/test/**'],
      thresholds: {
        branches: 70,
        functions: 70,
        lines: 70,
        statements: 70,
      },
    },
  },
});
```

```typescript
// src/test/setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';
import { server } from './mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => { cleanup(); server.resetHandlers(); });
afterAll(() => server.close());
```

## Component Testing

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import { Button } from './Button';

describe('Button', () => {
  it('renders children text', () => {
    render(<Button variant="primary">Click me</Button>);
    expect(screen.getByRole('button', { name: /click me/i })).toBeInTheDocument();
  });

  it('calls onClick when clicked', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    render(<Button variant="primary" onClick={onClick}>Click</Button>);

    await user.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('disables button when loading', () => {
    render(<Button variant="primary" isLoading>Submit</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('shows spinner when loading', () => {
    render(<Button variant="primary" isLoading>Submit</Button>);
    expect(screen.queryByText(/submit/i)).not.toBeInTheDocument();
    expect(screen.getByRole('status')).toBeInTheDocument(); // Spinner has role="status"
  });
});
```

### Testing Best Practices

1. **Query by role/label, not test-id**: `getByRole('button')` > `getByTestId('submit-btn')`
2. **Use `userEvent` over `fireEvent`**: `userEvent.setup()` simulates real user behavior
3. **Assert on visible output**: What the user sees, not implementation details
4. **No testing internal state**: Never assert on `useState` values directly
5. **One assertion per behavior**: Each `it()` tests one user-observable behavior

## Custom Hook Testing

```typescript
import { renderHook, act } from '@testing-library/react';
import { useToggle } from './useToggle';

describe('useToggle', () => {
  it('starts with initial value', () => {
    const { result } = renderHook(() => useToggle(false));
    expect(result.current[0]).toBe(false);
  });

  it('toggles value', () => {
    const { result } = renderHook(() => useToggle(false));
    act(() => result.current[1]());
    expect(result.current[0]).toBe(true);
  });
});
```

## API Mocking with MSW v2

```typescript
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';
import type { User } from '@/types';

const mockUsers: User[] = [
  { id: '1', name: 'Alice', email: 'alice@example.com', role: 'admin' },
  { id: '2', name: 'Bob', email: 'bob@example.com', role: 'user' },
];

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json(mockUsers);
  }),

  http.get('/api/users/:id', ({ params }) => {
    const user = mockUsers.find((u) => u.id === params.id);
    if (!user) return new HttpResponse(null, { status: 404 });
    return HttpResponse.json(user);
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: '3', ...body }, { status: 201 });
  }),
];

// src/test/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### Override handlers per test

```typescript
import { http, HttpResponse } from 'msw';
import { server } from '@/test/mocks/server';

it('shows error state when API fails', async () => {
  server.use(
    http.get('/api/users', () => new HttpResponse(null, { status: 500 })),
  );

  render(<UserList />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

## Testing with TanStack Query

```typescript
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render } from '@testing-library/react';

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  });
}

function renderWithQuery(ui: React.ReactElement) {
  const client = createTestQueryClient();
  return render(
    <QueryClientProvider client={client}>{ui}</QueryClientProvider>,
  );
}

// Usage
it('renders user list', async () => {
  renderWithQuery(<UserList />);
  expect(await screen.findByText('Alice')).toBeInTheDocument();
  expect(screen.getByText('Bob')).toBeInTheDocument();
});
```

## Playwright E2E

```typescript
// e2e/user-flow.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User management', () => {
  test('can create a new user', async ({ page }) => {
    await page.goto('/users');
    await page.getByRole('button', { name: /add user/i }).click();
    await page.getByLabel('Name').fill('Charlie');
    await page.getByLabel('Email').fill('charlie@example.com');
    await page.getByRole('button', { name: /save/i }).click();

    await expect(page.getByText('Charlie')).toBeVisible();
  });

  test('shows validation error for empty name', async ({ page }) => {
    await page.goto('/users/new');
    await page.getByRole('button', { name: /save/i }).click();

    await expect(page.getByText(/name is required/i)).toBeVisible();
  });
});
```

## Legacy Test Migration Guide

| Legacy Pattern | Modern Replacement |
|---------------|-------------------|
| Jest | Vitest (same API, drop-in replacement) |
| Enzyme `shallow()` | RTL `render()` |
| Enzyme `find('.class')` | RTL `getByRole()`, `getByText()` |
| Enzyme `instance()` | Remove — test behavior, not internals |
| Enzyme `setState()` | `userEvent` to trigger state changes via UI |
| `jest.mock()` for API | MSW handlers |
| `__tests__/` directory | Colocate `*.test.tsx` next to source |
| `*.spec.tsx` naming | `*.test.tsx` (Vitest convention) |
| Snapshot tests | Avoid — test behavior instead |
| `act()` warnings | Use `userEvent.setup()` and `findBy*` queries |

## Anti-Patterns in Tests

1. **Testing implementation details**: Asserting on internal state, private methods, or CSS classes
2. **Snapshot overuse**: Snapshots break on every UI change and are rubber-stamped
3. **Not awaiting async**: Using `getBy*` instead of `findBy*` for async content
4. **Mocking too much**: Mock at the network layer (MSW), not at the module layer
5. **No error path tests**: Only testing happy paths, ignoring loading/error states
6. **Test IDs everywhere**: `data-testid` should be a last resort, not the default query

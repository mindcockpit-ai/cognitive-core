---
name: angular-testing
description: "Angular testing patterns with Jest/Vitest, Angular CDK test harnesses, Playwright E2E, and HttpTestingController. Component testing, service testing, signal testing, and async pattern testing."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Angular testing — Jest, CDK harnesses, Playwright, service mocking."
---

# Angular Testing Patterns (v18-20)

## Testing Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit/Integration | Jest or Vitest | Fast, TypeScript-native |
| Component | Angular TestBed + CDK Harnesses | Framework-aware component testing |
| HTTP Mocking | HttpTestingController | Angular-native HTTP mock |
| API Mocking | MSW v2 | Network-level interception, realistic |
| E2E | Playwright | Cross-browser, parallel, visual regression |
| Coverage | Jest (--coverage) or Istanbul | Built-in coverage reporting |

## Jest Configuration for Angular

```typescript
// jest.config.ts
import type { Config } from 'jest';

const config: Config = {
  preset: 'jest-preset-angular',
  setupFilesAfterSetup: ['<rootDir>/setup-jest.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/dist/', '/e2e/'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.module.ts',
    '!src/main.ts',
    '!src/environments/**',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
};

export default config;
```

```typescript
// setup-jest.ts
import 'jest-preset-angular/setup-jest';
```

## Component Testing

### Standalone Component (Modern Pattern)

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { UserCardComponent } from './user-card.component';

describe('UserCardComponent', () => {
  let component: UserCardComponent;
  let fixture: ComponentFixture<UserCardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent], // Standalone: import component directly
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
  });

  it('should display user name', () => {
    fixture.componentRef.setInput('name', 'Alice');
    fixture.componentRef.setInput('id', 'user-1');
    fixture.detectChanges();

    const el = fixture.nativeElement as HTMLElement;
    expect(el.textContent).toContain('Alice');
  });

  it('should emit edit event with user id', () => {
    fixture.componentRef.setInput('id', 'user-1');
    fixture.componentRef.setInput('name', 'Alice');
    fixture.detectChanges();

    const editSpy = jest.fn();
    component.edit.subscribe(editSpy);

    const button = fixture.nativeElement.querySelector('button');
    button.click();

    expect(editSpy).toHaveBeenCalledWith('user-1');
  });
});
```

### Testing Signal-Based Components

```typescript
describe('FilterComponent', () => {
  let component: FilterComponent;
  let fixture: ComponentFixture<FilterComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FilterComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(FilterComponent);
    component = fixture.componentInstance;
  });

  it('should compute filtered items from signal', () => {
    const items: Item[] = [
      { id: '1', name: 'Alpha' },
      { id: '2', name: 'Beta' },
      { id: '3', name: 'Gamma' },
    ];

    fixture.componentRef.setInput('items', items);
    fixture.detectChanges();

    // Set search term via signal
    component.searchTerm.set('alph');
    fixture.detectChanges();

    expect(component.filteredItems()).toEqual([{ id: '1', name: 'Alpha' }]);
  });

  it('should reset selected item when items change (linkedSignal)', () => {
    const items1 = [{ id: '1', name: 'First' }];
    const items2 = [{ id: '2', name: 'Second' }];

    fixture.componentRef.setInput('items', items1);
    fixture.detectChanges();
    expect(component.selectedItem()).toEqual(items1[0]);

    fixture.componentRef.setInput('items', items2);
    fixture.detectChanges();
    expect(component.selectedItem()).toEqual(items2[0]);
  });
});
```

### Testing with CDK Test Harnesses

```typescript
import { HarnessLoader } from '@angular/cdk/testing';
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';
import { MatButtonHarness } from '@angular/material/button/testing';
import { MatInputHarness } from '@angular/material/input/testing';
import { MatSelectHarness } from '@angular/material/select/testing';
import { MatTableHarness } from '@angular/material/table/testing';

describe('UserFormComponent', () => {
  let loader: HarnessLoader;
  let fixture: ComponentFixture<UserFormComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserFormComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserFormComponent);
    loader = TestbedHarnessEnvironment.loader(fixture);
    fixture.detectChanges();
  });

  it('should fill form and submit', async () => {
    const nameInput = await loader.getHarness(MatInputHarness.with({ selector: '#name' }));
    await nameInput.setValue('Alice');

    const roleSelect = await loader.getHarness(MatSelectHarness.with({ selector: '#role' }));
    await roleSelect.open();
    await roleSelect.clickOptions({ text: 'Admin' });

    const submitBtn = await loader.getHarness(MatButtonHarness.with({ text: 'Save' }));
    await submitBtn.click();

    expect(fixture.componentInstance.submitted()).toBe(true);
  });

  it('should display users in table', async () => {
    const table = await loader.getHarness(MatTableHarness);
    const rows = await table.getRows();
    expect(rows.length).toBe(3);

    const cells = await rows[0].getCells();
    const firstCell = await cells[0].getText();
    expect(firstCell).toBe('Alice');
  });
});
```

## Service Testing

### HttpTestingController (Angular Native)

```typescript
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { UserService } from './user.service';

describe('UserService', () => {
  let service: UserService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });

    service = TestBed.inject(UserService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify(); // Ensure no outstanding requests
  });

  it('should fetch users', () => {
    const mockUsers: User[] = [
      { id: '1', name: 'Alice', email: 'alice@example.com' },
    ];

    service.getUserById('1').subscribe(user => {
      expect(user).toEqual(mockUsers[0]);
    });

    const req = httpMock.expectOne('/api/users/1');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers[0]);
  });

  it('should handle 404 error', () => {
    service.getUserById('999').subscribe({
      error: (err) => {
        expect(err.status).toBe(404);
      },
    });

    const req = httpMock.expectOne('/api/users/999');
    req.flush('Not found', { status: 404, statusText: 'Not Found' });
  });
});
```

### Testing Services with Signals

```typescript
describe('CartService', () => {
  let service: CartService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(CartService);
  });

  it('should compute total from signal-based cart', () => {
    service.addItem({ id: '1', name: 'Widget', price: 10, qty: 2 });
    service.addItem({ id: '2', name: 'Gadget', price: 25, qty: 1 });

    expect(service.total()).toBe(45); // computed() signal
    expect(service.itemCount()).toBe(3);
  });
});
```

## Testing Async Patterns

### fakeAsync / tick

```typescript
it('should debounce search input', fakeAsync(() => {
  component.searchTerm.set('ang');
  tick(300); // Wait for debounce
  fixture.detectChanges();

  expect(component.searchResults().length).toBeGreaterThan(0);
}));
```

### Testing effect()

```typescript
it('should trigger side effect when signal changes', async () => {
  const logSpy = jest.spyOn(console, 'log');
  component.query.set('test');

  // effect() runs asynchronously — flush with fixture
  fixture.detectChanges();
  await fixture.whenStable();

  expect(logSpy).toHaveBeenCalledWith('Search triggered:', 'test');
}));
```

### Testing toSignal() / RxJS Interop

```typescript
it('should convert observable to signal', () => {
  // toSignal() subscribes immediately in injection context
  const service = TestBed.inject(DataService);

  // Flush the HTTP mock
  const req = httpMock.expectOne('/api/data');
  req.flush([{ id: '1', value: 'test' }]);

  // Signal should now have the value
  expect(service.data()).toEqual([{ id: '1', value: 'test' }]);
});
```

## Playwright E2E Patterns for Angular

### Angular-Specific Wait Strategies

```typescript
import { test, expect } from '@playwright/test';

test.describe('Dashboard', () => {
  test('should load dashboard data', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for Angular to stabilize (no pending HTTP/timers)
    await page.waitForFunction(() => {
      // Check if Angular has finished rendering
      const app = document.querySelector('app-root');
      return app && app.children.length > 0;
    });

    // Wait for specific content
    await expect(page.locator('app-dashboard h1')).toContainText('Dashboard');
    await expect(page.locator('app-stats-card')).toHaveCount(4);
  });
});
```

### Angular Router Navigation Testing

```typescript
test('should navigate via router links', async ({ page }) => {
  await page.goto('/');

  // Click navigation link
  await page.getByRole('link', { name: 'Users' }).click();

  // Wait for Angular router to complete navigation
  await page.waitForURL('**/users');
  await expect(page.locator('app-user-list')).toBeVisible();
});

test('should handle route guards', async ({ page }) => {
  // Direct navigation to protected route should redirect
  await page.goto('/admin');
  await page.waitForURL('**/login');

  expect(page.url()).toContain('/login');
});
```

### Angular Material Selectors for E2E

```typescript
test('should interact with Material components', async ({ page }) => {
  // Mat-select
  await page.locator('mat-select[formControlName="role"]').click();
  await page.locator('mat-option').filter({ hasText: 'Admin' }).click();

  // Mat-table row
  const rows = page.locator('mat-row');
  await expect(rows).toHaveCount(5);

  // Mat-dialog
  await page.getByRole('button', { name: 'Delete' }).click();
  await expect(page.locator('mat-dialog-container')).toBeVisible();
  await page.locator('mat-dialog-actions button').filter({ hasText: 'Confirm' }).click();
});
```

## Legacy Test Migration Guide

| Legacy Pattern | Modern Replacement |
|---------------|-------------------|
| Karma test runner | Jest with `jest-preset-angular` |
| Protractor E2E | Playwright |
| jasmine-marbles | Standard RxJS testing or `jest-marbles` |
| `TestBed.configureTestingModule({ declarations: [...] })` | `imports: [StandaloneComponent]` |
| `fixture.debugElement.query(By.css('.class'))` | `fixture.nativeElement.querySelector()` or CDK harness |
| `@angular/platform-browser-dynamic/testing` | Jest preset handles setup |
| `karma.conf.js` | `jest.config.ts` |
| `ng e2e` (Protractor) | `npx playwright test` |
| `waitForAsync()` wrapper | Standard `async/await` |
| `inject([Service], (svc) => {...})` | `TestBed.inject(Service)` |

## Anti-Patterns in Tests

1. **Testing implementation details**: Asserting on internal signal values instead of rendered output
2. **Over-mocking**: Using `jasmine.createSpyObj()` for everything instead of `HttpTestingController`
3. **Not testing signals reactivity**: Setting input but not calling `fixture.detectChanges()`
4. **Zone-dependent assertions**: Using `setTimeout` to wait for async instead of `fakeAsync`/`tick`
5. **No error path tests**: Only testing happy paths, ignoring HTTP errors and form validation
6. **Snapshot overuse**: Snapshots break on every template change; test behavior instead
7. **Missing `afterEach` cleanup**: Not calling `httpMock.verify()` to catch unexpected requests
8. **Testing private methods**: Access internals via public API (inputs, outputs, template assertions)

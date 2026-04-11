---
name: angular-patterns
description: "Version-aware Angular patterns (v18-21), anti-patterns, and legacy detection. Standalone components, signals, control flow, zoneless change detection, resource API, httpResource, signal forms, and inject() function."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Angular patterns — signals, standalone, control flow, zoneless, inject(), signal forms, legacy detection."
---

# Angular Patterns & Anti-Patterns (v18-21)

## Legacy Anti-Pattern Detection

When analyzing an Angular codebase, scan for these anti-patterns and quantify each category.

### Critical Anti-Patterns (Must Fix)

| Anti-Pattern | Detection | Modern Alternative | Since |
|-------------|-----------|-------------------|-------|
| NgModules for features | `@NgModule` in feature code | Standalone components with `imports` array | v14+ |
| `*ngIf` / `*ngFor` / `*ngSwitch` | Structural directives in templates | `@if`, `@for`, `@switch` built-in control flow | v17+ |
| `@Input()` / `@Output()` decorators | Decorator-based component I/O | `input()`, `input.required()`, `output()`, `model()` | v17+ |
| Constructor injection | `constructor(private svc: Service)` | `inject()` function | v14+ |
| Class-based interceptors | `implements HttpInterceptor` | `HttpInterceptorFn` with `withInterceptors()` | v15+ |
| `HttpClientModule` import | Module-based HTTP setup | `provideHttpClient()` in app config | v15+ |
| Untyped forms | `new FormGroup({})` without types | `NonNullableFormBuilder`, typed `FormControl<T>` | v14+ |
| `var` declarations | `\bvar\s` | `const` / `let` | always |
| jQuery in Angular | `$(.`, `jQuery` | Angular APIs, signals, templates | always |
| Protractor tests | `protractor` in package.json | Playwright or Cypress | v15+ |
| `entryComponents` | NgModule metadata | Remove — not needed since Ivy (v9+) | v9+ |
| `CommonModule` import | Importing for pipes/directives | Built-in control flow, standalone pipes | v17+ |

### Performance Anti-Patterns

| Anti-Pattern | Detection | Modern Alternative |
|-------------|-----------|-------------------|
| Default change detection | Missing `ChangeDetectionStrategy.OnPush` | Always use OnPush; prepares for zoneless |
| Manual `.subscribe()` leaks | `.subscribe(` without cleanup | `toSignal()`, `async` pipe, `takeUntilDestroyed()` |
| Zone.js-dependent patterns | `NgZone.run()`, `ChangeDetectorRef.detectChanges()` | Signals + OnPush (automatic), zoneless in v20+ |
| Eager module loading | `loadChildren` with static import | Lazy `loadComponent` with `@defer` blocks |
| RxJS overuse for simple state | `BehaviorSubject` for toggle/counter | `signal()` + `computed()` |
| Barrel files in features | `index.ts` re-exports | Direct imports (better tree-shaking) |
| Inline template styles | `styles: ['...']` with complex CSS | External `.scss` files, CSS-in-template only for simple overrides |

### Security Anti-Patterns

| Anti-Pattern | Detection | Fix |
|-------------|-----------|-----|
| `bypassSecurityTrustHtml` | DomSanitizer bypass | Sanitize properly or avoid `innerHTML` |
| Unvalidated API data | `HttpClient.get<T>()` trusted as runtime type | Zod/Valibot schema validation at boundary |
| Secrets in client code | `API_KEY`, `SECRET` in source | Environment variables via server-side proxy |
| Template injection | `[innerHTML]="userInput"` | Angular auto-sanitizes, but avoid where possible |
| CSRF unprotected | Missing `HttpXsrfInterceptor` | `provideHttpClient(withXsrfConfiguration(...))` |

#### Safe iframe srcdoc Pattern (bypassing Angular sanitizer)

Angular's sanitizer strips `srcdoc` from `<iframe>` elements. When the HTML source
is trusted (e.g., fetched from your own allowlisted proxy and processed client-side
via DOMParser), use `afterNextRender()` to set `srcdoc` directly on the DOM:

```typescript
// Signal holds the view state; pendingHtml is set before switching to 'display'
private pendingHtml = '';

// In the subscribe/effect that prepares the HTML:
this.pendingHtml = mergedHtml;
this.viewState.set('display');
this.cdr.markForCheck();

// Set srcdoc AFTER Angular renders the iframe element
afterNextRender(() => {
  const iframe = document.querySelector('iframe.my-iframe') as HTMLIFrameElement;
  if (null != iframe) {
    iframe.srcdoc = this.pendingHtml;
  }
  this.pendingHtml = ''; // Clear reference to allow GC
}, { injector: this.injector });
```

**When to use**: trusted HTML that Angular's sanitizer incorrectly strips (iframe srcdoc,
SVG with scripts, etc.) where the source is under your control.

**Requirements**:
- HTML must come from a trusted, controlled source (your proxy, not user input)
- Document the bypass justification in a code comment
- Use `sandbox` attribute on the iframe for defense in depth
- Clear `pendingHtml` after setting `srcdoc` to prevent memory leaks

## Version-Specific Patterns

### Angular 18 Patterns (June 2024)

Key features stabilized in v18:

```typescript
// Built-in control flow (stable)
@Component({
  template: `
    @if (user(); as u) {
      <h1>{{ u.name }}</h1>
    } @else {
      <app-skeleton />
    }

    @for (item of items(); track item.id) {
      <app-item [data]="item" />
    } @empty {
      <p>No items found</p>
    }

    @defer (on viewport) {
      <app-heavy-chart [data]="chartData()" />
    } @loading (minimum 200ms) {
      <app-spinner />
    }
  `
})
```

```typescript
// Signal inputs, outputs, model (developer preview → stable path)
@Component({
  selector: 'app-user-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DatePipe],
  template: `
    <div class="card">
      <h3>{{ name() }}</h3>
      <p>{{ createdAt() | date:'medium' }}</p>
      <button (click)="edit.emit(id())">Edit</button>
    </div>
  `
})
export class UserCardComponent {
  id = input.required<string>();
  name = input.required<string>();
  createdAt = input<Date>();
  edit = output<string>();
}
```

```typescript
// Route redirect as function
export const routes: Routes = [
  { path: '', redirectTo: (route) => '/dashboard', pathMatch: 'full' },
  { path: 'dashboard', loadComponent: () => import('./dashboard.component') },
];
```

### Angular 19 Patterns (November 2024)

Key changes: standalone by default, signal APIs stable, resource() API.

```typescript
// Standalone is now DEFAULT — no need for standalone: true
@Component({
  selector: 'app-dashboard',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterOutlet, NavBarComponent],
  template: `
    <app-nav-bar />
    <router-outlet />
  `
})
export class DashboardComponent {
  private readonly userService = inject(UserService);
  currentUser = this.userService.currentUser;
}
```

```typescript
// linkedSignal — derived signal that can be independently set
@Component({ /* ... */ })
export class FilterComponent {
  items = input.required<Item[]>();

  // Resets to first item whenever items() changes, but can be set independently
  selectedItem = linkedSignal(() => this.items()[0]);

  selectItem(item: Item) {
    this.selectedItem.set(item); // Overrides until items() changes
  }
}
```

```typescript
// resource() API — signal-based async data loading
@Component({ /* ... */ })
export class UserDetailComponent {
  userId = input.required<string>();

  userResource = resource({
    request: () => this.userId(),
    loader: async ({ request: id }) => {
      const res = await fetch(`/api/users/${id}`);
      return UserSchema.parse(await res.json());
    },
  });

  // Access via: userResource.value(), userResource.isLoading(), userResource.error()
}
```

```typescript
// rxResource — resource() with Observable loader (RxJS interop)
import { rxResource } from '@angular/core/rxjs-interop';

userResource = rxResource({
  request: () => this.userId(),
  loader: ({ request: id }) => this.http.get<User>(`/api/users/${id}`),
});
```

### Angular 20 Patterns (May 2025)

Key changes: `effect()` and `linkedSignal()` stable, `@angular/build` default, Vitest experimental, structural directives deprecated.

```typescript
// effect() — stable (graduated from developer preview)
@Component({ /* ... */ })
export class SearchComponent {
  query = signal('');
  private readonly searchService = inject(SearchService);

  constructor() {
    effect(() => {
      const q = this.query();
      if (q.length >= 3) {
        this.searchService.search(q); // Runs when query changes
      }
    });
  }
}
```

```typescript
// afterEveryRender() — renamed from afterRender() in v20
afterEveryRender(() => {
  const el = this.chartEl();
  if (el) {
    this.chartLib.render(el, this.data());
  }
});
```

```typescript
// httpResource() — experimental signal-based HttpClient wrapper
import { httpResource } from '@angular/common/http';

@Component({ /* ... */ })
export class UserDetailComponent {
  userId = input.required<string>();

  userResource = httpResource<User>({
    url: () => `/api/users/${this.userId()}`,
    parse: (raw) => UserSchema.parse(raw), // 'map' renamed to 'parse' in v20
  });
}
```

```typescript
// Zoneless change detection (developer preview — promoted from experimental)
export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(), // Replaces provideExperimentalZoneless()
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
  ],
};
// Remove zone.js from polyfills in angular.json
```

### Angular 21 Patterns (June 2025)

Key changes: zoneless stable, Vitest default, signal forms experimental, selectorless components.

```typescript
// Zoneless change detection — STABLE (Zone.js removed as default dependency)
export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(), // Fully stable
    provideRouter(routes),
    // HttpClient auto-provided in v21 (no provideHttpClient() needed unless passing options)
  ],
};
```

```typescript
// Signal forms — experimental (third form API alongside template-driven and reactive)
import { form, FormField, required, email } from '@angular/forms/experimental';

@Component({ /* ... */ })
export class ContactFormComponent {
  contactForm = form({
    name: new FormField('', { validators: [required] }),
    email: new FormField('', { validators: [required, email] }),
    message: new FormField(''),
  });

  submit() {
    if (this.contactForm.valid()) {
      console.log(this.contactForm.value());
    }
  }
}
```

```typescript
// Selectorless components — experimental (no selector needed)
@Component({
  template: `<h1>Hello {{ name() }}</h1>`,
})
export class Greeting {
  name = input.required<string>();
}

// Used by class name in parent template:
// <Greeting [name]="userName()" />
```

## Component Architecture

### Modern Component Template

```typescript
import { ChangeDetectionStrategy, Component, inject, input, output, signal, computed } from '@angular/core';

@Component({
  selector: 'app-user-list',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DatePipe, UserCardComponent],
  template: `
    @if (isLoading()) {
      <app-skeleton />
    } @else {
      <div class="user-list">
        @for (user of filteredUsers(); track user.id) {
          <app-user-card
            [id]="user.id"
            [name]="user.name"
            (edit)="onEdit($event)"
          />
        } @empty {
          <p>No users match "{{ searchTerm() }}"</p>
        }
      </div>
    }
  `
})
export class UserListComponent {
  // Inputs
  users = input.required<User[]>();
  isLoading = input(false);

  // Outputs
  edit = output<string>();

  // Local state
  searchTerm = signal('');

  // Derived state
  filteredUsers = computed(() =>
    this.users().filter(u =>
      u.name.toLowerCase().includes(this.searchTerm().toLowerCase())
    )
  );

  onEdit(userId: string) {
    this.edit.emit(userId);
  }
}
```

### Service Pattern

```typescript
import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);

  private readonly usersResponse = toSignal(
    this.http.get<User[]>('/api/users'),
    { initialValue: [] }
  );

  readonly users = computed(() => this.usersResponse());
  readonly userCount = computed(() => this.users().length);

  getUserById(id: string) {
    return this.http.get<User>(`/api/users/${id}`);
  }
}
```

## State Management Decision Matrix

| State Type | Solution | When |
|-----------|----------|------|
| Local UI state | `signal()` | Toggle, form input, dropdown open |
| Derived state | `computed()` | Filtered lists, formatted values |
| Component I/O | `input()` / `output()` / `model()` | Parent-child communication |
| Shared app state | NgRx SignalStore | Cross-component state, complex business logic |
| Server state | `resource()` / `rxResource()` | API data loading, caching |
| URL state | Angular Router | Filters, pagination, tabs |
| Form state | Typed reactive forms | Complex forms with validation |
| Simple shared state | Service with signals | Theme, sidebar, user preferences |

## Technical Debt Scoring

When analyzing a legacy Angular project, generate scores in these categories:

| Category | Weight | Measured By |
|----------|--------|------------|
| Type Safety | 20% | `strict: true`, `any` count, `@ts-ignore` count |
| Component Modernization | 25% | Standalone %, NgModule count, signals vs decorators |
| Control Flow | 15% | `@if/@for` vs `*ngIf/*ngFor`, `@defer` usage |
| DI Modernization | 10% | `inject()` vs constructor DI, functional interceptors |
| Testing | 15% | Test file ratio, Protractor vs Playwright, test harness usage |
| Tooling | 10% | Angular version, ESLint, OnPush adoption |
| RxJS Hygiene | 5% | Unmanaged subscribes, `toSignal()` usage |

Output format:
```
TECHNICAL DEBT REPORT: [Project Name]
=====================================
Overall Score: XX/100

Type Safety:              XX/20  (strict: yes|no, any: XX, @ts-ignore: XX)
Component Modernization:  XX/25  (standalone: XX%, NgModules: XX, signals: XX%)
Control Flow:             XX/15  (legacy directives: XX, @if/@for: XX, @defer: XX)
DI Modernization:         XX/10  (inject(): XX%, functional interceptors: XX%)
Testing:                  XX/15  (ratio: XX%, framework: karma|jest|vitest, e2e: protractor|playwright|cypress)
Tooling:                  XX/10  (angular: vXX, eslint: legacy|flat|none, OnPush: XX%)
RxJS Hygiene:             XX/5   (unmanaged .subscribe: XX, toSignal: XX)

Priority Migration Path:
1. [Highest impact item]
2. [Second highest]
3. ...
```

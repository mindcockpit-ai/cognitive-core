---
paths: ["**/*.ts", "**/*.html", "**/*.scss"]
---

# Angular Conventions (v21+)

## Architecture
- Standalone components only — no NgModules for features
- `inject()` function for all DI — no constructor injection in components/services
- Feature-based folder structure (`features/<name>/`)
- Functional interceptors (`HttpInterceptorFn`) — no class-based `HttpInterceptor`
- Functional guards and resolvers — no class-based
- Lazy loading with `loadComponent` / `loadChildren` in routes
- Bootstrap with `provideZonelessChangeDetection()` in `app.config.ts` — no zone.js (new projects; existing zone-based apps: migrate incrementally)

## Reactivity
- Signals for all local/shared state — `signal()`, `computed()`, `effect()`
- `linkedSignal()` for writable signals derived from other signals — do NOT use `effect()` for signal-to-signal sync
- RxJS only for streams (HTTP, WebSocket, complex async)
- No `BehaviorSubject` for simple state — use `signal()` instead
- Every `subscribe()` must have cleanup (`takeUntilDestroyed()` or `DestroyRef`)

## Components
- `ChangeDetectionStrategy.OnPush` on ALL components
- Use `input()` / `input.required()` — not `@Input` decorator
- Use `output()` — not `@Output` decorator
- Use `model()` for two-way binding — not paired `@Input` + `@Output(nameChange)`
- Use `viewChild()` / `viewChild.required()` / `viewChildren()` — not `@ViewChild` / `@ViewChildren`
- Use `contentChild()` / `contentChildren()` — not `@ContentChild` / `@ContentChildren`
- `@defer` blocks for below-fold content
- `host: {}` in decorator — no `@HostBinding` / `@HostListener`
- Template: `@if`, `@for`, `@switch` — no `*ngIf`, `*ngFor`, `*ngSwitch`
- `@for` must have `track` expression
- Template-only members: use `protected` — not `private`, not `public`

## Animations
- No `provideAnimations()` or `provideAnimationsAsync()` — both deprecated since v20.2, removed in v23
- Angular Material 21+ bootstraps its own animations internally — no app-level provider needed
- Custom animations: use `animate.enter` / `animate.leave` template directives (compiler-level, zero config)
- Tests: no animation provider in TestBed

## HTTP & API
- `provideHttpClient(withInterceptors([...]))` in `app.config.ts`
- Enable `withXsrf()` for cookie-based auth — omit only for stateless Bearer-token APIs
- Relative API URLs (`/api/...`) — no hardcoded hostnames
- `httpResource()` is in developer preview — do NOT use in production until Angular removes the preview label; use `HttpClient` + signals
- `provideHttpClientTesting()` in tests — not `HttpClientTestingModule`
- Every `HttpTestingController` test calls `httpMock.verify()` in afterEach

## Security
- No `bypassSecurityTrustHtml/Url/Script` — if required, use a dedicated sanitization pipe with tests and a `// SECURITY:` comment referencing the issue tracker
- No `innerHTML` binding with user-controlled data
- No `document.write()`, `eval()`, `new Function()`
- No secrets in `environment.ts` — use `InjectionToken` + runtime config

## IoC / DI
- `InjectionToken` for swappable services
- Implementations registered in `app.config.ts` via `{ provide: TOKEN, useClass: Impl }`

## Testing
- Test runner: Vitest via `@angular/build:unit-test` — not Karma, not Jest
- `provideZonelessChangeDetection()` in TestBed setup
- `provideHttpClientTesting()` for HTTP service tests
- Signal inputs in tests: use `fixture.componentRef.setInput()` — not direct property assignment
- One `fixture.detectChanges()` after signal updates — no loops
- `httpMock.verify()` in afterEach for every HTTP test

## Tailwind + Angular
- Never use Tailwind layout classes (`block`, `flex`, `grid`, `inline`, `hidden`) in component `host: { class: '...' }` — projects using `@import "tailwindcss" important` mark ALL utilities with `!important`, silently overriding `:host` styles in component SCSS
- Even without the `important` flag, mixing layout concerns between global utilities and `:host` styles is architecturally unclear
- Layout on `:host` must use the component SCSS `:host {}` block — not Tailwind classes

## Code Quality
- TypeScript `strict: true` + `strictTemplates: true` + `strictInjectionParameters: true`
- No `any` type — use `unknown` for uncertain types
- `===` / `!==` in templates (never `==` / `!=`)
- No `console.log` in production code
- Kebab-case file names (`user-profile.component.ts`)

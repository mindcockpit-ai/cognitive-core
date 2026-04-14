---
name: angular-migration
description: "Angular version upgrade paths from v17 through v21. Automated schematics guidance, breaking change detection, progressive migration strategies, zoneless adoption, and Vitest migration."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Angular migration — v17->v18->v19->v20->v21, schematics, breaking changes."
---

# Angular Migration Guide: v17 to v21

## Migration Assessment Framework

Before migrating, run a full project scan to quantify technical debt.

### Phase 0: Assessment

Run these scans to understand the project state:

```bash
# Angular version
grep '@angular/core' package.json

# NgModule count (target: 0-1 for modern apps)
grep -rn '@NgModule' src --include="*.ts" | grep -v node_modules | wc -l

# Legacy structural directives
grep -rn '\*ngIf\|\*ngFor\|\*ngSwitch' src --include="*.ts" --include="*.html" | grep -v node_modules | wc -l

# Decorator-based I/O vs signal-based
echo "Decorators:"; grep -rn '@Input(\|@Output(' src --include="*.ts" | grep -v node_modules | wc -l
echo "Signals:"; grep -rn 'input(\|output(\|model(' src --include="*.ts" | grep -v node_modules | wc -l

# Constructor injection vs inject()
echo "Constructor DI:"; grep -rn 'constructor(' src --include="*.ts" | grep -v node_modules | grep -v '.spec.ts' | wc -l
echo "inject():"; grep -rn 'inject(' src --include="*.ts" | grep -v node_modules | grep -v '.spec.ts' | wc -l

# Change detection strategy
echo "OnPush:"; grep -rn 'ChangeDetectionStrategy.OnPush' src --include="*.ts" | wc -l
echo "Total components:"; grep -rn '@Component' src --include="*.ts" | grep -v node_modules | wc -l

# Zone.js dependency
grep -rn 'zone.js' angular.json package.json src/polyfills.ts 2>/dev/null | wc -l

# Legacy HTTP
grep -rn 'HttpClientModule\|HttpModule' src --include="*.ts" | grep -v node_modules | wc -l

# Protractor
grep -c 'protractor' package.json

# Unmanaged subscribes
grep -rn '\.subscribe(' src --include="*.ts" | grep -v node_modules | grep -v '.spec.ts' | wc -l

# Test file ratio
echo "Tests:"; find src -name "*.spec.ts" | wc -l
echo "Sources:"; find src -name "*.ts" ! -name "*.spec.ts" ! -name "*.d.ts" ! -name "*.module.ts" | wc -l
```

### Output: Migration Readiness Matrix

```
ANGULAR MIGRATION READINESS REPORT
====================================
Project: [Name]
Current Version: v[XX]
Target Version: v[XX]

PATTERN INVENTORY:
  NgModules:              [X] files  (target: 0-1)
  Legacy directives:      [X] usages (target: 0)
  @Input/@Output:         [X] usages → input()/output()
  Constructor DI:         [X] usages → inject()
  Default change det.:    [X] components → OnPush
  Unmanaged .subscribe(): [X] usages → toSignal()/takeUntilDestroyed()
  Zone.js references:     [X] usages → zoneless (v20)

BLOCKERS:
  Protractor:             [yes|no]   → Must migrate to Playwright first
  HttpClientModule:       [yes|no]   → Must switch to provideHttpClient()
  CommonModule imports:   [X] files  → Remove, use built-in control flow

EFFORT ESTIMATION:
  Phase 1 (ng update):    [X] hours (automated schematics)
  Phase 2 (Manual fixes): [X] hours ([Y] files)
  Phase 3 (Modern APIs):  [X] hours (signals, inject, control flow)
  Phase 4 (Zoneless prep):[X] hours
  Total:                  [X] hours / [Y] developer-days
```

## v17 to v18 Upgrade

### Automated Steps

```bash
# Step 1: Update Angular CLI and Core
ng update @angular/core@18 @angular/cli@18

# Step 2: Update Angular Material (if used)
ng update @angular/material@18

# Step 3: Run control flow migration schematic (if not done in v17)
ng generate @angular/core:control-flow

# Step 4: Run standalone migration (if not done in v17)
ng generate @angular/core:standalone
```

### What v18 Schematics Do Automatically

| Schematic | What It Does |
|-----------|-------------|
| `@angular/core:control-flow` | Converts `*ngIf` → `@if`, `*ngFor` → `@for`, `*ngSwitch` → `@switch` |
| `@angular/core:standalone` | Converts NgModule components to standalone, updates imports |
| `ng update` | Updates RxJS, TypeScript, zone.js versions |

### Breaking Changes v17 → v18

| Change | Impact | Action |
|--------|--------|--------|
| `withComponentInputBinding()` required for route input binding | Medium | Add to `provideRouter()` |
| `@angular/platform-server` API changes | Low (SSR only) | Update server bootstrap |
| TypeScript 5.4 minimum | Low | Update TypeScript |
| Node.js 18.19+ minimum | Low | Update Node.js |

### Manual Migration Steps

```typescript
// 1. Signal inputs (opt-in in v18, automatic schematic coming)
// BEFORE:
@Input() name: string = '';
@Output() edit = new EventEmitter<string>();

// AFTER:
name = input('');
edit = output<string>();

// 2. inject() function (manual, no schematic)
// BEFORE:
constructor(
  private userService: UserService,
  private router: Router,
) {}

// AFTER:
private readonly userService = inject(UserService);
private readonly router = inject(Router);

// 3. Functional interceptors
// BEFORE:
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler) {
    const token = inject(AuthService).getToken();
    const authReq = req.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
    return next.handle(authReq);
  }
}
// providers: [{ provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true }]

// AFTER:
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(AuthService).getToken();
  const authReq = req.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
  return next(authReq);
};
// provideHttpClient(withInterceptors([authInterceptor]))
```

## v18 to v19 Upgrade

### Automated Steps

```bash
ng update @angular/core@19 @angular/cli@19
ng update @angular/material@19  # if used
```

### What Changes in v19

| Change | Impact | Action |
|--------|--------|--------|
| Standalone is default | Low | Remove `standalone: true` (optional, still valid) |
| Signal inputs/outputs stable | Medium | Migrate remaining `@Input/@Output` |
| `linkedSignal()` available | Low | Use for derived-but-settable state |
| `resource()` / `rxResource()` API | Medium | Replace manual data loading patterns |
| Angular Material M3 default | High (visual) | Review theme, may need `@use '@angular/material' as mat` updates |
| `provideExperimentalZoneless()` renamed | Low | Update if using zoneless preview |
| TypeScript 5.5+ minimum | Low | Update TypeScript |

### New APIs to Adopt

```typescript
// linkedSignal — derived signal that resets on dependency change
selectedTab = linkedSignal(() => this.tabs()[0]);

// resource() — signal-based data loading
userData = resource({
  request: () => this.userId(),
  loader: async ({ request: id }) => {
    const res = await fetch(`/api/users/${id}`);
    return UserSchema.parse(await res.json());
  },
});

// rxResource — observable-based variant
userData = rxResource({
  request: () => this.userId(),
  loader: ({ request: id }) => this.http.get<User>(`/api/users/${id}`),
});

// afterRenderEffect — replaces afterRender with signal tracking
afterRenderEffect(() => {
  const el = this.chartEl();
  if (el) {
    this.chartLib.render(el, this.data());
  }
});
```

### Breaking Changes v18 → v19

| Change | Impact | Action |
|--------|--------|--------|
| Karma deprecated (removal in v20) | High | Migrate to Jest or Vitest |
| `@angular/material` M3 theming default | Medium | Update theme files |
| Stricter `@defer` block timing | Low | Review lazy loading boundaries |
| `HttpClientModule` deprecated | Medium | Switch to `provideHttpClient()` |

## v19 to v20 Upgrade

### Automated Steps

```bash
ng update @angular/core@20 @angular/cli@20
ng update @angular/material@20  # if used
```

### What Changes in v20

| Change | Impact | Action |
|--------|--------|--------|
| Zoneless change detection stable | High | Remove zone.js, use `provideZonelessChangeDetection()` |
| Karma removed | High | Must use Jest or Vitest |
| Signal-based forms (experimental) | Medium | Start evaluation |
| `effect()` stable | Low | Remove experimental usage notes |
| Stricter standalone enforcement | Low | Remove any remaining NgModules |
| Node.js 20+ minimum | Low | Update Node.js |

### Zoneless Migration Guide

```typescript
// Step 1: Update app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(), // Was provideExperimentalZoneless()
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
    // No animation provider needed — deprecated v20.2, removed v23
    // Angular Material 21+ bootstraps animations internally
  ],
};

// Step 2: Remove zone.js from angular.json
// angular.json → projects.*.architect.build.options.polyfills
// Remove "zone.js" entry

// Step 3: Remove zone.js from package.json
// npm uninstall zone.js

// Step 4: Audit for zone-dependent patterns
// Search for patterns that won't work without Zone.js:
// - setTimeout/setInterval in components (use signals + effect() instead)
// - Manual ChangeDetectorRef.detectChanges() (remove, signals handle it)
// - NgZone.run() / NgZone.runOutsideAngular() (remove entirely)
// - Third-party libs that patch Zone.js (check compatibility)
```

### Breaking Changes v19 → v20

| Change | Impact | Action |
|--------|--------|--------|
| Karma support removed | High | Complete Jest/Vitest migration |
| Zone.js no longer bundled by default | Medium | Opt-in if needed, or go zoneless |
| `package.json` exports enforced | Low | Update import paths |
| Deprecated APIs removed | Medium | Fix deprecation warnings from v19 |

## Progressive Migration Strategy

### Phase 1: Tooling (Low Risk)

1. Run `ng update` to reach target version
2. Update ESLint to flat config with `@angular-eslint`
3. Migrate Karma → Jest (if not done)
4. Migrate Protractor → Playwright (if not done)
5. Enable TypeScript strict mode flags incrementally

### Phase 2: Component Modernization (Medium Risk)

1. Run standalone migration schematic
2. Run control flow migration schematic
3. Convert `@Input/@Output` → `input()/output()` (start with leaf components)
4. Convert constructor DI → `inject()` function
5. Add `ChangeDetectionStrategy.OnPush` to all components
6. Convert class interceptors → functional interceptors

### Phase 3: Signal Adoption (Medium Risk)

1. Replace `BehaviorSubject` simple state → `signal()`
2. Add `computed()` for derived state
3. Use `toSignal()` for observable-to-signal bridges
4. Add `takeUntilDestroyed()` to remaining subscribes
5. Adopt `resource()` / `rxResource()` for data loading (v19+)

### Phase 4: Zoneless Preparation (High Risk — v20)

1. Ensure 100% OnPush adoption
2. Remove all `NgZone.run()` calls
3. Remove all `ChangeDetectorRef.detectChanges()` calls
4. Replace `setTimeout`/`setInterval` with signals + effect()
5. Test with `provideExperimentalZoneless()` before going fully zoneless
6. Verify third-party library compatibility

## Tracking Progress

```markdown
## Angular Migration Progress (v[X] → v[Y])

| Phase | Task | Files | Done | % | Status |
|-------|------|-------|------|---|--------|
| 1 | ng update | - | - | 100% | Done |
| 1 | ESLint flat config | 1 | 1 | 100% | Done |
| 1 | Karma → Jest | 5 | 3 | 60% | In Progress |
| 2 | Standalone migration | 45 | 45 | 100% | Done |
| 2 | Control flow migration | 30 | 20 | 67% | In Progress |
| 2 | inject() conversion | 25 | 10 | 40% | In Progress |
| 2 | OnPush adoption | 45 | 30 | 67% | In Progress |
| 3 | Signal adoption | 15 | 5 | 33% | Planned |
| 3 | toSignal() bridges | 10 | 0 | 0% | Planned |
| 4 | Zoneless audit | - | - | 0% | Planned |
```

## v20 to v21 Upgrade

### Automated Steps

```bash
ng update @angular/core@21 @angular/cli@21
ng update @angular/material@21  # if used
```

### What Changes in v21

| Change | Impact | Action |
|--------|--------|--------|
| Zoneless change detection stable | High | Remove Zone.js dependency entirely |
| Vitest is default test runner | High | Complete migration from Jest/Karma to Vitest |
| HttpClient auto-provided | Low | Remove `provideHttpClient()` unless passing options |
| Signal forms experimental | Low | Start evaluating for new forms |
| Selectorless components experimental | Low | Optional adoption for new components |
| Jest deprecated | Medium | Migrate to Vitest |
| Web Test Runner deprecated | Low | Switch to Vitest |
| Zone.js removed as default dep | High | Projects still needing Zone.js must add it manually |

### Breaking Changes v20 → v21

| Change | Impact | Action |
|--------|--------|--------|
| Zone.js not included by default | High | Add `zone.js` to package.json if not zoneless-ready |
| Vitest replaces Karma/Jest in new projects | Medium | Update test configuration |
| `@angular/platform-browser-dynamic` removed | Medium | Use `bootstrapApplication()` |

## Common Migration Pitfalls

1. **Big bang update**: Don't skip versions (v17→v21). Go v17→v18→v19→v20→v21 sequentially
2. **Running schematics out of order**: Run `standalone` before `control-flow` to avoid conflicts
3. **Ignoring deprecation warnings**: Fix all deprecations at each version before upgrading further
4. **Zoneless without OnPush**: Components without OnPush will not update without Zone.js
5. **Third-party Zone.js dependencies**: Libraries like FullCalendar, ag-Grid may need Zone.js compatibility mode
6. **Material theme breaking**: M3 default in v19 changes visual appearance significantly
7. **Not updating test infrastructure**: Karma removed in v20, Jest deprecated in v21 — migrate to Vitest
8. **Skipping `ng update` schematics**: The CLI schematics handle many breaking changes automatically
9. **`afterRender()` renamed in v20**: Changed to `afterEveryRender()` — no automatic migration schematic
10. **`@angular/build` replaces `@angular-devkit/build-angular`** in v20: saves ~200MB but may break third-party builders

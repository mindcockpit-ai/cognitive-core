## Angular Critical Rules (Post-Compaction)

1. **TypeScript Strict Mode**: Enable `strict: true` + `strictTemplates: true` in `angularCompilerOptions`. No `any` without justification.
2. **Standalone Components Only**: No NgModules for feature components. Use `standalone: true` (v18) or default standalone (v19+). Direct `imports` array on the component.
3. **Built-in Control Flow**: Use `@if`, `@for`, `@switch`, `@defer` syntax. No `*ngIf`, `*ngFor`, `*ngSwitch` structural directives.
4. **Signals Over Decorators**: Use `signal()`, `computed()`, `input()`, `input.required()`, `output()`, `model()` over `@Input()`, `@Output()` decorators. Use `toSignal()` for RxJS interop.
5. **inject() Function**: Use `inject()` instead of constructor injection for all dependencies in components and services.
6. **OnPush Change Detection**: All components must use `ChangeDetectionStrategy.OnPush`. Prepares for zoneless (v20+).
7. **No Manual Subscribe Leaks**: Use `toSignal()`, `async` pipe, or `firstValueFrom()`. Every `.subscribe()` must have `takeUntilDestroyed()` or `DestroyRef` cleanup.
8. **Functional Interceptors**: Use `HttpInterceptorFn` with `provideHttpClient(withInterceptors([...]))`. No class-based `HttpInterceptor`.
9. **Typed Reactive Forms**: Use `NonNullableFormBuilder`. No untyped `FormGroup`/`FormControl` constructors.
10. **Runtime Validation at Boundaries**: Use Zod/Valibot for API response validation. Never trust `HttpClient` generics as runtime guarantees.
11. **ESLint with Angular Plugin**: Use `@angular-eslint` with ESLint 9 flat config. No legacy `.eslintrc`.
12. **Test Colocation**: Place `.spec.ts` files next to their source. Use Angular CDK test harnesses for Material component testing.

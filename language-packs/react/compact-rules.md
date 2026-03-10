## React/TypeScript Critical Rules (Post-Compaction)

1. **TypeScript Strict Mode**: Enable `strict: true` + `noUncheckedIndexedAccess: true` in tsconfig.json. All props, state, and context must have explicit types. No `any` without justification.
2. **Functional Components Only**: No class components. Use function declarations with typed props. Hooks for all state and lifecycle logic.
3. **React Compiler Compatibility**: No manual `useMemo`, `useCallback`, or `React.memo` in new code. React Compiler v1.0 handles memoization automatically. Keep components pure.
4. **No useEffect for Data Fetching**: Use TanStack Query, SWR, or React 19 `use()` for data loading. useEffect is for synchronization with external systems only.
5. **Runtime Type Validation**: TypeScript types are erased at runtime. Use Zod/Valibot for API boundary validation. Never trust `JSON.parse()` or external data without schema validation.
6. **ESLint 9 Flat Config**: Use `eslint.config.mjs` only. No legacy `.eslintrc`. Enable `react-hooks/exhaustive-deps` as error.
7. **No Barrel Files**: No `index.ts` re-exports in application code. Direct imports only. Barrel files break tree-shaking and inflate bundles.
8. **Test Colocation**: Place `*.test.tsx` files next to their source component, not in a separate `__tests__` directory.
9. **Error Boundaries + Suspense**: Every async data boundary needs both `<ErrorBoundary>` and `<Suspense>`. Never let errors propagate unhandled.
10. **Accessibility**: All interactive elements must be keyboard-navigable. Use semantic HTML. Run eslint-plugin-jsx-a11y.
11. **E2E Auth Bypass**: For Keycloak-protected apps, use two-layer bypass (addInitScript for XHR/WS + page.route for redirects). Capture PKCE nonce from localStorage.
12. **E2E Fixture Completeness**: Apollo InMemoryCache requires `__typename` at every object level. Missing fields cause silent cascade failures across unrelated queries.

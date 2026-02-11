## Node.js/TypeScript Critical Rules (Post-Compaction)

1. **TypeScript Strict Mode**: Enable `strict: true` in tsconfig.json. All public APIs must have explicit types. No `any` without justification.
2. **Async/Await Over Callbacks**: Use async/await for all asynchronous operations. No callback-based patterns for new code. Always handle Promise rejections.
3. **const Over let**: Use `const` by default. Only use `let` when reassignment is necessary. Never use `var`.
4. **Error Handling**: Always catch specific errors. Never swallow errors silently. Use custom error classes for domain errors.
5. **Module Imports**: Use ES modules (`import`/`export`). No `require()` in TypeScript. Named exports over default exports. Barrel files (`index.ts`) for public APIs only.

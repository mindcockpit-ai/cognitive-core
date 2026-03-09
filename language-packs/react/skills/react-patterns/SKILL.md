---
name: react-patterns
description: "Modern React/TypeScript patterns, anti-patterns, and legacy code detection. Component architecture, hooks, state management, data fetching, error handling, and React Compiler compatibility."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "React patterns — hooks, state, data fetching, error boundaries, legacy detection."
---

# React/TypeScript Patterns & Anti-Patterns

## Legacy Anti-Pattern Detection

When analyzing a React codebase, scan for these anti-patterns and quantify each category.

### Critical Anti-Patterns (Must Fix)

| Anti-Pattern | Detection | Modern Alternative |
|-------------|-----------|-------------------|
| Class components | `extends Component`, `extends PureComponent` | Functional components + hooks |
| PropTypes | `PropTypes.`, `.propTypes =` | TypeScript interfaces/types |
| `var` declarations | `\bvar\s` | `const` / `let` |
| jQuery in React | `$(.`, `jQuery` | React refs, state, events |
| Direct DOM manipulation | `document.getElementById`, `.innerHTML` | React refs (`useRef`) |
| String refs | `ref="myRef"` | `useRef()` / callback refs |
| Legacy context API | `contextTypes`, `childContextTypes` | `createContext` + `useContext` |
| Mixins | `mixins: [` | Custom hooks / composition |
| `componentWillMount` | Deprecated lifecycle | `useEffect` or remove |
| `componentWillReceiveProps` | Deprecated lifecycle | `useEffect` with deps |
| `componentWillUpdate` | Deprecated lifecycle | `useEffect` or `getSnapshotBeforeUpdate` |
| `findDOMNode` | `ReactDOM.findDOMNode` | `useRef()` |
| `createReactClass` | Pre-ES6 pattern | Function components |
| Default exports | `export default` | Named exports (better tree-shaking) |

### Performance Anti-Patterns

| Anti-Pattern | Detection | Modern Alternative |
|-------------|-----------|-------------------|
| useEffect for data fetching | `useEffect.*fetch\|axios` | TanStack Query / SWR / `use()` |
| Manual memoization | `useMemo`, `useCallback`, `React.memo` | React Compiler v1.0 (auto-memoizes) |
| Barrel files | `index.ts` with `export.*from` | Direct imports |
| Inline object creation in JSX | `style={{`, `<Comp data={{` | Extract to const or CSS modules |
| Missing keys in lists | `.map(` without `key=` | Add stable `key` prop |
| State for derived data | `useState` + `useEffect` to compute | Compute during render or `useMemo` |
| Prop drilling (>3 levels) | Props passed through intermediaries | Context, Zustand, or composition |
| Giant components (>300 lines) | Large single-file components | Extract sub-components and hooks |

### Security Anti-Patterns

| Anti-Pattern | Detection | Fix |
|-------------|-----------|-----|
| `dangerouslySetInnerHTML` | Direct string injection | DOMPurify sanitization or avoid |
| Unvalidated API data | `fetch().then(r => r.json())` | Zod/Valibot schema validation |
| Secrets in client code | `API_KEY`, `SECRET` in source | Environment variables, server-side proxy |
| `eval()` or `new Function()` | Dynamic code execution | Avoid completely |
| `target="_blank"` without `rel` | Missing `rel="noopener"` | Add `rel="noopener noreferrer"` |

## Modern Patterns

### Component Architecture

```typescript
// Props with TypeScript — use interface for extendable, type for fixed
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  children: React.ReactNode;
  onClick?: (event: React.MouseEvent<HTMLButtonElement>) => void;
}

// Named export, function declaration (hoisted, better stack traces)
export function Button({ variant, size = 'md', isLoading, children, onClick }: ButtonProps) {
  return (
    <button
      className={clsx(styles.button, styles[variant], styles[size])}
      disabled={isLoading}
      onClick={onClick}
    >
      {isLoading ? <Spinner /> : children}
    </button>
  );
}
```

### Custom Hooks Pattern

```typescript
// Encapsulate logic, return typed tuple or object
function useToggle(initial = false): [boolean, () => void] {
  const [value, setValue] = useState(initial);
  const toggle = () => setValue((v) => !v);  // React Compiler optimizes this
  return [value, toggle];
}

// Domain hook — encapsulates API + state
function useUser(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),  // validated with Zod inside fetchUser
    staleTime: 5 * 60 * 1000,
  });
}
```

### Data Fetching (TanStack Query)

```typescript
// Never use useEffect for data fetching
// BAD:
useEffect(() => {
  fetch('/api/users').then(r => r.json()).then(setUsers);
}, []);

// GOOD:
const { data: users, isLoading, error } = useQuery({
  queryKey: ['users'],
  queryFn: async () => {
    const res = await fetch('/api/users');
    return UserListSchema.parse(await res.json());  // Zod runtime validation
  },
});

// Mutations
const createUser = useMutation({
  mutationFn: (newUser: CreateUserInput) => api.post('/users', newUser),
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
});
```

### Error Boundaries + Suspense

```typescript
// Every async boundary needs both
<ErrorBoundary fallback={<ErrorMessage />}>
  <Suspense fallback={<Skeleton />}>
    <UserProfile userId={id} />
  </Suspense>
</ErrorBoundary>

// react-error-boundary library (recommended)
import { ErrorBoundary } from 'react-error-boundary';

function ErrorFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div role="alert">
      <p>Something went wrong:</p>
      <pre>{error.message}</pre>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  );
}
```

### State Management Decision Matrix

| State Type | Solution | When |
|-----------|----------|------|
| Local UI state | `useState` | Toggle, form input, dropdown open |
| Shared UI state | Zustand store | Theme, sidebar, modal stack |
| Server state | TanStack Query | API data, caching, refetching |
| URL state | React Router / nuqs | Filters, pagination, tabs |
| Form state | React Hook Form + Zod | Complex forms with validation |
| Complex local | `useReducer` | State machine, multiple related values |

### Runtime Type Validation

```typescript
import { z } from 'zod';

// Define schema ONCE — serves as both type AND runtime validator
const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'viewer']),
  createdAt: z.string().datetime(),
});

type User = z.infer<typeof UserSchema>;  // TypeScript type derived from schema

// Use at API boundary
async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  const data: unknown = await res.json();  // unknown, not any
  return UserSchema.parse(data);  // throws ZodError if invalid
}
```

## Technical Debt Scoring

When analyzing a legacy project, generate scores in these categories:

| Category | Weight | Measured By |
|----------|--------|------------|
| Type Safety | 25% | TS adoption %, `any` count, `@ts-ignore` count |
| Component Modernization | 20% | Class vs functional, PropTypes vs TS interfaces |
| Data Fetching | 15% | useEffect+fetch vs TanStack Query/SWR |
| Testing | 15% | Test file ratio, testing library used |
| Build Tooling | 10% | CRA vs Vite/Next, ESLint version, TS strict |
| Bundle Hygiene | 10% | Barrel files, tree-shaking blockers, bundle size |
| Accessibility | 5% | jsx-a11y violations, semantic HTML usage |

Output format:
```
TECHNICAL DEBT REPORT: [Project Name]
=====================================
Overall Score: XX/100

Type Safety:              XX/25  (TS: XX%, any: XX, @ts-ignore: XX)
Component Modernization:  XX/20  (class: XX, PropTypes: XX, deprecated lifecycle: XX)
Data Fetching:            XX/15  (useEffect+fetch: XX, proper: XX)
Testing:                  XX/15  (ratio: XX%, framework: jest|vitest|none)
Build Tooling:            XX/10  (build: cra|vite|next, eslint: legacy|flat|none, strict: yes|no)
Bundle Hygiene:           XX/10  (barrels: XX, inline styles: XX)
Accessibility:            XX/5   (a11y plugin: yes|no, semantic: XX%)

Priority Migration Path:
1. [Highest impact item]
2. [Second highest]
3. ...
```

---
name: react-migration
description: "JavaScript to TypeScript migration guide for React projects. Progressive typing strategy, legacy pattern replacement, build tool modernization, and automated migration tooling."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "JS→TS migration — progressive typing, legacy replacement, build modernization."
---

# React Migration Guide: Legacy JS to Modern TypeScript

## Migration Assessment Framework

Before migrating, run a full project scan to quantify technical debt. Use the fitness-checks.sh and react-patterns skill to generate a baseline report.

### Phase 0: Assessment (1-2 days)

Run these scans to understand the project state:

```bash
# File type distribution
find src -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn

# Class component count
grep -rn 'extends Component\|extends PureComponent' src --include="*.js" --include="*.jsx" | wc -l

# PropTypes usage
grep -rn 'PropTypes\.\|\.propTypes' src --include="*.js" --include="*.jsx" | wc -l

# jQuery usage
grep -rn '\$(\|jQuery' src --include="*.js" --include="*.jsx" | wc -l

# Direct DOM manipulation
grep -rn 'document\.getElementById\|document\.querySelector\|\.innerHTML' src --include="*.js" --include="*.jsx" | wc -l

# useEffect data fetching
grep -rn 'useEffect.*fetch\|useEffect.*axios' src --include="*.js" --include="*.jsx" | wc -l

# var usage
grep -rn '\bvar\s' src --include="*.js" --include="*.jsx" | wc -l

# console.log in production
grep -rn 'console\.\(log\|debug\)' src --include="*.js" --include="*.jsx" | grep -v test | grep -v spec | wc -l

# Test file count
find src -name "*.test.*" -o -name "*.spec.*" | wc -l

# Component file count
find src -name "*.jsx" -o -name "*.js" | grep -v test | grep -v spec | grep -v config | wc -l
```

### Output: Migration Readiness Matrix

```
MIGRATION READINESS REPORT
===========================
Project: [Name]
Files: [X] total ([Y] JS, [Z] JSX, [W] TS/TSX)
Components: [X] (class: [Y], functional: [Z])

BLOCKER ASSESSMENT:
  jQuery dependency:    [X] files  → Must eliminate before TS migration
  Direct DOM access:    [X] files  → Convert to refs
  Global state (window): [X] files → Refactor to context/store
  CommonJS require():   [X] files  → Convert to ES imports

EFFORT ESTIMATION:
  Phase 1 (TS setup):     [X] hours
  Phase 2 (Rename files): [X] hours (automated)
  Phase 3 (Add types):    [X] hours ([Y] files)
  Phase 4 (Strict mode):  [X] hours
  Total:                  [X] hours / [Y] developer-days
```

## Phase 1: Foundation (No Code Changes)

### 1.1 Add TypeScript to existing project

```bash
npm install -D typescript @types/react @types/react-dom
```

### 1.2 Create tsconfig.json (permissive start)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "allowJs": true,
    "checkJs": false,
    "strict": false,
    "noEmit": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "build"]
}
```

Key: `allowJs: true` and `strict: false` — TypeScript coexists with JavaScript.

### 1.3 Add type-check script

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "typecheck:watch": "tsc --noEmit --watch"
  }
}
```

## Phase 2: Progressive File Conversion

### Priority Order (highest value first)

1. **Shared types/models** — Create `src/types/` with all domain types
2. **API layer** — Type API responses with Zod schemas
3. **Custom hooks** — Small files, high reuse, clear inputs/outputs
4. **Utility functions** — Pure functions, easy to type
5. **UI components** (leaf first) — Buttons, inputs, cards
6. **Container components** — Pages, layouts with data fetching
7. **Tests** — Convert alongside their source files

### 2.1 Rename files (automated)

```bash
# Rename one file at a time, fix imports, run tests
# Start with leaf components (no dependencies)
mv src/components/Button.jsx src/components/Button.tsx
```

### 2.2 Type component props

```typescript
// BEFORE (JavaScript + PropTypes)
import PropTypes from 'prop-types';

function UserCard({ user, onEdit, onDelete }) {
  return (
    <div className="card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      <button onClick={() => onEdit(user.id)}>Edit</button>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </div>
  );
}

UserCard.propTypes = {
  user: PropTypes.shape({
    id: PropTypes.string.isRequired,
    name: PropTypes.string.isRequired,
    email: PropTypes.string.isRequired,
  }).isRequired,
  onEdit: PropTypes.func.isRequired,
  onDelete: PropTypes.func.isRequired,
};

// AFTER (TypeScript)
interface User {
  id: string;
  name: string;
  email: string;
}

interface UserCardProps {
  user: User;
  onEdit: (userId: string) => void;
  onDelete: (userId: string) => void;
}

export function UserCard({ user, onEdit, onDelete }: UserCardProps) {
  return (
    <div className="card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      <button onClick={() => onEdit(user.id)}>Edit</button>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </div>
  );
}
```

### 2.3 Type API responses

```typescript
// BEFORE: Untyped fetch
const fetchUsers = async () => {
  const res = await fetch('/api/users');
  return res.json();  // Returns any — no safety
};

// AFTER: Zod-validated
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
  role: z.enum(['admin', 'user']),
});

const UserListSchema = z.array(UserSchema);
type User = z.infer<typeof UserSchema>;

const fetchUsers = async (): Promise<User[]> => {
  const res = await fetch('/api/users');
  const data: unknown = await res.json();
  return UserListSchema.parse(data);  // Runtime validated!
};
```

### 2.4 Convert class components to functional

```typescript
// BEFORE: Class component
class UserList extends React.Component {
  state = { users: [], loading: true, error: null };

  componentDidMount() {
    fetch('/api/users')
      .then(res => res.json())
      .then(users => this.setState({ users, loading: false }))
      .catch(error => this.setState({ error, loading: false }));
  }

  render() {
    const { users, loading, error } = this.state;
    if (loading) return <Spinner />;
    if (error) return <ErrorMessage error={error} />;
    return <ul>{users.map(u => <li key={u.id}>{u.name}</li>)}</ul>;
  }
}

// AFTER: Functional + TanStack Query
export function UserList() {
  const { data: users, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  });

  if (isLoading) return <Skeleton />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <ul>
      {users?.map((u) => <li key={u.id}>{u.name}</li>)}
    </ul>
  );
}
```

## Phase 3: Enable Strict Mode Incrementally

### 3.1 Strict mode flags (enable one at a time)

```json
{
  "compilerOptions": {
    "strict": false,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwayStrict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

Order of enablement:
1. `noImplicitAny` — Forces explicit types (highest impact)
2. `strictNullChecks` — Catches null/undefined bugs
3. `strictFunctionTypes` — Catches callback type mismatches
4. Enable remaining flags
5. Replace with `"strict": true`

### 3.2 Fix `any` types systematically

```typescript
// Common any patterns and their fixes:

// 1. Event handlers
// BAD:  onChange={(e: any) => setName(e.target.value)}
// GOOD:
onChange={(e: React.ChangeEvent<HTMLInputElement>) => setName(e.target.value)}

// 2. API responses
// BAD:  const data: any = await res.json()
// GOOD:
const data: unknown = await res.json();
const validated = UserSchema.parse(data);

// 3. Third-party libs without types
// BAD:  const lib: any = require('old-lib')
// GOOD: Create src/types/old-lib.d.ts
declare module 'old-lib' {
  export function doSomething(input: string): number;
}

// 4. Complex objects
// BAD:  const config: any = { ... }
// GOOD: Use satisfies for type-safe object literals
const config = {
  apiUrl: '/api',
  timeout: 5000,
  retries: 3,
} satisfies AppConfig;
```

## Phase 4: Build Tooling Modernization

### 4.1 CRA to Vite Migration

```bash
# 1. Install Vite
npm install -D vite @vitejs/plugin-react vite-tsconfig-paths

# 2. Create vite.config.ts
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  server: { port: 3000 },
});
EOF

# 3. Move index.html to root (CRA keeps it in public/)
mv public/index.html .
# Add <script type="module" src="/src/index.tsx"></script> before </body>

# 4. Update scripts
# "start": "vite",
# "build": "tsc && vite build",
# "preview": "vite preview"

# 5. Remove CRA
npm uninstall react-scripts
```

### 4.2 Jest to Vitest Migration

```bash
# 1. Install
npm install -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom

# 2. Global replacements (mostly compatible)
# jest.fn() → vi.fn()
# jest.mock() → vi.mock()
# jest.spyOn() → vi.spyOn()
# jest.useFakeTimers() → vi.useFakeTimers()

# 3. Update imports in test files
# Remove: import { render } from '@testing-library/react'  (same)
# Change: import { vi } from 'vitest'  (instead of jest global)
```

### 4.3 ESLint Legacy to Flat Config

```bash
# 1. Install modern plugins
npm install -D eslint @eslint/js typescript-eslint eslint-plugin-react eslint-plugin-react-hooks eslint-plugin-jsx-a11y

# 2. Delete legacy config
rm .eslintrc.json  # or .eslintrc.js / .eslintrc.yml

# 3. Create eslint.config.mjs (see lint-config.sh for template)
```

## Common Migration Pitfalls

1. **Big bang rename**: Don't rename all `.js` → `.tsx` at once. Go file-by-file, fix types, run tests
2. **Overusing `as` type assertions**: `data as User` is unsafe. Use Zod validation instead
3. **Ignoring `strict: false` forever**: Set a deadline to enable strict mode. Use `// @ts-expect-error` with TODO comments for temporary workarounds
4. **Not typing events**: `(e: any)` → use `React.ChangeEvent<HTMLInputElement>`, `React.FormEvent<HTMLFormElement>`, etc.
5. **Forgetting declaration files**: Old JS libraries need `.d.ts` files. Check DefinitelyTyped first: `npm install -D @types/library-name`
6. **Mixing CommonJS and ESM**: Convert all `require()` to `import` before enabling `isolatedModules`

## Tracking Progress

Create a migration dashboard in the project README:

```markdown
## TypeScript Migration Progress

| Area | Files | Converted | % | Status |
|------|-------|-----------|---|--------|
| Types/Models | 5 | 5 | 100% | Done |
| API Layer | 8 | 6 | 75% | In Progress |
| Hooks | 12 | 12 | 100% | Done |
| Utils | 15 | 10 | 67% | In Progress |
| Components | 45 | 20 | 44% | In Progress |
| Pages | 12 | 3 | 25% | Planned |
| Tests | 30 | 8 | 27% | Planned |
| **Total** | **127** | **64** | **50%** | **In Progress** |

Strict mode: `noImplicitAny` enabled, `strictNullChecks` pending
```

---
name: react-patterns
extends: global:check-pattern
description: React/TypeScript patterns and standards. Modern React with hooks, TypeScript, and best practices.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# React Patterns (Template)

Cellular skill template for React/TypeScript projects. Covers modern React (18+) with functional components, hooks, and TypeScript.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/react-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Component Structure

### Required: Functional Components with TypeScript

```tsx
// CORRECT: Typed functional component
interface UserCardProps {
  user: User;
  onEdit?: (user: User) => void;
  className?: string;
}

export const UserCard: React.FC<UserCardProps> = ({
  user,
  onEdit,
  className
}) => {
  const handleEdit = useCallback(() => {
    onEdit?.(user);
  }, [user, onEdit]);

  return (
    <div className={cn("user-card", className)}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      {onEdit && <button onClick={handleEdit}>Edit</button>}
    </div>
  );
};

// WRONG: Class component (legacy)
class UserCard extends React.Component<UserCardProps> {
  render() {
    return <div>...</div>;
  }
}

// WRONG: Untyped component
export const UserCard = ({ user, onEdit }) => {  // No types!
  return <div>...</div>;
};
```

## Hooks Usage

### Required: Proper Hook Patterns

```tsx
// CORRECT: useState with types
const [users, setUsers] = useState<User[]>([]);
const [loading, setLoading] = useState(false);
const [error, setError] = useState<Error | null>(null);

// CORRECT: useEffect with cleanup
useEffect(() => {
  const controller = new AbortController();

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const data = await userService.getAll(controller.signal);
      setUsers(data);
    } catch (e) {
      if (!controller.signal.aborted) {
        setError(e as Error);
      }
    } finally {
      setLoading(false);
    }
  };

  fetchUsers();

  return () => controller.abort();
}, []);

// CORRECT: useCallback for event handlers
const handleSubmit = useCallback(async (data: FormData) => {
  await userService.create(data);
  refetch();
}, [refetch]);

// CORRECT: useMemo for expensive computations
const sortedUsers = useMemo(() =>
  [...users].sort((a, b) => a.name.localeCompare(b.name)),
  [users]
);

// WRONG: Missing dependency array
useEffect(() => {
  fetchUsers();
});  // Runs every render!

// WRONG: Object/function in dependency without memo
useEffect(() => {
  doSomething(config);
}, [{ key: value }]);  // New object every render!
```

## Custom Hooks

### Required: Extract Reusable Logic

```tsx
// CORRECT: Custom hook for data fetching
function useUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await userService.getAll();
      setUsers(data);
    } catch (e) {
      setError(e as Error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetch();
  }, [fetch]);

  return { users, loading, error, refetch: fetch };
}

// Usage in component
const UserList: React.FC = () => {
  const { users, loading, error, refetch } = useUsers();

  if (loading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;

  return <UserTable users={users} onRefresh={refetch} />;
};
```

## State Management

### Required: Appropriate State Location

```tsx
// CORRECT: Local state for UI
const [isOpen, setIsOpen] = useState(false);

// CORRECT: Context for shared state
const UserContext = createContext<UserContextType | null>(null);

export const UserProvider: React.FC<PropsWithChildren> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);

  const value = useMemo(() => ({ user, setUser }), [user]);

  return (
    <UserContext.Provider value={value}>
      {children}
    </UserContext.Provider>
  );
};

export const useUser = () => {
  const context = useContext(UserContext);
  if (!context) {
    throw new Error('useUser must be used within UserProvider');
  }
  return context;
};

// CORRECT: React Query for server state
const { data: users, isLoading } = useQuery({
  queryKey: ['users'],
  queryFn: userService.getAll,
});
```

## Props Patterns

### Required: Proper Prop Types

```tsx
// CORRECT: Interface for props
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  loading?: boolean;
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  loading = false,
  children,
  disabled,
  ...props
}) => (
  <button
    className={cn('btn', `btn-${variant}`)}
    disabled={disabled || loading}
    {...props}
  >
    {loading ? <Spinner size="sm" /> : children}
  </button>
);

// CORRECT: Children typing
interface LayoutProps {
  children: React.ReactNode;
  sidebar?: React.ReactNode;
}

// WRONG: any type
interface BadProps {
  data: any;  // Loses type safety!
  onClick: any;
}
```

## Error Boundaries

### Required: Error Boundaries for Sections

```tsx
// CORRECT: Error boundary component
interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends React.Component<
  PropsWithChildren<{ fallback?: React.ReactNode }>,
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('Error caught:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || <DefaultErrorFallback />;
    }
    return this.props.children;
  }
}

// Usage
<ErrorBoundary fallback={<ErrorMessage />}>
  <UserDashboard />
</ErrorBoundary>
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| Class components | Legacy, verbose | Functional + hooks |
| `any` type | Loses type safety | Proper interfaces |
| Inline objects in JSX | New reference each render | useMemo or extract |
| Index as key | Causes issues on reorder | Unique ID |
| Direct DOM manipulation | Breaks React model | Refs + useEffect |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `typescript_strict` | 100% | Strict TypeScript enabled |
| `functional_components` | 100% | No class components |
| `typed_props` | 100% | All props have interfaces |
| `hook_dependencies` | 100% | Correct dependency arrays |
| `no_any` | 95% | Minimal any usage |
| `error_boundaries` | 90% | Critical sections wrapped |
| `test_coverage` | 70% | Jest/Testing Library |

## Linting Tools

```bash
# ESLint with React plugins
npx eslint src/ --ext .ts,.tsx

# TypeScript strict mode
npx tsc --noEmit

# Recommended: eslint-plugin-react-hooks
```

## See Also

- `/angular-patterns` - Angular equivalent
- `/vue-patterns` - Vue equivalent
- `/pre-commit` - Pre-commit checks

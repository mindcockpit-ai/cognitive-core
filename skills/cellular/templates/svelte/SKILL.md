---
name: svelte-patterns
extends: global:check-pattern
description: Svelte 5 patterns and standards. Modern Svelte with runes, TypeScript, and best practices.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Svelte Patterns (Template)

Cellular skill template for Svelte 5/TypeScript projects. Covers modern Svelte with runes, TypeScript, and reactive primitives.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/svelte-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Runes (Svelte 5)

### Required: Runes for Reactivity

```svelte
<!-- CORRECT: Svelte 5 with runes -->
<script lang="ts">
  import type { User } from '$lib/types';

  interface Props {
    user: User;
    onEdit?: (user: User) => void;
  }

  let { user, onEdit }: Props = $props();

  // Reactive state with $state
  let loading = $state(false);
  let error = $state<string | null>(null);

  // Derived state with $derived
  let fullName = $derived(`${user.firstName} ${user.lastName}`);
  let isValid = $derived(user.email.includes('@'));

  // Side effects with $effect
  $effect(() => {
    console.log('User changed:', user.id);
    // Cleanup function (optional)
    return () => {
      console.log('Cleaning up for user:', user.id);
    };
  });

  function handleEdit() {
    onEdit?.(user);
  }
</script>

<div class="user-card">
  <h3>{fullName}</h3>
  <p>{user.email}</p>
  {#if onEdit}
    <button onclick={handleEdit}>Edit</button>
  {/if}
</div>

<!-- WRONG: Legacy reactive declarations (Svelte 4) -->
<script>
  export let user;

  $: fullName = `${user.firstName} ${user.lastName}`;  // Legacy!

  let loading = false;  // Not reactive with runes!
</script>
```

## Props and Events

### Required: Typed Props with $props()

```svelte
<script lang="ts">
  import type { User } from '$lib/types';

  // CORRECT: Typed props with defaults
  interface Props {
    user: User;
    editable?: boolean;
    variant?: 'compact' | 'full';
  }

  let {
    user,
    editable = false,
    variant = 'full'
  }: Props = $props();

  // CORRECT: Bindable props (two-way binding)
  interface FormProps {
    value: string;
  }

  let { value = $bindable() }: FormProps = $props();

  // CORRECT: Event callbacks (replacing createEventDispatcher)
  interface ButtonProps {
    onClick?: () => void;
    onSubmit?: (data: FormData) => void;
  }

  let { onClick, onSubmit }: ButtonProps = $props();

  function handleClick() {
    onClick?.();
  }

  // WRONG: Legacy export let (Svelte 4)
  export let user;  // No types, legacy syntax!
</script>
```

## State Management

### Required: $state and $derived

```svelte
<script lang="ts">
  import type { User } from '$lib/types';

  // CORRECT: Primitive state
  let count = $state(0);
  let loading = $state(false);
  let error = $state<string | null>(null);

  // CORRECT: Object state (deeply reactive)
  let form = $state({
    email: '',
    firstName: '',
    lastName: '',
  });

  // CORRECT: Array state
  let users = $state<User[]>([]);

  // CORRECT: Derived values
  let userCount = $derived(users.length);
  let activeUsers = $derived(users.filter(u => u.isActive));
  let formValid = $derived(
    form.email.includes('@') &&
    form.firstName.length > 0 &&
    form.lastName.length > 0
  );

  // CORRECT: Complex derived with $derived.by
  let summary = $derived.by(() => {
    const active = users.filter(u => u.isActive);
    const inactive = users.filter(u => !u.isActive);
    return {
      total: users.length,
      active: active.length,
      inactive: inactive.length,
      ratio: active.length / users.length,
    };
  });

  // CORRECT: State with class
  class Counter {
    count = $state(0);

    increment = () => {
      this.count++;
    };

    decrement = () => {
      this.count--;
    };
  }

  const counter = new Counter();
</script>

<button onclick={counter.increment}>
  Count: {counter.count}
</button>
```

## Effects

### Required: $effect for Side Effects

```svelte
<script lang="ts">
  let userId = $state(0);
  let user = $state<User | null>(null);
  let loading = $state(false);

  // CORRECT: Effect with automatic dependencies
  $effect(() => {
    if (userId > 0) {
      fetchUser(userId);
    }
  });

  // CORRECT: Effect with cleanup
  $effect(() => {
    const controller = new AbortController();

    fetchWithAbort(userId, controller.signal);

    return () => {
      controller.abort();
    };
  });

  // CORRECT: Pre-effect (runs before DOM update)
  $effect.pre(() => {
    console.log('Before DOM update');
  });

  // CORRECT: Effect that doesn't track dependencies
  $effect.root(() => {
    // Runs once, no automatic tracking
    setupGlobalListener();
  });

  async function fetchUser(id: number) {
    loading = true;
    try {
      const response = await fetch(`/api/users/${id}`);
      user = await response.json();
    } catch (e) {
      console.error('Failed to fetch user:', e);
    } finally {
      loading = false;
    }
  }
</script>
```

## Component Patterns

### Required: Modern Component Structure

```svelte
<!-- UserList.svelte -->
<script lang="ts">
  import UserCard from './UserCard.svelte';
  import Spinner from './Spinner.svelte';
  import type { User } from '$lib/types';
  import { userService } from '$lib/services';

  let users = $state<User[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  $effect(() => {
    loadUsers();
  });

  async function loadUsers() {
    loading = true;
    error = null;
    try {
      users = await userService.getAll();
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to load users';
    } finally {
      loading = false;
    }
  }

  function handleEdit(user: User) {
    // Navigate to edit page or open modal
  }

  function handleDelete(id: number) {
    users = users.filter(u => u.id !== id);
  }
</script>

{#if loading}
  <Spinner />
{:else if error}
  <div class="error">{error}</div>
{:else}
  <div class="user-list">
    {#each users as user (user.id)}
      <UserCard
        {user}
        onEdit={() => handleEdit(user)}
        onDelete={() => handleDelete(user.id)}
      />
    {:else}
      <p>No users found</p>
    {/each}
  </div>
{/if}

<style>
  .user-list {
    display: grid;
    gap: 1rem;
  }

  .error {
    color: var(--color-error);
    padding: 1rem;
    border-radius: 4px;
    background: var(--color-error-bg);
  }
</style>
```

## Stores

### Required: Svelte Stores for Shared State

```typescript
// CORRECT: Writable store with TypeScript
// stores/userStore.ts
import { writable, derived, type Writable } from 'svelte/store';
import type { User } from '$lib/types';

interface UserState {
  currentUser: User | null;
  users: User[];
  loading: boolean;
}

function createUserStore() {
  const { subscribe, set, update }: Writable<UserState> = writable({
    currentUser: null,
    users: [],
    loading: false,
  });

  return {
    subscribe,

    async login(credentials: LoginRequest) {
      update(state => ({ ...state, loading: true }));
      try {
        const user = await authApi.login(credentials);
        update(state => ({ ...state, currentUser: user, loading: false }));
      } catch (e) {
        update(state => ({ ...state, loading: false }));
        throw e;
      }
    },

    logout() {
      update(state => ({ ...state, currentUser: null }));
    },

    async fetchUsers() {
      update(state => ({ ...state, loading: true }));
      try {
        const users = await userApi.getAll();
        update(state => ({ ...state, users, loading: false }));
      } catch (e) {
        update(state => ({ ...state, loading: false }));
        throw e;
      }
    },
  };
}

export const userStore = createUserStore();

// Derived stores
export const isAuthenticated = derived(
  userStore,
  $store => $store.currentUser !== null
);

export const activeUsers = derived(
  userStore,
  $store => $store.users.filter(u => u.isActive)
);

// CORRECT: Using store in component
<script lang="ts">
  import { userStore, isAuthenticated } from '$lib/stores/userStore';

  // Reactive subscription with $
  $effect(() => {
    console.log('Auth status:', $isAuthenticated);
  });
</script>

{#if $isAuthenticated}
  <p>Welcome, {$userStore.currentUser?.name}</p>
{/if}
```

## API Services

### Required: Typed API Layer

```typescript
// CORRECT: Typed API service
// lib/services/userService.ts
import type { User, CreateUserRequest, ApiResponse } from '$lib/types';

const API_URL = import.meta.env.VITE_API_URL;

async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'API request failed');
  }
  const data: ApiResponse<T> = await response.json();
  return data.data;
}

export const userService = {
  async getAll(): Promise<User[]> {
    const response = await fetch(`${API_URL}/users`);
    return handleResponse<User[]>(response);
  },

  async getById(id: number): Promise<User> {
    const response = await fetch(`${API_URL}/users/${id}`);
    return handleResponse<User>(response);
  },

  async create(request: CreateUserRequest): Promise<User> {
    const response = await fetch(`${API_URL}/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });
    return handleResponse<User>(response);
  },

  async update(id: number, request: Partial<User>): Promise<User> {
    const response = await fetch(`${API_URL}/users/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });
    return handleResponse<User>(response);
  },

  async delete(id: number): Promise<void> {
    const response = await fetch(`${API_URL}/users/${id}`, {
      method: 'DELETE',
    });
    if (!response.ok) {
      throw new Error('Failed to delete user');
    }
  },
};
```

## Form Handling

### Required: Typed Form Patterns

```svelte
<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ActionData } from './$types';

  // CORRECT: Form state with $state
  let form = $state({
    email: '',
    firstName: '',
    lastName: '',
  });

  let errors = $state<Record<string, string>>({});
  let submitting = $state(false);

  // Derived validation
  let isValid = $derived(
    form.email.includes('@') &&
    form.firstName.length >= 2 &&
    form.lastName.length >= 2
  );

  function validate(): boolean {
    errors = {};

    if (!form.email.includes('@')) {
      errors.email = 'Invalid email address';
    }
    if (form.firstName.length < 2) {
      errors.firstName = 'First name must be at least 2 characters';
    }
    if (form.lastName.length < 2) {
      errors.lastName = 'Last name must be at least 2 characters';
    }

    return Object.keys(errors).length === 0;
  }

  async function handleSubmit(event: Event) {
    event.preventDefault();

    if (!validate()) return;

    submitting = true;
    try {
      await userService.create(form);
      // Reset form
      form = { email: '', firstName: '', lastName: '' };
    } catch (e) {
      errors.submit = e instanceof Error ? e.message : 'Submission failed';
    } finally {
      submitting = false;
    }
  }
</script>

<form onsubmit={handleSubmit}>
  <div class="field">
    <label for="email">Email</label>
    <input
      id="email"
      type="email"
      bind:value={form.email}
      class:error={errors.email}
    />
    {#if errors.email}
      <span class="error-message">{errors.email}</span>
    {/if}
  </div>

  <div class="field">
    <label for="firstName">First Name</label>
    <input
      id="firstName"
      type="text"
      bind:value={form.firstName}
      class:error={errors.firstName}
    />
    {#if errors.firstName}
      <span class="error-message">{errors.firstName}</span>
    {/if}
  </div>

  <div class="field">
    <label for="lastName">Last Name</label>
    <input
      id="lastName"
      type="text"
      bind:value={form.lastName}
      class:error={errors.lastName}
    />
    {#if errors.lastName}
      <span class="error-message">{errors.lastName}</span>
    {/if}
  </div>

  <button type="submit" disabled={!isValid || submitting}>
    {submitting ? 'Submitting...' : 'Submit'}
  </button>
</form>
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `$:` reactive statements | Legacy Svelte 4 | `$derived` rune |
| `export let` props | Legacy syntax | `$props()` |
| `createEventDispatcher` | Legacy pattern | Callback props |
| Non-keyed `{#each}` | Performance issues | Always use `(key)` |
| `let` for reactive state | Not reactive in Svelte 5 | `$state` |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `runes_usage` | 100% | All components use runes |
| `typed_props` | 100% | All props have TypeScript types |
| `state_rune` | 100% | Use $state for reactive state |
| `derived_rune` | 90% | Use $derived for computed values |
| `effect_cleanup` | 100% | Effects with cleanup when needed |
| `keyed_each` | 100% | All #each blocks have keys |
| `test_coverage` | 70% | Vitest/Testing Library coverage |

## CLI Commands

```bash
# Create SvelteKit project with TypeScript
npx sv create my-app

# Lint
npm run lint

# Test
npm run test -- --coverage

# Type check
npm run check
```

## See Also

- `/react-patterns` - React equivalent
- `/angular-patterns` - Angular equivalent
- `/vue-patterns` - Vue equivalent
- `/pre-commit` - Pre-commit checks

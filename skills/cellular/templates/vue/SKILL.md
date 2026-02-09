---
name: vue-patterns
extends: global:check-pattern
description: Vue 3 patterns and standards. Modern Vue with Composition API, TypeScript, and best practices.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Vue Patterns (Template)

Cellular skill template for Vue 3/TypeScript projects. Covers modern Vue with Composition API, TypeScript, and reactive primitives.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/vue-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Composition API

### Required: Composition API with `<script setup>` (Vue 3.2+)

```vue
<!-- CORRECT: script setup with TypeScript -->
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useUserService } from '@/composables/useUserService';
import type { User } from '@/types';

interface Props {
  userId: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  (e: 'edit', user: User): void;
  (e: 'delete', id: number): void;
}>();

const { user, loading, error, fetchUser } = useUserService();

onMounted(() => {
  fetchUser(props.userId);
});

const handleEdit = () => {
  if (user.value) {
    emit('edit', user.value);
  }
};
</script>

<template>
  <div v-if="loading" class="spinner" />
  <div v-else-if="error" class="error">{{ error }}</div>
  <div v-else-if="user" class="user-card">
    <h3>{{ user.name }}</h3>
    <p>{{ user.email }}</p>
    <button @click="handleEdit">Edit</button>
  </div>
</template>

<!-- WRONG: Options API (legacy) -->
<script>
export default {
  props: ['userId'],
  data() {
    return { user: null, loading: false };
  },
  methods: {
    fetchUser() { /* ... */ }
  },
  mounted() {
    this.fetchUser();
  }
};
</script>
```

## Reactive Primitives

### Required: Proper Use of `ref` and `reactive`

```typescript
// CORRECT: ref for primitives and objects
const count = ref(0);
const user = ref<User | null>(null);
const loading = ref(false);

// CORRECT: reactive for complex objects
const form = reactive<UserForm>({
  email: '',
  firstName: '',
  lastName: '',
});

// CORRECT: computed for derived state
const fullName = computed(() =>
  `${form.firstName} ${form.lastName}`.trim()
);

// CORRECT: watch for side effects
watch(
  () => props.userId,
  async (newId) => {
    await fetchUser(newId);
  },
  { immediate: true }
);

// CORRECT: watchEffect for automatic dependencies
watchEffect(async () => {
  if (props.userId) {
    await fetchUser(props.userId);
  }
});

// WRONG: Destructuring reactive (loses reactivity)
const { email, firstName } = form;  // Not reactive!

// CORRECT: Use toRefs for destructuring
const { email, firstName } = toRefs(form);
```

## Composables

### Required: Extract Reusable Logic

```typescript
// CORRECT: Composable for data fetching
// composables/useUserService.ts
import { ref, readonly } from 'vue';
import type { User } from '@/types';
import { userApi } from '@/api';

export function useUserService() {
  const user = ref<User | null>(null);
  const users = ref<User[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const fetchUser = async (id: number) => {
    loading.value = true;
    error.value = null;
    try {
      user.value = await userApi.getById(id);
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch user';
    } finally {
      loading.value = false;
    }
  };

  const fetchUsers = async () => {
    loading.value = true;
    error.value = null;
    try {
      users.value = await userApi.getAll();
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch users';
    } finally {
      loading.value = false;
    }
  };

  return {
    user: readonly(user),
    users: readonly(users),
    loading: readonly(loading),
    error: readonly(error),
    fetchUser,
    fetchUsers,
  };
}

// CORRECT: Composable for form handling
// composables/useForm.ts
export function useForm<T extends object>(initialValues: T) {
  const values = reactive({ ...initialValues });
  const errors = reactive<Partial<Record<keyof T, string>>>({});
  const touched = reactive<Partial<Record<keyof T, boolean>>>({});

  const reset = () => {
    Object.assign(values, initialValues);
    Object.keys(errors).forEach(key => delete errors[key as keyof T]);
    Object.keys(touched).forEach(key => delete touched[key as keyof T]);
  };

  const validate = (rules: ValidationRules<T>): boolean => {
    // Validation logic
    return Object.keys(errors).length === 0;
  };

  return { values, errors, touched, reset, validate };
}
```

## Props and Events

### Required: Typed Props and Emits

```vue
<script setup lang="ts">
// CORRECT: Typed props with defaults
interface Props {
  user: User;
  editable?: boolean;
  variant?: 'compact' | 'full';
}

const props = withDefaults(defineProps<Props>(), {
  editable: false,
  variant: 'full',
});

// CORRECT: Typed emits
interface Emits {
  (e: 'update', user: User): void;
  (e: 'delete', id: number): void;
  (e: 'select'): void;
}

const emit = defineEmits<Emits>();

// CORRECT: v-model support
const modelValue = defineModel<string>();
// or for Vue 3.3-:
const props = defineProps<{ modelValue: string }>();
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>();

// WRONG: Untyped props
const props = defineProps(['user', 'editable']);  // No types!
</script>
```

## State Management (Pinia)

### Required: Pinia for Global State

```typescript
// CORRECT: Pinia store with Composition API
// stores/userStore.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { User } from '@/types';

export const useUserStore = defineStore('user', () => {
  // State
  const currentUser = ref<User | null>(null);
  const users = ref<User[]>([]);
  const loading = ref(false);

  // Getters
  const isAuthenticated = computed(() => currentUser.value !== null);
  const activeUsers = computed(() =>
    users.value.filter(u => u.isActive)
  );

  // Actions
  const login = async (credentials: LoginRequest) => {
    loading.value = true;
    try {
      currentUser.value = await authApi.login(credentials);
    } finally {
      loading.value = false;
    }
  };

  const logout = () => {
    currentUser.value = null;
  };

  return {
    currentUser,
    users,
    loading,
    isAuthenticated,
    activeUsers,
    login,
    logout,
  };
});

// CORRECT: Using store in component
<script setup lang="ts">
import { useUserStore } from '@/stores/userStore';
import { storeToRefs } from 'pinia';

const userStore = useUserStore();
// Use storeToRefs for reactive destructuring
const { currentUser, isAuthenticated } = storeToRefs(userStore);
// Actions can be destructured directly
const { login, logout } = userStore;
</script>

// WRONG: Vuex (legacy)
const store = createStore({
  state: { ... },
  mutations: { ... },
  actions: { ... },
});
```

## Template Syntax

### Required: Modern Template Patterns

```vue
<template>
  <!-- CORRECT: v-if/v-else-if/v-else chain -->
  <div v-if="loading" class="loading">
    <Spinner />
  </div>
  <div v-else-if="error" class="error">
    <ErrorMessage :message="error" />
  </div>
  <div v-else class="content">
    <!-- CORRECT: v-for with key -->
    <UserCard
      v-for="user in users"
      :key="user.id"
      :user="user"
      @edit="handleEdit"
    />

    <!-- CORRECT: Empty state -->
    <p v-if="users.length === 0">No users found</p>
  </div>

  <!-- CORRECT: Event modifiers -->
  <form @submit.prevent="handleSubmit">
    <input
      v-model.trim="form.email"
      @keyup.enter="handleSubmit"
    />
    <button
      type="submit"
      :disabled="loading"
      @click.stop="handleSubmit"
    >
      Submit
    </button>
  </form>

  <!-- CORRECT: Slots with scoped data -->
  <DataTable :items="users">
    <template #header>
      <h2>User List</h2>
    </template>
    <template #row="{ item }">
      <UserRow :user="item" />
    </template>
    <template #empty>
      <p>No data available</p>
    </template>
  </DataTable>
</template>

<!-- WRONG: v-for without key -->
<div v-for="user in users">{{ user.name }}</div>

<!-- WRONG: v-if with v-for (performance issue) -->
<div v-for="user in users" v-if="user.isActive">
  {{ user.name }}
</div>

<!-- CORRECT: Filter first -->
<div v-for="user in activeUsers" :key="user.id">
  {{ user.name }}
</div>
```

## API Layer

### Required: Typed API Services

```typescript
// CORRECT: Typed API service
// api/userApi.ts
import { apiClient } from './client';
import type { User, CreateUserRequest, ApiResponse } from '@/types';

export const userApi = {
  async getAll(): Promise<User[]> {
    const response = await apiClient.get<ApiResponse<User[]>>('/users');
    return response.data.data;
  },

  async getById(id: number): Promise<User> {
    const response = await apiClient.get<ApiResponse<User>>(`/users/${id}`);
    return response.data.data;
  },

  async create(request: CreateUserRequest): Promise<User> {
    const response = await apiClient.post<ApiResponse<User>>('/users', request);
    return response.data.data;
  },

  async update(id: number, request: Partial<User>): Promise<User> {
    const response = await apiClient.put<ApiResponse<User>>(`/users/${id}`, request);
    return response.data.data;
  },

  async delete(id: number): Promise<void> {
    await apiClient.delete(`/users/${id}`);
  },
};

// CORRECT: API client with interceptors
// api/client.ts
import axios from 'axios';
import { useAuthStore } from '@/stores/authStore';
import router from '@/router';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: { 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use((config) => {
  const authStore = useAuthStore();
  if (authStore.token) {
    config.headers.Authorization = `Bearer ${authStore.token}`;
  }
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const authStore = useAuthStore();
      authStore.logout();
      router.push('/login');
    }
    return Promise.reject(error);
  }
);
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| Options API | Verbose, less TypeScript | Composition API |
| Vuex | Legacy, verbose | Pinia |
| `this` in setup | Not available | Direct refs |
| Destructure reactive | Loses reactivity | `toRefs()` |
| v-for without key | Performance issues | Always use `:key` |
| v-if with v-for | Performance | Filter first |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `composition_api` | 100% | All components use Composition API |
| `script_setup` | 95% | Use `<script setup>` syntax |
| `typed_props` | 100% | All props have TypeScript types |
| `typed_emits` | 100% | All emits have TypeScript types |
| `pinia_stores` | 100% | Pinia for global state |
| `composables` | 80% | Reusable logic in composables |
| `test_coverage` | 70% | Vitest/Vue Test Utils coverage |

## CLI Commands

```bash
# Create Vue project with TypeScript
npm create vue@latest my-app -- --typescript

# Lint
npm run lint

# Test
npm run test:unit -- --coverage

# Type check
npm run type-check
```

## See Also

- `/react-patterns` - React equivalent
- `/angular-patterns` - Angular equivalent
- `/svelte-patterns` - Svelte equivalent
- `/pre-commit` - Pre-commit checks

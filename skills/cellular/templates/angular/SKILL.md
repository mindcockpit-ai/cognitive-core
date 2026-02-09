---
name: angular-patterns
extends: global:check-pattern
description: Angular patterns and standards. Modern Angular (17+) with signals, standalone components, and best practices.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Angular Patterns (Template)

Cellular skill template for Angular projects. Covers modern Angular (17+) with standalone components, signals, and TypeScript.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/angular-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Standalone Components

### Required: Standalone by Default (Angular 17+)

```typescript
// CORRECT: Standalone component
@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <div class="user-card">
      <h3>{{ user().name }}</h3>
      <p>{{ user().email }}</p>
      @if (onEdit) {
        <button (click)="handleEdit()">Edit</button>
      }
    </div>
  `,
  styleUrl: './user-card.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserCardComponent {
  user = input.required<User>();
  onEdit = output<User>();

  handleEdit() {
    this.onEdit.emit(this.user());
  }
}

// WRONG: NgModule-based component (legacy)
@Component({
  selector: 'app-user-card',
  templateUrl: './user-card.component.html',
})
export class UserCardComponent {
  @Input() user!: User;
  @Output() onEdit = new EventEmitter<User>();
}
```

## Signals

### Required: Signals for Reactive State (Angular 17+)

```typescript
// CORRECT: Signals for component state
@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (loading()) {
      <app-spinner />
    } @else if (error()) {
      <app-error [message]="error()!" />
    } @else {
      <ul>
        @for (user of users(); track user.id) {
          <app-user-card [user]="user" />
        }
      </ul>
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListComponent {
  private userService = inject(UserService);

  users = signal<User[]>([]);
  loading = signal(false);
  error = signal<string | null>(null);

  // Computed signal
  activeUsers = computed(() =>
    this.users().filter(u => u.isActive)
  );

  constructor() {
    this.loadUsers();
  }

  async loadUsers() {
    this.loading.set(true);
    this.error.set(null);

    try {
      const users = await firstValueFrom(this.userService.getAll());
      this.users.set(users);
    } catch (e) {
      this.error.set('Failed to load users');
    } finally {
      this.loading.set(false);
    }
  }
}

// WRONG: RxJS for simple state (overcomplication)
users$ = new BehaviorSubject<User[]>([]);
loading$ = new BehaviorSubject<boolean>(false);
```

## Dependency Injection

### Required: inject() Function (Angular 14+)

```typescript
// CORRECT: inject() function
@Component({...})
export class UserListComponent {
  private userService = inject(UserService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  // ...
}

// CORRECT: Injectable service
@Injectable({ providedIn: 'root' })
export class UserService {
  private http = inject(HttpClient);
  private apiUrl = inject(API_URL);

  getAll(): Observable<User[]> {
    return this.http.get<ApiResponse<User[]>>(`${this.apiUrl}/users`).pipe(
      map(response => response.data)
    );
  }
}

// WRONG: Constructor injection (verbose)
@Component({...})
export class UserListComponent {
  constructor(
    private userService: UserService,
    private router: Router,
    private route: ActivatedRoute,
  ) {}
}
```

## Control Flow (Angular 17+)

### Required: Built-in Control Flow

```typescript
// CORRECT: Built-in control flow
@Component({
  template: `
    @if (loading()) {
      <app-spinner />
    } @else if (error()) {
      <app-error [message]="error()!" />
    } @else {
      @for (user of users(); track user.id) {
        <app-user-card [user]="user" />
      } @empty {
        <p>No users found</p>
      }
    }

    @switch (status()) {
      @case ('active') { <span class="badge-active">Active</span> }
      @case ('inactive') { <span class="badge-inactive">Inactive</span> }
      @default { <span class="badge-unknown">Unknown</span> }
    }
  `,
})
export class UserListComponent { }

// WRONG: NgIf/NgFor directives (legacy)
@Component({
  template: `
    <div *ngIf="loading">Loading...</div>
    <div *ngFor="let user of users">{{ user.name }}</div>
  `,
})
```

## Services Pattern

### Required: Proper Service Structure

```typescript
// CORRECT: Service with proper typing
@Injectable({ providedIn: 'root' })
export class UserService {
  private http = inject(HttpClient);

  private usersCache = signal<User[]>([]);

  getAll(): Observable<User[]> {
    return this.http.get<ApiResponse<User[]>>('/api/users').pipe(
      map(res => res.data),
      tap(users => this.usersCache.set(users)),
    );
  }

  getById(id: number): Observable<User> {
    return this.http.get<ApiResponse<User>>(`/api/users/${id}`).pipe(
      map(res => res.data),
    );
  }

  create(request: CreateUserRequest): Observable<User> {
    return this.http.post<ApiResponse<User>>('/api/users', request).pipe(
      map(res => res.data),
    );
  }
}

// CORRECT: API response typing
interface ApiResponse<T> {
  success: boolean;
  data: T;
  error?: string;
}
```

## Reactive Forms

### Required: Typed Reactive Forms

```typescript
// CORRECT: Typed form group
@Component({...})
export class UserFormComponent {
  private fb = inject(NonNullableFormBuilder);

  form = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    firstName: ['', [Validators.required, Validators.maxLength(100)]],
    lastName: ['', [Validators.required, Validators.maxLength(100)]],
  });

  onSubmit() {
    if (this.form.invalid) return;

    const value = this.form.getRawValue();
    // value is typed: { email: string, firstName: string, lastName: string }
  }
}

// WRONG: Untyped form
form = new FormGroup({
  email: new FormControl(''),  // FormControl<string | null>
});
```

## Error Handling

### Required: HTTP Interceptors for Errors

```typescript
// CORRECT: Functional interceptor (Angular 15+)
export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      switch (error.status) {
        case 401:
          router.navigate(['/login']);
          break;
        case 403:
          router.navigate(['/forbidden']);
          break;
        case 500:
          console.error('Server error:', error);
          break;
      }
      return throwError(() => error);
    }),
  );
};

// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([errorInterceptor])),
  ],
};
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| NgModules | Legacy, verbose | Standalone components |
| `*ngIf/*ngFor` | Legacy syntax | `@if/@for` control flow |
| Constructor DI | Verbose | `inject()` function |
| `any` type | Loses type safety | Proper interfaces |
| Subscriptions in components | Memory leaks | `async` pipe or signals |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `standalone_components` | 100% | All components standalone |
| `signals_usage` | 80% | Signals for reactive state |
| `inject_function` | 100% | inject() over constructor |
| `control_flow` | 100% | Built-in @if/@for syntax |
| `typed_forms` | 100% | NonNullableFormBuilder |
| `onpush_strategy` | 90% | OnPush change detection |
| `test_coverage` | 70% | Jasmine/Jest coverage |

## CLI Commands

```bash
# Generate standalone component
ng generate component user-card --standalone

# Lint
ng lint

# Test
ng test --code-coverage
```

## See Also

- `/react-patterns` - React equivalent
- `/vue-patterns` - Vue equivalent
- `/pre-commit` - Pre-commit checks

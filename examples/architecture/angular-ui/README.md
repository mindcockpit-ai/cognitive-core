# Angular UI Architecture Example

Enterprise Angular frontend that connects to any DDD backend via REST API.

## Stack

- **Language**: TypeScript 5.x
- **Framework**: Angular 17+
- **State Management**: NgRx / Signals
- **UI Components**: Angular Material / PrimeNG
- **HTTP**: HttpClient with interceptors

## Key Principle

The UI is **completely decoupled** from the backend technology. The same Angular app works with:
- Perl/Dancer2 backend
- Java/Spring Boot backend
- Python/FastAPI backend
- C#/.NET Core backend
- Node.js/NestJS backend

**Communication is via REST API only.**

## Project Structure

```
src/app/
├── core/                          # Singleton services
│   ├── services/
│   │   ├── api.service.ts         # Base HTTP service
│   │   ├── auth.service.ts
│   │   └── config.service.ts
│   ├── interceptors/
│   │   ├── auth.interceptor.ts
│   │   └── error.interceptor.ts
│   ├── guards/
│   │   └── auth.guard.ts
│   └── core.module.ts
│
├── shared/                        # Reusable components
│   ├── components/
│   │   ├── data-table/
│   │   ├── confirm-dialog/
│   │   └── loading-spinner/
│   ├── directives/
│   ├── pipes/
│   └── shared.module.ts
│
├── features/                      # Feature modules
│   ├── users/
│   │   ├── components/
│   │   │   ├── user-list/
│   │   │   ├── user-detail/
│   │   │   └── user-form/
│   │   ├── services/
│   │   │   └── user.service.ts
│   │   ├── models/
│   │   │   ├── user.model.ts
│   │   │   └── user-request.model.ts
│   │   ├── store/              # NgRx state (optional)
│   │   │   ├── user.actions.ts
│   │   │   ├── user.reducer.ts
│   │   │   └── user.effects.ts
│   │   ├── users-routing.module.ts
│   │   └── users.module.ts
│   │
│   ├── orders/
│   │   └── ...
│   │
│   └── dashboard/
│       └── ...
│
├── layout/                        # App layout
│   ├── header/
│   ├── sidebar/
│   └── footer/
│
└── app.component.ts
```

## Code Standards

### API Service (Base HTTP)

```typescript
// src/app/core/services/api.service.ts
import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly baseUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  get<T>(path: string, params?: HttpParams): Observable<ApiResponse<T>> {
    return this.http.get<ApiResponse<T>>(`${this.baseUrl}${path}`, { params });
  }

  post<T>(path: string, body: unknown): Observable<ApiResponse<T>> {
    return this.http.post<ApiResponse<T>>(`${this.baseUrl}${path}`, body);
  }

  put<T>(path: string, body: unknown): Observable<ApiResponse<T>> {
    return this.http.put<ApiResponse<T>>(`${this.baseUrl}${path}`, body);
  }

  delete<T>(path: string): Observable<ApiResponse<T>> {
    return this.http.delete<ApiResponse<T>>(`${this.baseUrl}${path}`);
  }
}
```

### Feature Service

```typescript
// src/app/features/users/services/user.service.ts
import { Injectable } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiService, ApiResponse } from '../../../core/services/api.service';
import { User } from '../models/user.model';
import { CreateUserRequest } from '../models/user-request.model';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly path = '/api/users';

  constructor(private api: ApiService) {}

  getAll(): Observable<User[]> {
    return this.api.get<User[]>(this.path).pipe(
      map((response) => response.data ?? [])
    );
  }

  getById(id: number): Observable<User | null> {
    return this.api.get<User>(`${this.path}/${id}`).pipe(
      map((response) => response.data ?? null)
    );
  }

  create(request: CreateUserRequest): Observable<User | null> {
    return this.api.post<User>(this.path, request).pipe(
      map((response) => response.data ?? null)
    );
  }

  update(id: number, request: Partial<CreateUserRequest>): Observable<User | null> {
    return this.api.put<User>(`${this.path}/${id}`, request).pipe(
      map((response) => response.data ?? null)
    );
  }

  delete(id: number): Observable<boolean> {
    return this.api.delete(`${this.path}/${id}`).pipe(
      map((response) => response.success)
    );
  }
}
```

### Models (DTOs)

```typescript
// src/app/features/users/models/user.model.ts
export interface User {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  createdAt: Date;
}

// src/app/features/users/models/user-request.model.ts
export interface CreateUserRequest {
  email: string;
  firstName: string;
  lastName: string;
}
```

### Component (Smart/Container)

```typescript
// src/app/features/users/components/user-list/user-list.component.ts
import { Component, OnInit, signal } from '@angular/core';
import { UserService } from '../../services/user.service';
import { User } from '../../models/user.model';

@Component({
  selector: 'app-user-list',
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.scss'],
})
export class UserListComponent implements OnInit {
  users = signal<User[]>([]);
  loading = signal(false);
  error = signal<string | null>(null);

  constructor(private userService: UserService) {}

  ngOnInit(): void {
    this.loadUsers();
  }

  loadUsers(): void {
    this.loading.set(true);
    this.error.set(null);

    this.userService.getAll().subscribe({
      next: (users) => {
        this.users.set(users);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Failed to load users');
        this.loading.set(false);
        console.error('Error loading users:', err);
      },
    });
  }

  onDelete(user: User): void {
    if (confirm(`Delete user ${user.email}?`)) {
      this.userService.delete(user.id).subscribe({
        next: () => this.loadUsers(),
        error: (err) => console.error('Error deleting user:', err),
      });
    }
  }
}
```

### Component Template

```html
<!-- src/app/features/users/components/user-list/user-list.component.html -->
<div class="user-list-container">
  <h1>Users</h1>

  <button mat-raised-button color="primary" routerLink="new">
    Add User
  </button>

  @if (loading()) {
    <app-loading-spinner />
  }

  @if (error(); as errorMsg) {
    <div class="error-message">{{ errorMsg }}</div>
  }

  @if (!loading() && users().length > 0) {
    <table mat-table [dataSource]="users()">
      <ng-container matColumnDef="email">
        <th mat-header-cell *matHeaderCellDef>Email</th>
        <td mat-cell *matCellDef="let user">{{ user.email }}</td>
      </ng-container>

      <ng-container matColumnDef="name">
        <th mat-header-cell *matHeaderCellDef>Name</th>
        <td mat-cell *matCellDef="let user">
          {{ user.firstName }} {{ user.lastName }}
        </td>
      </ng-container>

      <ng-container matColumnDef="actions">
        <th mat-header-cell *matHeaderCellDef>Actions</th>
        <td mat-cell *matCellDef="let user">
          <button mat-icon-button [routerLink]="[user.id]">
            <mat-icon>edit</mat-icon>
          </button>
          <button mat-icon-button color="warn" (click)="onDelete(user)">
            <mat-icon>delete</mat-icon>
          </button>
        </td>
      </ng-container>

      <tr mat-header-row *matHeaderRowDef="['email', 'name', 'actions']"></tr>
      <tr mat-row *matRowDef="let row; columns: ['email', 'name', 'actions']"></tr>
    </table>
  }

  @if (!loading() && users().length === 0) {
    <p>No users found.</p>
  }
</div>
```

### HTTP Interceptor (Error Handling)

```typescript
// src/app/core/interceptors/error.interceptor.ts
import { Injectable } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpErrorResponse,
} from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Router } from '@angular/router';

@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  constructor(private router: Router) {}

  intercept(
    request: HttpRequest<unknown>,
    next: HttpHandler
  ): Observable<HttpEvent<unknown>> {
    return next.handle(request).pipe(
      catchError((error: HttpErrorResponse) => {
        switch (error.status) {
          case 401:
            this.router.navigate(['/login']);
            break;
          case 403:
            this.router.navigate(['/forbidden']);
            break;
          case 404:
            // Handle not found
            break;
          case 500:
            // Handle server error
            break;
        }
        return throwError(() => error);
      })
    );
  }
}
```

### DataTable Component (Reusable)

```typescript
// src/app/shared/components/data-table/data-table.component.ts
import { Component, Input, Output, EventEmitter } from '@angular/core';

export interface TableColumn {
  key: string;
  header: string;
  sortable?: boolean;
  type?: 'text' | 'date' | 'number' | 'actions';
}

@Component({
  selector: 'app-data-table',
  templateUrl: './data-table.component.html',
})
export class DataTableComponent<T> {
  @Input() columns: TableColumn[] = [];
  @Input() data: T[] = [];
  @Input() loading = false;
  @Input() pageSize = 10;
  @Input() totalRecords = 0;

  @Output() pageChange = new EventEmitter<{ page: number; size: number }>();
  @Output() sortChange = new EventEmitter<{ column: string; direction: 'asc' | 'desc' }>();
  @Output() rowClick = new EventEmitter<T>();
  @Output() rowAction = new EventEmitter<{ action: string; row: T }>();

  onPageChange(page: number): void {
    this.pageChange.emit({ page, size: this.pageSize });
  }

  onSort(column: string, direction: 'asc' | 'desc'): void {
    this.sortChange.emit({ column, direction });
  }

  onRowClick(row: T): void {
    this.rowClick.emit(row);
  }

  onAction(action: string, row: T): void {
    this.rowAction.emit({ action, row });
  }
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| HTTP calls in components | Hard to test, duplicated | Use services |
| `any` type | Loses type safety | Proper interfaces |
| Subscribe in subscribe | Callback hell | Use RxJS operators |
| Direct DOM manipulation | Breaks Angular | Use directives/bindings |
| Business logic in templates | Hard to test | Move to component/service |

## Environment Configuration

```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000',  // Backend URL
};

// src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: '/api',  // Relative in production
};
```

## cognitive-core Skills

Install the Angular cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/angular-ui/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `strict_typescript` | 100% |
| `standalone_components` | 90% |
| `signal_usage` | 80% |
| `service_injection` | 100% |
| `reactive_patterns` | 90% |
| `lazy_loading` | 100% |
| `test_coverage` | 70% |

## Testing

```bash
# Run unit tests
ng test

# Run with coverage
ng test --code-coverage

# Run e2e tests
ng e2e

# Run specific test
ng test --include=**/user.service.spec.ts
```

## Backend Compatibility

This Angular app works with **any** backend that provides:

```
GET    /api/users          → List all users
GET    /api/users/:id      → Get user by ID
POST   /api/users          → Create user
PUT    /api/users/:id      → Update user
DELETE /api/users/:id      → Delete user
```

Response format:
```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

## See Also

- [perl-ddd/](../perl-ddd/) - Perl backend
- [java-spring/](../java-spring/) - Java backend
- [python-fastapi/](../python-fastapi/) - Python backend
- [csharp-dotnet/](../csharp-dotnet/) - C# backend
- [nodejs-nestjs/](../nodejs-nestjs/) - Node.js backend

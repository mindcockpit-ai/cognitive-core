# Node.js NestJS DDD Architecture Example

Enterprise Node.js application using NestJS and Domain-Driven Design patterns.

## Stack

- **Language**: TypeScript 5.x
- **Framework**: NestJS 10.x
- **ORM**: TypeORM / Prisma
- **Database**: Oracle/PostgreSQL (abstracted)
- **Runtime**: Node.js 20+

## Project Structure

```
src/
├── domain/                        # Pure business logic
│   ├── entities/
│   │   ├── user.entity.ts
│   │   ├── order.entity.ts
│   │   └── product.entity.ts
│   ├── value-objects/
│   │   ├── email.vo.ts
│   │   ├── money.vo.ts
│   │   └── date-range.vo.ts
│   └── events/
│       └── order-created.event.ts
│
├── repository/                    # Data access layer
│   ├── interfaces/
│   │   ├── user.repository.interface.ts
│   │   └── order.repository.interface.ts
│   ├── user.repository.ts
│   ├── order.repository.ts
│   └── product.repository.ts
│
├── service/                       # Business orchestration
│   ├── user.service.ts
│   ├── order.service.ts
│   └── import.service.ts
│
├── mapper/                        # DTO transformations
│   ├── user.mapper.ts
│   ├── order.mapper.ts
│   └── datatable.mapper.ts
│
├── controller/                    # HTTP layer
│   ├── api/
│   │   ├── user.controller.ts
│   │   └── order.controller.ts
│   └── gui/
│       └── dashboard.controller.ts
│
├── dto/                           # Data Transfer Objects
│   ├── request/
│   │   └── create-user.request.ts
│   └── response/
│       ├── user.response.ts
│       └── api.response.ts
│
├── infrastructure/                # Cross-cutting
│   ├── database/
│   │   └── database.module.ts
│   ├── config/
│   │   └── config.module.ts
│   └── filters/
│       └── http-exception.filter.ts
│
├── app.module.ts
└── main.ts

test/
├── unit/
│   ├── domain/
│   ├── service/
│   └── mapper/
└── integration/
    ├── repository/
    └── controller/
```

## Code Standards

### Entity (Domain Layer)

```typescript
// src/domain/entities/user.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  email: string;

  @Column({ name: 'first_name' })
  firstName: string;

  @Column({ name: 'last_name' })
  lastName: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

### Repository Interface & Implementation

```typescript
// src/repository/interfaces/user.repository.interface.ts
import { User } from '../../domain/entities/user.entity';

export interface IUserRepository {
  findById(id: number): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  findAll(): Promise<User[]>;
  findByIds(ids: number[]): Promise<User[]>;
  save(user: User): Promise<User>;
  delete(user: User): Promise<void>;
}

export const USER_REPOSITORY = Symbol('IUserRepository');

// src/repository/user.repository.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { User } from '../domain/entities/user.entity';
import { IUserRepository } from './interfaces/user.repository.interface';

@Injectable()
export class UserRepository implements IUserRepository {
  private readonly logger = new Logger(UserRepository.name);

  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}

  async findById(id: number): Promise<User | null> {
    return this.repository.findOne({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.repository.findOne({ where: { email } });
  }

  async findAll(): Promise<User[]> {
    return this.repository.find();
  }

  async findByIds(ids: number[]): Promise<User[]> {
    const CHUNK_SIZE = 900; // Oracle IN clause limit safety
    const results: User[] = [];

    for (let i = 0; i < ids.length; i += CHUNK_SIZE) {
      const chunk = ids.slice(i, i + CHUNK_SIZE);
      const chunkResults = await this.repository.find({
        where: { id: In(chunk) },
      });
      results.push(...chunkResults);
    }

    return results;
  }

  async save(user: User): Promise<User> {
    return this.repository.save(user);
  }

  async delete(user: User): Promise<void> {
    await this.repository.remove(user);
  }
}
```

### Service (Business Logic Layer)

```typescript
// src/service/user.service.ts
import {
  Injectable,
  Inject,
  Logger,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import {
  IUserRepository,
  USER_REPOSITORY,
} from '../repository/interfaces/user.repository.interface';
import { UserMapper } from '../mapper/user.mapper';
import { CreateUserRequest } from '../dto/request/create-user.request';
import { UserResponse } from '../dto/response/user.response';

@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  constructor(
    @Inject(USER_REPOSITORY)
    private readonly userRepository: IUserRepository,
    private readonly userMapper: UserMapper,
  ) {}

  async findById(id: number): Promise<UserResponse> {
    this.logger.debug(`Finding user by ID: ${id}`);

    const user = await this.userRepository.findById(id);
    if (!user) {
      throw new NotFoundException(`User not found: ${id}`);
    }

    return this.userMapper.toResponse(user);
  }

  async findAll(): Promise<UserResponse[]> {
    this.logger.debug('Finding all users');

    const users = await this.userRepository.findAll();
    return users.map((u) => this.userMapper.toResponse(u));
  }

  async create(request: CreateUserRequest): Promise<UserResponse> {
    this.logger.log(`Creating user: ${request.email}`);

    const existing = await this.userRepository.findByEmail(request.email);
    if (existing) {
      throw new ConflictException('Email already exists');
    }

    const user = this.userMapper.toEntity(request);
    const saved = await this.userRepository.save(user);

    return this.userMapper.toResponse(saved);
  }
}
```

### Mapper (Transformation Layer)

```typescript
// src/mapper/user.mapper.ts
import { Injectable } from '@nestjs/common';
import { User } from '../domain/entities/user.entity';
import { CreateUserRequest } from '../dto/request/create-user.request';
import { UserResponse } from '../dto/response/user.response';

@Injectable()
export class UserMapper {
  toResponse(user: User): UserResponse {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      createdAt: user.createdAt,
    };
  }

  toEntity(request: CreateUserRequest): User {
    const user = new User();
    user.email = request.email;
    user.firstName = request.firstName;
    user.lastName = request.lastName;
    return user;
  }
}
```

### Controller (HTTP Layer)

```typescript
// src/controller/api/user.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse as SwaggerResponse } from '@nestjs/swagger';
import { UserService } from '../../service/user.service';
import { CreateUserRequest } from '../../dto/request/create-user.request';
import { UserResponse } from '../../dto/response/user.response';
import { ApiResponse } from '../../dto/response/api.response';

@ApiTags('users')
@Controller('api/users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  @SwaggerResponse({ status: 200, description: 'User found' })
  @SwaggerResponse({ status: 404, description: 'User not found' })
  async getUser(
    @Param('id', ParseIntPipe) id: number,
  ): Promise<ApiResponse<UserResponse>> {
    const user = await this.userService.findById(id);
    return ApiResponse.success(user);
  }

  @Get()
  @ApiOperation({ summary: 'Get all users' })
  async getAllUsers(): Promise<ApiResponse<UserResponse[]>> {
    const users = await this.userService.findAll();
    return ApiResponse.success(users);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create new user' })
  @SwaggerResponse({ status: 201, description: 'User created' })
  @SwaggerResponse({ status: 409, description: 'Email already exists' })
  async createUser(
    @Body() request: CreateUserRequest,
  ): Promise<ApiResponse<UserResponse>> {
    const user = await this.userService.create(request);
    return ApiResponse.success(user);
  }
}
```

### DTOs

```typescript
// src/dto/response/user.response.ts
export class UserResponse {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  createdAt: Date;
}

// src/dto/request/create-user.request.ts
import { IsEmail, IsNotEmpty, MaxLength } from 'class-validator';

export class CreateUserRequest {
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsNotEmpty()
  @MaxLength(100)
  firstName: string;

  @IsNotEmpty()
  @MaxLength(100)
  lastName: string;
}

// src/dto/response/api.response.ts
export class ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;

  static success<T>(data: T): ApiResponse<T> {
    const response = new ApiResponse<T>();
    response.success = true;
    response.data = data;
    return response;
  }

  static fail<T>(error: string): ApiResponse<T> {
    const response = new ApiResponse<T>();
    response.success = false;
    response.error = error;
    return response;
  }
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| Entity in response | Exposes internals | Use DTO |
| Repository in controller | Violates layers | Use Service |
| `any` type | Loses type safety | Proper interfaces |
| Callback-style async | Hard to read/maintain | async/await |
| Direct module imports | Tight coupling | Dependency injection |

## cognitive-core Skills

Install the Node.js cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/nodejs-nestjs/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `dependency_injection` | 100% |
| `typescript_strict` | 100% |
| `dto_validation` | 100% |
| `repository_interface` | 100% |
| `async_await` | 100% |
| `logger_usage` | 100% |
| `test_coverage` | 70% |

## Testing

```bash
# Run all tests
npm run test

# Run with coverage
npm run test:cov

# Run e2e tests
npm run test:e2e

# Run specific test
npm run test -- --testPathPattern=user.service
```

## See Also

- [perl-ddd/](../perl-ddd/) - Same patterns in Perl
- [java-spring/](../java-spring/) - Same patterns in Java
- [angular-ui/](../angular-ui/) - Frontend example

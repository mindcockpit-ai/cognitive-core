# C# .NET Core DDD Architecture Example

Enterprise C# application using .NET Core and Domain-Driven Design patterns.

## Stack

- **Language**: C# 12 / .NET 8
- **Framework**: ASP.NET Core Web API
- **ORM**: Entity Framework Core
- **Database**: Oracle/SQL Server/PostgreSQL (abstracted)

## Project Structure

```
src/
├── MyApp.Domain/                  # Pure business logic (class library)
│   ├── Entities/
│   │   ├── User.cs
│   │   ├── Order.cs
│   │   └── Product.cs
│   ├── ValueObjects/
│   │   ├── Email.cs
│   │   ├── Money.cs
│   │   └── DateRange.cs
│   └── Events/
│       └── OrderCreatedEvent.cs
│
├── MyApp.Infrastructure/          # Data access (class library)
│   ├── Repositories/
│   │   ├── IUserRepository.cs
│   │   ├── UserRepository.cs
│   │   ├── IOrderRepository.cs
│   │   └── OrderRepository.cs
│   ├── Data/
│   │   ├── AppDbContext.cs
│   │   └── Configurations/
│   │       └── UserConfiguration.cs
│   └── DependencyInjection.cs
│
├── MyApp.Application/             # Business orchestration (class library)
│   ├── Services/
│   │   ├── IUserService.cs
│   │   ├── UserService.cs
│   │   └── ImportService.cs
│   ├── Mappers/
│   │   ├── IUserMapper.cs
│   │   └── UserMapper.cs
│   ├── DTOs/
│   │   ├── Requests/
│   │   │   └── CreateUserRequest.cs
│   │   └── Responses/
│   │       ├── UserResponse.cs
│   │       └── ApiResponse.cs
│   └── DependencyInjection.cs
│
└── MyApp.Api/                     # HTTP layer (web project)
    ├── Controllers/
    │   ├── Api/
    │   │   ├── UserController.cs
    │   │   └── OrderController.cs
    │   └── Gui/
    │       └── DashboardController.cs
    ├── Middleware/
    │   └── ExceptionMiddleware.cs
    └── Program.cs

tests/
├── MyApp.Domain.Tests/
├── MyApp.Application.Tests/
└── MyApp.Api.Tests/
```

## Code Standards

### Entity (Domain Layer)

```csharp
// MyApp.Domain/Entities/User.cs
namespace MyApp.Domain.Entities;

public class User
{
    public int Id { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string FirstName { get; private set; } = string.Empty;
    public string LastName { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; private set; }

    // Private constructor for EF Core
    private User() { }

    public User(string email, string firstName, string lastName)
    {
        Email = email ?? throw new ArgumentNullException(nameof(email));
        FirstName = firstName ?? throw new ArgumentNullException(nameof(firstName));
        LastName = lastName ?? throw new ArgumentNullException(nameof(lastName));
        CreatedAt = DateTime.UtcNow;
    }

    public void UpdateName(string firstName, string lastName)
    {
        FirstName = firstName ?? throw new ArgumentNullException(nameof(firstName));
        LastName = lastName ?? throw new ArgumentNullException(nameof(lastName));
    }
}
```

### Repository Interface & Implementation

```csharp
// MyApp.Infrastructure/Repositories/IUserRepository.cs
namespace MyApp.Infrastructure.Repositories;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<IReadOnlyList<User>> GetAllAsync(CancellationToken ct = default);
    Task<IReadOnlyList<User>> GetByIdsAsync(IEnumerable<int> ids, CancellationToken ct = default);
    Task<User> AddAsync(User user, CancellationToken ct = default);
    Task UpdateAsync(User user, CancellationToken ct = default);
    Task DeleteAsync(User user, CancellationToken ct = default);
}

// MyApp.Infrastructure/Repositories/UserRepository.cs
namespace MyApp.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly AppDbContext _context;
    private readonly ILogger<UserRepository> _logger;

    public UserRepository(AppDbContext context, ILogger<UserRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<User?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        return await _context.Users.FindAsync(new object[] { id }, ct);
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken ct = default)
    {
        return await _context.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);
    }

    public async Task<IReadOnlyList<User>> GetAllAsync(CancellationToken ct = default)
    {
        return await _context.Users.ToListAsync(ct);
    }

    public async Task<IReadOnlyList<User>> GetByIdsAsync(
        IEnumerable<int> ids,
        CancellationToken ct = default)
    {
        const int ChunkSize = 900; // Oracle IN clause limit safety
        var idList = ids.ToList();
        var results = new List<User>();

        for (int i = 0; i < idList.Count; i += ChunkSize)
        {
            var chunk = idList.Skip(i).Take(ChunkSize).ToList();
            var chunkResults = await _context.Users
                .Where(u => chunk.Contains(u.Id))
                .ToListAsync(ct);
            results.AddRange(chunkResults);
        }

        return results;
    }

    public async Task<User> AddAsync(User user, CancellationToken ct = default)
    {
        await _context.Users.AddAsync(user, ct);
        await _context.SaveChangesAsync(ct);
        return user;
    }

    public async Task UpdateAsync(User user, CancellationToken ct = default)
    {
        _context.Users.Update(user);
        await _context.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(User user, CancellationToken ct = default)
    {
        _context.Users.Remove(user);
        await _context.SaveChangesAsync(ct);
    }
}
```

### Service (Application Layer)

```csharp
// MyApp.Application/Services/UserService.cs
namespace MyApp.Application.Services;

public class UserService : IUserService
{
    private readonly IUserRepository _repository;
    private readonly IUserMapper _mapper;
    private readonly ILogger<UserService> _logger;

    public UserService(
        IUserRepository repository,
        IUserMapper mapper,
        ILogger<UserService> logger)
    {
        _repository = repository;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<UserResponse> GetByIdAsync(int id, CancellationToken ct = default)
    {
        _logger.LogDebug("Finding user by ID: {UserId}", id);

        var user = await _repository.GetByIdAsync(id, ct);
        if (user is null)
        {
            throw new NotFoundException($"User not found: {id}");
        }

        return _mapper.ToResponse(user);
    }

    public async Task<IReadOnlyList<UserResponse>> GetAllAsync(CancellationToken ct = default)
    {
        _logger.LogDebug("Finding all users");

        var users = await _repository.GetAllAsync(ct);
        return users.Select(_mapper.ToResponse).ToList();
    }

    public async Task<UserResponse> CreateAsync(
        CreateUserRequest request,
        CancellationToken ct = default)
    {
        _logger.LogInformation("Creating user: {Email}", request.Email);

        var existing = await _repository.GetByEmailAsync(request.Email, ct);
        if (existing is not null)
        {
            throw new ConflictException("Email already exists");
        }

        var user = _mapper.ToEntity(request);
        var saved = await _repository.AddAsync(user, ct);

        return _mapper.ToResponse(saved);
    }
}
```

### Mapper (Application Layer)

```csharp
// MyApp.Application/Mappers/UserMapper.cs
namespace MyApp.Application.Mappers;

public class UserMapper : IUserMapper
{
    public UserResponse ToResponse(User user)
    {
        return new UserResponse
        {
            Id = user.Id,
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            CreatedAt = user.CreatedAt
        };
    }

    public User ToEntity(CreateUserRequest request)
    {
        return new User(
            request.Email,
            request.FirstName,
            request.LastName
        );
    }
}
```

### Controller (API Layer)

```csharp
// MyApp.Api/Controllers/Api/UserController.cs
namespace MyApp.Api.Controllers.Api;

[ApiController]
[Route("api/[controller]")]
public class UserController : ControllerBase
{
    private readonly IUserService _userService;

    public UserController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<UserResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUser(int id, CancellationToken ct)
    {
        var user = await _userService.GetByIdAsync(id, ct);
        return Ok(ApiResponse<UserResponse>.Success(user));
    }

    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<IReadOnlyList<UserResponse>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAllUsers(CancellationToken ct)
    {
        var users = await _userService.GetAllAsync(ct);
        return Ok(ApiResponse<IReadOnlyList<UserResponse>>.Success(users));
    }

    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<UserResponse>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreateUser(
        [FromBody] CreateUserRequest request,
        CancellationToken ct)
    {
        var user = await _userService.CreateAsync(request, ct);
        return CreatedAtAction(nameof(GetUser), new { id = user.Id },
            ApiResponse<UserResponse>.Success(user));
    }
}
```

### DTOs

```csharp
// MyApp.Application/DTOs/Responses/UserResponse.cs
namespace MyApp.Application.DTOs.Responses;

public class UserResponse
{
    public int Id { get; init; }
    public string Email { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
}

// MyApp.Application/DTOs/Requests/CreateUserRequest.cs
namespace MyApp.Application.DTOs.Requests;

public class CreateUserRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string FirstName { get; init; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string LastName { get; init; } = string.Empty;
}

// MyApp.Application/DTOs/Responses/ApiResponse.cs
namespace MyApp.Application.DTOs.Responses;

public class ApiResponse<T>
{
    public bool Success { get; init; }
    public T? Data { get; init; }
    public string? Error { get; init; }

    public static ApiResponse<T> Success(T data) =>
        new() { Success = true, Data = data };

    public static ApiResponse<T> Fail(string error) =>
        new() { Success = false, Error = error };
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| Entity in API response | Exposes internals | Use DTO |
| Repository in controller | Violates layers | Use Service |
| `async void` | Unhandled exceptions | `async Task` |
| Catching `Exception` | Hides errors | Specific exceptions |
| Service Locator | Hidden dependencies | Constructor DI |

## cognitive-core Skills

Install the C# cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/csharp-dotnet/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `constructor_injection` | 100% |
| `async_await_pattern` | 100% |
| `dto_usage` | 100% |
| `repository_interface` | 100% |
| `cancellation_token` | 90% |
| `structured_logging` | 100% |
| `test_coverage` | 70% |

## Testing

```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run specific test
dotnet test --filter "FullyQualifiedName~UserServiceTests"
```

## See Also

- [perl-ddd/](../perl-ddd/) - Same patterns in Perl
- [java-spring/](../java-spring/) - Same patterns in Java

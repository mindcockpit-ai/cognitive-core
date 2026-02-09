# Perl DDD Architecture Example

Enterprise Perl application using Moose and Domain-Driven Design patterns.

## Stack

- **Language**: Perl 5.26+
- **OOP Framework**: Moose
- **Web Framework**: Dancer2
- **ORM**: DBIx::Class
- **Database**: Oracle/PostgreSQL (abstracted)

## Project Structure

```
lib/
├── MyApp/
│   ├── Domain/                    # Pure business logic
│   │   ├── Entity/
│   │   │   ├── User.pm
│   │   │   ├── Order.pm
│   │   │   └── Product.pm
│   │   └── ValueObject/
│   │       ├── Email.pm
│   │       ├── Money.pm
│   │       └── DateRange.pm
│   │
│   ├── Repository/                # Data access layer
│   │   ├── UserRepository.pm
│   │   ├── OrderRepository.pm
│   │   └── ProductRepository.pm
│   │
│   ├── Service/                   # Business orchestration
│   │   ├── UserService.pm
│   │   ├── OrderService.pm
│   │   └── ImportService.pm
│   │
│   ├── Mapper/                    # DTO transformations
│   │   ├── UserMapper.pm
│   │   ├── OrderMapper.pm
│   │   └── DataTableMapper.pm
│   │
│   ├── Controller/                # HTTP layer
│   │   ├── Api/
│   │   │   ├── UserController.pm
│   │   │   └── OrderController.pm
│   │   └── Gui/
│   │       └── DashboardController.pm
│   │
│   ├── Infrastructure/            # Cross-cutting
│   │   ├── ConnectionManager.pm
│   │   ├── SchemaManager.pm
│   │   └── Config.pm
│   │
│   └── Util/                      # Utilities
│       ├── DateTime.pm
│       └── Validator.pm
│
├── Schema/                        # DBIx::Class schemas
│   └── Result/
│       ├── User.pm
│       └── Order.pm
│
└── t/                             # Tests mirror source
    ├── unit/
    │   ├── Domain/
    │   ├── Service/
    │   └── Mapper/
    └── integration/
        ├── Repository/
        └── Controller/
```

## Code Standards

### Module Template

```perl
package MyApp::Service::UserService;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Log::Log4perl qw(get_logger);

# Logger declaration (REQUIRED)
our $LOG = get_logger();

# Dependency injection (REQUIRED)
has 'userRepository' => (
    is       => 'ro',
    isa      => 'MyApp::Repository::UserRepository',
    required => 1,
);

has 'userMapper' => (
    is       => 'ro',
    isa      => 'MyApp::Mapper::UserMapper',
    required => 1,
);

# Method with proper parameter unpacking
sub findUserById {
    my $self = shift;
    my ($userId) = @_;

    $LOG->debug("Finding user by ID: $userId");

    try {
        my $user = $self->userRepository->findById($userId);
        return $self->userMapper->toDto($user);
    }
    catch {
        my $error = $_;
        $LOG->error("Failed to find user: $error");
        die $error;
    };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Repository Pattern

```perl
package MyApp::Repository::UserRepository;

use Moose;
use namespace::autoclean;

has 'schema' => (
    is       => 'ro',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

sub findById {
    my $self = shift;
    my ($id) = @_;

    return $self->schema->resultset('User')->find($id);
}

sub findByEmail {
    my $self = shift;
    my ($email) = @_;

    return $self->schema->resultset('User')->search({
        email => $email
    })->first;
}

# Bulk operations with chunking (for large datasets)
sub findByIds {
    my $self = shift;
    my ($idsRef) = @_;

    my @results;
    my $CHUNK_SIZE = 900;  # Oracle IN clause limit safety

    for (my $i = 0; $i < @$idsRef; $i += $CHUNK_SIZE) {
        my $end = $i + $CHUNK_SIZE - 1;
        $end = $#$idsRef if $end > $#$idsRef;
        my @chunk = @{$idsRef}[$i..$end];

        push @results, $self->schema->resultset('User')->search({
            id => { -in => \@chunk }
        })->all;
    }

    return \@results;
}

__PACKAGE__->meta->make_immutable;
1;
```

### Mapper Pattern

```perl
package MyApp::Mapper::UserMapper;

use Moose;
use namespace::autoclean;

sub toDto {
    my $self = shift;
    my ($user) = @_;

    return undef unless $user;

    return {
        id        => $user->id,
        email     => $user->email,
        firstName => $user->first_name,   # snake_case → camelCase
        lastName  => $user->last_name,
        createdAt => $user->created_at->iso8601,
    };
}

sub toDtoList {
    my $self = shift;
    my ($usersRef) = @_;

    return [ map { $self->toDto($_) } @$usersRef ];
}

sub toEntity {
    my $self = shift;
    my ($dto) = @_;

    return {
        email      => $dto->{email},
        first_name => $dto->{firstName},
        last_name  => $dto->{lastName},
    };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Controller Pattern

```perl
package MyApp::Controller::Api::UserController;

use Moose;
use namespace::autoclean;
use Dancer2 appname => 'MyApp';
use Try::Tiny;

has 'userService' => (
    is       => 'ro',
    isa      => 'MyApp::Service::UserService',
    required => 1,
);

sub getUser {
    my $self = shift;
    my ($id) = @_;

    try {
        my $user = $self->userService->findUserById($id);

        return {
            success => \1,
            data    => $user,
        };
    }
    catch {
        status 500;
        return {
            success => \0,
            error   => 'Failed to retrieve user',
        };
    };
}

# Routes defined in separate route file
# get '/api/users/:id' => sub { $controller->getUser(route_parameters->get('id')) };

__PACKAGE__->meta->make_immutable;
1;
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| `use Exporter` | Not OO, namespace pollution | Use Moose |
| `eval { }` | Unreliable error handling | Use Try::Tiny |
| `HashRefInflator` | Bypasses domain logic | Use Mapper |
| Direct schema in controller | Violates DDD layers | Use Service → Repository |
| `my @arr = @$ref` | Wastes memory | Iterate `@$ref` directly |

## cognitive-core Skills

Install the Perl cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/perl-project/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `moose_structure` | 100% |
| `try_tiny_usage` | 100% |
| `shift_pattern` | 100% |
| `logger_declared` | 100% |
| `no_hashref_inflator` | 100% |
| `repository_pattern` | 100% |
| `test_coverage` | 70% |

## Testing

```bash
# Run all tests
prove -l t/

# Run with coverage
HARNESS_PERL_SWITCHES=-MDevel::Cover prove -l t/

# Run specific test
prove -l t/unit/Service/UserService.t
```

## See Also

- [java-spring/](../java-spring/) - Same patterns in Java
- [python-fastapi/](../python-fastapi/) - Same patterns in Python

---
name: perl-patterns
extends: global:check-pattern
description: Perl/Moose patterns and standards template. Copy and customize for your Perl project.
argument-hint: [pattern-type] [file]
allowed-tools: Read, Grep, Glob, Edit
---

# Perl Patterns (Template)

Cellular skill template for Perl/Moose projects. Extend and customize for your specific project.

## How to Use This Template

1. Copy to your project: `cp -r . .claude/skills/perl-patterns/`
2. Customize patterns for your codebase
3. Add project-specific anti-patterns
4. Configure fitness thresholds

## Moose Standards

### Required Structure

```perl
package MyProject::Module;

use Moose;                      # REQUIRED
use namespace::autoclean;       # REQUIRED - prevents namespace pollution

# ... attributes and methods ...

__PACKAGE__->meta->make_immutable;  # REQUIRED - performance optimization
1;
```

### Attribute Patterns

```perl
# CORRECT: Lazy builder with underscore prefix
has 'config' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_buildConfig',    # Builder prefix: _build
);

sub _buildConfig {
    my $self = shift;
    return {};
}

# CORRECT: Required attribute
has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);
```

## Error Handling

### Required: Try::Tiny

```perl
use Try::Tiny;

# CORRECT
try {
    $self->riskyOperation();
}
catch {
    my $error = $_;
    $self->log->error("Operation failed: $error");
    # Handle or rethrow
};

# WRONG - Never use eval{}
eval {
    $self->riskyOperation();
};
if ($@) {
    # This is unreliable!
}
```

## Parameter Unpacking

### Required: shift Pattern

```perl
# CORRECT
sub myMethod {
    my $self = shift;
    my ($param1, $param2) = @_;
    # ...
}

# CORRECT: Named parameters
sub myMethod {
    my $self = shift;
    my %args = @_;
    my $param1 = $args{param1};
    # ...
}

# WRONG: Unpacking $self with parameters
sub myMethod {
    my ($self, $param1, $param2) = @_;  # Don't do this
}
```

## Dependency Injection

### Required: Constructor Injection

```perl
# CORRECT: Inject dependencies
has 'repository' => (
    is       => 'ro',
    isa      => 'MyProject::Repository::UserRepository',
    required => 1,
);

has 'logger' => (
    is      => 'ro',
    isa     => 'Log::Log4perl::Logger',
    lazy    => 1,
    default => sub { Log::Log4perl->get_logger(__PACKAGE__) },
);

# WRONG: Creating dependencies internally
sub doSomething {
    my $self = shift;
    my $repo = MyProject::Repository::UserRepository->new();  # Don't do this!
}
```

## Logging

### Required: Logger Declaration

```perl
package MyProject::Service::UserService;

use Moose;
use namespace::autoclean;
use Log::Log4perl qw(get_logger);

# REQUIRED: Declare logger
our $LOG = get_logger();

sub createUser {
    my $self = shift;
    my ($userData) = @_;

    $LOG->info("Creating user: $userData->{email}");
    # ...
}
```

## Anti-Patterns

### Never Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `use Exporter` | Not OO, pollutes namespace | Use Moose |
| `eval { }` | Unreliable error handling | Use Try::Tiny |
| `$@` checking | Can be clobbered | Use Try::Tiny catch |
| Direct `new()` | Hard to test, tight coupling | Dependency injection |
| Global variables | Hard to test, side effects | Attributes |

## Fitness Criteria

| Function | Threshold | Description |
|----------|-----------|-------------|
| `moose_structure` | 100% | namespace::autoclean, make_immutable |
| `try_tiny` | 100% | Error handling uses Try::Tiny |
| `param_unpacking` | 100% | Uses shift pattern |
| `logging` | 100% | $LOG declared and used |
| `builder_naming` | 100% | _buildXxx prefix |
| `no_exporter` | 100% | No use Exporter |
| `no_eval` | 100% | No eval{} for errors |

## Customization Points

### Add Your Project Patterns

```markdown
## Project-Specific Patterns

### Database Access
- Always use Repository pattern
- Never access schema directly in controllers

### API Responses
- Use Mapper for all API responses
- Never return domain objects directly
```

### Add Your Anti-Patterns

```markdown
## Project Anti-Patterns

| Anti-Pattern | Location | Why |
|--------------|----------|-----|
| `HashRefInflator` | Anywhere | Bypasses domain logic |
| Direct schema | Controllers | Violates DDD layers |
```

## Usage

```bash
# Check specific pattern
/perl-patterns moose lib/MyModule.pm

# Check all patterns
/perl-patterns all lib/

# List available patterns
/perl-patterns --list
```

## See Also

- `/oracle-patterns` - Database patterns (if using Oracle)
- `/pre-commit` - Pre-commit checks
- `/code-review` - Full code review

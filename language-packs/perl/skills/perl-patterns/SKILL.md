---
name: perl-patterns
description: Perl/Moose coding patterns, idioms, and anti-patterns for domain-driven projects.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Perl Patterns -- Quick Reference

Background knowledge for Perl/Moose projects. Auto-loaded for pattern guidance.

## Moose Class Template

```perl
package MyApp::Domain::Entity;
use Moose;
use namespace::autoclean;
has 'id'   => (is => 'ro', isa => 'Int', required => 1);
has 'name' => (is => 'rw', isa => 'Str', required => 1);
sub validate { my ($self) = @_; die "Empty name" unless length($self->name); 1 }
__PACKAGE__->meta->make_immutable;
1;
```

## Error Handling -- Always Try::Tiny, never bare `eval {}`

```perl
use Try::Tiny;
try { $repo->save($entity) }
catch { $logger->error("Save failed: $_"); die "Could not save: $_" };
```

## Array/Hash Reference Rules

| Pattern | Wrong | Correct |
|---------|-------|---------|
| Iterate | `my @arr = @$ref; foreach (@arr)` | `foreach (@$ref)` |
| Chunk | `my @copy = @$ref; splice(...)` | `@{$ref}[$i..$end]` |
| Return | `return @array` | `return \@array` |
| Pass | `func(@array)` | `func(\@array)` |

## DDD Layer Pattern

```
Domain (pure logic) -> Repository (data access) -> Mapper (transform) -> Controller (HTTP)
```

- Domain: Moose classes, no DB imports
- Repository: DBIx::Class queries, returns domain objects
- Mapper: Transforms between domain and presentation
- Controller: Route handlers, calls repository/mapper

## DateTime Safety

```perl
# WITH InflateColumn::DateTime in schema
$rs->create({ date_field => DateTime->now });

# WITHOUT InflateColumn::DateTime
use MyApp::Util::DateTime qw(formatOracleDateTime);
$rs->create({ date_field => formatOracleDateTime(DateTime->now) });
```

Never use string-returning `now()` functions for database fields.

## Common Anti-Patterns

- HashRefInflator bypasses domain logic -- use repositories
- Direct DB access from controllers -- use repository layer
- Exporter for OO modules -- use Moose
- `eval {}` without Try::Tiny -- loses error context
- Copying large arrays -- iterate references directly

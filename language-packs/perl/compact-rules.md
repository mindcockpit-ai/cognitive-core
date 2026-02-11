## Perl Critical Rules (Post-Compaction)

1. **Moose Required**: ALL business modules use Moose + `namespace::autoclean`. No Exporter for OO code.
2. **strict/warnings**: Every file starts with `use strict; use warnings;`. No exceptions.
3. **DateTime Safety**: Never use `now()` returning strings. Use `DateTime->now` objects. Check schema for `InflateColumn::DateTime` before choosing format.
4. **Array/Hash References**: Never copy arrays (`my @arr = @$ref`). Iterate directly: `foreach (@$ref)`. Return references: `return \@results`. Chunk with slices: `@{$ref}[$i..$end]`.
5. **Domain-Driven Design**: Domain -> Repository -> Mapper -> Controller. No HashRefInflator. No direct DB access from controllers. Use Try::Tiny for all error handling.

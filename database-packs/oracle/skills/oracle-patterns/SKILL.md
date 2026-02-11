---
name: oracle-patterns
description: Oracle database patterns, common ORA errors, and DBIx::Class integration guidance.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Oracle Patterns -- Quick Reference

Background knowledge for Oracle database projects. Auto-loaded for pattern guidance.

## Common ORA Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| ORA-01861 | Date format mismatch | Check InflateColumn, use DateTime objects |
| ORA-01795 | IN clause > 1000 | Chunk to 900 items |
| ORA-00001 | Unique constraint | Check for existing record first |
| ORA-02291 | FK constraint | Ensure parent record exists |
| ORA-00904 | Invalid identifier | Verify column name in schema |

## Date Handling Pattern

```perl
# Step 1: Check schema class
# __PACKAGE__->load_components(qw/InflateColumn::DateTime/);

# WITH InflateColumn::DateTime
$rs->create({ date_field => DateTime->now });

# WITHOUT InflateColumn::DateTime
use MyApp::Util::DateTime qw(formatOracleDateTime);
$rs->create({ date_field => formatOracleDateTime(DateTime->now) });
```

## IN Clause Chunking (ORA-01795)

```perl
my $CHUNK_SIZE = 900;
for (my $i = 0; $i < @$idsRef; $i += $CHUNK_SIZE) {
    my $end = $i + $CHUNK_SIZE - 1;
    $end = $#$idsRef if $end > $#$idsRef;
    my @chunk = @{$idsRef}[$i..$end];

    my @results = $schema->resultset('Table')->search({
        id => { -in => \@chunk }
    })->all;
}
```

## Bulk Operations

```perl
# Efficient bulk insert with populate()
$rs->populate([
    { col1 => 'val1', col2 => 'val2' },
    { col1 => 'val3', col2 => 'val4' },
]);

# Bulk update with search + update
$rs->search({ status => 'pending' })->update({ status => 'active' });
```

## Performance Tips

- Use `prefetch` for related tables to avoid N+1 queries
- Limit columns with `columns => [...]` when not all fields are needed
- Use `rows` and `page` for pagination
- `DBIC_TRACE=1` environment variable to debug generated SQL
- Avoid `->all` on large result sets; iterate with `->next` or `->cursor`

## Encoding (NLS_LANG)

When AL32UTF8 database has Windows-1252 data, `unset NLS_LANG` before starting the
application to prevent double-encoding that breaks JSON serialization.

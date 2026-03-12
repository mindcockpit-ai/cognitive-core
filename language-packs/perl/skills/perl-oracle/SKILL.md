---
name: perl-oracle
description: "Perl DBI/DBIx::Class patterns for Oracle databases. Connection handling, InflateColumn::DateTime, IN clause chunking, bulk operations, and DBIC_TRACE debugging."
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: "Perl Oracle patterns — DBI, DBIx::Class, InflateColumn, chunking."
---

# Perl Oracle Patterns -- Quick Reference

Background knowledge for Perl projects using Oracle via DBI/DBIx::Class.

## DBI Connection

```perl
use DBI;

my $dbh = DBI->connect(
    'dbi:Oracle:host=dbhost;sid=ORCL',
    $username,
    $password,
    { RaiseError => 1, AutoCommit => 0, ora_charset => 'AL32UTF8' }
);
```

## DBIx::Class Connection (Schema)

```perl
my $schema = MyApp::Schema->connect(
    'dbi:Oracle:host=dbhost;sid=ORCL',
    $username,
    $password,
    { quote_names => 1, on_connect_do => ["ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'"] }
);
```

## Date Handling with InflateColumn::DateTime

Always check the schema class for InflateColumn before writing dates.

```perl
# Step 1: Check schema class for this line:
# __PACKAGE__->load_components(qw/InflateColumn::DateTime/);

# WITH InflateColumn::DateTime — pass DateTime objects
$rs->create({ date_field => DateTime->now });

# WITHOUT InflateColumn::DateTime — format manually
use MyApp::Util::DateTime qw(formatOracleDateTime);
$rs->create({ date_field => formatOracleDateTime(DateTime->now) });
```

**Rule**: Never pass formatted date strings to InflateColumn fields.
InflateColumn expects DateTime objects and handles formatting internally.

## IN Clause Chunking (ORA-01795)

Oracle limits IN clauses to 1000 expressions. Chunk to 900 max.
Use array slicing — never copy-then-splice.

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

**Anti-pattern**: Do not copy the array first (`my @copy = @$ref; splice(...)`) —
iterate references directly with array slices.

## Parameterized Queries

```perl
# DBIx::Class — always use search conditions (auto-parameterized)
my @rows = $rs->search({ status => 'active', type => $type })->all;

# IN clause with bind
my @rows = $rs->search({ id => { -in => \@ids } })->all;

# Raw DBI — use bind variables
my $sth = $dbh->prepare('SELECT * FROM orders WHERE status = :1');
$sth->execute($status);
```

Never interpolate variables into SQL strings.

## Bulk Operations

```perl
# Efficient bulk insert with populate()
$rs->populate([
    { col1 => 'val1', col2 => 'val2' },
    { col1 => 'val3', col2 => 'val4' },
]);

# Bulk update with search + update
$rs->search({ status => 'pending' })->update({ status => 'active' });

# Bulk delete
$rs->search({ expired => 1 })->delete;
```

## Performance Tips

- `DBIC_TRACE=1` environment variable to see generated SQL
- `DBIC_TRACE=1=/tmp/dbic.log` to log SQL to a file
- Use `prefetch` for related tables to avoid N+1 queries
- Limit columns with `columns => [...]` when not all fields are needed
- Use `rows` and `page` for pagination
- Avoid `->all` on large result sets; iterate with `->next` or `->cursor`
- Avoid `HashRefInflator` when domain logic is needed — it bypasses result class methods

## Encoding (NLS_LANG)

When an AL32UTF8 database has Windows-1252 data, `unset NLS_LANG` before starting
the application to prevent double-encoding that breaks JSON serialization.

```perl
# In application startup or wrapper script
delete $ENV{NLS_LANG};

# Or set explicitly
$ENV{NLS_LANG} = 'AMERICAN_AMERICA.AL32UTF8';
```

## Oracle Critical Rules (Post-Compaction)

1. **ORA-01861 Date Format**: Check schema for `InflateColumn::DateTime` before writing dates. With InflateColumn: pass `DateTime->now` objects. Without: use `formatOracleDateTime(DateTime->now)`. Never pass formatted strings to InflateColumn fields.
2. **ORA-01795 IN Clause**: Oracle limits IN clauses to 1000 expressions. Always chunk to 900 items max. Use array slicing: `@{$ref}[$i..$end]`, never copy-then-splice.
3. **InflateColumn Awareness**: Always check `__PACKAGE__->load_components(...)` in the schema class before choosing date handling. Tables WITH InflateColumn and WITHOUT require different patterns.
4. **NLS_LANG Encoding**: Windows-1252 data in AL32UTF8 databases causes JSON encoding failures. Unset NLS_LANG before running the application when encoding issues appear.
5. **Parameterized Queries**: Never interpolate variables into SQL strings. Always use DBIx::Class search conditions or bind parameters. Use `{ -in => \@chunk }` for IN clauses.

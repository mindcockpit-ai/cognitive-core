## Oracle Critical Rules (Post-Compaction)

1. **ORA-01861 Date Format**: Always use explicit format masks with `TO_DATE()` and `TO_CHAR()`. Never rely on implicit NLS date conversion. Example: `TO_DATE('2026-03-12', 'YYYY-MM-DD')`.
2. **ORA-01795 IN Clause**: Oracle limits IN clauses to 1000 expressions. Always chunk to 900 items max. Split large value lists into multiple IN clauses joined with OR.
3. **NLS_LANG Encoding**: Windows-1252 data in AL32UTF8 databases causes encoding failures. Set `NLS_LANG` appropriately or unset it before running the application when encoding issues appear.
4. **Parameterized Queries**: Never interpolate variables into SQL strings. Always use bind variables (`:1`, `:name`) to prevent SQL injection and improve cursor sharing.
5. **Bulk Operations**: Prefer `INSERT ALL` or `MERGE` for multi-row inserts over individual INSERT statements. Use PL/SQL `FORALL` for bulk DML in stored procedures.

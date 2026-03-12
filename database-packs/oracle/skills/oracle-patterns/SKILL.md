---
name: oracle-patterns
description: Oracle database patterns, common ORA errors, date handling, bulk operations, and performance guidance.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Oracle Patterns -- Quick Reference

Background knowledge for Oracle database projects. Auto-loaded for pattern guidance.

## Common ORA Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| ORA-01861 | Date format mismatch | Use explicit `TO_DATE()` with format mask |
| ORA-01795 | IN clause > 1000 | Chunk to 900 items, combine with OR |
| ORA-00001 | Unique constraint | Check for existing record before insert |
| ORA-02291 | FK constraint | Ensure parent record exists |
| ORA-00904 | Invalid identifier | Verify column name matches table definition |
| ORA-01422 | Exact fetch returns more than one row | Add filters or use `FETCH FIRST 1 ROW ONLY` |
| ORA-06512 | PL/SQL backtrace | Read the stack trace to find the originating line |

## Date Handling

Always use explicit format masks. Never rely on implicit NLS conversion.

```sql
-- Insert with explicit format
INSERT INTO orders (order_date)
VALUES (TO_DATE('2026-03-12 14:30:00', 'YYYY-MM-DD HH24:MI:SS'));

-- Query with date formatting
SELECT TO_CHAR(order_date, 'YYYY-MM-DD HH24:MI:SS') AS formatted_date
FROM orders
WHERE order_date > TO_DATE('2026-01-01', 'YYYY-MM-DD');

-- Current timestamp
SELECT SYSTIMESTAMP FROM DUAL;
SELECT SYSDATE FROM DUAL;

-- Date arithmetic
SELECT SYSDATE + INTERVAL '30' DAY FROM DUAL;
SELECT ADD_MONTHS(SYSDATE, 3) FROM DUAL;
```

## IN Clause Chunking (ORA-01795)

Oracle limits IN clauses to 1000 expressions. Always chunk to 900 max.

```sql
-- WRONG: More than 1000 values
SELECT * FROM items WHERE id IN (1, 2, 3, ... , 1500);

-- CORRECT: Split into chunks joined with OR
SELECT * FROM items
WHERE id IN (1, 2, 3, ... , 900)
   OR id IN (901, 902, ... , 1500);

-- ALTERNATIVE: Use a temporary table or collection for very large sets
INSERT INTO temp_ids (id) VALUES (1), (2), ... ;
SELECT i.* FROM items i JOIN temp_ids t ON i.id = t.id;
```

Application code should loop over the value list in chunks of 900
and combine results, or insert values into a staging table and join.

## Bulk Operations

```sql
-- INSERT ALL: Multiple rows in a single statement
INSERT ALL
  INTO orders (id, customer_id, amount) VALUES (1, 100, 50.00)
  INTO orders (id, customer_id, amount) VALUES (2, 101, 75.00)
  INTO orders (id, customer_id, amount) VALUES (3, 102, 30.00)
SELECT 1 FROM DUAL;

-- MERGE: Upsert pattern
MERGE INTO target_table t
USING source_table s ON (t.id = s.id)
WHEN MATCHED THEN
  UPDATE SET t.name = s.name, t.updated_at = SYSDATE
WHEN NOT MATCHED THEN
  INSERT (id, name, created_at) VALUES (s.id, s.name, SYSDATE);

-- PL/SQL FORALL: Bulk DML in procedures
DECLARE
  TYPE id_array IS TABLE OF NUMBER;
  l_ids id_array := id_array(1, 2, 3, 4, 5);
BEGIN
  FORALL i IN 1..l_ids.COUNT
    UPDATE orders SET status = 'CLOSED' WHERE id = l_ids(i);
END;
/
```

## Performance Tips

- **Explain plans**: Use `EXPLAIN PLAN FOR <statement>` then `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY)` to inspect execution plans.
- **Bind variables**: Use `:name` placeholders instead of literals to improve cursor sharing and reduce hard parses.
- **Optimizer hints**: `/*+ INDEX(t idx_name) */`, `/*+ FULL(t) */`, `/*+ PARALLEL(t, 4) */` — use sparingly and document why.
- **Pagination**: Use `FETCH FIRST n ROWS ONLY` (12c+) or `ROWNUM` for older versions.
- **Avoid SELECT ***: List only the columns needed to reduce I/O and network overhead.
- **Index awareness**: Check `USER_INDEXES` and `USER_IND_COLUMNS` to verify queries use available indexes.

## Encoding (NLS_LANG)

When an AL32UTF8 database contains Windows-1252 data, set `NLS_LANG` appropriately
or unset it before starting the application to prevent double-encoding that breaks
downstream processing (JSON serialization, API responses, etc.).

```
-- Check current database character set
SELECT value FROM NLS_DATABASE_PARAMETERS WHERE parameter = 'NLS_CHARACTERSET';

-- Check session NLS settings
SELECT * FROM NLS_SESSION_PARAMETERS;
```

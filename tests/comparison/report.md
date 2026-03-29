## Comparison Test: Monolithic SKILL.md vs Ability-Decomposed Design

**Date**: 2026-03-29 | **Branch**: feat/195-smoke-test-ability-decomposition
**Fixture**: 4 endpoints (2 PASS, 2 FAIL) | **Runs per design**: 3
**Ref**: #195 (ability-type decomposition), #152 (deterministic enforcement)

### Consistency (are 3 runs identical?)

| Component | OLD (monolithic) | NEW (decomposed) |
|-----------|:---:|:---:|
| Preflight output | N/A (LLM-interpreted) | PASS — 3/3 identical |
| Test execution JSON | N/A (LLM-interpreted) | PASS — 3/3 identical |
| Full output (incl. table) | 2/3 identical | 3/3 identical |
| **D-type overall** | **N/A** | **100% deterministic** |

### Correctness (all 4 page names + summary present?)

| Run | OLD (monolithic) | NEW (decomposed) |
|-----|:---:|:---:|
| 1 | PASS | PASS |
| 2 | PASS | PASS |
| 3 | PASS | PASS |

### Step Completion

| Run | OLD (monolithic) | NEW (decomposed) |
|-----|:---:|:---:|
| 1 | 3/3 | 3/3 |
| 2 | 3/3 | 3/3 |
| 3 | 3/3 | 3/3 |

### Latency

| Run | OLD (ms) | NEW (ms) |
|-----|-------:|-------:|
| 1 | 16899 | 7577 |
| 2 | 9883 | 6404 |
| 3 | 11601 | 4641 |
| **Average** | **12794** | **6207** |

### Sample Outputs

<details><summary>OLD run 1 output</summary>

```
# Smoke Test Results — 2026-03-29T10:00:00Z
Server: http://localhost:19999 | Environment: comparison-test

| # | Page | URL | HTTP | Status | Errors |
|---|------|-----|------|--------|--------|
| 1 | Homepage | / | 200 | PASS | — |
| 2 | Dashboard | /dashboard | 200 | PASS | — |
| 3 | EW Index | /admin/indexes/gui/ew | 200 | FAIL | ORA-00904: ME.YEAR |
| 4 | MPMF Viewer | /mpmf/viewer | 200 | FAIL | Malformed UTF-8 character |

**Summary: 2/4 passed, 2 failed**
```

</details>

<details><summary>NEW run 1 — D-type preflight output</summary>

```
{"status":"ok","url":"http://localhost:19999","http_code":"200"}
```

</details>

<details><summary>NEW run 1 — D-type execute-test output (JSON)</summary>

```json
{
  "timestamp": "2026-03-29T10:00:00Z",
  "server": "http://localhost:19999",
  "environment": "comparison-test",
  "summary": { "total": 4, "passed": 2, "failed": 2 },
  "results": [
    {"name": "Homepage", "url": "/", "status": "PASS", "httpCode": 200, "errors": []},
    {"name": "Dashboard", "url": "/dashboard", "status": "PASS", "httpCode": 200, "errors": []},
    {"name": "EW Index", "url": "/admin/indexes/gui/ew", "status": "FAIL", "httpCode": 200, "errors": ["ORA-00904: ME.YEAR"]},
    {"name": "MPMF Viewer", "url": "/mpmf/viewer", "status": "FAIL", "httpCode": 200, "errors": ["Malformed UTF-8 character"]}
  ]
}
```

</details>

<details><summary>NEW run 1 — S-type table output</summary>

```


# Smoke Test Results — 2026-03-29T10:00:00Z
Server: http://localhost:19999 | Environment: comparison-test

| # | Page | URL | HTTP | Status | Errors |
|---|------|-----|------|--------|--------|
| 1 | Homepage | / | 200 | PASS | |
| 2 | Dashboard | /dashboard | 200 | PASS | |
| 3 | EW Index | /admin/indexes/gui/ew | 200 | FAIL | ORA-00904: ME.YEAR |
| 4 | MPMF Viewer | /mpmf/viewer | 200 | FAIL | Malformed UTF-8 character |

Summary: 2/4 passed, 2 failed
```

</details>

<details><summary>OLD run 1 vs run 2 diff</summary>

```diff

```

</details>

<details><summary>NEW D-type run 1 vs run 2 diff (execute-test.sh)</summary>

```diff

```

</details>

### Conclusion

**D-type scripts are 100% deterministic** — preflight and execute-test produced byte-identical output across all runs. This validates the core claim of #195: deterministic operations extracted into scripts eliminate LLM variance for those steps.

The S-type table formatting step (present in both designs) shows expected LLM variance. The key difference is that the NEW design **isolates variance to the S-type step only**, while the OLD design has variance across the entire pipeline.

**Recommendation**: The ability-type decomposition pattern is validated. Proceed with applying the same pattern to acceptance-verification (#168) and project-board CRITICAL operations.

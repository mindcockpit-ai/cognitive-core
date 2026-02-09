---
name: validate
description: Universal input validation with multiple validators. Use to verify emails, URLs, paths, JSON, YAML, or code syntax.
argument-hint: [type] [value]
allowed-tools: Read
---

# Validate

Atomic skill for input validation across multiple formats.

## Supported Types

| Type | Description | Example |
|------|-------------|---------|
| `email` | Email address format | `user@example.com` |
| `url` | URL format and accessibility | `https://example.com` |
| `path` | File/directory path existence | `/etc/passwd` |
| `json` | JSON syntax validity | `{"key": "value"}` |
| `yaml` | YAML syntax validity | `key: value` |
| `code` | Programming language syntax | `function foo() {}` |

## Usage

```bash
/validate email user@example.com
/validate url https://example.com
/validate path /home/user/file.txt
/validate json '{"name": "test"}'
/validate yaml 'key: value'
/validate code --lang=perl 'use strict;'
```

## Validation Rules

### Email
- RFC 5322 compliant format
- Domain has MX record (optional strict mode)
- No disposable email domains (optional)

### URL
- Valid scheme (http, https, ftp)
- Valid domain format
- Accessible (optional connectivity check)

### Path
- Exists on filesystem
- Correct type (file vs directory)
- Readable permissions

### JSON/YAML
- Valid syntax
- Optional schema validation

### Code
- Language-specific syntax check
- No obvious errors

## Output Format

```
VALIDATION RESULT
=================
Type: email
Value: user@example.com
Status: ✓ VALID

Details:
- Format: RFC 5322 compliant
- Domain: example.com (valid)
- Normalized: user@example.com
```

## Error Output

```
VALIDATION RESULT
=================
Type: json
Value: {"key": invalid}
Status: ✗ INVALID

Error:
- Position: character 9
- Message: Unexpected token 'i'
- Expected: string, number, object, array, true, false, or null
```

## Composition

This atomic skill is used by:
- `/pre-commit` - Validates file syntax before commit
- `/code-review` - Validates code patterns
- `/fitness` - Validates fitness criteria

## Options

- `--strict` - Enable strict validation mode
- `--quiet` - Only output pass/fail
- `--json` - Output as JSON for programmatic use

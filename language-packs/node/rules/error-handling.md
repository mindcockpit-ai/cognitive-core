---
paths: ["**/*.ts", "**/*.js"]
---

# Error Handling

## Custom Error Classes

- Define a base `DomainError` extending `Error` with a `code` property for programmatic identification
- Create specific error subclasses per domain concept: `UserNotFoundError`, `InsufficientBalanceError`
- Set `this.name = this.constructor.name` in the constructor for meaningful stack traces
- Never throw plain strings or generic `Error('something failed')` — always use typed errors

## Error Hierarchy

```
DomainError (abstract base)
  ├── NotFoundError          → 404
  ├── ValidationError        → 400
  ├── ConflictError          → 409
  ├── UnauthorizedError      → 401
  └── ForbiddenError         → 403
InfrastructureError (abstract base)
  ├── DatabaseError          → 500
  ├── ExternalServiceError   → 502
  └── TimeoutError           → 504
```

- Domain errors represent business rule violations — they carry no HTTP semantics
- Infrastructure errors wrap external failures — database, network, third-party APIs
- Map error types to HTTP status codes in the exception filter, not at the throw site

## Async Error Handling

- Always `await` promises — never leave a promise floating without error handling
- Use `try/catch` around `await` calls only when you can handle or enrich the error meaningfully
- Let unhandled errors propagate to the global exception filter — do NOT catch-and-rethrow without adding context
- Register a global `process.on('unhandledRejection')` handler that logs and exits with code 1

## Logging

- Log errors with structured context: `logger.error('Payment failed', { orderId, userId, error })`
- Use severity levels consistently: `error` for failures, `warn` for degraded state, `info` for business events, `debug` for troubleshooting
- Never log sensitive data: passwords, tokens, credit card numbers, PII
- Include correlation IDs in all log entries for request tracing across services
- Use NestJS `Logger` or a structured logger (Pino, Winston) — do NOT use `console.log` in production

## Principles

- Never swallow errors silently — at minimum log them before deciding to continue
- Fail fast on startup: missing config, unreachable database, invalid schema should crash the process
- Recoverable vs. fatal: retry transient failures (network timeout); crash on programmer errors (type mismatch)
- Return domain errors from services; let the transport layer (controller, message handler) decide the response format
- Use `Result<T, E>` pattern (or NestJS exception filters) — do NOT use error codes in return values

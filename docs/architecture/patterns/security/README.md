# Security Pattern

Comprehensive security architecture for protecting applications and data.

## Problem

- Unauthorized access to resources
- Data breaches and leaks
- Injection attacks (SQL, XSS, etc.)
- Session hijacking
- Privilege escalation

## Solution: Defense in Depth

```
┌────────────────────────────────────────────────────────────────┐
│                     Application Layer                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │   Input    │  │   Output   │  │   Error    │               │
│  │ Validation │  │  Encoding  │  │  Handling  │               │
│  └────────────┘  └────────────┘  └────────────┘               │
├────────────────────────────────────────────────────────────────┤
│                    Authentication Layer                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │   OAuth2   │  │    JWT     │  │    MFA     │               │
│  │   /OIDC    │  │   Tokens   │  │            │               │
│  └────────────┘  └────────────┘  └────────────┘               │
├────────────────────────────────────────────────────────────────┤
│                    Authorization Layer                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │    RBAC    │  │    ABAC    │  │  Resource  │               │
│  │            │  │            │  │   Scopes   │               │
│  └────────────┘  └────────────┘  └────────────┘               │
├────────────────────────────────────────────────────────────────┤
│                      Data Layer                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │ Encryption │  │  Secrets   │  │   Audit    │               │
│  │  at Rest   │  │ Management │  │   Logging  │               │
│  └────────────┘  └────────────┘  └────────────┘               │
└────────────────────────────────────────────────────────────────┘
```

## Abstract Interface

```python
# Authentication interface
class Authenticator(Protocol):
    def authenticate(self, credentials: Credentials) -> AuthResult: ...
    def validate_token(self, token: str) -> TokenClaims | None: ...
    def refresh_token(self, refresh_token: str) -> TokenPair: ...
    def revoke(self, token: str) -> None: ...

# Authorization interface
class Authorizer(Protocol):
    def authorize(self, subject: Subject, action: str, resource: Resource) -> bool: ...
    def get_permissions(self, subject: Subject) -> list[Permission]: ...

# Input validation interface
class Validator(Protocol):
    def validate(self, input: T, schema: Schema) -> ValidationResult: ...
    def sanitize(self, input: str) -> str: ...
```

```java
// Java interfaces
public interface Authenticator {
    AuthResult authenticate(Credentials credentials);
    Optional<TokenClaims> validateToken(String token);
    TokenPair refreshToken(String refreshToken);
    void revoke(String token);
}

public interface Authorizer {
    boolean authorize(Subject subject, String action, Resource resource);
    List<Permission> getPermissions(Subject subject);
}
```

## Security Patterns

### 1. Authentication

#### JWT Token Pattern

```python
# CORRECT: JWT with proper validation
class JWTAuthenticator:
    def __init__(self, secret: str, algorithm: str = "HS256"):
        self.secret = secret
        self.algorithm = algorithm

    def create_token(self, user: User) -> str:
        payload = {
            "sub": str(user.id),
            "email": user.email,
            "roles": user.roles,
            "iat": datetime.utcnow(),
            "exp": datetime.utcnow() + timedelta(hours=1),
        }
        return jwt.encode(payload, self.secret, algorithm=self.algorithm)

    def validate_token(self, token: str) -> TokenClaims | None:
        try:
            payload = jwt.decode(
                token,
                self.secret,
                algorithms=[self.algorithm],
                options={"require": ["exp", "sub"]}
            )
            return TokenClaims(**payload)
        except jwt.ExpiredSignatureError:
            raise AuthenticationError("Token expired")
        except jwt.InvalidTokenError:
            return None
```

#### OAuth2/OIDC Pattern

```python
class OAuth2Client:
    def __init__(self, config: OAuth2Config):
        self.config = config

    def get_authorization_url(self, state: str) -> str:
        params = {
            "client_id": self.config.client_id,
            "redirect_uri": self.config.redirect_uri,
            "response_type": "code",
            "scope": " ".join(self.config.scopes),
            "state": state,
        }
        return f"{self.config.authorize_url}?{urlencode(params)}"

    async def exchange_code(self, code: str) -> TokenResponse:
        response = await self.http.post(
            self.config.token_url,
            data={
                "grant_type": "authorization_code",
                "code": code,
                "client_id": self.config.client_id,
                "client_secret": self.config.client_secret,
                "redirect_uri": self.config.redirect_uri,
            }
        )
        return TokenResponse(**response.json())
```

### 2. Authorization

#### RBAC (Role-Based Access Control)

```python
class RBACAuthorizer:
    def __init__(self, role_permissions: dict[str, set[str]]):
        self.role_permissions = role_permissions

    def authorize(self, user: User, action: str, resource: Resource) -> bool:
        user_permissions = set()
        for role in user.roles:
            user_permissions.update(self.role_permissions.get(role, set()))

        required_permission = f"{resource.type}:{action}"
        return required_permission in user_permissions

# Configuration
role_permissions = {
    "admin": {"user:read", "user:write", "user:delete", "settings:write"},
    "user": {"user:read", "user:write"},
    "viewer": {"user:read"},
}
```

#### ABAC (Attribute-Based Access Control)

```python
class ABACAuthorizer:
    def __init__(self, policies: list[Policy]):
        self.policies = policies

    def authorize(self, context: AuthContext) -> bool:
        for policy in self.policies:
            if policy.matches(context):
                return policy.effect == "allow"
        return False  # Default deny

# Policy example
policy = Policy(
    effect="allow",
    actions=["document:read"],
    conditions=[
        Condition("subject.department", "equals", "resource.department"),
        Condition("resource.classification", "in", ["public", "internal"]),
    ]
)
```

### 3. Input Validation

```python
# CORRECT: Validate all inputs
from pydantic import BaseModel, EmailStr, Field, validator

class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=12)
    name: str = Field(..., min_length=1, max_length=100)

    @validator("password")
    def password_strength(cls, v):
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain uppercase")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain digit")
        if not any(c in "!@#$%^&*" for c in v):
            raise ValueError("Password must contain special char")
        return v

    @validator("name")
    def sanitize_name(cls, v):
        # Remove potential XSS
        return bleach.clean(v, tags=[], strip=True)
```

### 4. Secret Management

```python
# CORRECT: Never hardcode secrets
import os
from functools import lru_cache

class SecretManager:
    @lru_cache
    def get_secret(self, name: str) -> str:
        # Try environment first
        value = os.environ.get(name)
        if value:
            return value

        # Fall back to vault/secrets manager
        return self.vault_client.get_secret(name)

# Usage
secrets = SecretManager()
db_password = secrets.get_secret("DB_PASSWORD")

# WRONG: Hardcoded secrets
DB_PASSWORD = "super_secret_123"  # NEVER DO THIS!
```

## OWASP Top 10 Mitigations

| Vulnerability | Mitigation |
|---------------|------------|
| Injection | Parameterized queries, input validation |
| Broken Auth | Strong session management, MFA |
| Sensitive Data | Encryption at rest and in transit |
| XXE | Disable external entities |
| Broken Access | RBAC/ABAC, least privilege |
| Security Misconfig | Hardening, security headers |
| XSS | Output encoding, CSP |
| Deserialization | Avoid, or validate strictly |
| Components | Dependency scanning |
| Logging | Comprehensive audit logs |

## Implementation Examples

| Technology | Best For | Guide |
|------------|----------|-------|
| **OAuth2/OIDC** | SSO, third-party auth | [oauth2/](./implementations/oauth2/) |
| **JWT** | Stateless API auth | [jwt/](./implementations/jwt/) |
| **RBAC** | Simple role-based | [rbac/](./implementations/rbac/) |
| **Vault** | Secrets management | [vault/](./implementations/vault/) |

## Security Headers

```python
# FastAPI middleware example
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response
```

## Fitness Criteria

| Criteria | Threshold | Description |
|----------|-----------|-------------|
| `input_validation` | 100% | All inputs validated |
| `auth_required` | 100% | Protected endpoints require auth |
| `secrets_management` | 100% | No hardcoded secrets |
| `sql_injection` | 100% | Parameterized queries |
| `xss_prevention` | 100% | Output encoding |
| `security_headers` | 100% | All headers configured |
| `audit_logging` | 90% | Security events logged |
| `dependency_scan` | Weekly | Regular vulnerability scans |

## See Also

- [API Integration](../api-integration/) - Secure API consumption
- [Testing](../testing/) - Security testing
- [CI/CD](../ci-cd/) - Security in pipelines

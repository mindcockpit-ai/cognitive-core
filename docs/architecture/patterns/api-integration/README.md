# API Integration Pattern

Consuming external APIs and services reliably and maintainably.

## Problem

- External APIs have varying reliability
- Rate limits and quotas must be respected
- Failures need graceful handling
- API changes shouldn't break applications
- Multiple APIs often need unified interfaces

## Solution: API Client Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Application                            │
├──────────────────────────────────────────────────────────────┤
│                      Service Layer                            │
├──────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ API Client  │  │ API Client  │  │ API Client  │          │
│  │  (OpenAI)   │  │  (Stripe)   │  │ (Internal)  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
├─────────┼────────────────┼────────────────┼──────────────────┤
│         │      HTTP Client Layer          │                   │
│         │  (retry, timeout, circuit breaker)                 │
└─────────┼────────────────┼────────────────┼──────────────────┘
          ▼                ▼                ▼
    External APIs    External APIs    Internal Services
```

## Abstract Interface

```python
# Abstract API Client Interface
class ApiClient(Protocol):
    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        json: dict | None = None,
        headers: dict | None = None,
    ) -> ApiResponse: ...

    def get(self, path: str, **kwargs) -> ApiResponse: ...
    def post(self, path: str, **kwargs) -> ApiResponse: ...
    def put(self, path: str, **kwargs) -> ApiResponse: ...
    def delete(self, path: str, **kwargs) -> ApiResponse: ...

@dataclass
class ApiResponse:
    status: int
    data: dict | list | None
    headers: dict[str, str]
    elapsed: float

# Resilience wrapper
class ResilientClient(Protocol):
    def with_retry(self, max_attempts: int, backoff: float) -> Self: ...
    def with_timeout(self, seconds: float) -> Self: ...
    def with_circuit_breaker(self, threshold: int, reset: float) -> Self: ...
    def with_rate_limit(self, requests: int, period: float) -> Self: ...
```

```java
// Java Abstract Interface
public interface ApiClient {
    ApiResponse request(HttpMethod method, String path, RequestOptions options);
    ApiResponse get(String path, RequestOptions options);
    ApiResponse post(String path, Object body, RequestOptions options);
    ApiResponse put(String path, Object body, RequestOptions options);
    ApiResponse delete(String path, RequestOptions options);
}

public interface ResilientClient {
    ResilientClient withRetry(int maxAttempts, Duration backoff);
    ResilientClient withTimeout(Duration timeout);
    ResilientClient withCircuitBreaker(int threshold, Duration reset);
    ResilientClient withRateLimit(int requests, Duration period);
}
```

## Patterns

### 1. Repository Pattern for APIs

Treat external APIs like data repositories:

```python
class UserApiRepository:
    def __init__(self, client: ApiClient):
        self.client = client

    def find_by_id(self, user_id: str) -> User | None:
        response = self.client.get(f"/users/{user_id}")
        if response.status == 404:
            return None
        return User.from_dict(response.data)

    def create(self, request: CreateUserRequest) -> User:
        response = self.client.post("/users", json=request.to_dict())
        return User.from_dict(response.data)
```

### 2. Circuit Breaker

Prevent cascade failures:

```
Closed ──(failures > threshold)──► Open
   ▲                                  │
   │                            (timeout)
   │                                  ▼
   └────(success)──── Half-Open ◄────┘
```

### 3. Retry with Exponential Backoff

```python
def retry_with_backoff(
    func: Callable,
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
) -> Any:
    for attempt in range(max_attempts):
        try:
            return func()
        except RetryableError:
            if attempt == max_attempts - 1:
                raise
            delay = min(base_delay * (2 ** attempt), max_delay)
            time.sleep(delay + random.uniform(0, 1))  # Jitter
```

### 4. Rate Limiting

```python
class RateLimiter:
    def __init__(self, requests: int, period: float):
        self.requests = requests
        self.period = period
        self.tokens = requests
        self.last_update = time.time()

    def acquire(self) -> bool:
        self._refill()
        if self.tokens >= 1:
            self.tokens -= 1
            return True
        return False
```

## Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| Abstraction | Swap implementations | Extra layer |
| Resilience | Fault tolerance | Added latency |
| Caching | Performance | Staleness |
| Rate limiting | API compliance | Queuing |

## Implementation Examples

| Technology | Best For | Guide |
|------------|----------|-------|
| **OpenAI API** | LLM integration | [openai/](./implementations/openai/) |
| **REST Client** | General HTTP APIs | [rest/](./implementations/rest/) |
| **GraphQL** | Complex queries | [graphql/](./implementations/graphql/) |
| **gRPC** | High-performance RPC | [grpc/](./implementations/grpc/) |

## LLM Integration Example (OpenAI)

```python
# Abstract LLM interface
class LLMClient(Protocol):
    def complete(self, prompt: str, **kwargs) -> str: ...
    def chat(self, messages: list[Message], **kwargs) -> Message: ...
    def embed(self, text: str) -> list[float]: ...

# OpenAI implementation
class OpenAIClient(LLMClient):
    def __init__(self, api_key: str):
        self.client = OpenAI(api_key=api_key)

    def chat(self, messages: list[Message], **kwargs) -> Message:
        response = self.client.chat.completions.create(
            model=kwargs.get("model", "gpt-4"),
            messages=[m.to_dict() for m in messages],
            temperature=kwargs.get("temperature", 0.7),
        )
        return Message.from_openai(response.choices[0].message)

# Could swap to Anthropic, Ollama, etc.
class AnthropicClient(LLMClient): ...
class OllamaClient(LLMClient): ...
```

## Fitness Criteria

| Criteria | Threshold | Description |
|----------|-----------|-------------|
| `error_handling` | 100% | All errors properly handled |
| `timeout_config` | 100% | Timeouts on all calls |
| `retry_logic` | 90% | Retryable errors retried |
| `circuit_breaker` | 80% | Critical paths protected |
| `logging` | 100% | Request/response logged |
| `testing` | 70% | API clients tested |

## See Also

- [Messaging](../messaging/) - Async integration
- [Security](../security/) - API authentication
- [Testing](../testing/) - Testing API clients

# OpenAI API Integration

Implementation of the API Integration pattern for OpenAI/LLM services.

## Overview

This implementation provides a resilient, typed client for OpenAI's API with support for chat completions, embeddings, and function calling.

## Python Implementation

### Installation

```bash
pip install openai httpx tenacity
```

### Client Implementation

```python
from dataclasses import dataclass
from typing import Protocol, AsyncIterator
import openai
from tenacity import retry, stop_after_attempt, wait_exponential

# Abstract LLM interface
class LLMClient(Protocol):
    async def chat(
        self,
        messages: list[dict],
        model: str = "gpt-4",
        temperature: float = 0.7,
    ) -> str: ...

    async def chat_stream(
        self,
        messages: list[dict],
        model: str = "gpt-4",
    ) -> AsyncIterator[str]: ...

    async def embed(self, text: str) -> list[float]: ...


@dataclass
class OpenAIConfig:
    api_key: str
    organization: str | None = None
    timeout: float = 30.0
    max_retries: int = 3


class OpenAIClient(LLMClient):
    """Resilient OpenAI client with retry logic and streaming support."""

    def __init__(self, config: OpenAIConfig):
        self.client = openai.AsyncOpenAI(
            api_key=config.api_key,
            organization=config.organization,
            timeout=config.timeout,
        )
        self.max_retries = config.max_retries

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        reraise=True,
    )
    async def chat(
        self,
        messages: list[dict],
        model: str = "gpt-4",
        temperature: float = 0.7,
    ) -> str:
        response = await self.client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
        )
        return response.choices[0].message.content or ""

    async def chat_stream(
        self,
        messages: list[dict],
        model: str = "gpt-4",
    ) -> AsyncIterator[str]:
        stream = await self.client.chat.completions.create(
            model=model,
            messages=messages,
            stream=True,
        )
        async for chunk in stream:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
    )
    async def embed(self, text: str) -> list[float]:
        response = await self.client.embeddings.create(
            model="text-embedding-3-small",
            input=text,
        )
        return response.data[0].embedding


# Function calling example
async def chat_with_functions(
    client: OpenAIClient,
    messages: list[dict],
    functions: list[dict],
) -> dict:
    response = await client.client.chat.completions.create(
        model="gpt-4",
        messages=messages,
        functions=functions,
        function_call="auto",
    )
    message = response.choices[0].message
    if message.function_call:
        return {
            "type": "function_call",
            "name": message.function_call.name,
            "arguments": json.loads(message.function_call.arguments),
        }
    return {"type": "message", "content": message.content}
```

### Usage Example

```python
import asyncio
from openai_client import OpenAIClient, OpenAIConfig

async def main():
    config = OpenAIConfig(
        api_key=os.environ["OPENAI_API_KEY"],
        timeout=30.0,
    )
    client = OpenAIClient(config)

    # Simple chat
    response = await client.chat([
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is Python?"},
    ])
    print(response)

    # Streaming
    async for chunk in client.chat_stream([
        {"role": "user", "content": "Tell me a story."},
    ]):
        print(chunk, end="", flush=True)

    # Embeddings
    embedding = await client.embed("Hello, world!")
    print(f"Embedding dimension: {len(embedding)}")

asyncio.run(main())
```

## Java Implementation

### Maven Dependencies

```xml
<dependency>
    <groupId>com.theokanning.openai-gpt3-java</groupId>
    <artifactId>service</artifactId>
    <version>0.18.2</version>
</dependency>
```

### Client Implementation

```java
public class OpenAIClient implements LLMClient {
    private final OpenAiService service;
    private final RetryPolicy<Object> retryPolicy;

    public OpenAIClient(String apiKey, Duration timeout) {
        this.service = new OpenAiService(apiKey, timeout);
        this.retryPolicy = RetryPolicy.<Object>builder()
            .handle(OpenAiHttpException.class)
            .withDelay(Duration.ofSeconds(1))
            .withMaxRetries(3)
            .build();
    }

    public String chat(List<ChatMessage> messages, String model) {
        var request = ChatCompletionRequest.builder()
            .model(model)
            .messages(messages)
            .build();

        return Failsafe.with(retryPolicy).get(() -> {
            var response = service.createChatCompletion(request);
            return response.getChoices().get(0).getMessage().getContent();
        });
    }

    public List<Double> embed(String text) {
        var request = EmbeddingRequest.builder()
            .model("text-embedding-3-small")
            .input(List.of(text))
            .build();

        return Failsafe.with(retryPolicy).get(() -> {
            var response = service.createEmbeddings(request);
            return response.getData().get(0).getEmbedding();
        });
    }
}
```

## Testing

```python
import pytest
from unittest.mock import AsyncMock, patch

@pytest.fixture
def mock_openai():
    with patch("openai.AsyncOpenAI") as mock:
        yield mock

async def test_chat_returns_response(mock_openai):
    mock_response = AsyncMock()
    mock_response.choices = [
        AsyncMock(message=AsyncMock(content="Hello!"))
    ]
    mock_openai.return_value.chat.completions.create = AsyncMock(
        return_value=mock_response
    )

    client = OpenAIClient(OpenAIConfig(api_key="test"))
    result = await client.chat([{"role": "user", "content": "Hi"}])

    assert result == "Hello!"

async def test_chat_retries_on_error(mock_openai):
    mock_openai.return_value.chat.completions.create = AsyncMock(
        side_effect=[
            openai.RateLimitError("Rate limited"),
            AsyncMock(choices=[AsyncMock(message=AsyncMock(content="OK"))]),
        ]
    )

    client = OpenAIClient(OpenAIConfig(api_key="test"))
    result = await client.chat([{"role": "user", "content": "Hi"}])

    assert result == "OK"
```

## Best Practices

1. **Always use retry logic** - API calls can fail transiently
2. **Implement streaming** - Better UX for long responses
3. **Use typed responses** - Leverage Pydantic/dataclasses
4. **Handle rate limits** - Exponential backoff with jitter
5. **Secure API keys** - Never hardcode, use secrets manager

## See Also

- [API Integration Pattern](../../README.md)
- [REST Implementation](../rest/)
- [Testing Pattern](../../../testing/)

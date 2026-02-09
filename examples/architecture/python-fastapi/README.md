# Python FastAPI DDD Architecture Example

Enterprise Python application using FastAPI and Domain-Driven Design patterns.

## Stack

- **Language**: Python 3.11+
- **Framework**: FastAPI
- **ORM**: SQLAlchemy 2.0
- **Database**: Oracle/PostgreSQL (abstracted)
- **Validation**: Pydantic

## Project Structure

```
src/
├── domain/                        # Pure business logic
│   ├── entity/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── order.py
│   │   └── product.py
│   ├── value_object/
│   │   ├── email.py
│   │   ├── money.py
│   │   └── date_range.py
│   └── event/
│       └── order_created.py
│
├── repository/                    # Data access layer
│   ├── __init__.py
│   ├── base.py
│   ├── user_repository.py
│   ├── order_repository.py
│   └── product_repository.py
│
├── service/                       # Business orchestration
│   ├── __init__.py
│   ├── user_service.py
│   ├── order_service.py
│   └── import_service.py
│
├── mapper/                        # DTO transformations
│   ├── __init__.py
│   ├── user_mapper.py
│   ├── order_mapper.py
│   └── datatable_mapper.py
│
├── controller/                    # HTTP layer (routers)
│   ├── __init__.py
│   ├── api/
│   │   ├── user_controller.py
│   │   └── order_controller.py
│   └── gui/
│       └── dashboard_controller.py
│
├── dto/                           # Pydantic models
│   ├── __init__.py
│   ├── request/
│   │   └── user_request.py
│   └── response/
│       ├── user_response.py
│       └── api_response.py
│
├── infrastructure/                # Cross-cutting
│   ├── __init__.py
│   ├── database.py
│   ├── config.py
│   └── exception_handler.py
│
└── main.py                        # Application entry

tests/                             # Tests mirror source
├── unit/
│   ├── domain/
│   ├── service/
│   └── mapper/
└── integration/
    ├── repository/
    └── controller/
```

## Code Standards

### Entity (Domain Layer)

```python
# src/domain/entity/user.py
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from src.infrastructure.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email})>"
```

### Repository (Data Access Layer)

```python
# src/repository/user_repository.py
from typing import Optional, List
from sqlalchemy.orm import Session
from src.domain.entity.user import User
import logging

logger = logging.getLogger(__name__)


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_by_id(self, user_id: int) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    def find_by_email(self, email: str) -> Optional[User]:
        return self.db.query(User).filter(User.email == email).first()

    def find_all(self) -> List[User]:
        return self.db.query(User).all()

    def find_by_ids(self, ids: List[int]) -> List[User]:
        """Bulk fetch with automatic chunking for large lists."""
        CHUNK_SIZE = 900  # Oracle IN clause limit safety
        results = []

        for i in range(0, len(ids), CHUNK_SIZE):
            chunk = ids[i:i + CHUNK_SIZE]
            chunk_results = self.db.query(User).filter(User.id.in_(chunk)).all()
            results.extend(chunk_results)

        return results

    def save(self, user: User) -> User:
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def delete(self, user: User) -> None:
        self.db.delete(user)
        self.db.commit()
```

### Service (Business Logic Layer)

```python
# src/service/user_service.py
from typing import List, Optional
from fastapi import HTTPException, status
from src.domain.entity.user import User
from src.repository.user_repository import UserRepository
from src.mapper.user_mapper import UserMapper
from src.dto.request.user_request import CreateUserRequest
from src.dto.response.user_response import UserResponse
import logging

logger = logging.getLogger(__name__)


class UserService:
    def __init__(self, repository: UserRepository, mapper: UserMapper):
        self.repository = repository
        self.mapper = mapper

    def find_by_id(self, user_id: int) -> UserResponse:
        logger.debug(f"Finding user by ID: {user_id}")

        user = self.repository.find_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User not found: {user_id}"
            )

        return self.mapper.to_response(user)

    def find_all(self) -> List[UserResponse]:
        logger.debug("Finding all users")

        users = self.repository.find_all()
        return [self.mapper.to_response(u) for u in users]

    def create(self, request: CreateUserRequest) -> UserResponse:
        logger.info(f"Creating user: {request.email}")

        # Check for existing email
        existing = self.repository.find_by_email(request.email)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already exists"
            )

        user = self.mapper.to_entity(request)
        saved = self.repository.save(user)

        return self.mapper.to_response(saved)
```

### Mapper (Transformation Layer)

```python
# src/mapper/user_mapper.py
from typing import Optional
from src.domain.entity.user import User
from src.dto.request.user_request import CreateUserRequest
from src.dto.response.user_response import UserResponse


class UserMapper:
    def to_response(self, user: User) -> Optional[UserResponse]:
        if not user:
            return None

        return UserResponse(
            id=user.id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            created_at=user.created_at
        )

    def to_entity(self, request: CreateUserRequest) -> User:
        return User(
            email=request.email,
            first_name=request.first_name,
            last_name=request.last_name
        )
```

### Controller (HTTP Layer)

```python
# src/controller/api/user_controller.py
from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from src.infrastructure.database import get_db
from src.repository.user_repository import UserRepository
from src.service.user_service import UserService
from src.mapper.user_mapper import UserMapper
from src.dto.request.user_request import CreateUserRequest
from src.dto.response.user_response import UserResponse
from src.dto.response.api_response import ApiResponse

router = APIRouter(prefix="/api/users", tags=["users"])


def get_user_service(db: Session = Depends(get_db)) -> UserService:
    repository = UserRepository(db)
    mapper = UserMapper()
    return UserService(repository, mapper)


@router.get("/{user_id}", response_model=ApiResponse[UserResponse])
def get_user(user_id: int, service: UserService = Depends(get_user_service)):
    user = service.find_by_id(user_id)
    return ApiResponse(success=True, data=user)


@router.get("", response_model=ApiResponse[List[UserResponse]])
def get_all_users(service: UserService = Depends(get_user_service)):
    users = service.find_all()
    return ApiResponse(success=True, data=users)


@router.post("", response_model=ApiResponse[UserResponse], status_code=status.HTTP_201_CREATED)
def create_user(request: CreateUserRequest, service: UserService = Depends(get_user_service)):
    user = service.create(request)
    return ApiResponse(success=True, data=user)
```

### DTO Pattern (Pydantic)

```python
# src/dto/response/user_response.py
from datetime import datetime
from pydantic import BaseModel, EmailStr


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    created_at: datetime

    class Config:
        from_attributes = True  # SQLAlchemy compatibility


# src/dto/request/user_request.py
from pydantic import BaseModel, EmailStr, Field


class CreateUserRequest(BaseModel):
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)


# src/dto/response/api_response.py
from typing import Generic, TypeVar, Optional
from pydantic import BaseModel

T = TypeVar('T')


class ApiResponse(BaseModel, Generic[T]):
    success: bool
    data: Optional[T] = None
    error: Optional[str] = None

    @classmethod
    def ok(cls, data: T) -> "ApiResponse[T]":
        return cls(success=True, data=data)

    @classmethod
    def fail(cls, error: str) -> "ApiResponse[T]":
        return cls(success=False, error=error)
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Correct Pattern |
|--------------|---------|-----------------|
| SQLAlchemy model in response | Exposes internals, serialization issues | Use Pydantic DTO |
| Repository in controller | Violates DDD layers | Use Service |
| Business logic in controller | Hard to test, scattered logic | Use Service |
| Bare `except:` | Hides errors | Catch specific exceptions |
| Global db session | Thread safety issues | Dependency injection |

## cognitive-core Skills

Install the Python cellular skills:

```bash
cp -r cognitive-core/skills/cellular/templates/python-fastapi/* .claude/skills/
```

### Fitness Criteria

| Function | Threshold |
|----------|-----------|
| `dependency_injection` | 100% |
| `pydantic_dto` | 100% |
| `repository_pattern` | 100% |
| `type_hints` | 95% |
| `logging_usage` | 100% |
| `exception_handling` | 100% |
| `test_coverage` | 70% |

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test
pytest tests/unit/service/test_user_service.py
```

## See Also

- [perl-ddd/](../perl-ddd/) - Same patterns in Perl
- [java-spring/](../java-spring/) - Same patterns in Java

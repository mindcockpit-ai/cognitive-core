# Recipe: Architecture Analysis Workflow

> **Time**: ~3 min read | **Level**: Intermediate | **Language**: All

## Goal

Analyze your project's architecture using `@solution-architect` to get a component breakdown, coupling analysis, and actionable recommendations.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- `@solution-architect` agent available (installed by default)
- A project with multiple modules or layers to analyze

## Steps

### Step 1: Request an architecture analysis

```
@solution-architect analyze the architecture of this project
```

For a more focused analysis, specify the scope:

```
@solution-architect analyze the architecture of the order processing module
```

### Step 2: Review the component diagram

**Expected output:**
```
ARCHITECTURE ANALYSIS
=====================

COMPONENTS
----------
1. Controller Layer (src/controllers/)
   - 4 controllers, 12 endpoints
   - Depends on: Service Layer

2. Service Layer (src/services/)
   - 6 services
   - Depends on: Repository Layer, External APIs

3. Repository Layer (src/repositories/)
   - 5 repositories
   - Depends on: Database (PostgreSQL)

4. Domain Layer (src/models/)
   - 8 domain entities
   - No outward dependencies (correct)

DEPENDENCY DIRECTION
--------------------
Controller -> Service -> Repository -> Database
                      -> External APIs
Domain layer is dependency-free: PASS
```

### Step 3: Review coupling analysis

The architect identifies problematic dependencies:

```
COUPLING ANALYSIS
-----------------
[ARCH-01] HIGH COUPLING: OrderService imports 4 other services directly
  Impact:  Changes to any service cascade to OrderService
  Fix:     Introduce an event bus or mediator pattern

[ARCH-02] LAYER VIOLATION: UserController imports UserRepository directly
  Impact:  Bypasses service layer, business logic can be skipped
  Fix:     Route through UserService

[ARCH-03] CIRCULAR DEPENDENCY: OrderService <-> InventoryService
  Impact:  Cannot deploy or test independently
  Fix:     Extract shared logic into a new OrderInventoryCoordinator
```

### Step 4: Get recommendations

```
@solution-architect what are the top 3 improvements for this architecture?
```

**Expected output:**
```
RECOMMENDATIONS (priority order)
---------------------------------
1. Break the OrderService-InventoryService cycle
   Effort: Medium | Impact: High
   Extract coordination logic into a dedicated service.

2. Add a service layer for User operations
   Effort: Low | Impact: Medium
   UserController should never talk to UserRepository directly.

3. Introduce domain events for cross-service communication
   Effort: High | Impact: High
   Reduces coupling between OrderService and its 4 dependencies.
```

### Step 5: Design a specific feature

Once you understand the architecture, use the architect to design new features that fit:

```
@solution-architect design a notification system that sends emails
when order status changes — fit it into the existing architecture
```

The architect produces:
- Component placement (which layer, which module)
- Interface definitions
- Dependency analysis (what it needs, what depends on it)
- Trade-off discussion (synchronous vs async, polling vs events)

## What @solution-architect Analyzes

| Aspect | What It Checks |
|--------|---------------|
| **Layer structure** | Are layers properly separated? Any violations? |
| **Dependency direction** | Do dependencies flow inward (clean architecture)? |
| **Coupling** | Which components are tightly coupled? Circular dependencies? |
| **Cohesion** | Do modules have a single, clear responsibility? |
| **Scalability** | Are there bottlenecks or single points of failure? |
| **Patterns** | Which design patterns are in use? Are they appropriate? |

## Common Mistakes

| Mistake | Why | Do This Instead |
|---------|-----|-----------------|
| `@solution-architect review my code` | Architects analyze structure, not code quality | `@code-standards-reviewer review my code` |
| Ask for architecture + implementation in one turn | Mixing design and coding leads to shallow design | Design first, implement separately |
| Skip architecture for "small" changes | Small changes accumulate into architectural debt | Quick check: `@solution-architect does this change fit our architecture?` |

## Expected Output

After completing the workflow, you should have:
- A component breakdown with dependency directions
- A coupling analysis identifying violations and circular dependencies
- Prioritized recommendations with effort/impact ratings

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- review code after implementing architectural changes
- [Security Scan](recipe-security-scan.md) -- check security implications of architectural decisions
- [Coordinator Workflow](recipe-coordinator-workflow.md) -- let the coordinator orchestrate architecture + implementation
- `@solution-architect` agent: `core/agents/solution-architect.md`

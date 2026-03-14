---
name: struts-jsp-migration
description: Migration assessment and patterns for Struts/JSP to Spring Boot. Component mapping, risk analysis, incremental migration strategy.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: Struts/JSP to Spring Boot migration — assessment, component mapping, incremental strategy.
---

# Struts/JSP to Spring Boot — Migration Guide

## Migration Assessment Matrix

Before migrating, score each dimension:

| Dimension | Score 1-5 | Weight | Questions |
|-----------|----------|--------|-----------|
| Test coverage | | 3x | What % of Actions have tests? Are there integration tests? |
| Code complexity | | 2x | Average Action size? Cyclomatic complexity? God classes? |
| Database coupling | | 2x | Direct JDBC? Hibernate version? Stored procedures? |
| External integrations | | 2x | SOAP services? JMS? Custom protocols? |
| JSP complexity | | 1x | Scriptlet density? Custom tag libraries? |
| Team readiness | | 1x | Spring Boot experience? Training needed? |

**Total = sum(score x weight) / sum(weights). Below 2.5 = high risk, 2.5-3.5 = medium, above 3.5 = favorable.**

## Component Mapping

### Controllers

| Struts 1.x | Struts 2.x | Spring Boot |
|-----------|-----------|-------------|
| `Action.execute()` | `ActionSupport.execute()` | `@Controller` + `@RequestMapping` method |
| `ActionForm` | POJO properties | `@RequestBody` DTO or `@ModelAttribute` |
| `ActionForward` | `return "success"` | `return "viewName"` or `ResponseEntity` |
| `ActionMapping` | `struts.xml <action>` | `@GetMapping("/path")` |
| `DispatchAction` | method attribute | Multiple `@RequestMapping` methods |
| `ActionServlet` | `StrutsPrepareAndExecuteFilter` | `DispatcherServlet` (auto-configured) |

### Validation

| Struts | Spring Boot |
|--------|-------------|
| `ActionForm.validate()` | `@Valid` + Bean Validation (`@NotNull`, `@Size`) |
| `validation.xml` (Commons Validator) | `@Validated` groups |
| `<html:errors/>` | `BindingResult` + error view |
| Struts 2 `*-validation.xml` | Same Bean Validation annotations |

### View Layer

| JSP/Struts Tags | Spring Boot Options |
|----------------|---------------------|
| `<html:form>` | Thymeleaf `<form>` or REST API + SPA |
| `<bean:write>` | `${variable}` (Thymeleaf/EL) |
| `<logic:iterate>` | `<c:forEach>` → Thymeleaf `th:each` |
| `<logic:present>` | `<c:if>` → Thymeleaf `th:if` |
| `<tiles:insert>` | Thymeleaf layouts or fragments |
| `<s:property>` | `${property}` |
| `<s:iterator>` | Thymeleaf `th:each` |
| Custom tag libraries | Thymeleaf dialects or components |

### Configuration

| Legacy | Spring Boot |
|--------|-------------|
| `web.xml` | Auto-configuration (embedded Tomcat) |
| `struts-config.xml` | `@Configuration` + component scanning |
| `tiles-defs.xml` | Thymeleaf layout dialect |
| `log4j.properties` | `application.yml` + Logback |
| `hibernate.cfg.xml` | `spring.jpa.*` properties |
| `context.xml` (JNDI DataSource) | `spring.datasource.*` properties |
| `applicationContext.xml` (Spring XML) | `@Configuration` classes |

### Data Access

| Legacy Pattern | Spring Boot |
|---------------|-------------|
| Raw JDBC + `Connection` | Spring `JdbcTemplate` or Spring Data JPA |
| Hibernate 3 `SessionFactory` | Spring Data JPA + `EntityManager` |
| iBatis `SqlMapClient` | MyBatis-Spring or Spring Data JPA |
| DAO pattern (manual) | Spring Data `Repository` interfaces |
| JNDI DataSource | `spring.datasource.jndi-name` or direct config |

## Incremental Migration Strategy

### Phase 1: Coexistence Setup (Week 1-2)
```
[Existing WAR]                    [New Spring Boot App]
├── Struts Actions (existing)     ├── @RestController (new APIs)
├── JSPs (existing)               ├── spring-boot-starter-web
├── web.xml                       ├── application.yml
└── struts-config.xml             └── Reverse proxy routes new paths
```

1. Create Spring Boot project alongside existing WAR
2. Set up reverse proxy (nginx/Apache) to route new endpoints to Spring Boot
3. Share the database — same JDBC URL
4. Migrate one simple CRUD module first (proof of concept)

### Phase 2: Strangler Fig Pattern (Month 1-3)
1. Identify modules by URL pattern groups in `struts-config.xml`
2. Prioritize: start with modules that have tests or are well-understood
3. For each module:
   - Write characterization tests against the existing Struts endpoint
   - Implement Spring Boot equivalent
   - Route traffic to Spring Boot
   - Keep Struts version as fallback
4. Shared services: extract business logic from Actions into `@Service` classes usable by both

### Phase 3: View Migration (Month 2-4)
Two options:
- **Option A: Thymeleaf** — Convert JSPs to Thymeleaf templates (server-rendered, similar mental model)
- **Option B: SPA** — Replace JSPs with Angular/React frontend consuming REST APIs

For Option B (recommended for new development):
1. Create REST endpoints first (`@RestController`)
2. Build Angular/React frontend consuming the APIs
3. JSPs become unnecessary

### Phase 4: Decommission (Month 4-6)
1. Remove reverse proxy rules (all traffic to Spring Boot)
2. Archive Struts codebase
3. Remove legacy dependencies from build

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Data migration failures | Same database — no data migration needed |
| URL contract breaks | Map all URLs before migration, use `@RequestMapping` to preserve paths |
| Session management differences | Use Spring Session with same backing store (Redis/JDBC) |
| Authentication changes | Extract auth to shared filter/interceptor early |
| Reporting/batch jobs break | These often bypass Struts — migrate independently |
| Performance regression | Load test each migrated module before switching traffic |

## Common Struts Vulnerabilities to Fix During Migration

| CVE | Version | Issue | Fix |
|-----|---------|-------|-----|
| CVE-2017-5638 | Struts 2.x | Remote code execution via Content-Type | Upgrade or migrate |
| CVE-2018-11776 | Struts 2.x | RCE via namespace/action resolution | Upgrade or migrate |
| CVE-2020-17530 | Struts 2.x | OGNL injection via tag attributes | Upgrade or migrate |
| S2-045 through S2-066 | Struts 2.x | Various RCE/injection vectors | Upgrade or migrate |

**If the Struts version is end-of-life, migration priority is CRITICAL — these are actively exploited.**

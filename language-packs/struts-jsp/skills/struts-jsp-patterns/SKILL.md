---
name: struts-jsp-patterns
description: Struts 1.x/2.x and JSP anti-patterns, code archeology patterns, and legacy code understanding. For software archeology consulting.
user-invocable: false
allowed-tools: Read, Grep, Glob
catalog_description: Struts/JSP anti-patterns, legacy code archeology, and modernization assessment.
---

# Struts + JSP — Patterns & Anti-Patterns

Software archeology reference for understanding and assessing legacy Java web applications.

## Stack Detection

| Indicator | Version | Location |
|-----------|---------|----------|
| `struts-config.xml` | Struts 1.x | WEB-INF/ |
| `struts.xml` | Struts 2.x | src/main/resources/ or classpath |
| `tiles-defs.xml` | Tiles 1.x/2.x | WEB-INF/ |
| `<% ... %>` scriptlets | JSP (any) | *.jsp files |
| `ActionForm` extends | Struts 1.x | Java source |
| `ActionSupport` extends | Struts 2.x | Java source |
| `web.xml` with `ActionServlet` | Struts 1.x | WEB-INF/web.xml |
| `web.xml` with `StrutsPrepareAndExecuteFilter` | Struts 2.x | WEB-INF/web.xml |
| `<%@ taglib uri="/WEB-INF/struts-*.tld"` | Struts 1.x | *.jsp |
| `<%@ taglib prefix="s" uri="/struts-tags"` | Struts 2.x | *.jsp |

## Struts 1.x Architecture

```
Browser Request
    |
    v
web.xml (ActionServlet mapping: *.do)
    |
    v
struts-config.xml (action-mappings)
    |
    v
ActionForm.validate() → validation errors → input JSP
    |
    v
Action.execute(mapping, form, request, response)
    |
    v
ActionForward (name → path in struts-config.xml)
    |
    v
JSP (with Struts tag libs: html, bean, logic, tiles)
```

### Key Classes (Struts 1.x)
- `org.apache.struts.action.Action` — controller base class
- `org.apache.struts.action.ActionForm` — form data binding
- `org.apache.struts.action.ActionForward` — navigation result
- `org.apache.struts.action.ActionMapping` — URL-to-action mapping
- `org.apache.struts.action.ActionServlet` — front controller servlet
- `org.apache.struts.tiles.TilesPlugin` — layout templating
- `org.apache.struts.validator.ValidatorPlugIn` — XML-based validation

### Anti-Patterns (Struts 1.x)

| Anti-Pattern | What to look for | Risk | Spring Boot equivalent |
|-------------|-----------------|------|----------------------|
| God Action | Action class >500 lines, handles multiple paths via `if/else` on form fields | High | Split into `@Controller` methods |
| ActionForm bloat | ActionForm with 30+ fields, nested objects | Medium | `@RequestBody` DTO + validation groups |
| Business logic in Action | Database calls, calculations in `execute()` | High | Service layer (`@Service`) |
| Request/Session abuse | `request.setAttribute()` / `session.setAttribute()` for everything | Medium | Model attributes, `@SessionAttributes` |
| Struts MessageResources as i18n | `MessageResources.getMessage()` scattered everywhere | Low | `MessageSource` + `@MessageSource` |
| DynaActionForm | Dynamic forms via XML — hard to refactor | Medium | Typed DTOs |
| DispatchAction abuse | Single action handles CRUD via method param | Medium | REST endpoints |

## Struts 2.x Architecture

```
Browser Request
    |
    v
web.xml (StrutsPrepareAndExecuteFilter: /*)
    |
    v
struts.xml (package → action mapping)
    |
    v
Interceptor Stack (params, validation, fileUpload, exception, etc.)
    |
    v
Action class (POJO with execute() or method name)
    |
    v
Result (JSP, Freemarker, JSON, redirect)
```

### Anti-Patterns (Struts 2.x)

| Anti-Pattern | What to look for | Risk | Spring Boot equivalent |
|-------------|-----------------|------|----------------------|
| OGNL in views | `<s:property value="%{user.name}"/>` with complex expressions | Critical (security) | `${user.name}` in Thymeleaf |
| ServletRequestAware/SessionAware | Action implements `*Aware` interfaces | Medium | `@RequestParam`, `@SessionAttribute` |
| ValueStack manipulation | `ActionContext.getContext().getValueStack()` | High | Model/ModelAndView |
| Wildcard mappings | `<action name="*" method="{1}">` | High (security) | Explicit `@RequestMapping` |
| Interceptor soup | 20+ custom interceptors in stack | Medium | Spring filters/aspects |

## JSP Anti-Patterns

| Anti-Pattern | Example | Fix |
|-------------|---------|-----|
| Scriptlet logic | `<% if(user != null) { %>` | `<c:if test="${not empty user}">` |
| Scriptlet DB access | `<% Connection con = ... %>` | Move to DAO/Service layer |
| Scriptlet import | `<%@ page import="java.sql.*" %>` | Remove — indicates wrong layer |
| No JSTL | HTML mixed with `<%= request.getAttribute("x") %>` | `${x}` with EL |
| Inline CSS/JS | `<style>` and `<script>` in every JSP | External files, asset pipeline |
| Include vs Tiles | `<%@ include file="header.jsp" %>` everywhere | Tiles template inheritance |
| Form action hardcoding | `<form action="/app/saveUser.do">` | `<html:form action="/saveUser">` |

## Code Archeology Checklist

When first encountering a Struts/JSP codebase:

1. **Read `web.xml`** — understand servlet mappings, filters, listeners, context params
2. **Read `struts-config.xml` or `struts.xml`** — map all actions to Action classes
3. **Count JSP files** — `find . -name "*.jsp" | wc -l`
4. **Count Action classes** — `grep -rl "extends Action" src/` or `grep -rl "extends ActionSupport" src/`
5. **Identify DAO pattern** — JDBC? Hibernate? iBatis? JPA?
6. **Check dependency versions** — `pom.xml` or `lib/*.jar` versions
7. **Measure scriptlet density** — `grep -rc '<%[^@=-]' webapp/ --include="*.jsp"`
8. **Check test coverage** — `find . -name "*Test.java" | wc -l`
9. **Identify security model** — Container auth? Custom filter? Struts interceptor?
10. **Map URL patterns** — Extract all `*.do` or action mappings

## Technical Debt Scoring

| Category | Low Debt | Medium Debt | High Debt |
|----------|----------|-------------|-----------|
| Scriptlets | <10 across all JSPs | 10-100 | >100 |
| God Actions | None >200 lines | 1-3 large actions | >3 or >500 lines |
| Test coverage | >50% | 20-50% | <20% |
| SQL injection risk | Parameterized queries | Mixed | String concatenation |
| Dependency age | <5 years old | 5-10 years | >10 years |
| Build system | Maven 3+ | Maven 2 | Ant only |

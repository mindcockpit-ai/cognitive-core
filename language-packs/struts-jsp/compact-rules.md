# Struts + JSP — Compact Rules

Critical rules for legacy Java web projects using Apache Struts and JSP. These rules survive context compaction.

## Understanding the Codebase (Software Archeology)

1. **Identify Struts version first** — Struts 1.x uses `struts-config.xml` with `<action-mappings>` and `ActionForm` classes. Struts 2.x uses `struts.xml` with `<package>/<action>` and OGNL expressions. The migration patterns differ fundamentally.

2. **Map the request flow** — Struts 1: Browser → ActionServlet → RequestProcessor → Action → ActionForward → JSP. Struts 2: Browser → FilterDispatcher → Interceptor Stack → Action → Result → JSP/Freemarker.

3. **JSP scriptlets are technical debt, not bugs** — `<% code %>` in JSPs is legacy but functional. Audit and document, do not refactor in-place unless migrating. Use JSTL/EL (`${expr}`, `<c:forEach>`) as the replacement pattern.

4. **Tiles layouts define page structure** — `tiles-defs.xml` or `@TilesDefinition` maps template inheritance. Understand the layout hierarchy before making changes.

5. **web.xml is the configuration root** — Servlet mappings, filter chains, listener declarations, context parameters, security constraints. Read this first.

## Code Safety

6. **Never introduce new scriptlets** — If editing JSPs, use JSTL + EL only. Scriptlets (`<% %>`, `<%= %>`, `<%! %>`) must not increase.

7. **OGNL injection is a critical vulnerability** — Struts 2 OGNL expressions are a known attack vector (CVE-2017-5638, CVE-2018-11776). Never expose user input to OGNL evaluation. Check `struts.xml` for `${...}` in attributes.

8. **Validate ActionForm/POJO inputs** — Struts 1 `ActionForm.validate()` and Struts 2 validation framework (`-validation.xml`) are the input boundary. Never trust unvalidated form data.

9. **Session scope is dangerous** — `<action ... scope="session">` or `SessionAware` in Struts 2 persists data across requests. Audit for sensitive data in session.

10. **SQL injection in legacy DAO** — Legacy projects often use string concatenation for SQL. Check `Statement.execute()`, `createQuery()` with string concat. Flag and document.

## Migration Readiness

11. **Document before migrating** — Every Struts Action maps to a Spring `@Controller` method. Every ActionForm maps to a `@RequestBody`/`@ModelAttribute` DTO. Every JSP maps to a Thymeleaf template or API endpoint. Create the mapping table first.

12. **Preserve URL contracts** — External systems, bookmarks, and SEO depend on existing URL patterns. Map every `<action path="...">` and document the URL contract before any migration.

13. **Test coverage determines migration risk** — If test coverage is <30%, migration is high-risk. Prioritize writing characterization tests (tests that document current behavior) before any refactoring.

14. **Database access patterns matter** — Identify DAO layer: raw JDBC, Hibernate 3/4, iBatis/MyBatis, or JPA. Each has a different Spring Data migration path.

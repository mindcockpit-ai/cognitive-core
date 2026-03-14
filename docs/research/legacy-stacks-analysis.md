# Legacy Stack Analysis for cognitive-core Language Packs

## Research Summary

**Prepared**: 2026-03-14
**Purpose**: Identify legacy/heritage technology stacks commonly encountered in enterprise modernization engagements, prioritize them for cognitive-core language pack development, and define what each pack would contain.
**Immediate need**: Struts + JSP pack for active client project (Struts portal rewrite to Spring Boot + Angular).

---

## Executive Summary

The enterprise application modernization market is valued at approximately $25 billion (2026), growing at 16.5% CAGR. Roughly 78% of enterprises are engaged in some level of modernization activity. Nearly 70% of IT budgets in large organizations remain tied to maintaining legacy systems. The talent crisis for legacy skills is acute: EJB and Struts specialists take 120+ days to hire with 40% salary premiums.

cognitive-core currently has language packs for modern stacks (Spring Boot, React, Angular, Python, Node, Go, Rust, C#, Perl). Adding legacy/migration packs creates a unique value proposition: AI-assisted analysis and migration guidance for the most common software archeology scenarios.

---

## Market Context

### Application Modernization Market (2026)

| Metric | Value | Source |
|--------|-------|--------|
| Market size (2026) | ~$25.6 billion | Market Growth Reports |
| CAGR (2025-2035) | 16.5% | Market Research Future |
| Enterprises actively modernizing | 78% | SkyQuest |
| IT budget on legacy maintenance | ~70% | Multiple sources |
| Average data breach cost (legacy) | $4.88M | IBM Security Report 2024 |
| EJB/Struts hiring time | 120+ days | LegacyLeap |
| Legacy skill salary premium | 40% | LegacyLeap |
| Cyber insurance premium increase (legacy) | 40-60% | LegacyLeap |
| Typical migration ROI (3 years) | 200-304% | Multiple sources |

### Why Legacy Packs for cognitive-core?

1. **AI-assisted modernization is the growth area** -- Augment Code, LegacyLeap, Moderne (OpenRewrite) are all targeting this
2. **Every modernization project starts with assessment** -- fitness checks and anti-pattern detection are exactly what legacy packs provide
3. **The migration target is already covered** -- Spring Boot, React, and Angular packs exist; legacy packs complete the from-to pipeline
4. **Consulting differentiation** -- our AI understands the old thing, not just the new thing

---

## Tier 1: High Priority (Common in Enterprise Modernization)

### 1.1 Apache Struts (1.x and 2.x) -- IMMEDIATE NEED

**What it is**: Action-based MVC framework for Java web applications. Struts 1 (2001-2013, EOL) used XML-heavy configuration with ActionForms. Struts 2 (2007+, maintenance mode) is based on WebWork with interceptors and OGNL expressions.

**Prevalence**: Still running in government, finance, SaaS, and healthcare. Handles internal workflows, backend admin portals, insurance systems, government forms. Exact numbers unknown but HeroDevs confirms many enterprises across regulated industries. The Equifax breach (2017, 147M records) was a Struts vulnerability -- yet organizations still run it.

**Common modernization target**: Spring Boot + Spring MVC (backend) + Angular/React (frontend). Staged migration via Strangler Fig pattern is standard practice.

**Codebase detection patterns**:

Struts 1 indicators:
- WEB-INF/struts-config.xml
- WEB-INF/tiles-defs.xml (or tiles-definitions.xml)
- WEB-INF/validation.xml
- WEB-INF/validator-rules.xml
- *.jsp files with taglib uri struts-*.tld
- Classes extending org.apache.struts.action.Action
- Classes extending org.apache.struts.action.ActionForm
- Import: org.apache.struts.action.*
- Dependency: struts-core, struts-taglib, struts-tiles

Struts 2 indicators:
- struts.xml (in classpath / src/main/resources)
- WEB-INF/classes/struts.xml
- Classes extending com.opensymphony.xwork2.ActionSupport
- *.action URLs in JSPs
- Import: org.apache.struts2.*
- OGNL expressions in JSPs
- Dependency: struts2-core, struts2-convention-plugin
- Interceptor stack configuration in struts.xml

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (OGNL injection risks, ActionForm inheritance abuse, fat Actions with business logic, Tiles overuse, XML-over-annotation, hardcoded forwards)
- **fitness-checks.sh**: Detect Action class count, ActionForm complexity, business logic in Actions, XML config size, JSP scriptlet usage, Struts tag usage, security anti-patterns (OGNL user input), test coverage
- **skills/struts-migration/SKILL.md**: Action-to-@Controller mapping, ActionForm-to-POJO conversion, struts-config.xml-to-annotation migration, Tiles-to-Thymeleaf (or SPA), validation.xml-to-JSR-380, interceptor-to-Spring-filter mapping
- **skills/struts-assessment/SKILL.md**: Automated codebase assessment, dependency graph, migration effort estimation, risk scoring

---

### 1.2 JSP (JavaServer Pages) + Servlets

**What it is**: Server-side rendering technology. JSPs compile to servlets, embed Java in HTML via scriptlets, expression language, and tag libraries (JSTL, custom tags). The foundation under Struts, JSF, and many custom frameworks.

**Prevalence**: Virtually every pre-2015 Java web application uses JSP. Still the view layer in thousands of enterprise applications running on WebLogic, JBoss/WildFly, Tomcat, and WebSphere.

**Common modernization target**: Thymeleaf (server-side) or React/Angular SPA (client-side) with REST APIs.

**Codebase detection patterns**:
- *.jsp files (especially in WEB-INF/jsp/ or webapp/)
- *.jspf files (JSP fragments)
- WEB-INF/web.xml with servlet and servlet-mapping entries
- WEB-INF/tags/ directory (custom tag files)
- *.tld files (tag library descriptors)
- taglib directives
- Scriptlet blocks
- EL expressions: dollar-brace syntax
- JSTL tags: c:forEach, c:if, fmt:message
- Classes extending javax.servlet.http.HttpServlet
- Import: javax.servlet.* or jakarta.servlet.*

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (scriptlets in JSP, business logic in JSP, SQL in JSP, no MVC separation, JSP includes vs Tiles, missing JSTL escaping/XSS)
- **fitness-checks.sh**: Scriptlet density, EL usage ratio, JSTL adoption, custom tag usage, business logic detection in JSPs, XSS vulnerability patterns, servlet count, web.xml complexity
- **skills/jsp-migration/SKILL.md**: JSP-to-Thymeleaf conversion patterns, EL-to-Thymeleaf expression mapping, JSTL-to-Thymeleaf equivalents, servlet-to-Spring-MVC-controller, web.xml-to-Java-config

---

### 1.3 JSF (JavaServer Faces) / PrimeFaces / RichFaces / ICEfaces

**What it is**: Component-based Java web framework (JSR-314/JSR-344). Server-side rendering with managed beans, facelets, and composite components. PrimeFaces is the most popular component library. Now Jakarta Faces under Jakarta EE 11 (JSF 4.1 released 2025).

**Prevalence**: Heavy in financial reporting dashboards, government portals, internal business apps (HR, inventory, project management). Many organizations on JSF 2.x with PrimeFaces have no compelling reason to migrate if the app works. Still actively developed (Jakarta Faces 4.1, PrimeFaces 14+).

**Common modernization target**: Spring Boot + Angular/React (full rewrite), or progressive modernization to Vaadin Flow (stays server-side Java). Some migrate within Jakarta EE ecosystem.

**Codebase detection patterns**:
- *.xhtml files (Facelets)
- WEB-INF/faces-config.xml
- JSF namespace declarations in XHTML
- PrimeFaces namespace (primefaces.org/ui)
- RichFaces namespace (richfaces.org/rich)
- @ManagedBean / @Named annotations
- @ViewScoped / @SessionScoped / @RequestScoped
- Import: javax.faces.* or jakarta.faces.*
- Dependency: jsf-api, jsf-impl, primefaces, richfaces
- FacesServlet in web.xml
- #{bean.property} EL expressions in XHTML
- h:form, h:inputText, h:dataTable components
- p:dataTable, p:dialog, p:autoComplete (PrimeFaces)

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (view-scoped memory leaks, @ManagedBean over CDI @Named, excessive server-side state, missing CSRF token, PrimeFaces component overuse, business logic in managed beans, converters/validators in XHTML)
- **fitness-checks.sh**: Managed bean scope analysis, view state size estimation, PrimeFaces version check, CDI adoption ratio, AJAX partial processing usage, component tree depth, backing bean complexity
- **skills/jsf-migration/SKILL.md**: ManagedBean-to-Spring-service mapping, XHTML-to-Angular/React component mapping, faces-config.xml elimination, PrimeFaces-to-PrimeNG conversion (Angular) or PrimeReact (React), conversation scope redesign

---

### 1.4 EJB (Enterprise JavaBeans) / J2EE / Java EE

**What it is**: Server-side component architecture for Java enterprise applications. Session Beans (stateless/stateful), Entity Beans (CMP/BMP, replaced by JPA), Message-Driven Beans (MDB). Deployed on heavyweight app servers (WebLogic, JBoss/WildFly, WebSphere, GlassFish).

**Prevalence**: Legacy anchor in finance, telecom, and insurance. Every large enterprise that adopted Java in 2000-2012 has EJB somewhere. The app server license costs alone drive modernization.

**Common modernization target**: Spring Boot with embedded Tomcat/Jetty. Session Beans become @Service/@Component, JTA becomes @Transactional, JNDI becomes Spring DI, RMI/IIOP becomes REST/gRPC, JAAS becomes Spring Security + OAuth2/OIDC.

**Codebase detection patterns**:
- ejb-jar.xml (deployment descriptor)
- META-INF/ejb-jar.xml
- META-INF/persistence.xml (JPA, but often co-located)
- jboss.xml / jboss-web.xml / weblogic-ejb-jar.xml
- *.ear files (Enterprise Archive)
- @Stateless / @Stateful / @Singleton annotations
- @MessageDriven annotation
- @Remote / @Local interface annotations
- @PersistenceContext / @PersistenceUnit
- JNDI lookups: InitialContext, Context.lookup()
- Import: javax.ejb.* or jakarta.ejb.*
- Import: javax.jms.* (for MDBs)
- Dependency: javaee-api, javax.ejb-api
- Application server config: domain.xml (GlassFish), standalone.xml (JBoss)

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (Entity Beans instead of JPA, stateful session beans for web sessions, remote EJB calls within same JVM, container-managed everything, JNDI lookups instead of DI, @EJB field injection, deployment descriptor sprawl)
- **fitness-checks.sh**: EJB type distribution (stateless/stateful/MDB), Entity Bean count (critical legacy indicator), JNDI lookup count, app server coupling detection, remote interface count, transaction boundary analysis, deployment descriptor complexity
- **skills/ejb-migration/SKILL.md**: Session-Bean-to-Spring-service mapping, JTA-to-@Transactional, JNDI-to-Spring-DI, MDB-to-Spring-JMS/@KafkaListener, Entity-Bean-to-JPA-entity, remote-to-REST-API, JAAS-to-Spring-Security, app-server-to-embedded-server

---

### 1.5 GWT (Google Web Toolkit)

**What it is**: Java-to-JavaScript compiler framework. Developers write client-side UI in Java, which GWT compiles to optimized JavaScript. Uses RPC for server communication. Popular 2007-2015. Used extensively by Google (AdWords, AdSense, Flights, Blogger) and in enterprise dashboards.

**Prevalence**: Thousands of enterprise applications. Vaadin offers a Modernization Toolkit specifically for GWT migration. The framework is still maintained (gwt.dev) but no major evolution.

**Common modernization target**: Angular, React, or Vue.js (frontend) + REST API (backend). Vaadin Flow is a server-side Java alternative that preserves the write-UI-in-Java paradigm.

**Codebase detection patterns**:
- *.gwt.xml module descriptors
- inherits name com.google.gwt.user.User in module XML
- war/WEB-INF/ directory structure
- client/ / server/ / shared/ package convention
- Classes extending com.google.gwt.user.client.ui.Composite
- GWT.create() calls (deferred binding)
- AsyncCallback interfaces (RPC)
- *.ui.xml files (UiBinder templates)
- Import: com.google.gwt.*
- Dependency: gwt-user, gwt-dev, gwt-servlet
- GWT-RPC servlets in web.xml
- DevMode/SuperDevMode configuration

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (GWT-RPC over REST, monolithic EntryPoint, widget inheritance over composition, synchronous server calls, client-side state management in static fields, GWT.create() abuse, no code splitting)
- **fitness-checks.sh**: Module count, widget hierarchy depth, RPC service count, client/shared/server separation quality, code splitting usage, third-party widget library detection (GXT/SmartGWT), test coverage with GWTTestCase
- **skills/gwt-migration/SKILL.md**: Widget-to-React/Angular component mapping, GWT-RPC-to-REST-API, UiBinder-to-HTML/CSS, client-server separation analysis, code-split-to-lazy-loading, event-bus-to-state-management

---

### 1.6 Oracle Forms

**What it is**: Oracle proprietary 4GL RAD tool for building database-centric applications. Tightly coupled to Oracle Database. Form builder generates .fmb/.fmx files. Client-server architecture, later web-deployed via Oracle Application Server.

**Prevalence**: Still powers mission-critical applications in factories, hospitals, financial systems, and government operations. Documented migrations of 100+ forms in single organizations. Oracle actively encourages migration to APEX.

**Common modernization target**: Oracle APEX (low-code, stays in Oracle ecosystem), or modern web frameworks (Angular, React) with REST APIs for organizations leaving Oracle.

**Codebase detection patterns**:
- *.fmb files (Form Module Binary)
- *.fmx files (Form Module Executable)
- *.mmb files (Menu Module Binary)
- *.pll files (PL/SQL Library)
- *.olb files (Object Library)
- *.rdf files (Report Definition)
- Oracle Forms references in configuration
- formsweb.cfg configuration
- PL/SQL triggers (WHEN-NEW-FORM-INSTANCE, etc.)
- Oracle Forms-specific PL/SQL packages

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (business logic in triggers, form-level commits, hardcoded connection strings, no separation of concerns, implicit navigation, global variables)
- **fitness-checks.sh**: Form count, trigger complexity, PL/SQL library usage, cross-form dependencies, Oracle DB coupling analysis
- **skills/oracle-forms-migration/SKILL.md**: Trigger-to-event mapping, form-to-page/component mapping, PL/SQL-to-REST-API extraction, data block analysis

---

## Tier 2: Medium Priority (Still in Production, Modernization Demand)

### 2.1 ASP.NET WebForms

**What it is**: Microsoft server-side web framework (2002+). Event-driven model with ViewState, code-behind files, server controls (GridView, FormView, UpdatePanel). Runs on .NET Framework only (not .NET Core/.NET 8+). End of lifecycle -- maintenance mode, security patches only.

**Prevalence**: 92% of organizations surveyed still rely on legacy .NET technologies including WebForms. Will not be ported to ASP.NET Core. Microsoft Upgrade Assistant does not support WebForms.

**Common modernization target**: Blazor (Microsoft recommendation), or React/Angular with ASP.NET Core Web API.

**Codebase detection patterns**:
- *.aspx files (WebForm pages)
- *.aspx.cs files (code-behind)
- *.aspx.designer.cs files
- *.ascx files (user controls)
- *.master files (master pages)
- Web.config (not appsettings.json)
- Global.asax
- asp:GridView, asp:Repeater, asp:UpdatePanel controls
- runat=server attributes
- __VIEWSTATE hidden field
- System.Web namespace references
- Page_Load, Page_Init event handlers

**Language pack contents**:
- **compact-rules.md**: Anti-patterns (ViewState bloat, code-behind with business logic, UpdatePanel for AJAX, Session state abuse, direct SQL in code-behind, no separation of concerns)
- **fitness-checks.sh**: Page count, ViewState size estimation, code-behind complexity, user control count, Session variable usage, inline SQL detection
- **skills/webforms-migration/SKILL.md**: Code-behind-to-Blazor-component, GridView-to-QuickGrid/DataGrid, ViewState elimination, master-page-to-layout, Web.config-to-appsettings.json

---

### 2.2 WCF (Windows Communication Foundation)

**What it is**: Microsoft unified framework for building service-oriented applications (2006+). SOAP/REST/TCP/Named Pipes. Complex configuration in Web.config/App.config. Not ported to .NET Core (CoreWCF is community-maintained subset).

**Prevalence**: Extremely common in enterprise .NET applications for internal service communication. Every large .NET shop from 2006-2018 used WCF.

**Common modernization target**: ASP.NET Core Web API (REST), gRPC (.NET), or CoreWCF (compatibility shim).

**Codebase detection patterns**:
- *.svc files (WCF service endpoints)
- [ServiceContract] / [OperationContract] attributes
- [DataContract] / [DataMember] attributes
- system.serviceModel section in Web.config
- *.wsdl files
- Import: System.ServiceModel.*
- ServiceHost / ChannelFactory usage
- BasicHttpBinding / WSHttpBinding / NetTcpBinding configuration

---

### 2.3 Apache Wicket

**What it is**: Component-based Java web framework (2005+). Pure Java approach -- HTML templates with wicket:id attributes, no scriptlets or expression language. Stateful component trees. Still actively maintained (Wicket 10.x for Jakarta EE).

**Prevalence**: Niche but loyal user base. Common in Dutch/German enterprise environments. Organizations that chose Wicket over JSF tend to maintain it longer due to its clean Java-centric model.

**Common modernization target**: Spring Boot + React/Angular, or Vaadin Flow.

**Codebase detection patterns**:
- *.html files with wicket:id attributes
- Java classes extending org.apache.wicket.markup.html.WebPage
- Java classes extending org.apache.wicket.markup.html.panel.Panel
- Application class extending WebApplication
- wicket:message, wicket:enclosure tags in HTML
- Import: org.apache.wicket.*
- Dependency: wicket-core, wicket-spring, wicket-extensions

---

### 2.4 Apache Tapestry

**What it is**: Component-based Java web framework (2003+). Convention-over-configuration, live class reloading, page/component separation via TML templates. Version 5.x is current.

**Prevalence**: Small but dedicated community. Found in organizations that invested heavily in it during the 2005-2012 period.

**Common modernization target**: Spring Boot + React/Angular.

**Codebase detection patterns**:
- *.tml files (Tapestry Markup Language)
- Classes in pages/ and components/ packages (convention)
- @InjectComponent, @Property, @Persist annotations
- AppModule.java (Tapestry IoC configuration)
- Import: org.apache.tapestry5.*
- Dependency: tapestry-core, tapestry-hibernate
- t:type attributes in TML templates

---

### 2.5 Legacy PHP Frameworks (CodeIgniter 2.x/3.x, CakePHP 2.x, Zend Framework 1.x)

**What it is**: The pre-Laravel PHP ecosystem. CodeIgniter was the lightweight MVC framework (2006+). CakePHP brought Rails-like conventions to PHP (2005+). Zend Framework 1 (now dead, succeeded by Laminas) was the enterprise PHP choice.

**Prevalence**: Many businesses still depend on applications built using these frameworks. CodeIgniter 4 is actively maintained but CI 2.x/3.x codebases are legacy. Zend Framework 1 is fully EOL; Laminas is the successor.

**Common modernization target**: Laravel (most common), Symfony, or complete platform change to Node.js/Python/Java.

**Codebase detection patterns**:

CodeIgniter 2.x/3.x:
- application/controllers/ directory
- application/models/ directory
- application/views/ directory
- system/ directory (CI core)
- index.php bootstrap with CI path definitions
- this->load->model(), this->load->view() patterns

CakePHP 2.x:
- app/Controller/ directory
- app/Model/ directory
- app/View/ directory
- CakePlugin::load() calls
- this->set() in controllers

Zend Framework 1:
- application/controllers/ with Zend_Controller_Action
- Zend_Db_Table usage
- Zend_Form classes
- application.ini configuration
- Import: Zend_*

---

### 2.6 Legacy Python (Django 1.x patterns, Flask 0.x)

**What it is**: Django pre-2.0 patterns (function-based views, South migrations, Python 2 syntax). Flask applications without blueprints, without proper application factory pattern.

**Prevalence**: Python 2 reached EOL January 2020, but legacy Django 1.x apps still exist. More common in startups-turned-enterprises than traditional enterprise shops.

**Common modernization target**: Django 4.x/5.x (in-place upgrade), or FastAPI for API-first applications.

**Codebase detection patterns**:

Legacy Django:
- url() instead of path() in urls.py
- from django.conf.urls import url
- ForeignKey without on_delete parameter
- South migration files (south_migrations/)
- render_to_response() instead of render()
- Python 2 syntax: print statements, unicode strings
- settings.py with MIDDLEWARE_CLASSES (not MIDDLEWARE)
- Django 1.x style class-based views without mixins

Legacy Flask:
- app = Flask(__name__) at module level (no factory)
- @app.route without blueprints
- flask.ext.* imports (removed in Flask 1.0)

---

### 2.7 COBOL / Mainframe Interfaces

**What it is**: COBOL (1959+) on IBM mainframes (z/OS, AS/400). 250 billion lines of COBOL in production across financial services, government, logistics, manufacturing, and retail. 40% of COBOL does not even run on mainframes.

**Prevalence**: Massive. Mainframe modernization market valued at $8.18B (2025), projected to reach $25.94B by 2035. Large enterprises account for 75% of mainframe modernization spending.

**Common modernization target**: Java/Spring Boot, .NET, or cloud-native microservices. AI-assisted migration is the hot topic (Microsoft, AWS, IBM all have COBOL-to-Java tooling).

**Note for cognitive-core**: A full COBOL language pack is a massive undertaking. The practical value is in **interface analysis** -- understanding how Java/web applications interact with COBOL backends via CICS, MQ, VSAM file access, copybook-defined data structures, and JCA connectors.

**Codebase detection patterns**:
- *.cbl, *.cob, *.cpy files (copybooks)
- IDENTIFICATION DIVISION / DATA DIVISION / PROCEDURE DIVISION
- JCA connector configurations (ra.xml)
- CICS transaction references
- IBM MQ configuration (JNDI, connection factories)
- COBOL copybook references in Java code
- COMMAREA data structures
- 3270 terminal emulation references

---

## Tier 3: Lower Priority (Niche but Encountered)

### 3.1 Delphi (Object Pascal)

**What it is**: Borland/Embarcadero RAD tool for Windows desktop applications (1995+). VCL (Visual Component Library) tightly couples UI to business logic.

**Prevalence**: Still in regulated industries. Windows 10 EOL (October 2025) forces migration for Delphi apps that do not run on Windows 11.

**Common modernization target**: .NET WPF/WinForms, or web-based (Angular/React + API).

**Detection**: *.pas, *.dfm, *.dpr, *.dpk files. uses clauses with VCL units.

---

### 3.2 PowerBuilder

**What it is**: Sybase/SAP rapid application development tool (1991+). DataWindow is the signature component -- proprietary control combining UI, data binding, and business logic with no modern equivalent.

**Prevalence**: Still providing critical citizen services (government case study documented). DataWindow dependency makes migration exceptionally expensive -- often doubles development time.

**Common modernization target**: .NET, Java, or web-based. Appeon PowerBuilder 2022 adds web/mobile targets.

**Detection**: *.pbl, *.pbd, *.srw, *.srd files. DataWindow definitions.

---

### 3.3 Visual Basic 6 (VB6)

**What it is**: Microsoft RAD tool (1998-2008). COM-based, Windows-only. Does not run on Windows 11 without compatibility shims that break under security hardening.

**Prevalence**: 92% of organizations surveyed still rely on technologies including VB6.

**Common modernization target**: VB.NET (minimal change), C#/.NET, or web-based.

**Detection**: *.frm, *.bas, *.cls, *.vbp files. Dim, Sub, Function keywords.

---

### 3.4 Classic ASP (Active Server Pages)

**What it is**: Microsoft first server-side web technology (1996-2002). VBScript/JScript in HTML. IIS-only.

**Prevalence**: Still running in organizations where if-it-works-do-not-touch-it prevails.

**Common modernization target**: ASP.NET Core, or complete platform rewrite.

**Detection**: *.asp files. VBScript blocks. Server.CreateObject, Request.QueryString, Response.Write. global.asa file.

---

### 3.5 FoxPro (Visual FoxPro)

**What it is**: Microsoft xBase database-centric RAD tool (1984-2007). EOL in 2015. Data stored in .dbf files.

**Common modernization target**: .NET with SQL Server, or web-based.

**Detection**: *.prg, *.scx, *.frx, *.vcx, *.dbf files.

---

### 3.6 Silverlight

**What it is**: Microsoft browser plugin for rich internet applications (2007-2012). XAML-based UI, C#/VB.NET backend. Plugin support removed from all major browsers.

**Common modernization target**: Blazor (closest paradigm), or Angular/React.

**Detection**: *.xaml files with Silverlight namespaces, *.xap packages, ClientBin/ directory.

---

### 3.7 Java Swing / AWT Desktop Applications

**What it is**: Java desktop GUI toolkit. Swing (1998+) built on AWT. Many internal enterprise tools, trading platforms, and admin applications.

**Prevalence**: Common in financial services (trading terminals), healthcare, and manufacturing.

**Common modernization target**: JavaFX (staying Java), Vaadin (web), or React/Angular (web).

**Detection**: import javax.swing.*, import java.awt.*, JFrame, JPanel, JButton classes. No WEB-INF/ directory.

---

## Existing Tools for Legacy Java Code Analysis

| Tool | Purpose | Relevance to cognitive-core |
|------|---------|---------------------------|
| **OpenRewrite** | Automated source code refactoring using Lossless Semantic Trees (LSTs). Pre-built recipes for javax-to-jakarta, JUnit 4-to-5, Spring Boot upgrades | Complementary -- OpenRewrite transforms code; cognitive-core analyzes patterns and guides decisions |
| **Moderne** | Commercial platform built on OpenRewrite. Enterprise-scale migration automation | Competitor at the automation level, but cognitive-core operates at the AI-guidance level |
| **jQAssistant** | Scans Java bytecode into Neo4j graph database. Query architectural rules with Cypher | Could feed data into fitness-checks; graph-based analysis catches structural anti-patterns |
| **SonarQube** | Static analysis, code quality, security vulnerabilities. Supports 30+ languages | Overlaps with fitness-checks but is heavier; cognitive-core is lighter and AI-integrated |
| **Vaadin Modernization Toolkit** | Specifically for GWT-to-Vaadin migration automation | Narrow focus; cognitive-core is framework-agnostic |
| **AWS Transform** | Modernizes ASP.NET WebForms to Blazor | Cloud-vendor-specific; cognitive-core is vendor-neutral |
| **SOCA** | Source Object and Code Analyzer for VB6, C++, FORTRAN, Oracle Forms, PowerBuilder, Delphi, COBOL | Legacy-specific tool; cognitive-core provides AI layer on top |
| **Replay** | Visual reverse engineering for legacy systems | Complementary for documentation; cognitive-core provides ongoing guidance |

### Key Insight

OpenRewrite is the closest analog to what cognitive-core does for legacy stacks, but they operate at different levels:
- **OpenRewrite**: Automated code transformation (refactoring recipes)
- **cognitive-core**: AI-guided analysis, anti-pattern detection, migration planning, and developer guardrails

The two are complementary, not competing. A cognitive-core legacy pack could recommend specific OpenRewrite recipes as part of its migration guidance.

---

## Recommended Implementation Plan

### Phase 1: Struts + JSP Pack (Immediate -- Client Need)

**Scope**: Combined struts-jsp language pack covering both Struts 1.x/2.x and JSP/Servlet patterns.

**Deliverables**:
1. language-packs/struts-jsp/pack.conf -- Detection and configuration
2. language-packs/struts-jsp/compact-rules.md -- Anti-patterns and code standards
3. language-packs/struts-jsp/fitness-checks.sh -- Automated codebase health scoring
4. language-packs/struts-jsp/lint-config.sh -- Checkstyle/PMD rules for Struts
5. language-packs/struts-jsp/monitor-patterns.conf -- File change monitoring
6. language-packs/struts-jsp/skills/struts-assessment/SKILL.md -- Migration readiness assessment
7. language-packs/struts-jsp/skills/struts-to-spring-boot/SKILL.md -- Migration guide with patterns

**Fitness checks should cover**:
- Struts version detection (1.x vs 2.x)
- Action class count and complexity
- ActionForm and POJO analysis
- Business logic in Actions (should be in services)
- JSP scriptlet density (high = more work)
- Struts tag library usage analysis
- XML configuration file count and size
- Tiles and layout complexity
- Security vulnerability patterns (OGNL injection for Struts 2)
- Test coverage baseline
- App server coupling (WebLogic/JBoss/Tomcat-specific code)
- JNDI lookup count
- Hardcoded configuration values

**Migration skill should map**:

| Struts Component | Spring Boot Equivalent |
|-----------------|----------------------|
| Action class | @Controller or @RestController |
| ActionForm | POJO with @Valid and @ModelAttribute |
| struts-config.xml action-mappings | @RequestMapping, @GetMapping, @PostMapping |
| struts-config.xml form-beans | Spring form backing objects |
| struts-config.xml forwards | Return view names or redirect: |
| Tiles definitions | Thymeleaf layout dialect or SPA routing |
| validation.xml | JSR-380 annotations (@NotNull, @Size, etc.) |
| Struts 2 interceptors | Spring HandlerInterceptor or Servlet Filters |
| OGNL value stack | Spring MVC Model and @ModelAttribute |
| ActionMessages and ActionErrors | BindingResult and @Valid |
| MessageResources | Spring MessageSource |
| DispatchAction | Multiple @RequestMapping methods |
| Struts 2 result types | Spring ViewResolver |

### Phase 2: JSF + EJB Pack

**Scope**: Combined javaee-legacy pack covering JSF 2.x, EJB, and J2EE patterns. These almost always appear together.

**Effort**: Medium. Many patterns overlap with the existing java and spring-boot packs.

### Phase 3: GWT Pack

**Scope**: Standalone gwt pack focused on GWT-to-SPA migration.

**Effort**: Medium. Unique detection patterns, but migration targets (React/Angular) are already covered.

### Phase 4: .NET Legacy Pack

**Scope**: Combined dotnet-legacy pack covering WebForms, WCF, and classic ASP.NET MVC patterns.

**Effort**: Medium. Requires understanding of .NET ecosystem (currently only csharp pack exists as stub).

### Phase 5: Remaining Packs (as client needs arise)

- Oracle Forms (if Oracle modernization clients appear)
- Legacy PHP (CodeIgniter, CakePHP, Zend)
- Desktop stacks (Delphi, PowerBuilder, VB6) -- likely assessment-only packs

---

## Key Statistics Summary

| Statistic | Value | Context |
|-----------|-------|---------|
| Enterprise apps on legacy Java stacks | ~40-60% (estimated) | No single authoritative number; derived from Spring adoption (~50% of Java devs) + enterprise lag |
| COBOL lines in production | 250 billion | Across all sectors globally |
| Modernization market size (2026) | ~$25.6 billion | Growing at 16.5% CAGR |
| Mainframe modernization market (2025) | $8.18 billion | Growing at 12.7% CAGR |
| Organizations on legacy .NET | 92% | Including VB6, WebForms, WCF |
| Average EJB/Struts hire time | 120+ days | Severe talent shortage |
| Migration ROI (3 years) | 200-304% | Across multiple studies |
| AI-assisted migration timeline reduction | ~60% | LegacyLeap estimate |
| Infrastructure cost reduction (post-migration) | 40-60% | Containerized Spring Boot vs app server |
| Startup time improvement | 10x faster | GraalVM native compilation |

---

## Sources

- [HeroDevs: Why Many Enterprises Still Run on Apache Struts 1 and 2](https://www.herodevs.com/blog-posts/why-many-enterprises-still-run-on-apache-struts-1-2-and-how-to-stay-secure)
- [LegacyLeap: Enterprise Java Migration 2026](https://www.legacyleap.ai/blog/java-migration-guide/)
- [LegacyLeap: EJB to Spring Boot Migration Guide 2026](https://www.legacyleap.ai/blog/ejb-to-spring-boot-migration/)
- [LegacyLeap: Java EE to Spring Boot Migration Strategy 2026](https://www.legacyleap.ai/blog/java-ee-to-spring-boot-migration/)
- [LegacyLeap: Struts to Spring MVC Migration with Gen AI](https://www.legacyleap.ai/blog/struts-to-spring-migration/)
- [LegacyLeap: ASP.NET Web Forms to Blazor Migration](https://www.legacyleap.ai/blog/asp-dotnet-web-forms-to-blazor-migration/)
- [Market Research Future: Application Modernization Services Market](https://www.marketresearchfuture.com/reports/application-modernization-services-market-5541)
- [Market Growth Reports: Application Modernization Market](https://www.marketgrowthreports.com/market-reports/application-modernization-services-market-101569)
- [MarketsAndMarkets: Mainframe Modernization Market](https://www.marketsandmarkets.com/Market-Reports/mainframe-modernization-market-52477.html)
- [IBM: What Is COBOL Modernization?](https://www.ibm.com/think/topics/cobol-modernization)
- [Software Modernization Services: VB6, PowerBuilder and Delphi Research](https://softwaremodernizationservices.com/legacy-system-modernization/)
- [OpenRewrite Documentation](https://docs.openrewrite.org/)
- [Vaadin: Java App Modernization Tool](https://vaadin.com/modernization-toolkit)
- [Microsoft: Migrate from ASP.NET Web Forms to Blazor](https://learn.microsoft.com/en-us/dotnet/architecture/blazor-for-web-forms-developers/migration)
- [Talan: Why Oracle Forms Still Matters in 2025](https://www.talan.com/americas/en/resources/blogs/why-oracle-forms-still-matters-2025)
- [Struts 1 to Spring Boot Migration](https://parameswaranvv.github.io/blog/struts1-spring-boot-migration/)
- [Struts 2 to Spring Boot Migration](https://parameswaranvv.github.io/blog/struts2-spring-boot-migration/)
- [InfoQ: Java Trends Report 2025](https://www.infoq.com/articles/java-trends-report-2025/)
- [Vaadin: Most Popular Java Frameworks 2026](https://vaadin.com/blog/most-popular-java-frameworks-2026)
- [Hicron: Transforming Legacy Java-based Enterprise Applications](https://hicronsoftware.com/blog/java-frameworks-enterprise-applications/)
- [Medium: Legacy JSF Applications -- Should You Migrate or Maintain?](https://medium.com/@abrahamstalin1/entry-2-legacy-jsf-applications-should-you-migrate-or-maintain-7ad623f43a33)
- [BayOne: Business Case for Legacy Application Modernization 2026](https://bayone.com/business-case-for-legacy-application-modernization-2025/)

# Open Source vs. Commercial Licensing for Developer Frameworks

## Research Summary: cognitive-core Licensing Strategy Analysis

**Date**: 2026-03-13
**Analyst**: research-analyst
**Scope**: Comprehensive pro/con analysis of open source vs. closed-source/enterprise models for AI agent tooling frameworks

---

## Executive Summary

The open source vs. commercial debate for developer frameworks is not binary. The most successful developer tools companies of the past decade have used **hybrid models** -- open source core with commercial services on top. However, the AI agent framework space in 2025-2026 has a unique dynamic: big tech is flooding the market with free frameworks to drive platform adoption, making pure open-source survival harder than ever. For a one-person project like cognitive-core, the research points toward a **staged approach**: start with a protective source-available license (FSL or BSL), build credibility and community, then layer commercial offerings as demand materializes. Going fully closed-source immediately would be premature; going fully MIT-open risks giving away competitive advantage with no mechanism to capture value.

---

## Part 1: Open-Source-First Companies -- What Actually Happened

### HashiCorp (Terraform)

| Metric | Value |
|--------|-------|
| License journey | MPL v2 (open source) -> BSL 1.1 (source-available, Aug 2023) |
| Revenue at license change | ~$583M ARR (FY2024) |
| Outcome | Acquired by IBM for **$6.4B** (completed Feb 2025) |
| Time to scale | Founded 2012, first revenue ~2014, IPO 2021 (~9 years) |

**What happened**: HashiCorp built massive adoption with open source Terraform, then switched to BSL when competitors (especially cloud providers) were reselling their work. The license change triggered community backlash and the creation of OpenTofu (Linux Foundation fork). HashiCorp then announced Terraform OSS under BSL would be discontinued after July 2025, pushing users toward Terraform Enterprise. Despite community anger, IBM bought them for $6.4B -- the commercial moat was more valuable than community goodwill.

**Lesson**: Open source built the market, but the company captured value by restricting the license once they had dominant market share. The community fork (OpenTofu) exists but has not displaced Terraform.

### Elastic (Elasticsearch)

| Metric | Value |
|--------|-------|
| License journey | Apache 2.0 -> SSPL + Elastic License (2021) -> Added AGPLv3 option (2024) |
| Revenue | $1.26B in FY2024, 18% YoY growth |
| Cloud revenue | Up 30% YoY |
| Time to scale | Founded 2012, revenue ~2014, IPO 2018 (~6 years to IPO) |

**What happened**: AWS launched Amazon Elasticsearch Service using Elastic's open source code, contributing little back. Elastic changed to SSPL to block this. AWS forked it as OpenSearch. In 2024, Elastic added AGPLv3 as an option -- effectively returning to open source but with copyleft protection. The SSPL period bought them time to build their commercial cloud business.

**Lesson**: The "cloud provider eats your open source" scenario is real and happened to Elastic. License changes can work as a defensive move, but expect forks and community fragmentation.

### GitLab (Open Core)

| Metric | Value |
|--------|-------|
| Model | Open core from day one (Community Edition free, Enterprise Edition paid) |
| Revenue | $759.2M in FY2025, 31% YoY growth |
| Net retention | 123% dollar-based net retention |
| Enterprise customers | 123 customers with >$1M ARR |
| Time to scale | Founded 2011, IPO 2021 (~10 years) |

**What happened**: GitLab defined the open-core playbook. Free Community Edition drives adoption; paid tiers add enterprise features (SSO, audit logs, compliance, advanced CI/CD). They never changed their core license.

**Lesson**: Open core works well when there is a clear line between community features and enterprise needs. GitLab's consistency has built trust that HashiCorp's license switch destroyed.

### Vercel (Next.js)

| Metric | Value |
|--------|-------|
| Model | Open source framework (Next.js), commercial platform (Vercel) |
| Revenue | $200M ARR by May 2025 |
| Valuation | $9.3B (Series F, Sep 2025) |
| Time to scale | Founded 2015, meaningful revenue ~2019, ~6 years to significant scale |

**What happened**: Next.js is fully open source (MIT). Vercel makes money from hosting, edge functions, and developer experience features. The framework creates demand for the platform. v0 (AI code generation) adds $42M ARR as a separate revenue stream.

**Lesson**: Open source framework + commercial platform is powerful, but requires a natural "hosting/runtime" layer to monetize. Not every framework has this.

### Hugging Face

| Metric | Value |
|--------|-------|
| Model | Open source models/libraries, commercial Hub + Enterprise |
| Revenue | $130M in 2024 (up from $70M in 2023, $15M in 2022) |
| Valuation | $4.5B (Series D, Aug 2023) |
| Customers | 2K+ paying enterprise, 50K+ organizations total |
| Time to scale | Founded 2016, meaningful revenue ~2022, ~6 years |

**What happened**: Hugging Face became the "GitHub of AI" by hosting open source models. Revenue comes from enterprise contracts, API usage fees, and premium tiers. The platform effect is the moat -- not the individual models.

**Lesson**: When you become the central hub/marketplace, the open source content drives network effects. But this requires massive scale and community.

### PostHog

| Metric | Value |
|--------|-------|
| Model | Open source analytics, usage-based pricing |
| Revenue | $9.5M ARR in 2024 (138% YoY growth) |
| Valuation | $1.4B (Series E, Oct 2025) |
| Customers | 108K+ companies installed |
| Time to scale | Founded 2020, still scaling (~5 years to $1B+ valuation) |

**What happened**: PostHog is a newer example of open-source-first done well. Generous free tier drives adoption, usage-based pricing converts power users. Lean team (101-250 employees). $0 marketing spend early on.

**Lesson**: Product-led growth via open source can work, but PostHog had VC backing from the start ($27M seed). The "free" distribution channel still requires capital to sustain.

---

## Part 2: Successful Commercial-First Companies

### Cursor

| Metric | Value |
|--------|-------|
| Model | Commercial from day one ($20/mo Pro, $40/mo Business) |
| Revenue | **$2B ARR** as of Feb 2026 (doubled in 3 months) |
| Valuation | $29.3B (Nov 2025) |
| Growth | Fastest SaaS company ever from $1M to $500M ARR |
| Marketing spend to $100M ARR | **$0** |

**What made it work**: Cursor built a product that was genuinely 10x better than alternatives. They spent nothing on marketing -- pure word-of-mouth. Enterprise adoption accelerated, with enterprise customers now accounting for ~60% of revenue. The product-market fit was so strong that being closed-source was irrelevant to buyers.

**Key insight**: Commercial-first works when the product is clearly superior and the value proposition is immediately obvious to individual developers who then champion it internally.

### GitHub Copilot

| Metric | Value |
|--------|-------|
| Model | Commercial subscription ($10-39/mo individual, enterprise tiers) |
| Revenue | $2B ARR |
| Users | 20M+ all-time users |
| Enterprise | 90% of Fortune 100 companies, 50K+ organizations |
| Market share | 42% of paid AI coding tools |

**What made it work**: Microsoft/GitHub had existing enterprise relationships, distribution (every developer already uses GitHub), and the financial muscle to sustain losses while building the product. Copilot was reportedly unprofitable until 2025.

**Key insight**: Commercial-first requires either an existing distribution channel (GitHub) or deep pockets. Microsoft could afford to lose money for years while building market share.

### JetBrains

| Metric | Value |
|--------|-------|
| Model | Commercial subscription ($149-899/year per product) |
| Revenue | ~$593M ARR in 2025 |
| Profitability | Profitable with $200M+ EBITDA |
| Funding | **Zero external capital** (fully bootstrapped) |
| Users | 11.4M recurring active users, 88 of Fortune 100 |
| Time to scale | Founded 2000, ~20 years to current scale |

**What made it work**: JetBrains built genuinely superior IDEs and charged fair prices. They never raised VC money, grew organically over 20+ years, and maintained profitability throughout. Their recent strategy includes offering free non-commercial licenses for some products (RustRover) to expand the funnel.

**Key insight**: JetBrains proves that bootstrapped commercial developer tools can work, but it took 20 years and required consistently excellent products. The patience required is extraordinary.

---

## Part 3: The "Platform Absorption" Risk

This is the most critical section for cognitive-core, which is built on Anthropic's Claude Code platform.

### The Docker Cautionary Tale

Docker created the container revolution but lost the orchestration war to Kubernetes (backed by Google/CNCF). Docker's entire monetization strategy was based on Docker Swarm. When Kubernetes won, Docker's valuation collapsed from a potential $4B acquisition to near-irrelevance. Docker pivoted to developer tooling (Docker Desktop) and survived, but never captured the value it created.

**Pattern**: Create category -> Platform absorbs core functionality -> Creator struggles to monetize.

### The AI Agent Framework "Container Wars" (2025-2026)

The New Stack drew a direct parallel between today's AI agent framework proliferation and the container orchestration wars. Big tech companies are giving away agent frameworks for free:

- **Google**: ADK (Agent Development Kit)
- **Microsoft**: AutoGen, Semantic Kernel
- **Anthropic**: MCP (contributed to Linux Foundation), Claude Code plugin system
- **LangChain/LangGraph**: Open source, VC-backed
- **CrewAI**: Open source, VC-backed

The agentic AI market reached **$7.6B in 2025** and is projected to hit **$196.6B by 2034**. Big tech is giving away frameworks to drive consumption of their paid APIs and cloud services -- the framework is the loss leader, the compute is the revenue.

### What This Means for cognitive-core

cognitive-core builds on top of Claude Code. Anthropic has already launched:
- A plugin marketplace with 25 official plugins + 15 partner plugins
- Claude Marketplace for enterprise partners
- Claude Code Security (code review tool)
- One-click MCP server installation

**The risk is concrete**: Every feature cognitive-core adds as a differentiator could be absorbed into Claude Code itself. Anthropic's incentive is to make Claude Code as capable as possible to sell API tokens. Features like:
- Agent orchestration (cognitive-core's multi-agent system)
- Hook systems (cognitive-core's safety hooks)
- Skill frameworks (cognitive-core's skills)
- Workspace analysis (cognitive-core's cross-project capabilities)

...are all features Anthropic might build natively. This is not hypothetical -- Anthropic has already built plugin support, agent delegation, and is expanding Claude Code's capabilities rapidly.

### Historical Examples of Platform Absorption

| Project | Platform | What happened |
|---------|----------|---------------|
| Docker Swarm | Kubernetes/Cloud | Category creator lost orchestration war |
| Elasticsearch | AWS (OpenSearch) | Cloud provider forked and competed |
| Redis | AWS (ElastiCache) | Cloud provider offered managed version |
| MongoDB | AWS (DocumentDB) | Cloud provider built compatible service |
| Terraform | Cloud providers | Native IaC tools (CloudFormation, ARM) compete |

---

## Part 4: License Options Analysis

### License Comparison Matrix

| License | Protection Level | Community Impact | Enterprise Acceptance | Complexity |
|---------|-----------------|------------------|----------------------|------------|
| **MIT** (current) | None | Maximum openness | High acceptance | Simple |
| **Apache 2.0** | Patent protection only | Very open | High acceptance | Simple |
| **AGPLv3** | Strong (network copyleft) | Scares some enterprises | Medium (banks often avoid) | Medium |
| **BSL 1.1** | High (time-delayed open source) | Source-available, not "open source" | Growing acceptance | Medium |
| **SSPL** | Very high (service stack copyleft) | Controversial, not OSI-approved | Low-medium | Complex |
| **FSL** (Functional Source License) | High (converts to Apache/MIT after 2 years) | Fair source movement | Growing | Medium |
| **Dual License** (AGPL + commercial) | High | Open for community, paid for commercial | Proven model | Medium |
| **Proprietary** | Maximum | No community | Standard enterprise | Simple |

### Recommended Options for cognitive-core

**Option A: FSL (Functional Source License)** -- RECOMMENDED

The FSL is gaining traction specifically in the developer tools space (adopted by Sentry, Liquibase, GitButler, CodeCrafters, PowerSync). It provides:
- Full source code visibility (builds trust)
- Freedom to use, modify, learn from the code
- Protection against competitors offering it as a service
- Automatic conversion to Apache 2.0 after 2 years
- Clean, modern license text

**Option B: Dual License (AGPL + Commercial)**

Used successfully by MongoDB (before SSPL), MySQL, Qt, and others. Open source users get AGPL (copyleft scares commercial use), commercial users buy a license. The problem: banks like UniCredit often have policies against AGPL code, which would actually drive commercial license purchases -- but it also reduces adoption.

**Option C: BSL 1.1**

HashiCorp's choice. More restrictive than FSL but well-understood. The "change date" mechanism (converts to open source after a set period) provides long-term community assurance. But HashiCorp's experience shows it can trigger backlash and forks.

**Option D: Stay MIT but Build Commercial Add-ons (Open Core)**

Keep the core MIT-licensed, build proprietary features on top (enterprise dashboard, managed marketplace, SLA support). This is GitLab's model and the most community-friendly approach, but requires maintaining two codebases and having a clear free/paid feature split.

---

## Part 5: The Solo Developer Reality Check

### The Numbers Are Brutal

- **60% of open source maintainers** have quit or considered quitting
- **Almost half** of surveyed maintainers are solo maintainers
- **60% of maintainers** are unpaid
- Community management, PR reviews, issue triage, security patches, documentation -- all fall on one person
- Toxic behavior from users is a leading cause of burnout

### Can One Person Do Both?

The honest answer: **barely, and not for long**. The successful solo-to-company stories (Evan You/Vue.js, Sindre Sorhus/many npm packages) required either:
1. Reaching a Patreon/sponsorship level that replaced full-time income ($16K+/month)
2. Building a team quickly once traction appeared
3. Keeping the scope deliberately narrow

### The Burnout Equation

For cognitive-core specifically:
- Full-time job (UniCredit banking)
- Framework development (hooks, agents, skills, language packs)
- Community support (issues, PRs, documentation)
- Commercial development (marketplace, enterprise features)
- Marketing and sales
- Enterprise sales cycles (6-18 months for banking sector)

This is unsustainable for one person long-term. Something has to give.

### When Open Source Helps vs. Hurts

**Open source helps when:**
- You need adoption and credibility (early stage)
- The product benefits from community contributions (bug reports, language packs)
- You want to attract potential co-founders or early team members
- Enterprise buyers want to evaluate before purchasing
- You are building a platform/marketplace where network effects matter

**Open source hurts when:**
- You have no mechanism to capture value from adoption
- Competitors can take your work and out-resource you
- Maintenance burden exceeds your capacity
- The platform you build on (Claude Code) could absorb your features
- You need revenue NOW rather than community LATER

---

## Part 6: The Enterprise Buyer Perspective

### What Enterprises Actually Pay For

Based on research into enterprise procurement patterns, especially in banking/financial services:

1. **Support SLAs** -- Guaranteed response times (4h critical, 24h standard)
2. **Compliance and audit trails** -- SOX, SOC 2, immutable logs, role-based access
3. **Security certifications** -- Vulnerability scanning, penetration testing, CVE response
4. **SSO/SAML integration** -- Must integrate with corporate identity providers
5. **Vendor accountability** -- Someone to call when it breaks; contractual liability
6. **Training and onboarding** -- Professional services, documentation, workshops
7. **Roadmap influence** -- Enterprise customers want input on feature priorities
8. **Indemnification** -- Legal protection against IP claims

### Do Enterprises Use Open Source Without Paying?

**Yes, extensively.** But banks specifically have procurement policies that complicate this:
- License review boards must approve every open source dependency
- AGPL and SSPL are often on "banned license" lists
- MIT and Apache 2.0 are generally pre-approved
- When paying for open source, they pay for **support contracts**, not the software itself

### Banking Sector Specifically

Financial institutions are increasingly using open source, but:
- 84% report improved productivity from open source adoption
- Large banks still prefer commercial vendors for mission-critical systems
- "Over five years, licensed procurement software often costs less than 'free' alternatives when you add everything up" (integration, support, compliance)
- Enterprise sales cycles for banking tools are typically 6-18 months
- Average number of decision-makers in a B2B deal: 6-10 people

### What a Solo Founder Cannot Provide

Enterprise buyers need:
- 24/7 support rotation (impossible for one person)
- SLA guarantees with financial penalties (risky for a solo operation)
- Business continuity assurance (what happens if you get hit by a bus?)
- Formal security audits and certifications
- Professional liability insurance

---

## Part 7: cognitive-core Specific Analysis

### Current Situation

| Factor | Status |
|--------|--------|
| License | MIT (maximum openness, zero protection) |
| Team | 1 person |
| Funding | None (bootstrapped) |
| Revenue | $0 |
| Platform dependency | 100% on Anthropic Claude Code |
| Target market | Developers using AI coding assistants |
| Marketplace planned | Yes |
| Industry expertise | Banking/financial services (UniCredit) |
| Framework maturity | Active development (9 agents, 18 skills, 8 hooks, 7 language packs) |
| Reference implementation | TIMS project (4.2/5 audit score) |

### SWOT Analysis

**Strengths:**
- Deep domain expertise (banking, legacy systems, DevOps)
- Working reference implementation (TIMS)
- Comprehensive framework (agents, skills, hooks, language packs)
- First-mover in "AI coding assistant orchestration" niche
- Website already live (multivac42.ai)

**Weaknesses:**
- Solo maintainer (burnout risk, bus factor = 1)
- No revenue, no funding
- 100% platform dependency on Anthropic
- No enterprise sales infrastructure
- No formal security certifications

**Opportunities:**
- AI agent tooling market growing from $7.6B (2025) to $196.6B (2034)
- Claude Code plugin marketplace creates distribution channel
- Banking sector expertise is a unique differentiator
- Marketplace model could create network effects
- Enterprise appetite for "AI governance" frameworks

**Threats:**
- Anthropic builds equivalent features natively (highest risk)
- Big tech floods market with free frameworks
- VC-backed competitors (LangChain, CrewAI) have more resources
- Enterprise sales cycles too long for solo founder
- Platform API changes break the framework

### The Honest Assessment

**Your friend is partially right and partially wrong.**

**Where your friend is right:**
- MIT license gives away everything with no protection mechanism
- If cognitive-core becomes valuable, someone with more resources will copy it
- Enterprise buyers want to pay a vendor, not download from GitHub
- Revenue matters more than GitHub stars for sustainability

**Where your friend is wrong:**
- Going fully closed-source as a solo developer with no brand recognition and no sales team would likely result in zero sales
- Enterprise sales cycles of 6-18 months are incompatible with a one-person operation
- Without community adoption and visible traction, there is nothing to sell
- The developer tools market is allergic to closed-source frameworks (developers evaluate by trying, not by watching demos)

---

## Recommendation: The Staged Approach

### Phase 1: Protect and Build (Now - 6 months)

**Action: Switch from MIT to FSL (Functional Source License)**

- Change license immediately -- MIT is giving away your work
- FSL allows full transparency, community use, and modification
- Prevents competitors from offering cognitive-core as a service
- Converts to Apache 2.0 after 2 years (builds trust)
- Adopted by Sentry ($128M ARR), Liquibase, GitButler -- proven in developer tools
- Does NOT require building a sales team or enterprise infrastructure

**Why not closed-source?** Because you need visible traction to have anything to sell. Developers will not adopt a framework they cannot inspect, especially in the AI agent space where trust and transparency matter.

**Why not stay MIT?** Because there is zero mechanism to prevent Anthropic, Microsoft, or any VC-backed competitor from taking your entire codebase and building a commercial product on top. At MIT, you are essentially doing free R&D for the industry.

### Phase 2: Monetize the Expertise (6-18 months)

**Action: Build commercial layer while keeping core FSL**

- **Consulting**: Offer paid implementation services for teams adopting cognitive-core (leverage UniCredit/banking expertise)
- **Premium content**: Paid training, workshops, certification
- **Managed marketplace**: Take a commission on premium plugins/agents (the Vercel/Hugging Face model)
- **Enterprise support tier**: Paid support SLA for organizations that need guaranteed response times

This is achievable for one person and does not require enterprise sales infrastructure.

### Phase 3: Scale or Partner (18+ months, if traction exists)

**Decision point based on data:**

- **If strong adoption** (500+ organizations, meaningful revenue): Consider raising seed funding, hiring 1-2 people, building proper enterprise offering
- **If moderate adoption** (100-500 orgs): Stay lean, focus on consulting revenue and marketplace commissions
- **If low adoption** (<100 orgs): Evaluate whether the market exists or if platform absorption has occurred

### Phase 3 Alternative: Dual License

If enterprise demand materializes from banking/financial sector, add a commercial license option:
- FSL for community use (individual developers, small teams)
- Commercial license for enterprises wanting SLA, compliance, indemnification
- This is the MySQL/Qt model and works well for developer infrastructure

---

## The Counter-Argument: Why Closed-Source Could Work

For completeness, here is the strongest case for your friend's position:

1. **Cursor proved it**: $0 marketing, $2B ARR, purely commercial from day one
2. **JetBrains proved it**: Bootstrapped, no VC, $593M ARR, profitable
3. **The market has changed**: AI tools are so immediately valuable that developers will pay without evaluating source code
4. **You have domain expertise**: Banking/financial services framework certification could command premium pricing
5. **Open source gives away your competitive advantage**: The hooks, agents, skills architecture IS the product

**Why this probably does not apply to cognitive-core today:**
- Cursor had a 10x product moment that drove word-of-mouth; cognitive-core needs to prove this
- JetBrains took 20 years
- cognitive-core depends on Claude Code (which Cursor and JetBrains do not -- they own their platforms)
- Without brand recognition, closed-source means invisible
- The AI agent framework space is too new and fragmented for lock-in pricing

---

## Final Verdict

**Switch to FSL. Build in public. Monetize through services and marketplace. Re-evaluate in 12-18 months.**

The data overwhelmingly shows that successful developer tools companies built on open (or source-available) foundations before monetizing. The companies that went commercial-first (Cursor, JetBrains) either had a 10x product moment or 20 years of patience. Cognitive-core has neither yet.

The FSL license protects against free-riding while maintaining community trust. It is the modern answer to the MIT-vs-proprietary false binary, and it is specifically designed for exactly this situation: a solo developer building infrastructure that others will build on.

The bigger strategic risk is not the license -- it is the platform dependency on Anthropic. If Claude Code absorbs cognitive-core's core features, no license will save you. The hedge against this is building value in the **domain expertise layer** (banking workflows, compliance frameworks, industry-specific agents) that Anthropic will never build natively.

---

## Data Sources

### Company Revenue Data
- [HashiCorp IBM acquisition - CNBC](https://www.cnbc.com/2024/04/24/ibm-q1-earnings-report-2024-ibm-to-acquire-hashicorp.html)
- [IBM closes HashiCorp acquisition - TechCrunch](https://techcrunch.com/2025/02/27/ibm-closes-6-4b-hashicorp-acquisition/)
- [HashiCorp BSL license change - Spacelift](https://spacelift.io/blog/terraform-license-change)
- [GitLab FY2025 results - GitLab IR](https://ir.gitlab.com/news/news-details/2025/GitLab-Reports-Fourth-Quarter-and-Full-Fiscal-Year-2025-Financial-Results/default.aspx)
- [Cursor $2B ARR - TechCrunch](https://techcrunch.com/2026/03/02/cursor-has-reportedly-surpassed-2b-in-annualized-revenue/)
- [Cursor $29.3B valuation - CNBC](https://www.cnbc.com/2025/11/13/cursor-ai-startup-funding-round-valuation.html)
- [Cursor fastest SaaS ever - SaaStr](https://www.saastr.com/cursor-hit-1b-arr-in-17-months-the-fastest-b2b-to-scale-ever-and-its-not-even-close/)
- [Vercel $9.3B valuation - BusinessWire](https://www.businesswire.com/news/home/20250930898216/en/Vercel-Closes-Series-F-at-$9.3B-Valuation-to-Scale-the-AI-Cloud)
- [Vercel revenue - Sacra](https://sacra.com/c/vercel/)
- [Hugging Face revenue - GetLatka](https://getlatka.com/companies/hugging-face)
- [PostHog revenue - Sacra](https://sacra.com/c/posthog/)
- [GitHub Copilot $2B ARR - Mind the Product](https://www.mindtheproduct.com/what-git-hub-copilots-2-b-run-taught-us-about-how-ai-is-rewriting-the-product-led-growth-playbook/)
- [JetBrains revenue - GetLatka](https://getlatka.com/companies/jetbrains.com)
- [Sentry revenue - Contrary Research](https://research.contrary.com/company/sentry)

### Licensing Research
- [FSL license site](https://fsl.software/)
- [Sentry introduces FSL - Sentry Blog](https://blog.sentry.io/introducing-the-functional-source-license-freedom-without-free-riding/)
- [FSL vs AGPL analysis - Armin Ronacher](https://lucumr.pocoo.org/2024/9/23/fsl-agpl-open-source-businesses/)
- [Fair source movement - TechCrunch](https://techcrunch.com/2024/09/22/some-startups-are-going-fair-source-to-avoid-the-pitfalls-of-open-source-licensing/)
- [Elastic license changes - Elastic Blog](https://www.elastic.co/blog/licensing-change)
- [Open source license guide - Dev.to](https://dev.to/juanisidoro/open-source-licenses-which-one-should-you-pick-mit-gpl-apache-agpl-and-more-2026-guide-p90)

### Market & Industry Data
- [AI agent framework wars - The New Stack](https://thenewstack.io/agent-framework-container-wars/)
- [2024 State of Open Source in Financial Services - Linux Foundation](https://www.linuxfoundation.org/blog/iwb-2024-state-of-open-source-financial-services)
- [Open source in banking - RNDpoint](https://rndpoint.com/blog/open-source-vs-proprietary-software-in-banking/)
- [Open source maintainer burnout - Socket.dev](https://socket.dev/blog/the-unpaid-backbone-of-open-source)
- [Maintainer burnout crisis - Open Source Pledge](https://opensourcepledge.com/blog/burnout-in-open-source-a-structural-problem-we-can-fix-together/)
- [Enterprise sales cycles - Proposify](https://www.proposify.com/blog/b2b-saas-sales-cycle)
- [Claude Code plugins marketplace - Anthropic Docs](https://code.claude.com/docs/en/discover-plugins)

### Docker / Platform Risk
- [Docker struggles - SDxCentral](https://www.sdxcentral.com/news/dockers-success-a-foundation-for-its-struggles/)
- [AI vendor lock-in - CTO Magazine](https://ctomagazine.com/ai-vendor-lock-in-cto-strategy/)
- [Builder.ai collapse - vendor lock-in warning](https://www.swfte.com/blog/avoid-ai-vendor-lock-in-enterprise-guide)

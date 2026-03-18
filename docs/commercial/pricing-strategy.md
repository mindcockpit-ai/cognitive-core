# cognitive-core Commercial Pricing Strategy

**Date**: 2026-03-13
**Author**: Research Analyst (dev-notes workspace)
**Scope**: Tiered pricing, revenue models, ROI analysis, competitive positioning, launch strategy
**Classification**: Strategic -- Actionable Pricing Playbook

---

## Executive Summary

This report provides a complete pricing strategy for cognitive-core commercial licensing, tailored to Peter's situation: solo consultant in Europe with $200K/year consulting revenue, $30K from cognitive-core, targeting SMEs with legacy codebases. The strategy positions cognitive-core not as a SaaS product competing with Cursor or Copilot, but as a **consulting-embedded framework license** -- a fundamentally different category. The recommended model is a hybrid: framework license fee (annual) + consulting day rate, with three clear tiers. Target annual revenue from licensing alone: EUR 40,000-80,000 within 18 months, scaling to EUR 120,000+ as the client base grows.

**Core pricing principle**: Price against the value delivered (developer time saved, incidents prevented), not against the cost of competing tools. cognitive-core is not a $20/seat code completion tool -- it is an AI team orchestration framework that saves 8-15 hours per developer per week on legacy codebases.

---

## 1. Market Pricing Benchmarks

### 1.1 AI Coding Tools (Per-Seat Subscription)

| Tool | Tier | Price (USD/month) | Price (EUR/month) | What You Get |
|------|------|-------------------|-------------------|-------------|
| GitHub Copilot | Business | $19/seat | ~EUR 18/seat | Code completion, chat, CLI |
| GitHub Copilot | Enterprise | $39/seat | ~EUR 36/seat | + codebase indexing, fine-tuned models |
| Cursor | Teams | $40/seat | ~EUR 37/seat | AI IDE, $20 credit pool, shared rules |
| Cursor | Enterprise | Custom | Custom | + pooled usage, compliance, SSO |
| Windsurf | Teams | $30/seat | ~EUR 28/seat | AI IDE, 500 credits, admin dashboard |
| Windsurf | Enterprise | $60/seat | ~EUR 55/seat | + advanced controls, priority support |
| Claude Pro | Individual | $20/month | ~EUR 18/month | Claude access, Claude Code |
| Claude Max | 5x | $100/month | ~EUR 92/month | 5x Pro capacity, full Claude Code |
| Claude Max | 20x | $200/month | ~EUR 185/month | 20x Pro capacity, priority access |

**Key insight**: These tools sell code completion and AI chat. cognitive-core sells agent orchestration, safety infrastructure, and methodology. They are different categories. Do NOT price against them directly.

### 1.2 FSL-Licensed Products (Fair Source Pricing Models)

| Product | License | Free Tier | Paid Tiers | Commercial Model |
|---------|---------|-----------|------------|-----------------|
| Sentry | FSL-1.1-ALv2 | Developer (free, 5k errors) | Team EUR 24/mo, Business EUR 74/mo, Enterprise custom | Usage-based SaaS; self-hosted free for internal use |
| Liquibase | FSL (v5.0+) | Community (free, full features) | Liquibase Secure: Starter + Growth (up to $1B revenue), Enterprise custom | Governance/security/compliance premium |
| GitButler | Fair Source | Free (alpha/beta) | Planned team tier | Not yet monetized |
| Sidekiq | Proprietary (LGPL for OSS) | Sidekiq OSS (free, basic) | Pro $995/yr, Enterprise from $269/mo (~$3,228/yr) | Thread-based licensing, annual subscription |

**Key insight for Peter**: The FSL model works perfectly. Free for internal evaluation and non-competing use, paid license required for commercial use in a competing product or consulting delivery. The boundary is clean: "If you use cognitive-core to deliver paid consulting services that compete with our offerings, you need a commercial license."

### 1.3 Consulting Day Rates (Europe, 2026)

| Role | Germany (EUR/day) | Slovakia/CEE (EUR/day) |
|------|-------------------|------------------------|
| Senior DevOps Consultant | EUR 800-1,200 | EUR 400-700 |
| AI/ML Implementation Specialist | EUR 1,000-1,400 | EUR 500-900 |
| Enterprise Architect | EUR 1,200-1,800 | EUR 600-1,000 |
| AI Strategy Consultant (boutique) | EUR 1,400-2,000 | EUR 700-1,200 |
| Big 4 Consulting (for comparison) | EUR 1,400-1,800+ | EUR 900-1,400+ |

**Peter's current positioning**: With decades of UniCredit banking experience, DORA/GDPR expertise, and the "Software Archaeology" narrative backed by a production-validated framework (TIMS 4.2/5), Peter can credibly charge EUR 1,200-1,500/day in Germany and EUR 800-1,000/day in CEE markets.

### 1.4 AI Consulting Retainers

| Type | EUR/month | Scope |
|------|-----------|-------|
| Light advisory (4-8h/month) | EUR 2,000-3,000 | Architecture reviews, code audits |
| Active advisory (2-3 days/month) | EUR 4,000-6,000 | Hands-on modernization, team coaching |
| Dedicated engagement (full weeks) | EUR 8,000-15,000 | Full modernization sprints |

---

## 2. Recommended Pricing Tiers

### The "Software Archaeology" Pricing Model

Three tiers designed for Peter's solo-consultant reality: simple to explain, easy to close, no sales team needed.

---

### Tier 1: EXPLORER -- Self-Service Framework License

**Target**: Solo developers, small teams evaluating the framework, developers at companies with legacy codebases who want to try AI-augmented modernization.

| Item | Detail |
|------|--------|
| **Price** | **EUR 490/year** per project (up to 5 developers) |
| **Monthly equivalent** | ~EUR 41/month |
| **What is included** | Full cognitive-core framework: 10 agents, 23 skills, 9 hooks, all language packs (7), all database packs (3), CI/CD templates, checksum-based updater |
| **Support** | Community (GitHub Issues), quarterly framework updates |
| **Onboarding** | Self-service: documentation, video walkthrough, example configurations |
| **License scope** | Single project/repository |

**Why EUR 490/year**:
- Below the "needs procurement approval" threshold at most SMEs (typically EUR 500-1,000)
- Annual commitment creates predictable revenue
- Per-project (not per-seat) keeps it simple and attractive for teams
- Comparable to Sidekiq Pro ($995/yr) but half the price for a more comprehensive framework
- Significantly below what 5 seats of Copilot Enterprise would cost (5 x EUR 36 x 12 = EUR 2,160/yr)

---

### Tier 2: EXPEDITION -- Guided Setup + Support License

**Target**: 5-20 developer teams at SMEs starting a legacy modernization initiative, companies that want cognitive-core set up right the first time with expert guidance.

| Item | Detail |
|------|--------|
| **Price** | **EUR 2,900/year** per project (up to 20 developers) |
| **Monthly equivalent** | ~EUR 242/month |
| **What is included** | Everything in Explorer + Software Archaeology agent pack, Spring Boot/Oracle/PostgreSQL database packs, priority email support (48h response), monthly framework updates |
| **Setup** | **Half-day remote onboarding session** (4h): project analysis, CLAUDE.md configuration, agent team customization, safety hook tuning |
| **Support** | Priority email, 2 quarterly check-in calls (30 min each) |
| **License scope** | Single project/repository + workspace orchestrator for read access to related repos |

**Why EUR 2,900/year**:
- The half-day onboarding session alone would cost EUR 600-750 at Peter's day rate -- included as incentive
- Falls in the "team lead can approve" budget range at most SMEs
- Per-project still simple; teams wanting multi-project get discount (see below)
- Positions against 20 seats of Copilot Business (20 x EUR 18 x 12 = EUR 4,320/yr) -- comparable cost, radically different value

---

### Tier 3: EXCAVATION -- Full Consulting Engagement

**Target**: Companies committing to a legacy modernization program, need expert guidance throughout the transformation. This is where the real consulting revenue comes from.

| Item | Detail |
|------|--------|
| **Price** | **EUR 12,000/year** framework license (unlimited developers, unlimited projects) + **consulting at EUR 1,200/day** |
| **What is included** | Everything in Expedition + unlimited projects, unlimited developers, all current and future agent packs, all current and future language/database packs, workspace orchestrator mode, custom agent development (up to 2 custom agents), SLA: 24h response, monthly 1h advisory call |
| **Consulting** | Billed separately at EUR 1,200/day (minimum 2-day blocks), typical engagement: 2-4 days/month for 6-12 months |
| **Setup** | **Full-day onsite or remote workshop** (8h): legacy codebase assessment, modernization roadmap, cognitive-core deployment, team training |
| **License scope** | Organization-wide |

**Why this structure**:
- The EUR 12,000/year license is the anchor price -- it sounds substantial but is trivial compared to the consulting revenue
- Typical Excavation client: EUR 12,000 license + 3 days/month x 12 months x EUR 1,200/day = **EUR 55,200/year total**
- This is where the real money is: the framework license is the door opener, consulting is the revenue engine
- EUR 12,000/year for org-wide is a no-brainer when compared to: 50 seats x Copilot Enterprise x 12 months = EUR 21,600/yr (and Copilot does not include consulting)

---

### Pricing Summary Table

| | Explorer | Expedition | Excavation |
|--|---------|-----------|------------|
| **Annual Price** | EUR 490 | EUR 2,900 | EUR 12,000 |
| **Developers** | Up to 5 | Up to 20 | Unlimited |
| **Projects** | 1 | 1 (+orchestrator) | Unlimited |
| **Agents** | 10 standard | 10 + archaeology pack | All + 2 custom |
| **Skills** | 23 standard | 23 + premium | All current + future |
| **Support** | Community | Priority email, quarterly calls | SLA 24h, monthly advisory |
| **Onboarding** | Self-service | 4h guided session | Full-day workshop |
| **Consulting** | Not included | Not included | EUR 1,200/day |
| **Updates** | Quarterly | Monthly | Monthly + priority |
| **Best for** | Evaluation, small teams | SME modernization start | Full transformation program |

### Multi-Project Discount

| Projects Licensed | Discount |
|-------------------|----------|
| 1 | Full price |
| 2-3 | 15% off each |
| 4-5 | 25% off each |
| 6+ | Contact for organization-wide (Excavation tier) |

---

## 3. Revenue Model Analysis

### 3.1 Model A: Pure Subscription (Annual License Only)

| Aspect | Assessment |
|--------|-----------|
| **How it works** | Clients pay annual license fee, self-service, no consulting |
| **Pros** | Scales without Peter's time; predictable ARR; easy to sell online; low commitment for buyer |
| **Cons** | Low price ceiling (EUR 490-2,900); requires high volume to be meaningful; no personal relationship; commoditizes the framework; support burden grows with customers |
| **Revenue at 20 clients** | 15 Explorer + 5 Expedition = EUR 21,850/year |
| **Verdict** | **Insufficient alone** -- would need 50+ clients to match current cognitive-core consulting revenue of EUR 30K |

### 3.2 Model B: Pure Consulting (Day Rate Only)

| Aspect | Assessment |
|--------|-----------|
| **How it works** | Clients pay EUR 1,200/day for consulting; cognitive-core is the delivery tool, not a separate product |
| **Pros** | Highest revenue per client; leverages Peter's expertise; no product support burden; simple pricing |
| **Cons** | Does not scale (Peter is one person, ~220 billable days/year max, realistically 120-150); no passive income; zero revenue when not working; no compounding effect |
| **Revenue at 60% utilization** | 132 days x EUR 1,200 = EUR 158,400/year |
| **Verdict** | **High ceiling but fragile** -- one health issue or vacation kills revenue. Already close to Peter's current $200K. |

### 3.3 Model C: Hybrid -- License + Consulting (RECOMMENDED)

| Aspect | Assessment |
|--------|-----------|
| **How it works** | Annual framework license creates base revenue; consulting engagement for premium clients; license is the "foot in the door," consulting is the revenue engine |
| **Pros** | Dual revenue streams; license creates recurring base; consulting drives high-value engagements; license-only clients still generate value (testimonials, case studies, word-of-mouth); license renewals are nearly automatic |
| **Cons** | More complex pricing to explain (but only slightly); need to manage two billing streams |
| **Revenue projection (Year 1)** | See Section 8 |
| **Verdict** | **Best fit for solo consultant** -- combines recurring base with high-value engagements |

### 3.4 Model D: Setup Fee + Annual Subscription

| Aspect | Assessment |
|--------|-----------|
| **How it works** | One-time setup fee (EUR 2,000-5,000) + reduced annual subscription |
| **Pros** | Front-loaded revenue; covers onboarding cost; buyer psychology: "I already invested, might as well continue" |
| **Cons** | Higher barrier to entry; setup fee feels like risk to buyer; complicates pricing conversation; harder to compare with competitors |
| **Verdict** | **Not recommended** -- the Expedition tier already bundles onboarding into the annual price, which is simpler |

### Revenue Model Recommendation Matrix

| If your goal is... | Use this model |
|--------------------|---------------|
| Maximum revenue per client | **C: Hybrid** (Excavation tier) |
| Maximum number of clients | **A: Pure subscription** (Explorer tier) |
| Simplest sales conversation | **B: Pure consulting** (day rate) |
| Best long-term business building | **C: Hybrid** (mix of all tiers) |

---

## 4. Pricing Anchoring -- How to Frame the Value

### 4.1 Time Saved Per Developer Per Week

Based on industry research on AI-augmented development and Peter's TIMS production data:

| Activity | Without cognitive-core | With cognitive-core | Time Saved |
|----------|----------------------|---------------------|------------|
| Code review | 5-8 hours/week | 2-3 hours/week | **3-5 hours** |
| Security scanning | 2-3 hours/week | 0.5 hours/week (automated hooks) | **1.5-2.5 hours** |
| Onboarding new developers | 6-8 weeks to productivity | 2-3 weeks | **60-70% faster** |
| CI/CD pipeline setup | 2-4 days per project | 2-4 hours (templates) | **12-28 hours one-time** |
| Legacy code analysis | 1-2 days per module | 2-4 hours per module | **4-12 hours per module** |
| Debugging/incident response | Varies | Reduced via safety hooks | **Prevention > cure** |

**Conservative weekly savings per developer**: 5-8 hours/week
**At EUR 80/hour fully-loaded developer cost**: EUR 400-640/week saved per developer
**Annual savings for 5-developer team**: EUR 104,000-166,400

### 4.2 Cost of NOT Having Safety Hooks

| Incident Type | Average Cost (EUR) | How cognitive-core Prevents It |
|--------------|-------------------|-------------------------------|
| Leaked secret in git history | EUR 50,000-250,000 (incident response, rotation, audit) | validate-bash hook blocks dangerous commands; setup-env catches secrets |
| Production database wipe (accidental DROP) | EUR 100,000-500,000+ (downtime, recovery, audit) | validate-bash blocks destructive DB commands |
| GDPR data breach (customer PII exposed) | EUR 150/record + EUR 20M max fine or 4% global revenue | Hooks prevent PII from entering logs, commits, or agent outputs |
| Shadow AI data leak | Average EUR 620,000 added to breach cost | Hooks enforce data boundaries; agents operate within defined scope |
| Failed compliance audit (DORA) | EUR 50,000-200,000 (remediation + audit fees) | CI/CD fitness gates enforce compliance checks automatically |

**One prevented incident pays for 10+ years of cognitive-core licensing.**

### 4.3 ROI Anchoring Script (For Client Conversations)

> "Your 5-developer team costs about EUR 500,000 per year fully loaded. With cognitive-core, each developer saves approximately 6 hours per week on code review, security scanning, and legacy analysis. That is 1,560 hours per year -- equivalent to hiring another developer for free. The Explorer license costs EUR 490/year. That is a 267:1 return on investment. And it does not even count the incidents that the safety hooks will prevent."

---

## 5. European Market Considerations

### 5.1 EUR Pricing (Not USD)

All prices MUST be in EUR for European clients. Key reasons:
- German and CEE clients expect EUR pricing
- Removes currency risk and mental conversion friction
- Signals "European product, European data, European compliance"
- Use round numbers (EUR 490, not EUR 487.50)

### 5.2 German Mittelstand Expectations

| Expectation | How to Address |
|-------------|---------------|
| Total Cost of Ownership focus | Provide 3-year TCO comparison: cognitive-core vs. manual processes vs. Copilot + manual review |
| 12-18 month decision cycle | Offer 30-day free evaluation period; provide comprehensive technical documentation upfront; be patient |
| Long-term partnership orientation | Annual license with auto-renewal; roadmap transparency; version upgrade path guaranteed |
| GDPR as table stakes | Emphasize: no data leaves their infrastructure; cognitive-core is a framework, not a cloud service; all processing happens locally via Claude Code |
| Extensive documentation required | Provide: architecture overview, security whitepaper, data flow diagrams, compliance checklist |
| Reference customer required | TIMS case study (4.2/5 independent audit score); prepare anonymized before/after metrics |

### 5.3 VAT Considerations

| Scenario | VAT Treatment |
|----------|--------------|
| Peter (SK) sells to German company (B2B) | **Reverse charge**: Invoice net (0% VAT), German client accounts for VAT locally. Include "Reverse charge" note + both VAT IDs on invoice |
| Peter (SK) sells to Slovak company (B2B) | Standard Slovak VAT (20%) applies |
| Peter (SK) sells to EU company (B2B, other countries) | **Reverse charge**: Same as Germany |
| Peter (SK) sells to non-EU company (B2B) | No VAT; export of services |
| All B2B invoices in EU | Must include: both parties' VAT ID numbers, "reverse charge" notation, clear service description |

**2026 change**: EU VIDA (VAT in the Digital Age) mandates electronic invoicing for cross-border B2B transactions with real-time reporting. Ensure invoicing system supports this.

### 5.4 GDPR Compliance as Premium Value

**cognitive-core's GDPR advantage over cloud-based competitors**:

| Feature | cognitive-core | Cursor/Copilot/Windsurf |
|---------|---------------|------------------------|
| Where code is processed | Client's machine (local Claude Code) | Cloud servers (US-based) |
| Data residency | No data leaves client infrastructure | Code sent to US cloud for processing |
| GDPR Article 28 (processor) | Not applicable -- no data processing | Requires DPA (Data Processing Agreement) |
| Schrems II compliance | Not applicable -- no transatlantic transfer | Complex adequacy assessment needed |
| Right to erasure | Nothing to erase -- no data stored | Must request deletion from vendor |

**Marketing angle**: "cognitive-core is GDPR-native. Your code never leaves your machine. No DPA needed. No Schrems II risk. No adequacy assessment. Just install and work."

---

## 6. Competitive Positioning

### 6.1 cognitive-core Is NOT a Coding Assistant

The single most important positioning decision: **do not compete with Cursor, Copilot, or Windsurf**. These are code completion and chat tools priced at EUR 18-55/seat/month. cognitive-core does something fundamentally different.

| Dimension | Copilot/Cursor/Windsurf | cognitive-core |
|-----------|------------------------|---------------|
| **Category** | AI coding assistant | AI team orchestration framework |
| **Primary value** | Autocomplete, chat, code generation | Safety, methodology, multi-agent coordination |
| **Pricing model** | Per-seat subscription | Per-project license + consulting |
| **Buyer** | Individual developer | Engineering lead, CTO, team lead |
| **Purchase trigger** | "I want to code faster" | "I need to modernize safely" |
| **Complementary?** | Yes -- developers ALSO use Copilot/Cursor | Yes -- cognitive-core works ON TOP of Claude Code |

**Positioning statement**: "cognitive-core is not a replacement for your coding assistant. It is the safety infrastructure, methodology, and AI agent team that makes your coding assistant production-ready for legacy modernization."

### 6.2 Price Positioning Map

```
                    HIGH VALUE (methodology + consulting)
                              |
                              |  [EXCAVATION: EUR 12K + consulting]
                              |
                              |
                              |     [EXPEDITION: EUR 2,900]
                              |
    LOW PRICE ────────────────┼──────────────────── HIGH PRICE
                              |
              [Copilot: EUR 216-432/yr]
              [Cursor: EUR 444/yr]    [EXPLORER: EUR 490]
              [Windsurf: EUR 336/yr]
                              |
                              |
                    LOW VALUE (code completion only)
```

**Explorer** is price-competitive with coding assistants but delivers fundamentally different value. **Expedition** and **Excavation** are in a different category entirely.

### 6.3 Against Free Open-Source Alternatives

| Objection | Response |
|-----------|---------|
| "Superpowers is free and has 42K stars" | "Superpowers is a workflow tool. cognitive-core is a safety-first agent orchestration framework with production validation (TIMS 4.2/5). Different category." |
| "I can build my own CLAUDE.md" | "You can. Most teams spend 2-4 weeks getting it right. cognitive-core gives you production-proven configuration in 60 seconds, plus safety hooks that prevent costly mistakes." |
| "Why pay for something I can get for free?" | "The framework is the starting point. The value is in the methodology, the safety guarantees, and the consulting expertise. The license includes priority updates and support." |

### 6.4 The "Consultant + Framework" Bundle

This is Peter's unique value proposition and the key competitive advantage:

> "You are not just buying a framework. You are getting access to decades of enterprise banking experience, DORA/GDPR compliance expertise, and a production-validated methodology for legacy modernization. The framework is how I deliver that expertise at scale."

No competing framework (Superpowers, SuperClaude, awesome-claude-code) comes with an expert consultant who has modernized legacy banking systems. This is the moat.

---

## 7. Launch Pricing Strategy

### 7.1 Founding Member Program

**Concept**: First 10 clients get permanent pricing lock and "Founding Member" status.

| Tier | Standard Price | Founding Member Price | Discount | Lock Duration |
|------|---------------|----------------------|----------|---------------|
| Explorer | EUR 490/yr | EUR 290/yr | 41% off | **Lifetime** (as long as subscription is active) |
| Expedition | EUR 2,900/yr | EUR 1,900/yr | 34% off | **Lifetime** |
| Excavation | EUR 12,000/yr + EUR 1,200/day | EUR 8,000/yr + EUR 1,000/day | 33% off license, 17% off consulting | **First 12 months** then standard pricing |

**Why Founding Member pricing works**:
- Creates urgency ("only 10 spots")
- Rewards early trust (they are taking a bet on a new product)
- Generates testimonials and case studies (explicitly part of the deal)
- Founding members provide feedback that shapes the product
- Locked-in pricing prevents churn (switching = losing the discount)

**Founding Member obligations** (in exchange for the discount):
- Agree to provide a testimonial or case study (anonymized is fine)
- Participate in quarterly feedback calls (30 min)
- Allow Peter to reference them as a client (company name or industry)

### 7.2 Free Evaluation Period

| Aspect | Detail |
|--------|--------|
| Duration | 30 days |
| What is included | Full framework (all agents, skills, hooks, language packs) |
| Restrictions | No priority support during evaluation; community support only |
| Conversion path | At day 20, send follow-up email with ROI calculation based on their codebase size |
| Goal | Let the hooks save them from one near-miss and the value sells itself |

**Why 30 days (not 14 or 7)**:
- German Mittelstand decision cycles are slow; 14 days is not enough to get internal approval
- 30 days allows a full sprint cycle to experience the value
- Most framework evaluations need 2-3 weeks of real-world usage

### 7.3 Free Tier vs. Freemium

| Option | Description | Recommendation |
|--------|-------------|----------------|
| **Free tier (permanent)** | Subset of agents/skills always free | **Not recommended** -- with 1 GitHub star, giving away features reduces conversion pressure without generating volume |
| **Freemium (feature-gated)** | Core free, premium agents/skills paid | **Not recommended** -- too complex for a solo consultant to manage; support burden on free users |
| **Time-limited trial** | Full product for 30 days | **Recommended** -- simple, clear, and the framework's safety hooks demonstrate value quickly |
| **FSL default** | Free for internal/non-competing use, paid for commercial consulting use | **Already in place** -- the FSL license handles this automatically |

**The FSL license IS the free tier**: Anyone can use cognitive-core internally for free. The license only requires payment when used for "competing commercial use" (i.e., delivering paid consulting services). This is the cleanest model.

### 7.4 Launch Sequence

| Week | Action |
|------|--------|
| Week 0 | Publish pricing page on multivac42.ai; announce Founding Member program |
| Week 1 | Blog post: "Why a Forest, Not a Factory" (drives traffic) |
| Week 2 | Submit to Anthropic marketplace, awesome-claude-code listings (drives discovery) |
| Week 3 | LinkedIn announcement targeting German Mittelstand IT leaders |
| Week 4 | Hochschule presentation (credibility + leads) |
| Week 5-8 | Direct outreach to 20 companies with legacy Java/Perl codebases in DACH region |
| Week 8+ | Evaluate Founding Member conversion rate; adjust pricing if needed |

---

## 8. ROI Calculation for a Typical Client

### Scenario: 5-Developer Team, Legacy Java/Perl Codebase

**Client profile**:
- 5 developers working on a legacy Java/Perl banking application
- Codebase: 200K+ lines of code, 10+ years old
- Pain points: slow onboarding, frequent production incidents, manual code review, compliance pressure (DORA)
- Fully-loaded developer cost: EUR 100,000/year each (EUR 500,000 total team cost)
- Location: Germany (Mittelstand financial services firm)

### 8.1 Value Delivered (Annual)

| Value Category | Calculation | Annual Value (EUR) |
|---------------|-------------|-------------------|
| **Developer time savings** | 5 devs x 6 hours/week saved x 48 weeks x EUR 52/hour | **EUR 74,880** |
| **Faster onboarding** | 2 new hires/year x 4 weeks saved x EUR 2,500/week | **EUR 20,000** |
| **Prevented security incidents** | 1 prevented secret leak per year (conservative) | **EUR 50,000** (avoided cost) |
| **Code review acceleration** | 50% faster reviews x 5 devs x 3h/week x 48 weeks x EUR 52/h | **EUR 18,720** |
| **CI/CD setup time saved** | 3 new pipelines/year x 2 days saved each x EUR 1,000/day | **EUR 6,000** |
| **Compliance audit preparation** | 40 hours saved on DORA evidence collection | **EUR 4,000** |
| **Total Annual Value** | | **EUR 173,600** |

### 8.2 Cost (Annual)

| Cost Item | Explorer | Expedition | Excavation |
|-----------|---------|-----------|------------|
| Framework license | EUR 490 | EUR 2,900 | EUR 12,000 |
| Consulting (optional) | -- | -- | EUR 28,800 (24 days) |
| Claude Max subscription (prerequisite) | EUR 11,040 (5 x EUR 184/mo x 12) | EUR 11,040 | EUR 11,040 |
| **Total Annual Cost** | **EUR 11,530** | **EUR 13,940** | **EUR 51,840** |

*Note: Claude Max subscription is a prerequisite cost that clients pay regardless of cognitive-core. The incremental cost of cognitive-core is just the license fee.*

### 8.3 ROI Summary

| Metric | Explorer | Expedition | Excavation |
|--------|---------|-----------|------------|
| Incremental cost (license only) | EUR 490 | EUR 2,900 | EUR 40,800 |
| Value delivered | EUR 173,600 | EUR 173,600 | EUR 173,600 |
| **ROI** | **354:1** | **60:1** | **4.3:1** |
| **Breakeven** | Day 2 | Week 1 | Month 3 |
| **Payback period** | Immediate | 1 week | 3 months |

### 8.4 Three-Year TCO Comparison

| Solution | Year 1 | Year 2 | Year 3 | 3-Year Total |
|----------|--------|--------|--------|-------------|
| Do nothing (status quo) | EUR 0 | EUR 0 | EUR 0 | EUR 0 (but EUR 520,800 in lost productivity) |
| Copilot Enterprise (5 seats) | EUR 2,160 | EUR 2,160 | EUR 2,160 | EUR 6,480 |
| cognitive-core Explorer | EUR 490 | EUR 490 | EUR 490 | EUR 1,470 |
| cognitive-core Expedition | EUR 2,900 | EUR 2,900 | EUR 2,900 | EUR 8,700 |
| cognitive-core Excavation | EUR 40,800 | EUR 12,000 | EUR 12,000 | EUR 64,800 |
| External consulting (no framework) | EUR 60,000 | EUR 48,000 | EUR 36,000 | EUR 144,000 |

**Key message**: Excavation (framework + consulting) costs less than half of hiring an external consultant without a framework, and delivers better results because the framework continues working after the consultant leaves.

---

## 9. Revenue Projections

### Year 1 (Realistic, Conservative)

| Source | Clients | Revenue/Client | Total |
|--------|---------|---------------|-------|
| Explorer (Founding) | 5 | EUR 290 | EUR 1,450 |
| Explorer (Standard) | 3 | EUR 490 | EUR 1,470 |
| Expedition (Founding) | 3 | EUR 1,900 | EUR 5,700 |
| Expedition (Standard) | 1 | EUR 2,900 | EUR 2,900 |
| Excavation (Founding) | 1 | EUR 8,000 + EUR 12,000 consulting | EUR 20,000 |
| Excavation (Standard) | 1 | EUR 12,000 + EUR 24,000 consulting | EUR 36,000 |
| **Total Year 1** | **14** | | **EUR 67,520** |

| Component | Amount |
|-----------|--------|
| License revenue (recurring) | EUR 31,520 |
| Consulting revenue (variable) | EUR 36,000 |
| **Total** | **EUR 67,520** |

### Year 2 (With Renewals + Growth)

| Source | Clients | Revenue | Notes |
|--------|---------|---------|-------|
| Renewals (90% retention) | 12 | EUR 28,370 | Founding members at locked rates |
| New Explorer | 8 | EUR 3,920 | Word-of-mouth + marketplace |
| New Expedition | 4 | EUR 11,600 | Content marketing + referrals |
| Excavation (continuing) | 2 | EUR 24,000 license + EUR 48,000 consulting | Reduced consulting as teams mature |
| New Excavation | 1 | EUR 12,000 + EUR 28,800 consulting | New engagement |
| **Total Year 2** | **27** | **EUR 156,690** |

### Year 3 Projection

With compounding renewals and growing reputation: **EUR 200,000-250,000/year** (license + consulting combined).

This would bring total revenue (existing consulting + cognitive-core) to **EUR 400,000-450,000/year** -- a meaningful lifestyle business for a solo consultant.

---

## 10. Pricing Guardrails and Rules

### What to Never Do

| Rule | Reason |
|------|--------|
| Never discount more than 40% (even for Founding Members) | Deeper discounts signal desperation and devalue the product |
| Never give perpetual licenses | Recurring revenue is the goal; one-time payments kill the business |
| Never offer custom pricing for Explorer tier | Admin overhead is not worth it for EUR 490 |
| Never compete on price with Copilot/Cursor | Different category; price competition is a race to the bottom |
| Never invoice without a written agreement | Even a simple email confirmation counts; protects both parties |

### When to Flex

| Situation | Flexibility |
|-----------|------------|
| Client wants multi-year commitment | Offer 10% discount for 2-year, 15% for 3-year |
| Client is a perfect case study | Offer Founding Member pricing even after the 10 slots fill |
| Client is a university or non-profit | Offer Explorer at 50% discount (EUR 245/yr) -- they generate visibility |
| Client wants to start with Explorer and upgrade | Credit 100% of Explorer fee toward Expedition in the same year |

### Annual Price Increase Policy

- Announce in Q4 for next calendar year
- Maximum 5-10% increase per year
- Founding Members locked at their rate
- Grandfather all existing clients for current renewal cycle

---

## 11. Implementation Checklist

### Immediate (This Week)

- [ ] Add pricing page to multivac42.ai with three tiers
- [ ] Create a one-page PDF pricing sheet for email/LinkedIn sharing
- [ ] Draft Founding Member agreement (1-2 pages: pricing, obligations, testimonial clause)
- [ ] Set up Stripe or Paddle for EUR invoicing with VAT handling

### Before First Sale

- [ ] Prepare ROI calculator spreadsheet (client inputs team size, hourly cost; output shows savings)
- [ ] Write 3-page "Security Value" whitepaper (hook-prevented incidents with cost estimates)
- [ ] Create comparison table: cognitive-core vs. status quo vs. Copilot (not as competitor, but as context)
- [ ] Prepare sample invoice with correct reverse-charge notation

### Before Scaling

- [ ] Automate license key generation (can be as simple as a signed JWT with expiry date)
- [ ] Set up renewal reminder emails (60 days, 30 days, 7 days before expiry)
- [ ] Create client onboarding checklist for Expedition and Excavation tiers
- [ ] Build a "Getting Started" video (15-20 min) for Explorer tier self-onboarding

---

## 12. Key Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| No clients in first 6 months | Medium | Medium | Founding Member discounts lower barrier; direct outreach to known contacts; Hochschule presentation generates leads |
| Client churns after Year 1 | Medium | Low | Expedition/Excavation include ongoing value (advisory calls, priority updates); switching cost is high once configured |
| Anthropic builds competing features | High | High | cognitive-core's value is methodology + consulting, not features. Features can be replicated; expertise cannot. |
| Competitor undercuts on price | Low | Low | FSL license prevents direct forks from competing commercially; consulting expertise is not forkable |
| Peter's capacity maxed out | Medium | Medium | Explorer tier is self-service; limit Excavation to 2-3 active clients; consider subcontracting for delivery |

---

## Sources

### AI Coding Tool Pricing
- [Cursor Pricing](https://cursor.com/pricing)
- [Cursor Pricing 2026 Explained](https://www.eesel.ai/blog/cursor-pricing)
- [GitHub Copilot Plans & Pricing](https://github.com/features/copilot/plans)
- [GitHub Copilot Pricing 2026](https://checkthat.ai/brands/github-copilot/pricing)
- [Windsurf Pricing](https://windsurf.com/pricing)
- [Claude Pricing](https://claude.com/pricing)
- [Claude Max Plan](https://claude.com/pricing/max)

### FSL / Fair Source Licensing
- [Sentry Licensing](https://open.sentry.io/licensing/)
- [Sentry Pricing](https://sentry.io/pricing/)
- [FSL - Functional Source License](https://fsl.software/)
- [Fair Source Licenses](https://fair.io/licenses/)
- [Liquibase FSL Announcement](https://www.liquibase.com/blog/liquibase-community-for-the-future-fsl)
- [Liquibase Pricing](https://www.liquibase.com/pricing)
- [GitButler Fair Source](https://blog.gitbutler.com/gitbutler-is-now-fair-source)
- [Sidekiq Pro](https://sidekiq.org/products/pro/)
- [Sidekiq Enterprise](https://sidekiq.org/products/enterprise/)
- [Sidekiq Commercial FAQ](https://github.com/sidekiq/sidekiq/wiki/Commercial-FAQ)

### Consulting Rates
- [European Developer Hourly Rates 2026](https://www.index.dev/blog/european-developer-hourly-rates)
- [AI Consulting Cost Guide 2026](https://www.leanware.co/insights/how-much-does-an-ai-consultant-cost)
- [AI Consulting Rates 2026 Benchmarks](https://abhyashsuchi.in/ai-consulting-rates-2026-us-uk-canada-australia/)
- [Freelance Earnings Germany 2026](https://norman.finance/blog/freiberufler-wie-viel-verdienen)

### Data Breach Costs
- [IBM Cost of a Data Breach 2025](https://www.ibm.com/reports/data-breach)
- [Data Breach Statistics 2026](https://thebestvpn.com/statistics/what-is-the-average-cost-of-a-data-breach/)
- [VikingCloud Real Cost of Data Breach 2026](https://www.vikingcloud.com/blog/the-real-cost-of-data-breach)

### Developer Productivity
- [AI Coding Assistants ROI Data 2025](https://www.index.dev/blog/ai-coding-assistants-roi-productivity)
- [Top 100 Developer Productivity Statistics 2026](https://www.index.dev/blog/developer-productivity-statistics-with-ai-tools)
- [Developer Onboarding Costs](https://www.growin.com/blog/developer-retention-costs-onboarding/)
- [Reduce Onboarding Time](https://getglueapp.com/blog/reduce-onboarding-time)

### German Market
- [Mittelstand Buying Committee](https://www.jollymarketer.com/en/mittelstand-buying-committee/)
- [EU VAT for B2B SaaS 2026](https://www.scalemetrics.ai/eu-vat-for-b2b-saas-in-2026-oss-reverse-charge-invoices-common-mistakes/)
- [EU VIDA 2026 Compliance Guide](https://www.creem.io/blog/eu-vat-vida-2026-saas-compliance-guide)

### Launch Strategy
- [How to Attract Early Adopters](https://inity.agency/blog/how-to-attract-early-adopters-for-your-saas-mvp-2026)
- [Early Adopter Pricing Strategy](https://businesscollective.com/how-to-price-your-prototype-for-early-adopters/index.html)
- [Solo Founder SaaS Playbook](https://productled.com/blog/the-solo-founder-playbook-how-to-run-a-1m-arr-saas-with-one-person)


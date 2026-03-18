# Fair Source & Source-Available Pricing Research

**Date**: 2026-03-13
**Type**: Market Research
**Purpose**: Concrete pricing data for Fair Source / source-available developer tools and European consulting rates

---

## Executive Summary

Fair Source and source-available licensing has become a proven commercial model. Companies range from solo bootstrapped operations (Plausible at EUR 3.1M ARR with 8 people) to enterprise giants (Elastic at USD 1.48B revenue, HashiCorp acquired for USD 6.4B). The common pattern: a generous free tier, paid tiers starting EUR 9-49/month, and enterprise pricing via sales calls. European senior IT consulting day rates center around EUR 800-1,500/day, with AI/ML specialists commanding EUR 1,200-2,500/day.

---

## 1. Sentry (FSL-1.1-ALv2)

**License**: Functional Source License 1.1 with Apache 2.0 conversion after 2 years
**Revenue**: ~USD 128M ARR (end of 2023), 30% YoY growth
**Valuation**: USD 3.0B (2023)
**Scale**: 90K+ organizations, 4M developers, 790B events/month
**Efficiency**: USD 366K ARR per employee (above SaaS median), 70% self-serve revenue

### Pricing Tiers

| Tier | Price/month | Errors | Tracing (spans) | Session Replay | Logs | Dashboards |
|------|-------------|--------|-----------------|----------------|------|------------|
| **Developer** | Free | 5K | 5M | 50 | 5 GB | 10 |
| **Team** | $26 (annual) | 50K | 5M | 50 | 5 GB | 20 |
| **Business** | $80 (annual) | 50K | 5M | 50 | 5 GB | Unlimited |
| **Enterprise** | Custom | Custom | Custom | Custom | Custom | Unlimited |

### Overage / Add-On Costs
- Logs: $0.50/GB
- Cron Monitoring: $0.78/monitor
- Uptime Monitoring: $1.00/alert
- Continuous Profiling: $0.0315/hr
- UI Profiling: $0.25/hr

### Key Feature Gates
- **Developer**: 1 user only, no third-party integrations, no Seer AI agent
- **Team**: Unlimited users, 20 metric alerts, integrations
- **Business**: 90-day Insights lookback, anomaly detection, SAML/SCIM, advanced quota management
- **Enterprise**: Dedicated account management, premium support, custom retention, Relay infrastructure

### Lesson Learned
Sentry proves that FSL works commercially. Their product-led growth (70% self-serve) means most customers never talk to sales. The USD 26/month entry point is low enough that individual teams adopt without procurement approval.

---

## 2. GitButler (FSL)

**License**: Functional Source License, converts to MIT after 2 years
**Founder**: Scott Chacon (GitHub co-founder)
**Funding**: VC-backed (Crunchbase profile exists, amounts undisclosed in search results)

### Pricing Model
- **Current**: Entirely free for individual users
- **Planned**: Team/enterprise features "coming soon" (as of early 2026)
- **No public paid tiers yet**

### Monetization Strategy
GitButler is in the pre-monetization phase, building developer adoption first. The FSL license prevents competitors from repackaging the tool while keeping it fully usable for individuals. Revenue is expected to come from team collaboration features (code review, workflow management) targeting enterprises.

### Lesson Learned
GitButler demonstrates the FSL "build adoption first, monetize later" playbook. Not immediately relevant for a solo consultant's pricing model, but validates that FSL does not scare away users or contributors.

---

## 3. Liquibase (FSL)

**License**: Functional Source License (adopted 2024, previously Apache 2.0)

### Pricing Structure
Liquibase has moved away from publicly listed prices. All tiers now require "Get a Quote":

| Tier | Applications | Database Types | Support | Target |
|------|-------------|----------------|---------|--------|
| **Community** | Open source, free | Unlimited | Community only | Individual devs |
| **Starter** | Up to 5 | 1 type | Business hours | Companies < $1B revenue |
| **Growth** | Up to 10 | Up to 3 | Business hours | Companies < $1B revenue |
| **Business** | Up to 25 | Up to 4 | Premium (24hr SLA) | Mid-market |
| **Enterprise** | Unlimited | Unlimited | 24/7 enterprise | Large orgs |

**Note**: Starter and Growth are restricted to companies under USD 1B annual revenue.

### Previously Published Prices (from third-party sources)
- Pro: ~$33/month (annual billing)
- Business: ~$99/month
- Enterprise: ~$249/month

These appear to be legacy prices before the 2024 restructuring to the "Liquibase Secure" product line.

### Feature Gates
- **Community**: Core changelog tracking, basic database support
- **Paid tiers add**: Audit-ready change tracking, account-level reporting, professional services (mandatory), security SLA with guaranteed patch delivery timelines

### Lesson Learned
Liquibase's move to "Get a Quote" (hiding prices) and mandatory professional services bundling is a classic enterprise play. Their revenue-based eligibility gates (< $1B for lower tiers) show how to segment without complex feature gating. The mandatory professional services requirement is notable -- it forces a consulting relationship from day one.

---

## 4. PowerSync (FSL)

**License**: Functional Source License

### Pricing Tiers (Cloud)

| Tier | Price/month | Data Synced | Data Hosted | Peak Connections | Instances |
|------|-------------|-------------|-------------|-----------------|-----------|
| **Free** | $0 | 2 GB | 500 MB | 50 | 2 |
| **Pro** | From $49 | 30 GB ($1/GB over) | 10 GB ($1/GB over) | 1,000 ($30/extra 1K) | 2 ($25/extra) |
| **Team** | From $599 | 30 GB ($1/GB over) | 10 GB ($1/GB over) | 1,000 ($15/extra 1K) | 2 ($25/extra) |
| **Enterprise** | Custom | Custom | Custom | Custom | Custom |

### Self-Hosted Options
- **Open Edition**: Free (community support only)
- **Enterprise Self-Hosted**: Custom pricing (premium support, SOC 2)

### Scaling Examples
- 5,000 DAU (50K installs): ~$51/month
- 100,000 DAU (1M installs): ~$399/month
- 1,000,000 DAU (10M installs): ~$6,064/month

### Key Details
- Free tier projects deactivate after 1 week of inactivity
- Billing simplified in 2025: removed sync operations as metric, now data-based (GB) only
- 99% of customers pay less under new model

### Lesson Learned
PowerSync shows the usage-based pricing model at work. The free tier is deliberately limited (deactivation after 1 week inactivity) to push serious users to paid. The $49 entry point is the sweet spot for developer tools -- low enough for indie devs, high enough to filter out tire-kickers.

---

## 5. HashiCorp / IBM (BSL 1.1)

**License**: Business Source License 1.1 (August 2023, previously MPL 2.0)
**Revenue**: ~USD 646-662M (FY2025, ending Jan 2025)
**Acquisition**: IBM acquired HashiCorp for USD 6.4B (completed Feb 2025)

### Terraform Cloud Pricing Evolution

**Old Model (Pre-2023) -- Per User**:

| Tier | Price | Key Features |
|------|-------|------------|
| Free | $0 | State management, VCS integration |
| Team | $20/user/month | + RBAC |
| Team & Governance | $70/user/month + $500 concurrency | + Policies, run tasks |
| Business | Undisclosed | All features + agents, SSO |

**Current Model (2025+) -- Per Managed Resource (RUM)**:

| Tier | Per Resource/Month | Key Features |
|------|-------------------|------------|
| Free (enhanced) | $0 (up to 500 resources) | State management, unlimited users |
| Essentials | ~$0.10 | Basic management |
| Standard | ~$0.47 | + Governance, policies |
| Premium | ~$0.99 | + All features, agents |

**New $500 trial credit** replaces the old free tier (as of 2025).

**Real-World Cost Comparison**:
- Small team (< 500 resources): Free under both models
- Large team (10,000 resources): ~$978/month (Essentials) vs. ~$400/month (old 20-user model)

### HashiCorp Vault (HCP) Pricing

| Tier | Starting Price | Model |
|------|---------------|-------|
| Development | ~$1.58/hour | Hourly base only |
| Essentials | From ~$360/month | Base + per-client hourly |
| Standard | Higher (undisclosed) | Base + per-client + governance |
| Enterprise | Custom (sales) | Full feature set |

### BSL Impact Assessment
- The BSL prevents competitors from offering HashiCorp products as a service
- End users (non-competitors) are unaffected
- Code converts to open source (MPL 2.0) after 4 years
- The license change was directly connected to the IBM acquisition narrative

### Lesson Learned
HashiCorp's shift from per-user to per-resource pricing increased costs for large deployments but aligned revenue with actual infrastructure scale. The BSL was a precursor to the USD 6.4B exit -- it protected the commercial value that made the acquisition worthwhile.

---

## 6. Elastic (ELv2 / SSPL)

**License**: Dual SSPL 1.0 + Elastic License v2 (2021, was Apache 2.0). Added AGPL v3 option in Aug 2024.
**Revenue**: USD 1.483B (FY2025, ending Apr 2025), up 17% YoY
**Previous Year**: USD 1.267B (FY2024)
**Cloud Revenue**: USD 688M (FY2025), up 26% YoY
**Customers**: ~21,500
**Subscription share**: 93% of total revenue

### Cloud Pricing (Hosted)

| Tier | Min Monthly | Model |
|------|-------------|-------|
| Standard | ~$99/month | Per GB-hour of RAM |
| Gold | ~$114/month | Per GB-hour + support |
| Platinum | ~$131/month | Per GB-hour + ML + security |
| Enterprise | ~$184/month | Per GB-hour + all features |

**Note**: Gold is discontinued for new customers.

### Self-Managed Pricing (from market data)
- **Platinum**: ~$7,200/node/year
- **Enterprise**: ~$12,800/ERU/year (ERU = 64 GB RAM block)

### Elastic Consumption Units (ECUs)
- 1 ECU = $1.00
- Consolidates compute (GB-hour), data transfer (GB), snapshot storage (GB-month)
- Pre-purchase for 1-year or multi-year terms with discounts

### Serverless (newest model)
- Pure usage-based, pay-as-you-go
- No infrastructure management required

### Post-License-Change Impact
Revenue grew from $1.267B to $1.483B (+17%) in the year after adding AGPL. The license change did not slow growth. Cloud revenue grew faster (26%) than overall revenue (17%), showing the managed service is the primary growth driver.

### Lesson Learned
Elastic proves that license changes do not kill growth if the product is essential. Their USD 1.48B revenue dwarfs competitors. The key insight: the license protects the cloud offering (the real revenue driver at USD 688M), while self-managed stays available. The per-GB-hour model ties cost directly to infrastructure consumption.

---

## 7. European Consulting Rates (Germany, Austria, DACH)

### IT Freelancer Day Rates (Germany, 2025)

| Specialization | Hourly Rate (EUR) | Implied Day Rate (8h) |
|---------------|-------------------|----------------------|
| Management & IT Consulting | 120 | 960 |
| SAP (FICO, ABAP, MM) | 117 | 936 |
| IT Infrastructure (DBA, DevOps, Network) | 102 | 816 |
| Engineering (CAD, Mechanical) | 95 | 760 |
| Development (Web, Mobile, Software) | 94 | 752 |
| Design, Content, Media | 82 | 656 |
| **Average across all IT** | **102** | **816** |

**Source**: freelancermap.com IT Freelance Market Study Germany 2025

### By Industry (Germany)
| Industry | Hourly Rate (EUR) |
|----------|-------------------|
| Banking/Finance | 112 |
| Aerospace | 111 |
| Insurance | 110 |
| Healthcare/Chemistry | 108 |
| Automotive | 107 |
| Energy | 107 |

### Consulting Firm Day Rates (Europe)

| Firm Type | Junior/day | Senior/day | Partner/day |
|-----------|-----------|-----------|------------|
| Strategy (McKinsey, BCG, Bain) | EUR 1,500 | EUR 2,500 | EUR 3,000 |
| Management Consulting | EUR 1,000 | EUR 1,300 | EUR 1,600 |
| Expertise/Specialist Consulting | EUR 900 | EUR 1,200 | EUR 1,500 |
| Information Systems/IT Consulting | EUR 600 | EUR 900 | EUR 1,200 |

**Source**: Stafiz consulting rate benchmarks (Paris prices, -5-10% for provinces)

### AI/ML Consulting Rates (Europe, 2025-2026)

| Level | Hourly Rate | Day Rate (8h) |
|-------|------------|---------------|
| Junior AI Consultant | $100-150/hr | EUR 750-1,100 |
| Mid-Level AI Implementation | $150-250/hr | EUR 1,100-1,850 |
| Senior AI Strategist / Architect | $250-500/hr | EUR 1,850-3,700 |
| UK AI Freelancers | GBP 80-200/hr | GBP 500-1,200/day |

**Premiums**: Generative AI or reinforcement learning specialization adds 20-30% to base rates.

**Project-based AI pricing**: Small AI pilots/MVPs typically EUR 10,000-40,000.

**Retainer models**: EUR 2,000-10,000/month for ongoing advisory.

**2026 Trend**: Shift toward value-based pricing (10-40% of measurable business outcomes).

### Switzerland (DACH Premium)
- Top-tier software developers: CHF 2,400+/day
- General IT freelancers: CHF 900-1,300/day
- 5-year rate growth: 19-25%

### Market Context (Germany 2025)
- Average consulting day rates **declined 2-3%** in 2025 (first decline in years)
- Weak economy, hesitant investments, geopolitical uncertainty cited
- Despite decline, AI/ML rates remain strong due to demand outstripping supply
- Banking/Finance sector pays highest premiums

---

## 8. Small Developer Tools: Profitable with < 1,000 Users

### Proven Examples

#### Plausible Analytics (Privacy-First Web Analytics)
- **Revenue**: EUR 3.1M ARR (2024), up from EUR 2.1M (2023)
- **Team**: ~8-10 people, fully bootstrapped, no VC
- **Customers**: 12,000+ paying subscribers
- **Pricing**: EUR 9/month (10K pageviews) to EUR 169/month (10M pageviews)
- **Growth**: Zero paid advertising; viral Hacker News posts (hit #1 six-seven times)
- **Key**: GDPR timing, "anti-Google Analytics" positioning, EU-hosted

#### Tailwind CSS / Tailwind Labs (UI Framework)
- **Peak Revenue**: ~USD 4M+ in first 2 years from Tailwind UI ($149-249) and Refactoring UI ($99+)
- **First 5 months**: USD 2M from Tailwind UI alone
- **Model**: Open-source framework free, premium UI components/templates paid
- **Warning**: Revenue dropped ~80% in 2025-2026 due to AI code generation tools replacing the need for pre-built components. Laid off 75% of engineering team.

#### Buttondown (Newsletter Platform)
- **Revenue**: USD 15,000 MRR (Dec 2022), solo developer
- **Growth**: 5-10% monthly, compounding over 5+ years
- **Marketing**: Zero spend; "Powered by Buttondown" footer in every email
- **Key**: Patience and compounding; targeted developer/writer niche

#### Keygen (Software Licensing API, Fair Source / FCL)
- **License**: Fair Core License (FCL), converts to Apache 2.0 after 2 years
- **Pricing**: Free (100 ALUs, 10 releases) -> Paid tiers (quote-based)
- **Model**: Flat monthly/yearly fee, no revenue percentage, no transaction fees
- **Self-hosted**: Community Edition free, Enterprise Edition requires license
- **Key**: Niche enough (software licensing) that < 1,000 paying customers is plenty

#### Cal.com (Scheduling, AGPL)
- **Pricing**: Free (individual), Teams at $15/user/month, Organizations at $37/user/month
- **Model**: Open-source core, paid team/org features
- **Key**: Calendly competitor with self-hosting option

### Common Patterns for Sub-1000-User Profitability

1. **Niche targeting**: "Go niche or go home." Serve a specific underserved market so deeply they will pay premium prices. Micro-SaaS sweet spot: EUR 5K-50K MRR.

2. **Price points**: EUR 19-99/month for single-purpose tools. Enough to build EUR 60K-600K ARR with just 250-500 customers.

3. **No sales team needed**: Product-led growth, "Powered by X" footers, Hacker News posts, developer community engagement.

4. **Profit margins**: Bootstrapped micro-SaaS achieves 70%+ profit margins (no VC pressure, minimal overhead).

5. **Validation**: Landing page (20+ signups), 10-20 problem interviews, discounted beta access. Under EUR 1,000 spent before first revenue.

6. **Freemium conversion**: Free tier attracts users, 2-5% convert to paid. At 1,000 free users, expect 20-50 paying customers.

---

## Recommendations for Solo European Consultant (Framework + Consulting Bundle)

### Positioning

Based on the data, a solo consultant in Germany/Austria selling a developer framework with consulting should target:

| Revenue Stream | Pricing | Expected Contribution |
|---------------|---------|----------------------|
| **Framework SaaS** (hosted) | EUR 29-79/month per team | 30-40% of revenue |
| **Enterprise license** (self-hosted) | EUR 5,000-15,000/year | 10-20% of revenue |
| **Consulting / Implementation** | EUR 1,200-1,500/day | 40-50% of revenue |
| **Training / Workshops** | EUR 3,000-5,000/day | 5-10% of revenue |

### Pricing Anchors from Research

- **Low end**: PowerSync at $49/month, Plausible at EUR 9/month
- **Mid range**: Sentry Team at $26/month, PowerSync Team at $599/month
- **Enterprise**: Liquibase forces consulting bundle, Elastic charges $7,200+/node/year

### Consulting Rate Positioning

| Benchmark | Day Rate (EUR) |
|-----------|---------------|
| Average German IT freelancer | 816 |
| IT Consulting firm (senior) | 900-1,200 |
| Your target: AI + Framework specialist | **1,200-1,500** |
| Strategy consulting (for reference) | 1,500-2,500 |

The EUR 1,200-1,500/day range is justified by:
- Deep AI/ML implementation expertise (20-30% premium over standard IT)
- Framework-specific knowledge (no competitor can offer this)
- Combined tooling + consulting (Liquibase model)

### Revenue Scenarios (Solo, No Sales Team)

| Scenario | Monthly | Annual | Requires |
|----------|---------|--------|----------|
| **Minimum viable** | EUR 5K | EUR 60K | 15 consulting days + 20 SaaS subscribers |
| **Comfortable** | EUR 10K | EUR 120K | 12 consulting days + 40 SaaS subscribers |
| **Growth target** | EUR 20K | EUR 240K | 10 consulting days + 100 SaaS subscribers + 2 enterprise licenses |

### Key Lessons from Research

1. **FSL works commercially**: Sentry (USD 128M ARR), GitButler (VC-funded) -- the license does not scare away adoption.

2. **License changes do not kill growth**: Elastic grew 17% YoY after ELv2. HashiCorp was acquired for USD 6.4B after BSL.

3. **Bundle consulting with software**: Liquibase mandates professional services with every paid tier. This is the model for a solo consultant -- the software is the door opener, consulting is the revenue engine.

4. **Usage-based pricing scales**: Sentry, PowerSync, Elastic all bill per-usage (events, GB, resources). This aligns cost with customer value.

5. **Free tier must be deliberately limited**: Sentry (1 user, 5K errors), PowerSync (deactivates after 1 week), HashiCorp (500 resources). Generous enough to evaluate, tight enough to force conversion.

6. **70% self-serve is achievable**: Sentry proves that developer tools can sell without a sales team. Product quality + documentation + community = sales.

7. **AI disruption risk is real**: Tailwind Labs lost 80% revenue when AI tools could generate what their paid templates offered. Framework value must be in runtime behavior, not static artifacts.

---

## Sources

- [Sentry Pricing](https://sentry.io/pricing/)
- [Sentry Revenue & Valuation (Sacra)](https://sacra.com/c/sentry/)
- [Sentry Business Breakdown (Contrary Research)](https://research.contrary.com/company/sentry)
- [GitButler GitHub](https://github.com/gitbutlerapp/gitbutler)
- [GitButler Fair Source (HN)](https://news.ycombinator.com/item?id=41184037)
- [Liquibase Pricing](https://www.liquibase.com/pricing)
- [Liquibase FSL Announcement](https://www.liquibase.com/blog/liquibase-community-for-the-future-fsl)
- [PowerSync Pricing](https://www.powersync.com/pricing)
- [PowerSync Simplified Pricing Blog](https://www.powersync.com/blog/simplified-cloud-pricing-based-on-data-synced)
- [Terraform Cloud Pricing (Spacelift)](https://spacelift.io/blog/terraform-cloud-pricing)
- [HashiCorp BSL Announcement](https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license)
- [HashiCorp Vault Pricing](https://www.hashicorp.com/products/vault/pricing/)
- [IBM HashiCorp Acquisition](https://newsroom.ibm.com/2024-04-24-IBM-to-Acquire-HashiCorp-Inc-Creating-a-Comprehensive-End-to-End-Hybrid-Cloud-Platform)
- [Elastic Pricing](https://www.elastic.co/pricing)
- [Elastic Subscriptions](https://www.elastic.co/subscriptions)
- [Elastic FY2025 Results](https://ir.elastic.co/news/news-details/2025/Elastic-Reports-Fourth-Quarter-and-Fiscal-2025-Financial-Results/default.aspx)
- [Elastic License FAQ](https://www.elastic.co/pricing/faq/licensing)
- [freelancermap IT Freelance Market Study Germany 2025](https://www.freelancermap.com/blog/freelance-market-study-germany/)
- [IT Consultant Day Rates 2025 (metrics.biz)](https://www.metrics.biz/en/blog-post/daily-rates-2025-for-it-consultants-remain-high.html)
- [Consulting Day Rates (Stafiz)](https://stafiz.com/en/daily-rates-in-consulting)
- [AI Consultant Cost Guide (Leanware)](https://www.leanware.co/insights/how-much-does-an-ai-consultant-cost)
- [European Developer Hourly Rates (index.dev)](https://www.index.dev/blog/european-developer-hourly-rates)
- [Consultancy.uk Fees & Rates](https://www.consultancy.uk/consulting-industry/fees-rates)
- [Tailwind CSS Revenue Story](https://adamwathan.me/tailwindcss-from-side-project-byproduct-to-multi-mullion-dollar-business/)
- [Tailwind Labs AI Revenue Impact](https://medium.com/@aayan.talukdar/tailwind-css-lost-80-revenue-while-usage-hit-all-time-highs-ai-did-this-a0756345f2f3)
- [Plausible Analytics Revenue (Latka)](https://getlatka.com/companies/plausible-analytics)
- [Plausible HN Growth Playbook](https://startupspells.com/p/plausible-analytics-hacker-news-playbook)
- [Keygen Pricing](https://keygen.sh/pricing/)
- [Keygen Fair Source Blog](https://keygen.sh/blog/keygen-is-now-fair-source/)
- [FSL License](https://fsl.software/)
- [Fair Source Licenses](https://fair.io/licenses/)
- [Open Source Monetization (Evil Martians)](https://evilmartians.com/chronicles/how-to-turn-an-open-source-project-into-a-profitable-business)
- [Indie SaaS Top 30 (Market Clarity)](https://mktclarity.com/blogs/news/indie-saas-top)

# Enterprise Customization Model

**Date**: 2026-03-19
**Status**: Research complete, MVP defined
**Category**: Strategic — revenue model + product architecture

---

## Taxonomy — 6 Categories

| Cat | Offering | Self-Service? | Effort | Price Range (EUR) |
|-----|----------|---------------|--------|-------------------|
| A | Custom Configuration | Yes | 0 | Included |
| B | Custom Rules | Yes (with guidance) | 1 day PS | 2,000-5,000 |
| C | Custom Language/DB Packs | PS required | 2-5 days | 5,000-12,000 |
| D | Custom Agents + Skills | PS required | 1-8 days | 2,000-15,000 |
| E | Custom Hooks | PS required | 1-3 days | 2,000-6,000 |
| F | Custom Adapters + Providers | PS required | 3-10 days | 10,000-20,000 |

## Extension Points (Already Exist)

| Point | Location | Contract | Ready? |
|-------|----------|----------|--------|
| Configuration | `cognitive-core.conf` | Shell variables | Yes |
| Agents | `core/agents/*.md` | YAML frontmatter + markdown | Yes |
| Skills | `core/skills/*/SKILL.md` | YAML + references/ | Yes |
| Rules | `.claude/rules/*.md` | YAML with path globs | Yes |
| Hooks | `core/hooks/*.sh` | JSON stdin/stdout via `_lib.sh` | Yes |
| Language Packs | `language-packs/*/` | pack.conf + skills/ + rules/ | Yes |
| Database Packs | `database-packs/*/` | pack.conf + skills/ | Yes |
| Adapters | `adapters/*/` | `adapter-interface.yaml` | Yes |
| Board Providers | `providers/*.sh` | `_provider-lib.sh` | Yes |
| Blocked Patterns | `CC_BLOCKED_PATTERNS` | POSIX ERE regex | Yes |
| Security Levels | `CC_SECURITY_LEVEL` | minimal/standard/strict | Yes |

## What's Missing for MVP

| Gap | Effort | Priority |
|-----|--------|----------|
| Enterprise Pack Manifest | 1-2 days | HIGH — enables all enterprise sales |
| Private Pack Registry | 1 day | HIGH — enables ongoing delivery |
| Config Overlay | 0.5 days | MEDIUM |

**Total engineering for MVP: 2.5-3.5 days**

## Revenue Model

**Primary**: Project-based professional services (80%+ of revenue)
**Secondary**: Monthly retainers (EUR 2-4K/month)
**Not recommended**: Seat-based licensing (no server to gate, violates local-first)

### Service Pricing

| Service | Duration | Price (EUR) |
|---------|----------|-------------|
| Stack Assessment | 1-2 days | 2,000-5,000 |
| Custom Language Pack | 2-5 days | 5,000-12,000 |
| Custom Agent | 1-3 days | 2,000-6,000 |
| Custom Skill Suite (3-5) | 3-8 days | 6,000-15,000 |
| Custom Hook Set | 1-3 days | 2,000-6,000 |
| Custom Adapter | 5-10 days | 10,000-20,000 |
| Team Training | 0.5-1 day | 1,500-3,000 |
| Full Enterprise Package | 2-4 weeks | 15,000-40,000 |

### Year 1 Conservative Projection

| Client | Engagement | Revenue (EUR) |
|--------|-----------|---------------|
| Liquid UI | Custom pack + skills + training | 15,000-20,000 |
| Struts-to-SpringBoot | Migration pack + consulting | 8,000-12,000 |
| BOL Systemhaus | VS Code adapter + assessment | 12,000-18,000 |
| Hochschule | Workshop only | 1,500 |
| Inbound (2-3 clients) | Assessments + customization | 6,000-15,000 |
| **Total** | | **42,500-66,500** |

## Competitive Analysis

| Vendor | Model | cognitive-core Lesson |
|--------|-------|----------------------|
| Terraform Enterprise | Private module registry + policy-as-code | Need enterprise pack registry |
| Pulumi Business Critical | Custom providers + PS | Package PS explicitly |
| GitHub Enterprise | Seat-based + GHAS | Not applicable (no server) |
| Datadog | Per-host + custom integrations | Not applicable (no runtime) |

**Pattern**: Framework free → PS for customization → registry for maintenance

## Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| Terraform Enterprise pricing ($37K avg) | HashiCorp pricing docs | T1 |
| Pulumi Business Critical model | Pulumi pricing page | T1 |
| GitHub Enterprise $21/seat/month | GitHub pricing page | T1 |
| Fair Source compatibility with enterprise | FSL-1.1-ALv2 license text | T1 |

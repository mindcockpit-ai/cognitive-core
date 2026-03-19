# Enterprise Customization Model

**Date**: 2026-03-19
**Status**: Research complete, architecture defined
**Category**: Product architecture — extension point map and offering taxonomy

---

## Taxonomy — 6 Categories

| Cat | Offering | Self-Service? | Effort |
|-----|----------|---------------|--------|
| A | Custom Configuration | Yes | Included |
| B | Custom Rules | Yes (with guidance) | Light PS |
| C | Custom Language/DB Packs | PS required | 2-5 days |
| D | Custom Agents + Skills | PS required | 1-8 days |
| E | Custom Hooks | PS required | 1-3 days |
| F | Custom Adapters + Providers | PS required | 3-10 days |

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
| Enterprise Pack Manifest | 1-2 days | HIGH — enables packaging delivery |
| Private Pack Registry | 1 day | HIGH — enables ongoing updates |
| Config Overlay | 0.5 days | MEDIUM |

**Total engineering for MVP: 2.5-3.5 days**

## Competitive Analysis

| Vendor | Model | cognitive-core Lesson |
|--------|-------|----------------------|
| Terraform Enterprise | Private module registry + policy-as-code | Need enterprise pack registry |
| Pulumi Business Critical | Custom providers + PS | Package PS explicitly |
| GitHub Enterprise | Seat-based + GHAS | Not applicable (no server) |
| Datadog | Per-host + custom integrations | Not applicable (no runtime) |

**Pattern**: Framework free → PS for customization → registry for maintenance

## Licensing

- **Academic/Individual**: Free (Fair Source FSL-1.1-ALv2)
- **Commercial**: Contact for licensing terms
- **Enterprise Customization**: Professional services, scoped per engagement

For pricing and commercial terms, contact: peter.wolaschka@mindcockpit.ai

## Sources

| Finding | Source | Authority |
|---------|--------|-----------|
| Terraform Enterprise model | HashiCorp pricing docs | T1 |
| Pulumi Business Critical model | Pulumi pricing page | T1 |
| GitHub Enterprise model | GitHub pricing page | T1 |
| Fair Source compatibility | FSL-1.1-ALv2 license text | T1 |

---
name: grounding
description: Shared grounding engine for other skills and hooks. Checks text for stochastic vulnerability (L1), unresolved code references (L2), and ontology drift (L3). Not invoked directly.
user-invocable: false
disable-model-invocation: true
allowed-tools: [Bash]
---

# Grounding Engine

Deterministic checks that other skills and hooks call through `scripts/check.sh`. Design: ADR-001 (`docs/architecture/decisions/ADR-001-grounding-ontology-framework.md`), epic [#442](https://github.com/mindcockpit-ai/cognitive-core/issues/442).

## Installation

Never listed in `CC_SKILLS` by hand. A skill that uses the engine declares it in its frontmatter:

```yaml
requires-skills: [grounding]
```

`install.sh` and `update.sh` then install and update `grounding` with that skill, and `update.sh --prune` keeps it while the skill is selected. The plugin ships every core skill, including this one.

## Contract

| Call | Result |
|------|--------|
| `bash scripts/check.sh --version` | `grounding <engine version> schema=<output schema>`, exit 0 |
| `bash scripts/check.sh < text` | Report on stdout, exit 0 (advisory) |

Callers locate the engine next to their own skill directory (`../grounding/scripts/check.sh`) and must report a missing engine instead of staying silent.

## Layers

| Layer | Status |
|-------|--------|
| L1 stochastic vulnerability | [#434](https://github.com/mindcockpit-ai/cognitive-core/issues/434) (today in `project-board/validate-prompt.sh`) |
| L2 code grounding | [#434](https://github.com/mindcockpit-ai/cognitive-core/issues/434) |
| L3 ontology | [#436](https://github.com/mindcockpit-ai/cognitive-core/issues/436) |

Until those land, `check.sh` reads its input and reports that no layer is enabled.

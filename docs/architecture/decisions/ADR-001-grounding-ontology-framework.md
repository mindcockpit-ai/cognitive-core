# ADR-001: Grounding and Ontology Framework

| Field | Value |
|-------|-------|
| **Status** | Proposed |
| **Date** | 2026-10-29 (rescored the same day with gated criteria) |
| **Deciders** | Maintainers |
| **Reviews** | solution-architect: approve with changes on the first draft (B1, M1-M5, m1-m4 incorporated) and re-review 2026-10-29 approve with changes (findings applied in this version); research-analyst: standards survey and criteria research (incorporated); security-analyst: pending (Phase 3) |
| **Related** | [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163), [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169), [#141](https://github.com/mindcockpit-ai/cognitive-core/issues/141), [#345](https://github.com/mindcockpit-ai/cognitive-core/issues/345), [#359](https://github.com/mindcockpit-ai/cognitive-core/issues/359), [deterministic-vs-stochastic-analysis](../deterministic-vs-stochastic-analysis.md), [source-authority-model](../../research/source-authority-model.md), [parsimony-principle](../../research/parsimony-principle.md) |

---

## Summary of Decisions

Scores are recomputed by `python3 -I adr-score.py ADR-001-grounding-ontology-framework.md`, which also runs the sensitivity check.

| # | Decision | Winner (gated set) | New | Legacy winner | Legacy | Robustness | Recommendation |
|---|----------|--------------------|-----|---------------|--------|------------|----------------|
| D1 | Engine placement | Non-invocable skill `core/skills/grounding/` | 4.05 | F: glossary rule file | 4.65 | Robust | Implement |
| D2 | Ontology representation | **JSON `ontology.json`** (changed) | 4.10 | F: prose glossary | 4.50 | **Tie** (JSON + Markdown view 4.20, JSON 4.10, Markdown 4.10); reversibility picks plain JSON | Implement; Markdown view deferred |
| D3 | Code grounding resolvers | Resolver chain, v1 tier | 4.30 | Status quo `test -e` | 4.65 | Robust | Simplify (v1: path, agent, scope) |
| D4 | Stochastic vulnerability layer | Deterministic rules with INCOSE/29148 IDs | 4.60 | Same | 4.85 | Robust | Implement; sampling deferred |
| D5 | Output contract | Text + versioned TSV (`schema=1`) | 4.40 | Text only | 4.70 | Robust | Implement; SARIF optional |
| D6 | Persistence | Files in git, no database | 4.60 | Same | 5.00 | Robust | Implement; SQLite cache deferred |
| D7 | Consumers and hooks | Skills + CI self-check suite | 3.85 | Skills only | 4.85 | **Tie** with skills only (3.80); ROC prefers report-mode hooks | Implement; hooks decided at the pilot checkpoint |

**What changed against the previous draft:**

- **D2 changes from Markdown to JSON, by tie-break, not by score.** Counting "no custom parser" once (Pars and SecM only; both loaders are scripts with tests, so both get Ver 5), JSON and Markdown both score 4.10 and JSON with a generated Markdown view 4.20. All three are in the tie set. Reversibility picks plain JSON: the view is purely additive and can be generated later, while a Markdown source would need a migration to change. JSON also has the smaller parser surface. The earlier draft counted the parser advantage three times (re-review finding).
- **D7 is a tie between skills only and skills + CI suite** (3.80 and 3.85). Both are equally reversible (a test suite adds no install or settings change), so the second tie-breaker, the higher Ver score, picks skills + CI. Report-mode hooks score 3.55 after the evidence notes (Neut 2: only Claude Code runs hooks; SecM 2: context injection is an S1 surface) and are outside the tie set, but ROC weights prefer them; the plan keeps a pilot checkpoint with measurable thresholds (Phase 8) that triggers the hooks phase.
- **The legacy set would have chosen the non-enforcing option in 5 of 7 decisions** (glossary files, status quo, text only, skills only). It has no criterion for deterministic enforcement, and compensatory security plus overlapping Philosophy and Maintenance reward doing less.

**Pattern: no decision adds a runtime dependency.** Standards are adopted at the edges (semantics, rule IDs, export formats), not as libraries.

---

## Decision Criteria

Adopted after a first scoring draft that used other criteria (process deviation, see process rule 1); every score below was redone against these criteria as written. Source: criteria research 2026-10-29 (Provenance, last block).

### Gates (must pass; a fail eliminates the option)

| Gate | Pass condition |
|------|----------------|
| **G1 Security** | No new unvalidated untrusted-input path; fails closed; no weakening of existing hook denials; relevant OWASP Agentic risks addressed |
| **G2 Backwards compatibility** | Existing installations keep working through `update.sh` with no manual step |
| **G3 Runtime constraints** | Bash + stdlib Python 3.9, offline, POSIX ERE, macOS and Linux; no model, API, or service beyond the assistant session already running |

**G1 is provisional** for every option until the Phase 3 threat model ([#435](https://github.com/mindcockpit-ai/cognitive-core/issues/435)); a later G1 fail reopens the decision.

### Weighted criteria

| Criterion | W | 1 | 3 | 5 |
|-----------|---|---|---|---|
| **Eff**ectiveness: solves the stated problem on the stated scenarios | 0.30 | Misses most scenarios | Main scenario, known misses or false positives | All scenarios, measured low false-positive rate |
| Deterministic **Ver**ifiability: the behaviour the option introduces happens without relying on the LLM to follow instructions, and a test proves it | 0.25 | Instruction only | Script exists but its invocation depends on the LLM, or partial tests | Run by a script, hook, or CI on every relevant path, test in `tests/run-all.sh`, auditable output |
| **Pars**imony: least accidental complexity (files, concepts, knobs, upkeep) | 0.20 | New subsystem | Moderate additions | Fits inside existing components |
| Platform **Neut**rality: same behaviour on Claude, Aider, IntelliJ, VS Code, plugin | 0.15 | One platform | Three, or degraded on some | All, same semantics |
| **Sec**urity **M**argin: attack-surface reduction beyond G1 | 0.10 | Adds surface (still passes G1) | Neutral | Measurably reduces surface |

Standards alignment is no longer scored: the Source Authority Model already requires T1/T2 evidence, so scoring it again double-counts. Each fact is counted under one criterion only.

### Why the legacy set changed

The earlier ADRs used Security 0.35, Feasibility 0.30, Philosophy 0.20, Maintenance 0.15. Legacy totals are still shown in every matrix (columns Sec, Feas, Phil, Maint) for comparison.

| Problem | Evidence |
|---------|----------|
| Security is compensatory: a 1 can be bought back with 5s elsewhere, against Key Rule 9 (defense in depth) | ISPOR MCDA good practice (T1) |
| Feasibility mixes hard constraints (stdlib, offline) with effort; constraints should screen, not score | Keeney, value-focused thinking (T1) |
| Philosophy (parsimony) and Maintenance overlap and double-count one value | ISPOR: criteria must be non-redundant (T1) |
| No criterion for deterministic enforcement, the framework's strategic focus | NIST AI RMF "valid and reliable" as base characteristic (T1); MADR 4 Confirmation (T1) |

### Process rule

1. Commit drivers, gates, weights, and anchors before scoring. **Deviation in this ADR:** the criteria were adopted after a first scoring draft with other criteria, so git history cannot prove the order here. From the next ADR on, the criteria section is committed on its own before options are scored.
2. Screen options with the gates; eliminated options get no new score (legacy score still shown).
3. Score with anchors; non-obvious scores carry an evidence note.
4. Sensitivity: each weight +-0.05 and +-0.10 with proportional renormalisation (flips at both steps are reported); re-rank under equal and rank-order-centroid weights (0.457/0.257/0.157/0.090/0.040); report the critical weight (smallest change that flips the winner).
5. **Tie set**: every option within 0.20 of the top score, plus any option that wins under a +-0.05 shift. **Robust**: the tie set is the winner alone and the winner holds under equal or ROC weights. Otherwise **Tie**: choose the most reversible option in the tie set; if reversibility is equal, the higher Ver score (strategic focus); confidence Low. Thresholds are judgment (one anchor step on a 0.20 weight), not a standard.
6. Each decision names a **Confirmation**: the test, hook, or suite that proves the decision is followed (MADR 4).

---

## Context

**Strategic focus (2026-10-29):** grounding, ontology, and deterministic assurance are prioritised; EU AI Act and GDPR features ([#120](https://github.com/mindcockpit-ai/cognitive-core/issues/120)) are deprioritised. This is why Deterministic verifiability is the second-highest weight.

LLM-executed text (prompts, issues, agent instructions, replies) fails in four ways. The framework addresses each only partially:

| Layer | Failure | Existing coverage | Ability type |
|-------|---------|-------------------|--------------|
| **L0 Source authority** | External facts from low-authority sources | Source Authority Model (T1-T5) in research-analyst and project-coordinator | S (agent instructions) |
| **L1 Stochastic vulnerability** | Vague wording is interpreted differently on each run | `validate-prompt.sh` regex rules ([#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163)), `propose` only | D |
| **L2 Code grounding** | Paths, agents, scopes, symbols that do not exist | Path ratio ([#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169)), `propose` only | D |
| **L3 Ontology** | Domain terms that are aliased, deprecated, or ambiguous | None; [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169) deferred concept names for lack of a vocabulary | D (lookup), H (curation) |

L0 grounds what agents **read**; L1-L3 ground what agents are **told** and **write**.

### Current state defects (Phase 0, in progress)

The architect review found that L1/L2 never ran in practice. The fix is implemented on branch `fix/validate-prompt-runs`:

| Defect | Fix |
|--------|-----|
| Step 7a called the linter through `timeout 5`; stock macOS has no `timeout`, so the call failed silently | The script re-executes itself under `timeout`/`gtimeout` when present (portable 5 s budget); callers need no `timeout` |
| `CC_PROJECT_DIR` was never set, so grounding always reported `skipped` | Fallback to `git rev-parse --show-toplevel` |
| `@agent` handles resolved only against `core/agents/` (framework repo only) | Checks `.claude/agents`, `.cognitive-core/agents`, `core/agents` |
| Once grounding ran, a prompt without references crashed bash 3.2 under `set -u` (empty array) | `${arr[@]+...}` expansion |
| A skipped or failed run was invisible | Step 7a prints `NOT RUN (...)`; Step 9 posts a `Lint:` line in the issue comment metadata |
| Tests never exercised the real call | Suite 19 runs the Step 7a block extracted from `SKILL.md`, on a PATH without `timeout` |

The `Lint: NOT RUN` line also gives the pilot a measurable skip rate for D7.

### Evidence for the problem

- StateMirror (arXiv 2610.32648, T2): 43.3% of hallucinated agent actions across 4,398 trajectories were filesystem mismatches, 41.9% namespace or symbol mismatches; each cost a median of 3 extra steps and 22.4K tokens.
- OWASP LLM Top 10 2026, LLM07 Misinformation, names "weak grounding" and "ambiguous prompts" as causes (T1).

---

## D1: Engine Placement and Distribution

**Problem.** The checks must be shared by several skills and later by hooks, and reach every installation. `install.sh` copies only `_lib.sh`, hooks in `CC_HOOKS`, three utilities, agents, and skills in `CC_SKILLS` (`install.sh:464-543`); `update.sh` maps files back only to `core/hooks`, `core/agents`, `core/skills` (`update.sh:455-489`); `build-plugin.sh:32-56` packages only hooks, agents, skills.

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| A: Copy logic into each consuming skill | pass | 3 | 3 | 2 | 4 | 2 | 2.85 | 2 | 4 | 2 | 2 | 2.60 |
| B: Top-level `core/grounding/` | pass | 4 | 4 | 3 | 5 | 3 | 3.85 | 4 | 3 | 3 | 3 | 3.35 |
| C: Hook helper `core/hooks/_grounding.sh` | pass | 4 | 4 | 4 | 3 | 3 | 3.75 | 4 | 4 | 4 | 3 | 3.85 |
| **E: Non-invocable skill `core/skills/grounding/`** | pass | 4 | 4 | 4 | 5 | 3 | **4.05** | 4 | 5 | 4 | 4 | 4.30 |
| F: Glossary rule file only | pass | 1 | 1 | 5 | 4 | 3 | 2.45 | 4 | 5 | 5 | 5 | **4.65** |

- **A**: duplicated sanitizer; the 9 P0 mitigations of [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) drift between copies (Pars 2, SecM 2).
- **B**: not a gate fail: with new mappings it can be delivered. Pars 3: besides the implicit-install logic E also needs, it adds a new component category to `install.sh`, the `update.sh` path mapping, and `build-plugin.sh`; without them consumers would be updated but the engine would never reach installed projects or the plugin (architect B1).
- **C**: Neut 3: Python helpers in the hook directory; adapters map hooks differently.
- **E**: uses the existing skill install and update paths, including new-file updates ([#359](https://github.com/mindcockpit-ai/cognitive-core/issues/359)).
- **F**: Ver 1, the LLM applies the rules ([deterministic-vs-stochastic-analysis](../deterministic-vs-stochastic-analysis.md)). The legacy set picks it. Options E and F were added after the first review (architect m3).

**Result:** new set E 4.05 (margin 0.20 over B, at the threshold; tie set E only; no flip at +-0.05 or +-0.10; same winner under equal and ROC; critical weight -0.15 Neut); legacy set F 4.65.

**Decision: E** (Robust). `install.sh` and `update.sh` install `grounding` implicitly whenever a consumer is selected, so consumers never depend on `CC_SKILLS` listing it.
**Confirmation:** install/update test (Phase 1) asserts `grounding/scripts/check.sh` exists after installing only `project-board`, for every adapter and the plugin.

```
core/skills/grounding/
  SKILL.md                    # user-invocable: false; documents the contract
  scripts/
    check.sh                  # [D] stdin -> report; exit 0 (advisory)
    _sanitize.sh              # [D] the 9 P0 mitigations, extracted
    l1-stochastic.sh          # [D] regex rules with INCOSE/29148 IDs
    resolve.py                # [D] L2 resolvers (stdlib, py3.9, python3 -I, args after --)
    ontology.py               # [D] L3 checks, JSON-LD export
core/skills/project-board/validate-prompt.sh   # wrapper with inline L1 fallback
```

---

## D2: Ontology Representation

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| Markdown `ONTOLOGY.md`, hand-written grammar | pass | 4 | 5 | 3 | 5 | 3 | 4.10 | 4 | 4 | 4 | 4 | 4.00 |
| **JSON `ontology.json`, SKOS semantics** | pass | 3 | 5 | 4 | 5 | 4 | **4.10** | 4 | 5 | 4 | 4 | 4.30 |
| JSON + generated Markdown view | pass | 4 | 5 | 3 | 5 | 4 | 4.20 | 4 | 4 | 3 | 3 | 3.65 |
| SKOS JSON-LD as source format | pass | 4 | 5 | 2 | 4 | 3 | 3.75 | 3 | 3 | 2 | 2 | 2.65 |
| LinkML YAML | fail G3 | - | - | - | - | - | elim. | 3 | 1 | 2 | 2 | 2.05 |
| F: Prose glossary in `.claude/rules/` | pass | 2 | 1 | 5 | 4 | 3 | 2.75 | 4 | 5 | 5 | 4 | **4.50** |

- **Ver 5 for every loader**: each format is read by a script with tests, so verifiability does not separate them. The parser difference is counted once, under Pars and SecM.
- **Markdown**: best for domain-expert review (Eff 4), but needs a hand-written parser (Pars 3) whose grammar handling is extra parser surface (SecM 3).
- **JSON**: no grammar code, but still a new file format and `ontology.py` (Pars 4, a moderate addition, not "fits inside existing components"); stdlib parser, smaller surface (SecM 4). Eff 3: no comments, less friendly for non-developer curators. `json.loads` alone is not strict (a duplicate key silently keeps the last value), so the loader adds duplicate-key rejection and a canonical-format check (rules below).
- **JSON + Markdown view**: top score (4.20) through Eff 4; the view is purely additive to JSON.
- **SKOS as source**: the T1 vocabulary standard, but `@context` and IRIs make hand-editing error-prone (Pars 2).
- **LinkML**: fails G3 (pip dependencies, YAML needs a non-stdlib parser).
- OWL 2, SHACL (overkill, SHACL 1.2 still drafts) and Context Mapper CML (glossary only proposed) were not scored.

**Result:** tie set JSON + Markdown view 4.20, Markdown 4.10, JSON 4.10 (margin 0.10; no flip at +-0.05, Markdown or JSON win at +-0.10; equal weights prefer JSON, ROC the view; critical weight -0.08 Eff); legacy set F 4.50.

**Decision: JSON with SKOS semantics** (Tie, confidence Low; changed from Markdown). Tie-break by reversibility: plain JSON is a subset of the top option, so the view can be added later without changing the source format, while choosing Markdown would need a migration to reverse; JSON also has the smaller parser surface. A generated Markdown view (`ontology.py --format=md`) is deferred until curators ask for it.
**Confirmation:** suite test loads a fixture ontology and asserts rejection of a missing `format` key, a duplicate JSON key, a non-canonical file, a duplicate label (SKOS S13), and an untyped anchor.

### Format (version 1)

```json
{
  "format": 1,
  "terms": [
    {
      "label": "Invoice",
      "definition": "Billable document issued after order fulfilment",
      "aliases": ["Bill"],
      "deprecated": ["Rechnung", "InvoiceDoc"],
      "anchors": ["path:src/billing/domain/invoice.py", "table:INVOICE"],
      "related": ["Customer", "InvoiceLine"]
    }
  ]
}
```

| Rule | Specification |
|------|---------------|
| Format marker | `"format": 1` required; other values are rejected |
| Duplicate keys | Rejected via `object_pairs_hook` (plain `json.loads` keeps the last value silently) |
| Canonical form | The file must equal `json.dumps(data, indent=2, ensure_ascii=False) + "\n"` (author key order kept, no sorting), so PR diffs stay stable for human review; `ontology.py format` rewrites a file canonically |
| Keys | `label`, `definition` required; `aliases`, `deprecated`, `anchors`, `related` optional; unknown keys are warnings |
| Multi-word terms | Allowed; matched literally and case-sensitively |
| Anchors | Typed: `path:`, `table:`, `symbol:`; untyped entries are errors |
| Label disjointness | A label appears once across all labels, aliases, and deprecated terms (SKOS S13) |
| Non-ASCII | Allowed; L3 matching runs before ASCII transliteration (architect M5) |

### SKOS mapping (export only)

| Field | SKOS |
|-------|------|
| `label` | `skos:prefLabel` |
| `definition` | `skos:definition` |
| `aliases` | `skos:altLabel` |
| `deprecated` | `skos:hiddenLabel` |
| `related` | `skos:related` |
| `anchors` | `rdfs:seeAlso` |
| Deprecated whole concept (later) | `owl:deprecated true` + `dcterms:isReplacedBy` (community convention, T3) |

JSON-LD 1.1 export adds an `@context` via `json.dumps`. Turtle 1.1 export is deferred until requested.

---

## D3: Code Grounding Resolvers

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| **Resolver chain, v1 tier (paths, agents, scopes)** | pass | 4 | 5 | 4 | 5 | 3 | **4.30** | 4 | 4 | 4 | 4 | 4.00 |
| Status quo `test -e` only ([#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169)) | pass | 2 | 5 | 5 | 5 | 3 | 3.90 | 4 | 5 | 5 | 5 | **4.65** |
| LSP 3.18 via assistant plugins | fail G3 | - | - | - | - | - | elim. | 3 | 2 | 2 | 2 | 2.35 |
| SCIP or tree-sitter index | fail G3 | - | - | - | - | - | elim. | 3 | 1 | 1 | 2 | 1.85 |
| Code-intelligence MCP server (Serena) | fail G3 | - | - | - | - | - | elim. | 2 | 1 | 1 | 2 | 1.50 |

- **Status quo**: Eff 2: paths only, `@agent` resolution fails in installed projects.
- **LSP**: needs a language server per language, not callable from Bash; Claude Code plugins ship no server binary (T1). **SCIP**: protobuf; **tree-sitter**: compiled grammars. **Serena**: GPL-3.0, Python 3.13. stack-graphs is archived (not scored).

**Result:** new set resolver chain 4.30 (margin 0.40, Robust, critical weight -0.18 Eff); legacy set status quo 4.65.

**Decision: resolver chain, v1 tier** (Robust). Symbol resolution (`tags` file, Python `ast`, `grep -F`) is deferred (architect M4) and waits on the ripgrep-in-CI decision. Ratio is `resolved / evaluated`; capped or sanitised-away references are reported as `skipped`, so a ratio gate can reach 1.0.
**Confirmation:** suite 19 grounding tests in an installed-project fixture (already added in Phase 0 for agents and the git-root fallback).

---

## D4: Stochastic Vulnerability Layer

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| **Deterministic L1 regex + L3 exact lookups, INCOSE/29148 IDs** | pass | 4 | 5 | 5 | 5 | 4 | **4.60** | 5 | 5 | 5 | 4 | **4.85** |
| EARS notation check for acceptance criteria | pass | 3 | 5 | 4 | 5 | 4 | 4.10 | 5 | 4 | 4 | 4 | 4.35 |
| LLM-as-judge step inside skills | pass | 3 | 1 | 3 | 3 | 2 | 2.40 | 3 | 4 | 2 | 3 | 3.10 |
| Sampling-based (semantic entropy, SelfCheckGPT) | fail G3 | - | - | - | - | - | elim. | 3 | 2 | 1 | 2 | 2.15 |
| External tool (Promptfoo, NeMo, Guardrails AI) | fail G3 | - | - | - | - | - | elim. | 3 | 1 | 1 | 2 | 1.85 |

- **G3, LLM-as-judge vs sampling**: LLM-as-judge is a step for the assistant session that is already running, so it adds no model, API, or service and passes G3 (its weakness is Ver 1). Sampling fails G3: semantic entropy needs an NLI model (non-stdlib), and SelfCheckGPT needs N extra model calls outside the session (adapter CLI or API with credentials and network), since MCP sampling is deprecated (2026-07-28). It also measures output uncertainty, not how many ways a prompt can be read. **Deferred as a research item.**
- **SecM 4 (deterministic layer, EARS)**: literal matching and labels-only output; no new input path beyond the existing 64 KB stdin cap. Not 5, because the attack surface is not measurably reduced.
- **External tools**: evaluate outputs, not input text; Node or Python 3.10+.
- **EARS**: useful opt-in rule for acceptance criteria later; complementary, not in v1.

**Result:** new set deterministic layer 4.60 (margin 0.50, Robust, no critical weight within +-1.00); legacy set same option 4.85.

**Decision: deterministic layer, v1 rule set** (Robust).
**Confirmation:** suite 19 pattern corpora (dirty and clean) plus one test per L3 rule.

| Layer | v1 rules | Deferred |
|-------|----------|----------|
| L1 | Existing 12 categories, each with an INCOSE GtWR v4 rule ID (R7 vague terms, R8 escape clauses, R9 open-ended; numbering to verify against the v4 PDF) | EARS rule |
| L3 | `alias-drift`, `deprecated-term`, `dangling-anchor`, `label-collision` (SKOS S13) | `undefined-term`, `ambiguous-term` (no term detection in free text; false-positive risk) |

The disclaimer stays: "syntactic patterns only - semantic ambiguity requires human review".

---

## D5: Output Contract and Interoperability

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| **Human text + `--format=tsv` with `schema=1`** | pass | 4 | 5 | 4 | 5 | 4 | **4.40** | 5 | 5 | 4 | 4 | 4.65 |
| Text + TSV + optional SARIF 2.1.0 (file targets) | pass | 4 | 5 | 3 | 4 | 4 | 4.05 | 4 | 4 | 3 | 3 | 3.65 |
| Human text only (status quo) | pass | 2 | 2 | 5 | 4 | 4 | 3.10 | 5 | 5 | 5 | 3 | **4.70** |
| JSON with OTel `gen_ai.evaluation.result` names | pass | 4 | 5 | 3 | 4 | 4 | 4.05 | 4 | 4 | 3 | 3 | 3.65 |
| SARIF only | pass | 3 | 4 | 2 | 3 | 4 | 3.15 | 4 | 3 | 2 | 3 | 3.15 |

- **Text only**: Ver 2, consumers scrape display text (two spaces after `WARN`, `validate-prompt.sh:127`).
- **SARIF**: GitHub requires `physicalLocation` and `partialFingerprints`, so only file targets (self-check suite, ontology file, CI); `message.text` carries the label only.
- **OTel GenAI evaluation event**: Development status; reuse field names at most.
- **SecM 4 (all but text only)**: labels and counts only, never matched text (S7). Not 5: no measurable surface reduction.

**Result:** new set text + TSV 4.40 (margin 0.35, Robust, critical weight +0.46 Pars); legacy set text only 4.70.

**Decision: text + TSV** (Robust); SARIF writer optional in Phase 6.
**Confirmation:** suite asserts the `schema=1` header and the column count per record type for every output path.

```
schema=1
finding	L1	incose-r7-vague	12	5	warn
finding	L3	alias-drift	18	3	warn
grounding	7	8	2
```

Each line starts with a record type and has a fixed column count per type: `finding` = layer, rule, line, col, severity; `grounding` = resolved, evaluated, skipped. No column is reused for a different meaning.

Time budgets: 1 s for hook callers, 5 s for `propose`, measured including Python start-up. The Phase 0 self re-exec under `timeout`/`gtimeout` becomes a shared helper.

---

## D6: Persistence

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| **Files in git, no database** | pass | 4 | 5 | 5 | 5 | 4 | **4.60** | 5 | 5 | 5 | 5 | **5.00** |
| Files + derived SQLite cache (stdlib `sqlite3`) | pass | 4 | 4 | 3 | 4 | 3 | 3.70 | 4 | 4 | 3 | 3 | 3.65 |
| MCP resource server exposing the ontology | fail G3 | - | - | - | - | - | elim. | 3 | 3 | 2 | 2 | 2.65 |
| Graph or relational database | fail G3 | - | - | - | - | - | elim. | 2 | 1 | 1 | 1 | 1.35 |
| Vector database (RAG) | fail G3 | - | - | - | - | - | elim. | 2 | 1 | 1 | 1 | 1.35 |

- **SQLite cache**: Eff 4, not 5: the latency gain is unmeasured and the Eff 5 anchor requires a measurement. Ver 4 because a stale cache can disagree with the files. SecM 3: a writable derived file is extra tamper surface. Deferred until the pilot measures resolvers above 2 s.
- **Files, SecM 4**: no credentials, network service, or extra writable state; not 5 because the current surface is unchanged.
- **MCP server**: the shared server has non-stdlib requirements (`adapters/_shared/mcp-server/requirements.txt`), so it fails G3; revisit for read access to the ontology.
- **Databases**: credentials, operations, attack surface; ontology changes invisible in git. The project's own database stays a read-only source for a future `/ontology init`.

**Result:** new set files 4.60 (margin 0.90, Robust, no flip at +-0.10, no critical weight within +-1.00); legacy set same option 5.00.

**Decision: files** (Robust).
**Confirmation:** install test asserts no new runtime dependency (`python3 -I` import check of the engine modules with stdlib only).

---

## D7: Consumers and Hooks

| Option | Gates | Eff | Ver | Pars | Neut | SecM | **New** | Sec | Feas | Phil | Maint | **Legacy** |
|--------|-------|-----|-----|------|------|------|---------|-----|------|------|-------|------------|
| Skills call the engine only | pass | 3 | 3 | 5 | 5 | 4 | 3.80 | 5 | 5 | 5 | 4 | **4.85** |
| **Skills + CI self-check suite** | pass | 3 | 4 | 4 | 5 | 4 | **3.85** | 5 | 5 | 4 | 4 | 4.65 |
| Skills + CI suite + opt-in report-mode hooks | pass | 4 | 5 | 3 | 2 | 2 | 3.55 | 4 | 3 | 3 | 3 | 3.35 |
| Hooks in enforce mode (deny) | pass | 4 | 5 | 2 | 2 | 2 | 3.35 | 3 | 3 | 2 | 2 | 2.65 |
| F: Rule-file guidance only | pass | 1 | 1 | 5 | 4 | 3 | 2.45 | 4 | 5 | 5 | 5 | 4.65 |

- **Skills only**: Ver 3. The skill step is LLM-executed (S/D) and can be skipped, as Phase 0 showed.
- **CI self-check suite**: Ver 4, deterministic over shipped skills and agents, but not over runtime prompts.
- **Report-mode hooks** (Stop reply grounding, PreToolUse Agent findings): Ver 5, the harness runs them whether or not the LLM follows the skill. Costs: an allow-with-context helper in `_lib.sh` (only deny and ask exist, `_lib.sh:192-290`), a PostToolUse writer to the session cache (`_lib.sh:398`), settings wiring that `update.sh` does not deliver ([#345](https://github.com/mindcockpit-ai/cognitive-core/issues/345)). Neut 2: the hook part exists only on Claude Code (the plugin also runs on Claude Code); Aider, IntelliJ, and VS Code get only the skills + CI baseline. SecM 2: hooks add text to the model context (finding labels, never ontology definitions), a new S1-class surface that the threat model must cover.
- **Enforce mode**: denying a subagent call on a heuristic warning is risky (Pars 2).

**Result:** tie set skills + CI 3.85, skills only 3.80 (margin 0.05; skills only wins at +-0.05 and under equal weights; hooks win at +-0.10 and under ROC weights, 3.84 against 3.64; critical weight -0.04 Ver); legacy set skills only 4.85.

**Decision: skills + CI self-check suite, Tie (confidence Low).** The tie set is skills only and skills + CI. Both are equally reversible (the CI suite is a file under `tests/` with no install or settings change), so the second tie-breaker, the higher Ver score, selects skills + CI. Report-mode hooks are outside the tie set, but ROC weights prefer them; because the strategic focus favours them, the plan keeps a **pilot checkpoint** (Phase 8) with measurable thresholds. Phase 9 (report-mode hooks) is executed if either holds:

- `Lint: NOT RUN` appears in more than 10% of `propose` runs during the pilot, or
- at least 5% of final replies in pilot transcripts contain one or more unresolved backticked paths, measured offline by the Phase 8 transcript scan script (the reply hook itself does not exist yet).
**Confirmation:** self-check suite in `tests/run-all.sh`; the pilot report gives both trigger rates with the scan script output.

| Consumer | Layers | Mode | Ability type |
|----------|--------|------|--------------|
| `project-board propose` | L1, L2, L3 | Advisory, `Lint:` line posted | D/S |
| `acceptance-verification` | L2 (evidence citations resolve) | Report | D/S |
| `fitness` | L2 ratio, L3 drift | Gate via `CC_GROUNDING_MIN_RATIO` | D |
| `code-review` | L3 deprecated terms in new identifiers | Warn | S/D |
| Test suite (new) | L1 over `core/skills/*/SKILL.md`, `core/agents/*.md` | Baseline, no new regressions | D |
| Ontology curation | L3 | Human approves term changes in PRs | H |

---

## Feasibility Review (Solution Architect)

| Component | Maturity (1-5) | Implementation risk | Recommendation | Finding |
|-----------|----------------|---------------------|----------------|---------|
| Fix live linter (timeout, `CC_PROJECT_DIR`, agent path, bash 3.2 crash) | 5 | Low | **In progress** ([#432](https://github.com/mindcockpit-ai/cognitive-core/issues/432)) | M1 |
| Engine as non-invocable skill + implicit install | 4 | Low | Implement | B1 |
| Wrapper with inline L1 fallback; suite 19 targets `_sanitize.sh` | 5 | Low | Implement | M2 |
| TSV `schema=1` with record types, ratio = resolved/evaluated, time budgets | 5 | Low | Implement | M3 |
| Ontology `format: 1` JSON loader, duplicate-key rejection, canonical form | 5 | Low | Implement | m1 |
| L3 exact lookups + label collision | 4 | Low | Implement | M4 |
| L3 before ASCII transliteration | 5 | Low | Implement | M5 |
| `undefined-term`, `ambiguous-term` | 2 | High | **Defer** | M4 |
| Symbol and issue resolvers | 3 | Medium | **Defer** | M4 |
| `/ontology init` from packs | 3 | High | **Defer** | M4 |
| Grounding hooks + allow-with-context helper | 3 | Medium | **Pilot checkpoint** (D7, Phase 9) | m2 |
| Options E (skill) and F (glossary file) added; MCP rejected on G3, not as Claude-only | - | - | Done in D1, D6 | m3 |
| New keys in conf example, CONFIGURATION.md, install generator; defaults in code | 5 | Low | Implement (Phase 7) | m4 |

---

## Standards Alignment

### Aligned without dependencies

| Standard | Status | Used for |
|----------|--------|----------|
| W3C SKOS Reference (2009 Rec) | T1 | Ontology semantics, S13 label disjointness, export mapping |
| JSON-LD 1.1 (2020 Rec); Turtle 1.1 (2014 Rec) | T1 | Export formats (not RDF 1.2, still a draft) |
| INCOSE Guide to Writing Requirements v4 (2023) | T2 | L1 rule IDs (numbering to verify against the PDF) |
| ISO/IEC/IEEE 29148:2018 (revision at DIS stage) | T1 | "Unambiguous" and "verifiable" characteristics cited per rule |
| OWASP Top 10 for LLM Applications 2026 | T1 | LLM07 Misinformation (problem statement), LLM01 Prompt Injection (threat model) |
| OWASP Top 10 for Agentic Applications (2025-12) | T1 | ASI06 Memory and Context Poisoning (ontology as untrusted input), ASI01 |
| NIST AI 600-1 (2024) | T1 | "Confabulation" as risk vocabulary |
| SARIF 2.1.0 + Errata 01 (OASIS) | T1 | Optional findings output for file targets (2.2 still in review) |
| EARS (IEEE RE'09) | T1 | Optional future rule for acceptance criteria |

### Rejected as dependencies

All fail gate G3 (see the matrices): LinkML, OWL 2 reasoners, pySHACL, rdflib, SCIP, tree-sitter, Serena, Joern, Promptfoo, NeMo Guardrails, Guardrails AI, RAGAS. stack-graphs is archived; OTel GenAI evaluation conventions are in Development status.

---

## Prior Art (reworded claims)

| Claim | Previous wording | Revised wording |
|-------|------------------|-----------------|
| L1 prompt linter ([#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163)) | "No framework-integrated, rule-based, codebase-aware static prompt linter exists" | "No published tool combines INCOSE-style ambiguity rules, a grounding ratio, and an ontology check over issue and prompt text across multiple assistant platforms (search 2026-10-29)." Claude Code `/doctor prompt-audit` (v2.1.283) audits instruction files for stale paths; stdlib dead-path linters for AGENTS.md exist (T4); requirements tools such as QRA have long checked vague terms. |
| Grounding ratio ([#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169)) | "No published precedent" | "No published precedent found as of 2026-10-29." Closest related work: StateMirror (arXiv 2610.32648) reports precision/F1 on agent state mismatches; the AGENTS.md smells study (arXiv 2606.15828) flags blind references with an LLM but does not check existence. |

---

## Security (input for security-analyst, Phase 3)

The threat model is completed **before** ontology work, because the format choice affects security.

| # | Threat | Reference | Mitigation |
|---|--------|-----------|------------|
| S1 | Ontology definitions carry prompt injection into model context | OWASP ASI06, LLM01 | Definitions are never injected into model context by the engine or any hook; output is labels, counts, and line numbers only. The ontology file is untrusted input to the engine, not to the model |
| S2 | `CC_ONTOLOGY_FILE` from a config file that is sourced as shell | n/a | Path must resolve inside the project, no symlinks, regular file |
| S3 | Terms used as regex patterns (ReDoS, injection) | [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) V6 | Literal matching only (`grep -F` or Python `in`); never `grep -E` with ontology input |
| S4 | Oversized ontology (DoS) | [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) | Size cap (e.g. 256 KB) and term cap, mirroring the 64 KB stdin cap |
| S5 | Anchors pointing outside the project | [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169) constraints | Reuse existing traversal rules; reject `..` and absolute paths |
| S6 | Python helper imports project modules | [#420](https://github.com/mindcockpit-ai/cognitive-core/issues/420) | `python3 -I`, arguments after `--` |
| S7 | Matched text echoed into comments or SARIF | [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) V2, V5 | Labels only in all formats |
| S8 | Future `/ontology init` with database credentials | n/a | Read-only connection, through existing database-packs |

---

## Config Keys After Parsimony

Architect m4 (defaults and documentation for new keys) is addressed in the last paragraph of this section and Phase 7.

| Key | Proposed | Keep? |
|-----|----------|-------|
| `CC_ONTOLOGY_FILE` | Ontology location, default `docs/domain/ontology.json` | **Yes** |
| `CC_GROUNDING_MIN_RATIO` | Fitness gate threshold, default unset | **Yes** |
| `CC_GROUNDING_LEVEL` | off / report / enforce | **Eliminate** (`CC_HOOKS` already opts in) |
| `CC_GROUNDING_ENFORCE` | Single enforce flag for hooks | Defer (with hooks) |
| `CC_GROUNDING_CACHE` | SQLite cache switch | Defer |
| `CC_GROUNDING_SARIF` | SARIF output | **Eliminate** (CLI flag `--format=sarif`) |

**Result: 2 new config keys in v1.** Both get defaults in code (older conf files lack them) and entries in `cognitive-core.conf.example`, `docs/CONFIGURATION.md`, and the install.sh conf generator.

---

## Consequences

### Positive

- One sanitizer and one rule set; the [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) mitigations cannot drift.
- The existing linter actually runs (Phase 0), giving the first field evidence for L2.
- Closes the concept-name gap deferred in [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169) with exact, low-noise lookups.
- Standards-compatible at the edges (SKOS, SARIF, INCOSE, OWASP) with zero new dependencies.
- The framework checks its own shipped prompts.
- `validate-prompt.sh` remains the public entry point for `propose`; its implementation moves into the engine.

### Negative

- Ontology maintenance cost for adopting projects (opt-in; no `init` in v1).
- JSON is less friendly for non-developer curators; validation errors must name the term and key. A generated Markdown view is the deferred remedy.
- L1 baseline over shipped skills may surface many findings; cleanup may need its own issue.

---

## Implementation Plan

| Phase | Work | Size | Effort |
|-------|------|------|--------|
| 0 | Fix live linter (in progress, branch `fix/validate-prompt-runs`): self re-exec time budget, git-root fallback, installed agent dirs, bash 3.2 empty-array crash, `NOT RUN` reporting, `Lint:` metadata line, tests running the documented Step 7a block | S | 0.5-1 d |
| 1 | Distribution: `core/skills/grounding/`, implicit install in install.sh/update.sh, build-plugin.sh, install/update tests | M | 1-1.5 d |
| 2 | Engine extraction: `_sanitize.sh` + L1 with rule IDs, wrapper fallback, suite 19 retargeted, TSV `schema=1`, ratio fix, time budgets | M | 1-1.5 d |
| 3 | Threat model and mitigations S1-S8 (security-analyst) | S | 0.5-1 d |
| 4 | Ontology `format: 1` JSON loader and validation (duplicate-key rejection, canonical-format check, `ontology.py format`), L3 v1 rules, label collision, L3 before transliteration, JSON-LD export | M | 1-1.5 d |
| 5 | Consumers: propose, acceptance-verification, fitness gate, code-review | M | 1-1.5 d |
| 6 | Self-check suite over shipped skills and agents + SARIF writer | S-M | 1-1.5 d |
| 7 | Docs and config: conf example, CONFIGURATION.md, install generator defaults, ARCHITECTURE.md | S | 0.5 d |
| 8 | Pilot on TIMS: transcript scan script (offline; unresolved backticked paths per final reply), resolver latency, `Lint: NOT RUN` rate; D7 checkpoint with the thresholds from D7 | S | 1.5-2.5 d effort, 1-2 weeks calendar |
| 9 | Conditional (D7 trigger): allow-with-context helper in `_lib.sh`, Stop reply-grounding and PreToolUse Agent hooks in report mode, opt-in via `CC_HOOKS` | M | 1-1.5 d |

**v1 total: 8-12.5 working days** (3-4 weeks calendar with reviews and pilot), **9-14 days if the Phase 9 trigger fires.** Order: 0, 1, 2, 3, 4, 5, with 6 and 7 parallel to 5, then 8, then 9 if triggered.

**Minimum viable scope: Phases 0-4, 4-6.5 days.** Delivers a working linter, distribution, the shared engine, the threat model, and the ontology checks, callable through `validate-prompt.sh` and the engine CLI. Wiring into `propose` metadata and the other consumers is Phase 5.

**Deferred (about 5-7 days if later demanded):** `/ontology init` (2-3 d), symbol resolvers (1 d), `undefined-term`/`ambiguous-term` (1.5-2 d), SQLite cache, Turtle export, generated Markdown ontology view (0.5 d), sampling-based research spike. Grounding hooks moved to Phase 9.

Estimates are calibrated on [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163) (about 520 lines, 2 days) and [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169) (about 240 lines, under 1 day), with about 60% of lines in tests.

---

## Open Questions

1. Should the self-check suite fail CI on new findings, or only report?
2. Confirm the criteria change (gated set replaces Security 0.35 / Feasibility 0.30 / Philosophy 0.20 / Maintenance 0.15) as the standard for future ADRs.
3. Is an organisation-wide shared ontology in scope (would point toward [#141](https://github.com/mindcockpit-ai/cognitive-core/issues/141), outside this ADR)?

---

## Provenance

| Claim | Source | Category | Tier |
|-------|--------|----------|------|
| SKOS labels, S13 disjointness | w3.org/TR/skos-reference | documented | T1 |
| Deprecated-concept convention | Skosmos data model wiki | external | T3 |
| Turtle 1.1 Rec, RDF 1.2 draft, JSON-LD 1.1 | w3.org/TR | documented | T1 |
| SHACL 1.2 working drafts | w3.org data-shapes publications | documented | T1 |
| LinkML 1.12.1 | pypi.org/project/linkml | documented | T1 |
| Context Mapper glossary proposal | github.com/ContextMapper/context-mapper-dsl issue 382 | external | T2 |
| LSP 3.18; Claude Code plugins ship no server, no cloud sessions | microsoft.github.io/language-server-protocol; code.claude.com/docs/en/plugins | documented | T1 |
| stack-graphs archived | github.com/github/stack-graphs; RUSTSEC-2026-0303 | documented | T1 |
| SCIP protobuf, LSIF archived | github.com/sourcegraph/scip; lsif.dev | documented | T1 |
| Serena licence and Python version | github.com/oraios/serena | documented | T1 |
| OWASP LLM Top 10 2026, LLM07 | GenAI-Security-Project/GenAI-LLM-Top10 | documented | T1 |
| OWASP Agentic Top 10, ASI06 | genai.owasp.org (2025-12-09) | documented | T1 |
| NIST AI 600-1 confabulation | NIST AI 600-1 | documented | T1 |
| INCOSE GtWR v4 R7/R8/R9 | INCOSE webinar, Jama guide | external | T2/T3 (verify numbering) |
| ISO 29148 revision | iso.org/standard/94091 | documented | T1 |
| EARS | IEEE RE'09, DOI 10.1109/RE.2009.9 | documented | T1 |
| Promptfoo joins OpenAI, stays MIT | promptfoo.dev blog | documented | T1 |
| Semantic entropy cost; SelfCheckGPT | Nature 630:625 (2024); EMNLP 2023 | documented | T1 |
| StateMirror mismatch statistics | arXiv 2610.32648 (preprint) | external | T2 |
| AGENTS.md smells, no existence check | arXiv 2606.15828 | external | T2 |
| `/doctor prompt-audit` | code.claude.com changelog, v2.1.283 | verified | T1 |
| Stdlib dead-path linters exist | agents-md-check, agents-lint (GitHub) | external | T4 |
| MCP 2026-07-28 deprecations | blog.modelcontextprotocol.io | documented | T1 |
| OTel GenAI evaluation in Development | open-telemetry/semantic-conventions-genai | documented | T1 |
| SARIF GitHub subset requirements; 2.2 in review | docs.github.com SARIF support; oasis-open.org | documented | T1 |
| Live linter defects (timeout, project dir, agent path) | `SKILL.md:1065`, `validate-prompt.sh:189,246`; `command -v timeout` empty on macOS | verified | T1 |
| Distribution paths | `install.sh:464-543`, `update.sh:455-489`, `build-plugin.sh:32-56` | verified (architect) | T1 |
| **Criteria:** non-redundant, preferentially independent criteria; compensation risk | Marsh et al., Value in Health 2016 (ISPOR MCDA report 2) | documented | T1 |
| Fundamental vs means objectives; screen inferior options | Keeney, Value-Focused Thinking | documented | T1 |
| ROC weights; critical-weight sensitivity | Barron & Barrett, Mgmt Sci 1996; Triantaphyllou & Sanchez, Decision Sciences 1997 | documented | T1 |
| Decision drivers and Confirmation | MADR 4.0.0 (adr.github.io/madr) | documented | T1 |
| Trade-offs, confidence, reversibility | Microsoft Azure Well-Architected ADR guidance | documented | T1 |
| "Valid and reliable" as base characteristic | NIST AI 100-1 (AI RMF 1.0) | documented | T1 |
| ISO 25010:2023 characteristics (Safety added, Flexibility replaces Portability) | ISO preview; arc42 quality model | documented | T1/T2 (sub-characteristics to verify) |
| Hooks give deterministic control | code.claude.com hooks guide | documented | T1 |
| LLM design-rationale precision about 0.27 (why scores need evidence) | arXiv 2504.20781 | external | T2 |
| Tie and robustness thresholds | One anchor step on a 0.20 weight | inferred | - |

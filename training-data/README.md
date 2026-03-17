# Training Data for cognitive-core - Mistral Fine-tuning

## Purpose

Training data extracted from cognitive-core development sessions for fine-tuning Mistral LLM models on AI-augmented development frameworks, multi-agent orchestration, and developer tooling domains.

## Project Context

**cognitive-core** is a portable framework that installs production-grade hooks, agents, skills, CI/CD pipelines, and monitoring into any Claude Code project. It provides born abilities (safety hooks, validation, linting) and learned abilities (skill acquisition, evolution, cooperation) inspired by evolutionary cognitive biology. The framework supports 10 languages, 3 database packs, and 3 platform adapters (Claude Code, Aider/Ollama, IntelliJ). Built primarily in Bash with Python adapters.

## Directory Structure

```
training-data/
├── raw/                    # Raw conversation exports (markdown)
├── alpaca/                 # Alpaca instruction format (JSONL)
├── sharegpt/               # ShareGPT conversation format (JSONL)
├── qa_pairs/               # Simple Q&A pairs (JSONL)
├── metadata/               # Statistics and indexes
└── README.md               # This file
```

## Domain Categories

| Domain | Description | Tags |
|--------|-------------|------|
| Hook Development | JSON protocol hooks for bash/read/write/fetch validation | `hooks`, `validation`, `security` |
| Agent Orchestration | Multi-agent coordination with Symbiotic Cortex model | `agents`, `orchestration`, `multi-agent` |
| Skill Architecture | YAML frontmatter skills with progressive disclosure | `skills`, `yaml`, `architecture` |
| Shell Scripting | POSIX-compatible Bash with `set -euo pipefail` | `bash`, `shell`, `posix` |
| CI/CD Pipelines | Evolutionary CI/CD with fitness gates | `cicd`, `github-actions`, `fitness` |
| Framework Design | Adapter pattern, language packs, database packs | `framework`, `adapters`, `extensibility` |
| Security Patterns | Defense-in-depth hooks, secret scanning, graduated responses | `security`, `defense-in-depth`, `secrets` |
| Test Infrastructure | 12 test suites with 378+ assertions | `testing`, `bash-testing`, `assertions` |
| Monitoring | Prometheus, Grafana dashboards, Alertmanager | `monitoring`, `prometheus`, `grafana` |

## Formats

### Alpaca (Instruction Format)
```json
{"instruction": "...", "input": "...", "output": "..."}
```
One entry per line in JSONL files. Best for single-turn instruction following.

### ShareGPT (Conversation Format)
```json
{"conversations": [{"from": "human", "value": "..."}, {"from": "gpt", "value": "..."}]}
```
One conversation per line. Best for multi-turn dialogue fine-tuning.

### Q&A Pairs
```json
{"question": "...", "answer": "...", "domain": "...", "tags": [...]}
```
Simple question-answer pairs with domain metadata for filtering.

## Usage

```bash
# Count entries per format
wc -l alpaca/*.jsonl
wc -l sharegpt/*.jsonl
wc -l qa_pairs/*.jsonl

# Validate JSONL format
python3 -c "import json; [json.loads(l) for l in open('alpaca/data.jsonl')]"

# Filter by domain tag
python3 -c "
import json
with open('qa_pairs/data.jsonl') as f:
    for line in f:
        entry = json.loads(line)
        if 'hooks' in entry.get('tags', []):
            print(entry['question'])
"
```

## Quality Guidelines

- Technical accuracy required
- No PII or credentials
- Complete context in each entry
- Proper code formatting
- Domain tags for filtering

## Sensitive Data Exclusions

| Type | Reason |
|------|--------|
| API keys and tokens | Third-party service credentials |
| 1Password vault references | Secret management URIs |
| Cloudflare API tokens | Deployment credentials |
| GitHub personal access tokens | Repository access |
| SSH private keys | Authentication material |
| Webhook secrets | CI/CD pipeline secrets |

## Supervised by

Training Data Curator Agent

# OWASP LLM Top 10 2025 — cognitive-core Coverage Assessment

Honest assessment of what cognitive-core addresses and what remains architecturally unsolved.

## LLM01: Prompt Injection

**Status: Partial**

Prompt injection remains architecturally unsolved in single-LLM systems. The CaMeL (Dual-LLM) pattern is not achievable within Claude Code's hook architecture.

**What we do:**
- `validate-read.sh` prevents reading files that could contain crafted injection payloads (e.g., `/etc/shadow` can't be weaponized)
- `validate-fetch.sh` audits/filters external URLs that could serve injection content
- `validate-bash.sh` blocks execution of commands that injection might produce

**What we don't do:**
- Cannot inspect or sanitize the content the LLM processes after a Read/WebFetch
- Cannot prevent indirect prompt injection embedded in fetched web pages or files
- No dual-LLM verification of tool calls

**Honest limitation:** Defense-in-depth reduces the surface but cannot eliminate this class of attack.

## LLM02: Sensitive Information Disclosure

**Status: Addressed**

**What we do:**
- `validate-write.sh` scans all file writes for hardcoded secrets (AWS keys, PEM keys, API tokens, passwords)
- `validate-read.sh` blocks access to system credential files
- `validate-bash.sh` blocks `env |` which could leak environment variables
- `.env` pattern enforced (never committed, template committed)

**Residual risk:** The LLM could include sensitive info in its text responses (not file writes). We cannot intercept LLM output text.

## LLM03: Supply Chain Vulnerabilities

**Status: Partial**

**What we do:**
- `validate-bash.sh` blocks `curl | sh`, `wget | bash`, and encoded command execution
- `setup-env.sh` verifies hook integrity against framework source directory
- `install.sh` logs framework git commit hash

**What we don't do:**
- No SRI (Subresource Integrity) for downloaded packages
- No SBOM (Software Bill of Materials) generation
- No dependency vulnerability scanning (delegate to Dependabot/Snyk)

## LLM04: Data and Model Poisoning

**Status: Out of Scope**

Claude's model training is Anthropic's responsibility. cognitive-core operates at the tool/hook layer and cannot influence model weights or training data.

## LLM05: Improper Output Handling

**Status: Partial**

**What we do:**
- `post-edit-lint.sh` catches some output issues via lint rules
- `validate-write.sh` catches secrets in output files
- Security baseline skill provides language-specific output encoding rules

**What we don't do:**
- No runtime output sanitization (would require modifying Claude Code's core)
- No XSS/injection scanning of generated code (would need AST analysis)

## LLM06: Excessive Agency

**Status: Addressed**

**What we do:**
- Per-agent `disallowedTools` restricts what each specialist can do
- `validate-bash.sh` graduated response based on `CC_SECURITY_LEVEL`
- `validate-read.sh` restricts file access scope
- `validate-fetch.sh` restricts network access in strict mode
- Human-in-the-loop via "ask" decisions for unknown domains

**Design principle:** Least privilege per agent, graduated response (allow → ask → deny).

## LLM07: System Prompt Leakage

**Status: Not Addressed**

Claude Code architecture limitation. System prompts (CLAUDE.md, agent definitions, skill content) are visible to the model and could be extracted via prompt injection or social engineering. This is a known trade-off of the skill/agent architecture.

## LLM08: Vector Store and Embedding Vulnerabilities

**Status: Out of Scope**

cognitive-core does not include a RAG system or vector store. If child projects implement RAG, they should follow OWASP RAG security guidelines independently.

## LLM09: Misinformation

**Status: Not Addressed**

Model hallucination is a Claude behavior characteristic. cognitive-core cannot verify factual accuracy of LLM responses. The `research-analyst` agent emphasizes cross-referencing and authoritative sources as a process mitigation.

## LLM10: Unbounded Consumption

**Status: Partial**

**What we do:**
- `context-cleanup.sh` manages context size and archives old sessions
- `health-check.sh` monitors context budget (skills, agents, CLAUDE.md line counts)
- Strict mode can restrict network access (reducing fetch-loop risks)

**What we don't do:**
- No token counting or cost tracking
- No automatic session termination on budget exceeded
- No rate limiting on tool calls

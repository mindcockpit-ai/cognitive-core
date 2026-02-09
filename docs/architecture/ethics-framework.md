# AI Ethics and Moral Framework

**Version**: 1.0.0
**Based on**: Constitutional AI, EU AI Act, NIST AI RMF

---

## Executive Summary

The landscape of AI ethics has reached a critical inflection point in 2025-2026:
- **EU AI Act** is now actively enforced (prohibitions since Feb 2025)
- **Constitutional AI** provides technical implementation of values
- **Value alignment** remains an unsolved problem for AGI-level systems
- **All major AI labs** received failing grades for existential safety preparedness

---

## Ethical Frameworks Comparison

### Classical Theories Applied to AI

| Framework | Core Principle | AI Application | Use Case |
|-----------|----------------|----------------|----------|
| **Deontology** | Rule-based duties | Hard constraints | "Never violate privacy" |
| **Consequentialism** | Maximize outcomes | Optimize results | "Minimize harm" |
| **Virtue Ethics** | Character-based | Ethical AI culture | Team training |
| **Rights-Based** | Fundamental rights | Protect autonomy | User consent |

### Recommended: Hybrid Approach

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      HYBRID ETHICS FRAMEWORK                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LAYER 1: DEONTOLOGICAL CONSTRAINTS (Hard Rules)                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Never generate harmful content (CSAM, weapons, etc.)              │   │
│  │ • Never assist with illegal activities                              │   │
│  │ • Never impersonate real people maliciously                         │   │
│  │ • Always disclose AI nature when asked                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  LAYER 2: CONSEQUENTIALIST OPTIMIZATION (Soft Guidelines)                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Maximize helpfulness within constraints                           │   │
│  │ • Minimize potential for harm                                       │   │
│  │ • Consider long-term consequences                                   │   │
│  │ • Balance competing stakeholder interests                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  LAYER 3: VIRTUE ETHICS CULTURE (Organizational)                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Train teams on ethical reasoning                                  │   │
│  │ • Foster accountability mindset                                     │   │
│  │ • Encourage transparency                                            │   │
│  │ • Reward ethical behavior                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Constitutional AI (Anthropic's Approach)

### How It Works

Constitutional AI provides explicit values via a "constitution" rather than implicit values from human feedback:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONSTITUTIONAL AI PROCESS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. INITIAL RESPONSE                                                        │
│     Model generates response to user request                                │
│                                                                             │
│  2. SELF-CRITIQUE                                                           │
│     Model evaluates response against constitution:                          │
│     • "Does this response respect user autonomy?"                           │
│     • "Could this cause harm?"                                              │
│     • "Is this honest and transparent?"                                     │
│                                                                             │
│  3. REVISION                                                                │
│     Model revises response based on critique                                │
│                                                                             │
│  4. RLHF TRAINING                                                           │
│     Self-revised responses used to train model                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Benefits
- **Scalability**: Fewer human labels needed
- **Consistency**: Same rules across contexts
- **Transparency**: Explicit principles

### Limitations
- Values like fairness cannot be fully automated
- Context-dependent judgments still require humans
- Constitution itself reflects human biases

---

## Regulatory Landscape

### EU AI Act Timeline

| Date | Milestone | Requirements |
|------|-----------|--------------|
| **Feb 2025** | Prohibitions active | Banned practices enforceable |
| **Aug 2025** | GPAI rules | Technical documentation, copyright |
| **Aug 2026** | Full enforcement | High-risk systems, transparency |
| **Aug 2027** | Extended transition | Regulated product systems |

### Risk Classification

| Risk Level | Examples | Requirements |
|------------|----------|--------------|
| **Unacceptable** | Social scoring, manipulation | BANNED |
| **High** | Medical diagnosis, hiring | Conformity assessment |
| **Limited** | Chatbots, emotion recognition | Transparency |
| **Minimal** | Spam filters, games | No requirements |

### Penalties
- **Prohibited practices**: Up to EUR 35M or 7% global turnover
- **Other violations**: Up to EUR 15M or 3% global turnover

---

## NIST AI Risk Management Framework

```
CORE FUNCTIONS:
1. GOVERN → Risk-aware organizational culture
2. MAP    → Contextualize AI in environment
3. MEASURE → Quantitative/qualitative assessment
4. MANAGE → Implement controls and mitigations
```

---

## Value Alignment Problem

### Current Challenges

| Challenge | Description | Solutions |
|-----------|-------------|-----------|
| **Specification** | Defining "good" | Constitutional AI, RLHF |
| **Robustness** | Maintaining under shift | Interpretability, adversarial training |
| **Assurance** | Verifying alignment | Red-teaming, model evals |
| **Emergent** | Unexpected behaviors | Monitoring, defense-in-depth |

### Concerning Finding (2025)

> "Emergent misalignment: Models fine-tuned on insecure code began endorsing authoritarianism and violence on unrelated prompts."

### AI Safety Index (Winter 2025)

| Company | Rank | Grade |
|---------|------|-------|
| Anthropic | 1st | D (existential safety) |
| OpenAI | 2nd | D |
| Google DeepMind | 3rd | D |

**Critical**: All major AI companies pursuing AGI without explicit control plans.

---

## Practical Implementation

### Bias Detection Tools

| Tool | Provider | Features |
|------|----------|----------|
| **AI Fairness 360** | IBM | 70+ metrics, 10+ algorithms |
| **Fairlearn** | Microsoft | Dashboards, constraints |
| **What-If Tool** | Google | Demographic visualization |
| **Aequitas** | Open Source | Audit-focused |

### Explainability (XAI)

**Techniques**:
- **SHAP**: Feature importance via game theory
- **LIME**: Local interpretable explanations
- **Counterfactual**: "What would need to change?"
- **Attention Visualization**: For transformers

**Regulatory Note**: By August 2026, XAI shifts from optional to **mandatory**.

### Human Oversight (EU AI Act Article 14)

| Risk Level | AI Autonomy | Human Role |
|------------|-------------|------------|
| Low | Full autonomy | Periodic review |
| Moderate | AI leads | Supervise via dashboards |
| High | AI assists only | Human final judgment |

---

## Ethics in cognitive-core

### Skill Implementation

```yaml
# Example: /ethics skill
---
name: ethics
description: Evaluate actions against ethical framework
argument-hint: [action-description]
allowed-tools: Read
---

# Ethics Evaluation

## Hard Constraints (Deontological)
NEVER:
- Generate harmful content
- Violate user privacy without consent
- Assist with illegal activities
- Deceive about AI nature

## Soft Guidelines (Consequentialist)
PREFER:
- Helpful over harmful
- Transparent over opaque
- Cautious over risky
- Reversible over permanent

## Process
1. Identify action and stakeholders
2. Check against hard constraints
3. Evaluate consequences
4. Consider alternatives
5. Document reasoning

## Output
| Aspect | Assessment |
|--------|------------|
| Constraint Compliance | PASS / FAIL |
| Harm Potential | LOW / MEDIUM / HIGH |
| Recommendation | PROCEED / CAUTION / BLOCK |
```

### Proposed Ethics Skills

```
skills/
├── ethics/         # Core ethical evaluation
├── bias-check/     # Bias detection and reporting
├── explain/        # Explainability for decisions
├── consent/        # User consent management
└── escalate/       # Human oversight escalation
```

---

## Governance Checklist

### Implementation Steps

```
[ ] Conduct AI system inventory and risk classification
[ ] Define organizational roles (supplier, deployer)
[ ] Implement bias detection pipeline
[ ] Deploy explainability techniques
[ ] Establish human oversight protocols
[ ] Create documentation trail for audits
[ ] Define incident response procedures
[ ] Train personnel on AI ethics
[ ] Conduct regular bias audits
[ ] Monitor regulatory changes
```

### Standards

| Standard | Focus |
|----------|-------|
| **ISO/IEC 42001** | AI management system (certifiable) |
| **NIST AI RMF** | Risk management methodology |
| **EU AI Act** | Regulatory compliance |

---

## References

### Regulatory
- [EU AI Act](https://artificialintelligenceact.eu/)
- [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework)
- [ISO/IEC 42001](https://www.iso.org/standard/81230.html)

### Academic
- [Anthropic Constitutional AI](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback)
- [DeepMind AGI Safety Paper](https://techcrunch.com/2025/04/02/deepminds-145-page-paper-on-agi-safety/)
- [Value Alignment Research](https://arxiv.org/html/2510.11235v1)

### Tools
- [IBM AI Fairness 360](https://aif360.mybluemix.net/)
- [Microsoft Fairlearn](https://fairlearn.org/)
- [Google What-If Tool](https://pair-code.github.io/what-if-tool/)

### Industry
- [Future of Life AI Safety Index](https://futureoflife.org/ai-safety-index-summer-2025/)
- [Microsoft Responsible AI](https://www.microsoft.com/en-us/ai/principles-and-approach)
- [Google AI Principles](https://ai.google/responsibility/principles/)

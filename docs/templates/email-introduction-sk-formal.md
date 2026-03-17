# Email Template — Úvod cognitive-core (Slovenčina, formálna Vy-forma)

**Predmet:** cognitive-core — AI-Engineering Framework vyvinutý v Nemecku

---

Vážený/á [Meno],

ďakujem za Váš záujem. Dovoľte mi predstaviť cognitive-core.

Za posledné mesiace som testoval desiatky AI nástrojov, IDE, pluginov a frameworkov. Pritom sa ukázalo: dynamika v oblasti AI je tak veľká, že samotné evaluovanie a testovanie zaberá viac času ako skutočná práca. Cognitive overload je reálny problém — mnohé tímy neustále skúšajú nové nástroje bez toho, aby niektorý z nich produktívne nasadili.

Z tejto skúsenosti vznikol **cognitive-core** — AI-engineering framework vyvinutý v Nemecku. Nie je to IDE ani cloud service — je to prenositeľný framework ktorý sa nainštaluje do akéhokoľvek existujúceho projektu. Kompletný zdrojový kód je verejne prístupný a auditovateľný: https://multivac42.ai

**Čo to znamená konkrétne:**

- **10 špecializovaných agentov** (security, architektúra, testy, databázy, ...) koordinovaných centrálnym orchestrátorom — v našej praxi na produkčných projektoch vieme analyzovať rozsiahle codebases, pripraviť refactoring plán, rozplánovať šprinty s acceptance kritériami
- **Project management** — plná správa issues, šprintov a boardu s podporou YouTrack, Jira aj GitHub
- **CI/CD šablóny** — prenositeľné, adaptovateľné na každého zákazníka
- **Software Archeology** — Struts/JSP, legacy Java, analýza technical debt. Špeciálne pre modernizáciu legacy systémov
- **Plne lokálna prevádzka** — s Ollama adaptérom žiadne dáta neopustia počítač. Silný základ pre DSGVO konformitu
- **Viacjazyčný** — framework funguje v akomkoľvek jazyku ktorý model podporuje
- **Užívateľ si vytvorí vlastný skill, rule alebo agenta** pre akúkoľvek špecializovanú technológiu podľa svojich potrieb

**Human Approval Gate — acceptance by evidence:**

Každá zmena prechádza overením voči acceptance kritériám s konkrétnymi dôkazmi — code snippety, build output, deployment screenshoty, live verifikácia. Všetko je zdokumentované priamo na tickete. A žiadny ticket sa nezatvorí bez explicitného schválenia človekom. Nie je to voliteľný doplnok — je to architektonický princíp.

**Fair Source — otvorený a transparentný:**

cognitive-core je **Fair Source** (FSL-1.1-ALv2) — použitie pre vzdelávanie, výskum aj interné komerčné nasadenie je plne povolené. Obmedzené je len budovanie konkurenčných produktov. Po uplynutí change date sa licencia mení na Apache 2.0.

**Kvalita:**

Framework bol evaluovaný voči **Claude Certified Architect — Foundations** exam štandardu od Anthropic. Výsledok: **Grade A vo všetkých 5 doménach**. Plný report je na GitHube — každý si ho môže pozrieť a overiť. cognitive-core je od istého momentu vyvíjaný sám sebou — framework riadi vlastný vývoj, testovanie a deployment. Multi-agent peer review — kde agenti navzájom kontrolujú svoju prácu — sme mali implementovaný skôr než to Anthropic oficiálne zakomponoval do svojich nástrojov.

**Akademický základ a EU spolupráce:**

cognitive-core som vyvíjal na základe štúdií evolučnej kognitívnej biológie a behaviorálnej ekológie. Spolupráca s akademickou obcou prináša konkrétne výsledky — peer-reviewed štúdie (RAFT od UC Berkeley/Microsoft/Meta, RAG-HAT od EMNLP 2024) ukazujú že kombinácia RAG + finetuning znižuje halucináciu na 0-4%.

Existujúce spolupráce:
- **Hochschule Albstadt-Sigmaringen** — docent používa cognitive-core so študentami
- **Slovenský startup Brigadee** (EU projekt) — používa náš framework na vývoj
- **TZO startup TUKE Košice** a **Veterinárna univerzita Košice** (projekt PharmaSys)

**Kam smerujeme:**

Dnes používame najlepšie dostupné technológie — Claude je momentálne najlepší model pre engineering. Ale o rok to tak byť nemusí. A práve na to sme pripravení — prepnutie na iný model je zmena jedného riadku v konfiguráku.

Náš cieľ: **plná GDPR konformita s európskymi AI modelmi**. Mistral je európsky produkt. Základy umelej inteligencie sa zrodili v Európe. Čo nám chýba je odvaha budovať vlastné nástroje.

**Čo získate navyše:**

Toto nie je self-service SaaS od korporácie. Získate priamy prístup k autorovi, tailoring na mieru, adoptáciu na Vaše procesy. Váš feedback formuje roadmapu — win-win pre obe strany.

Rád by som Vám framework predstavil v krátkej demo prezentácii.

Viac informácií: https://multivac42.ai
Step-by-step recipes: https://github.com/mindcockpit-ai/cognitive-core/tree/main/docs/recipes

S pozdravom,
Peter Wolaschka
https://multivac42.ai

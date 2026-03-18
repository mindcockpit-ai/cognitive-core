# Source-Available License Comparison for cognitive-core

## Research Summary: FSL vs BSL vs ELv2 vs CC BY-NC vs Custom

**Date**: 2026-03-13
**Analyst**: research-analyst
**Scope**: Detailed license comparison for protecting cognitive-core from commercial copying while keeping code visible
**Current License**: MIT (fully permissive -- no protection at all)

---

## Executive Summary

After researching all five license options against Peter's specific situation (solo developer, consulting revenue, needs visibility, needs protection from big tech copying, wants future enterprise licensing), the **FSL-1.1-ALv2 (Functional Source License)** is the clear recommendation. It was designed precisely for this scenario, has strong industry adoption (Sentry, GitButler, Codecov, PowerSync, Liquibase), explicitly allows consulting/professional services use, prevents competitors from offering the framework as a service, and is simple enough for a solo developer to apply without a legal team. The 2-year auto-conversion to Apache 2.0 is a *feature*, not a bug -- it builds trust and only affects old versions.

---

## Part 1: License-by-License Deep Dive

### 1. FSL 1.1 (Functional Source License) -- by Sentry

**Created by**: Sentry (error monitoring company), with input from Heather Meeker (prominent open-source attorney)
**SPDX Identifier**: `FSL-1.1-ALv2` or `FSL-1.1-MIT`
**Full text**: https://fsl.software/

#### What is Permitted

- **Internal use** by anyone (individuals, corporations, governments)
- **Non-commercial education** (universities, courses, workshops)
- **Non-commercial research**
- **Professional services/consulting** to licensees using the software -- this is *explicitly* listed as a Permitted Purpose
- Copy, modify, create derivative works, publicly display, redistribute
- Proposing improvements back to the producer

#### What is Forbidden (Competing Use)

Making the Software available to others in a commercial product or service that:

1. **Substitutes** for the Software
2. **Substitutes** for any other product or service the licensor offers using the Software
3. Offers the **same or substantially similar functionality** as the Software

In plain language: nobody can take cognitive-core and sell "cognitive-core as a service" or rebrand it as their own competing framework.

#### Auto-Conversion Mechanism

- **When**: 2 years after each version's release date (per-version, not per-project)
- **To what**: Apache License 2.0 (ALv2 variant) or MIT (MIT variant)
- **Is this good?** YES, for three reasons:
  1. It only affects the specific version released 2 years ago -- your latest version stays protected
  2. It builds trust with adopters who fear vendor lock-in
  3. It keeps you ahead: if your 2-year-old code becomes Apache, your current code is still FSL-protected and has 2 years of improvements
- **Can someone take the code after 2 years?** Yes, but only the version that is 2+ years old. They cannot take your latest release. This is the same dynamic as any actively-developed project -- old versions becoming free drives adoption of new versions.

#### Who Uses It

| Company | Product | Notes |
|---------|---------|-------|
| **Sentry** | Error monitoring platform | Created the license |
| **GitButler** | Git client (founded by GitHub co-founder) | Went from closed-source to FSL |
| **Codecov** | Code coverage (Sentry-owned) | FSL since acquisition |
| **PowerSync** | Offline-first sync engine | FSL for core |
| **Liquibase** | Database change management | Moved to FSL in 2024 |
| **Keygen** | License key management | FSL adopter |
| **CodeCrafters** | Developer education platform | FSL adopter |
| **Convex** | Backend-as-a-service | FSL adopter |

#### Verdict for Peter's Situation

| Question | Answer |
|----------|--------|
| Can a corporation use it internally without paying? | **Yes** -- explicitly permitted |
| Can a corporation resell/offer it as a service? | **No** -- this is Competing Use |
| Can a corporation use it for consulting clients? | **Yes** -- explicitly permitted as "professional services to a licensee" |
| Can individuals use it freely? | **Yes** -- for any non-competing purpose |
| Does it auto-convert to open source? | **Yes** -- Apache 2.0 after 2 years per version |
| Is it OSI-approved? | **No** -- it is "Fair Source", not "Open Source" |
| How easy to apply for a solo developer? | **Very easy** -- fill in 2 placeholders (year, name), drop into repo |

---

### 2. BSL 1.1 (Business Source License) -- by MariaDB

**Created by**: MariaDB Corporation (2013), popularized by HashiCorp (2023)
**SPDX Identifier**: `BUSL-1.1`
**Full text**: https://mariadb.com/bsl11/

#### What is Permitted

- Copy, modify, create derivative works, redistribute
- **Non-production use** is always free (testing, development, evaluation)
- Production use is governed by the **Additional Use Grant** (customizable per licensor)
- After the Change Date, full open-source use under the Change License

#### What is Forbidden

- **Production use** without either (a) an Additional Use Grant that covers your case, or (b) a commercial license from the licensor
- The exact restrictions depend entirely on how the licensor writes the Additional Use Grant

#### The Additional Use Grant Problem

This is the critical weakness of BSL for solo developers. **Each BSL implementation is essentially a custom license** because the Additional Use Grant varies wildly:

| Company | Additional Use Grant |
|---------|---------------------|
| **HashiCorp** | Production use allowed except in products competing with HashiCorp |
| **MariaDB** | Production allowed with fewer than 3 server instances |
| **Directus** | Production allowed if company revenue is under $5M |
| **CockroachDB** | Varies by product component |

You would need to **write your own** Additional Use Grant, which effectively means drafting custom legal language -- exactly what a solo developer should avoid.

#### Change Date Mechanism

- **Maximum**: 4 years from release (required by the license)
- **Converts to**: Must be GPL-compatible (GPLv2 or later, or a compatible license)
- **Note**: This is longer than FSL's 2 years, and the Change License must be copyleft-compatible (GPL family), not permissive (Apache/MIT). This is a significant constraint.

#### Who Uses It

| Company | Product | Notes |
|---------|---------|-------|
| **HashiCorp** | Terraform, Vault, Consul, Vagrant, Packer | Switched from MPL v2 in Aug 2023 |
| **MariaDB** | MariaDB Server | Created the license |
| **CockroachDB** | CockroachDB | Early adopter |
| **Couchbase** | Couchbase Server, Sync Gateway | Adopted in 2022-2023 |
| **Akka** (Lightbend) | Akka runtime | Switched from Apache 2.0 |

#### Verdict for Peter's Situation

| Question | Answer |
|----------|--------|
| Can a corporation use it internally without paying? | **Depends** -- on your Additional Use Grant wording |
| Can a corporation resell/offer it as a service? | **No** -- if your AUG excludes it |
| Can a corporation use it for consulting clients? | **Gray area** -- depends on AUG |
| Can individuals use it freely? | **Non-production: Yes. Production: depends on AUG** |
| Does it auto-convert to open source? | **Yes** -- up to 4 years, must be GPL-compatible |
| Is it OSI-approved? | **No** -- explicitly states "not an Open Source license" |
| How easy to apply for a solo developer? | **Medium** -- requires writing a custom Additional Use Grant |

---

### 3. ELv2 (Elastic License v2) -- by Elastic

**Created by**: Elastic NV (2021)
**SPDX Identifier**: `Elastic-2.0`
**Full text**: https://www.elastic.co/licensing/elastic-license

#### What is Permitted

- Use, copy, distribute, make available, prepare derivative works
- **Internal corporate use** is fully allowed
- **Consulting/contractor work** is explicitly allowed (setting up for clients to use internally)
- Modification and redistribution (with attribution)

#### Three Limitations (the entire restriction set)

1. **No Managed Service**: Cannot provide the software to third parties as a hosted or managed service where users access substantial features/functionality
2. **No License Key Circumvention**: Cannot modify, disable, or circumvent license key functionality (relevant for commercial feature gating)
3. **No Notice Removal**: Cannot alter or remove licensing, copyright, or other notices

#### Key Characteristic: No Auto-Conversion

Unlike FSL and BSL, ELv2 **never converts to open source**. The restrictions are permanent for all versions. This is both a strength (permanent protection) and a weakness (some adopters distrust permanent restrictions).

#### Who Uses It

| Company | Product | Notes |
|---------|---------|-------|
| **Elastic** | Elasticsearch, Kibana | Created the license |
| **Apollo GraphQL** | Apollo Federation 2 | Adopted ELv2 |
| **Airbyte** | Data integration connectors | Moved from MIT to ELv2 |
| **BentoML** | Yatai ML platform | ELv2 licensed |

#### Verdict for Peter's Situation

| Question | Answer |
|----------|--------|
| Can a corporation use it internally without paying? | **Yes** -- explicitly allowed |
| Can a corporation resell/offer it as a service? | **No** -- managed service is forbidden |
| Can a corporation use it for consulting clients? | **Yes** -- explicitly allowed (contractor/setup use confirmed in Elastic FAQ) |
| Can individuals use it freely? | **Yes** -- for any non-managed-service purpose |
| Does it auto-convert to open source? | **No** -- never converts |
| Is it OSI-approved? | **No** |
| How easy to apply for a solo developer? | **Easy** -- short, clear text, no customization needed |

---

### 4. CC BY-NC 4.0 (Creative Commons NonCommercial)

**Created by**: Creative Commons
**Full text**: https://creativecommons.org/licenses/by-nc/4.0/legalcode

#### Why This is Wrong for Software

**Creative Commons itself recommends against using CC licenses for software.** From the official CC FAQ:

> "We recommend against using Creative Commons licenses for software and strongly encourage the use of one of the very good software licenses which are already available."

#### Specific Problems

1. **No patent clause**: Software needs explicit patent protections; CC licenses were designed for creative works (text, images, music), not code
2. **No source code provisions**: CC licenses say nothing about source code distribution, binary distribution, or linking
3. **Incompatible with software ecosystems**: Cannot be combined with GPL, Apache, MIT, or any standard software license
4. **"NonCommercial" is ambiguous for software**: Does running software in a business count as "commercial"? CC defines NonCommercial as "not primarily intended for or directed towards commercial advantage or monetary compensation" -- this is hopelessly vague for corporate internal use
5. **No managed service clause**: The restriction is on "commercial" broadly, not on competing services specifically. This is both too broad (blocks legitimate internal use) and too narrow (might not cover all service scenarios)

#### Verdict for Peter's Situation

| Question | Answer |
|----------|--------|
| Can a corporation use it internally without paying? | **Unclear** -- "NonCommercial" is ambiguous for internal business use |
| Can a corporation resell/offer it as a service? | **Probably No** -- but untested for software |
| Can a corporation use it for consulting clients? | **Probably No** -- commercial advantage |
| Can individuals use it freely? | **Yes** -- for non-commercial purposes |
| Does it auto-convert to open source? | **No** |
| Is it OSI-approved? | **No** -- and not designed for software |
| How easy to apply for a solo developer? | **Easy to apply, hard to enforce for software** |

**Recommendation: Do not use CC BY-NC for software. It is the wrong tool for this job.**

---

### 5. Source Available with Custom Terms (Anthropic-style)

**Example**: Claude Code by Anthropic

#### What Anthropic Does

Claude Code's LICENSE.md is just one line:

> "Copyright Anthropic PBC. All rights reserved. Use is subject to Anthropic's Commercial Terms of Service."

This is not a source-available license at all. It is **proprietary software with visible source code**. Anthropic retains all rights. You can look at the code (it is on GitHub and npm), but you have zero rights to use, copy, modify, or redistribute it except as Anthropic's Terms of Service allow.

#### Why This is Wrong for Peter

1. **Not a real license**: It grants no rights. Users must agree to a separate Terms of Service document.
2. **Requires a ToS**: You would need to write and maintain a Terms of Service -- legal document territory.
3. **No community trust**: Developers see "All rights reserved" and walk away. No one will build on a framework where the sole developer could revoke access at any time.
4. **No contribution model**: If someone finds a bug and wants to submit a fix, what are the terms? "All rights reserved" means their contribution has no clear licensing.
5. **Not enforceable by a solo developer**: Anthropic has a legal team. You do not.

#### Verdict for Peter's Situation

| Question | Answer |
|----------|--------|
| Can a corporation use it internally without paying? | **Only if ToS allows** |
| Can a corporation resell/offer it as a service? | **Only if ToS allows** |
| Can a corporation use it for consulting clients? | **Only if ToS allows** |
| Can individuals use it freely? | **Only if ToS allows** |
| Does it auto-convert to open source? | **No** |
| Is it OSI-approved? | **No** |
| How easy to apply for a solo developer? | **Hard** -- requires writing a Terms of Service |

**Recommendation: Do not use this model. It requires legal infrastructure that a solo developer does not have.**

---

## Part 2: Side-by-Side Comparison Matrix

| Criterion | FSL 1.1 | BSL 1.1 | ELv2 | CC BY-NC 4.0 | Custom (Anthropic) |
|-----------|---------|---------|------|--------------|---------------------|
| **Corporate internal use** | Yes | Depends on AUG | Yes | Unclear | Depends on ToS |
| **Corporate resell as service** | No | No (if AUG excludes) | No | Probably No | Depends on ToS |
| **Consulting/client projects** | **Yes (explicit)** | Gray area | **Yes (explicit)** | Probably No | Depends on ToS |
| **Individual free use** | Yes | Non-prod: yes | Yes | Non-commercial | Depends on ToS |
| **Auto-converts to FOSS** | Yes (2yr, Apache/MIT) | Yes (up to 4yr, GPL-compat) | **Never** | Never | Never |
| **OSI-approved** | No | No | No | No | No |
| **Designed for software** | Yes | Yes | Yes | **No** | N/A |
| **Customization needed** | None | **Must write AUG** | None | None | **Must write ToS** |
| **Industry adoption** | Strong (8+ companies) | Strong (5+ major) | Moderate (4+) | None for software | Rare |
| **Community perception** | Positive ("fair source") | Mixed (HashiCorp backlash) | Mixed | Negative for code | Negative |
| **Solo developer friendly** | **Very** | Medium | **Very** | Easy but wrong tool | Hard |
| **Future enterprise licensing** | **Compatible** | Compatible | Compatible | Incompatible | Compatible |
| **Patent protection** | Yes | No explicit | Yes | **No** | Depends on ToS |
| **SPDX recognized** | Yes | Yes | Yes | Yes | No |

---

## Part 3: The Auto-Conversion Question

### "Is the 2-year FSL conversion to Apache 2.0 a problem?"

**No. It is a strategic advantage.** Here is why:

#### How the clock works

The 2-year clock starts **per version**, not per project. If you release:

- v1.0 on 2026-06-01 -- becomes Apache 2.0 on 2028-06-01
- v1.5 on 2026-12-01 -- becomes Apache 2.0 on 2028-12-01
- v2.0 on 2027-06-01 -- becomes Apache 2.0 on 2029-06-01

At any given moment, your last 2 years of work are FSL-protected. Only old versions go free.

#### Why this is good for a solo developer

1. **Builds trust**: Adopters know they are not permanently locked to your goodwill. If you disappear or go hostile, the code eventually frees itself.
2. **Drives upgrades**: When v1.0 goes Apache, people are already on v2.0. The free old version attracts new users who then upgrade.
3. **Reduces fork risk**: With BSL/ELv2's permanent restrictions, frustrated users fork immediately (like OpenTofu forked Terraform). With FSL, there is no urgency to fork -- just wait 2 years.
4. **Competitive protection where it matters**: Your latest innovations are always protected. A competitor who copies your 2-year-old code is 2 years behind.

#### What about ELv2's "never converts" approach?

ELv2 offers permanent protection, which sounds better in theory. In practice:
- It creates more friction for adoption (enterprises worry about permanent lock-in)
- It does not prevent forks (Elastic's code was forked by AWS as OpenSearch despite the license)
- It does not generate more revenue than FSL for a solo developer

---

## Part 4: Recommendation

### Primary Recommendation: FSL-1.1-ALv2

For cognitive-core, the FSL-1.1-ALv2 (Functional Source License, converting to Apache 2.0) is the optimal choice. Here is the reasoning mapped to Peter's requirements:

| Requirement | How FSL Addresses It |
|-------------|---------------------|
| Solo developer, no legal team | Zero customization needed. Fill in name and year. Done. |
| Wants consulting revenue | **Explicitly permits** professional services/consulting to licensees |
| Wants visibility (source readable) | Source is fully visible and redistributable |
| Prevent big tech from copying | Competing Use clause forbids commercial products with same/similar functionality |
| Prevent competitors offering as service | Competing Use clause forbids making Software available in competing commercial service |
| May want enterprise licenses later | Dual-licensing compatible: offer FSL for community, commercial license for enterprises wanting different terms |
| Community adoption | "Fair Source" branding is increasingly trusted; Sentry, GitButler, etc. normalize it |

### Why Not the Others

| License | Why Not |
|---------|---------|
| **BSL 1.1** | Requires writing a custom Additional Use Grant (legal work). Each BSL is effectively a different license. 4-year conversion to GPL-compatible (not permissive). More complex, more baggage (HashiCorp backlash). |
| **ELv2** | Good option but no auto-conversion creates adoption friction. License key circumvention clause is irrelevant for cognitive-core. Less community momentum than FSL in the "fair source" movement. |
| **CC BY-NC** | Wrong tool entirely. Not designed for software. No patent clause. Ambiguous "NonCommercial" definition. Creative Commons itself says do not use it for software. |
| **Custom/Anthropic** | Requires writing Terms of Service. Zero community trust. No contribution model. Requires legal infrastructure. |

### Dual-Licensing Strategy (Future)

FSL supports a clean dual-licensing path:

```
Community Edition (free)          Enterprise Edition (paid)
─────────────────────────         ──────────────────────────
License: FSL-1.1-ALv2            License: Commercial Agreement
Cost: Free                       Cost: Per-seat or per-org annual
Includes: Full framework         Includes: Full framework
Restrictions: No competing       Restrictions: None (commercial
  commercial service               use fully permitted)
Support: Community only          Support: Direct from Peter
Extras: None                     Extras: Priority features,
                                   SLA, private Slack/Discord
```

When someone needs to use cognitive-core in a way that FSL does not permit (e.g., offering it as part of a commercial AI consulting platform), they contact you for a commercial license. This is exactly how Sentry, MariaDB, Elastic, and others monetize.

---

## Part 5: Ready-to-Use LICENSE File

Below is the complete FSL-1.1-ALv2 license text, ready to replace the current MIT license in the cognitive-core repository. Just copy this into `LICENSE` (or `LICENSE.md`).

```markdown
# Functional Source License, Version 1.1, ALv2 Future License

## Abbreviation

FSL-1.1-ALv2

## Notice

Copyright 2026 Peter Welander (mindcockpit-ai)

## Terms and Conditions

### Licensor ("We")

The party offering the Software under these Terms and Conditions.

### The Software

The "Software" is each version of the software that we make available under
these Terms and Conditions, as indicated by our inclusion of these Terms and
Conditions with the Software.

### License Grant

Subject to your compliance with this License Grant and the Patents,
Redistribution and Trademark clauses below, we hereby grant you the right to
use, copy, modify, create derivative works, publicly perform, publicly display
and redistribute the Software for any Permitted Purpose identified below.

### Permitted Purpose

A Permitted Purpose is any purpose other than a Competing Use. A Competing Use
means making the Software available to others in a commercial product or
service that:

1. substitutes for the Software;

2. substitutes for any other product or service we offer using the Software
   that exists as of the date we make the Software available; or

3. offers the same or substantially similar functionality as the Software.

Permitted Purposes specifically include using the Software:

1. for your internal use and access;

2. for non-commercial education;

3. for non-commercial research; and

4. in connection with professional services that you provide to a licensee
   using the Software in accordance with these Terms and Conditions.

### Patents

To the extent your use for a Permitted Purpose would necessarily infringe our
patents, the license grant above includes a license under our patents. If you
make a claim against any party that the Software infringes or contributes to
the infringement of any patent, then your patent license to the Software ends
immediately.

### Redistribution

The Terms and Conditions apply to all copies, modifications and derivatives of
the Software.

If you redistribute any copies, modifications or derivatives of the Software,
you must include a copy of or a link to these Terms and Conditions and not
remove any copyright notices provided in or with the Software.

### Disclaimer

THE SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING WITHOUT LIMITATION WARRANTIES OF FITNESS FOR A PARTICULAR
PURPOSE, MERCHANTABILITY, TITLE OR NON-INFRINGEMENT.

IN NO EVENT WILL WE HAVE ANY LIABILITY TO YOU ARISING OUT OF OR RELATED TO THE
SOFTWARE, INCLUDING INDIRECT, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES,
EVEN IF WE HAVE BEEN INFORMED OF THEIR POSSIBILITY IN ADVANCE.

### Trademarks

Except for displaying the License Details and identifying us as the origin of
the Software, you have no right under these Terms and Conditions to use our
trademarks, trade names, service marks or product names.

## Grant of Future License

We hereby irrevocably grant you an additional license to use the Software under
the Apache License, Version 2.0 that is effective on the second anniversary of
the date we make the Software available. On or after that date, you may use the
Software under the Apache License, Version 2.0, in which case the following
will apply:

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License.

You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
```

---

## Part 6: Implementation Steps

### Immediate Actions

1. **Replace `LICENSE`** in cognitive-core repo with the FSL-1.1-ALv2 text above
2. **Update `README.md`** to include a license badge and note:
   ```markdown
   ## License

   cognitive-core is licensed under the [Functional Source License, Version 1.1, ALv2 Future License (FSL-1.1-ALv2)](LICENSE).

   You can use, modify, and redistribute this software for any purpose **except** offering it as a competing commercial product or service. After 2 years, each version converts to the Apache License 2.0.

   For commercial licensing inquiries, contact: [your email]
   ```
3. **Add SPDX header** to key source files (optional but good practice):
   ```
   // SPDX-License-Identifier: FSL-1.1-ALv2
   ```
4. **Update `package.json`** (or equivalent) license field:
   ```json
   "license": "FSL-1.1-ALv2"
   ```
5. **Add `NOTICE` file** (recommended for tracking the software's initial availability date):
   ```
   cognitive-core
   Copyright 2026 Peter Welander (mindcockpit-ai)

   Initially made available under FSL-1.1-ALv2 on [DATE OF FIRST FSL RELEASE].
   ```

### Communication

When announcing the license change (from MIT to FSL), frame it as:

- "cognitive-core is now Fair Source" (positive framing)
- Emphasize what IS allowed (everything except competing commercial use)
- Link to https://fair.io for the broader movement context
- Note the 2-year Apache conversion as a trust-building feature

---

## Part 7: Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Enterprise adopters reject non-OSI license | Medium | FSL is increasingly normalized; offer commercial license as alternative |
| Competitor forks 2-year-old version | Low | You are 2 years ahead; fork momentum is minimal for niche frameworks |
| "Fair Source" movement loses momentum | Low | Backed by Sentry ($100M+ revenue company); growing adoption |
| Ambiguity in "competing use" for edge cases | Low | FSL is clearer than BSL's custom AUG; Sentry has set precedent |
| Existing MIT users claim perpetual MIT rights | **High** | Any code already released under MIT remains MIT forever. FSL only applies to new releases. You cannot retroactively change the license on already-released code. |

### Critical Note on MIT-to-FSL Transition

The current MIT license on cognitive-core means **all code released under MIT to date is permanently MIT-licensed**. Anyone who obtained it under MIT retains those rights. The FSL applies only to:

- New releases going forward
- New code added after the license change

This is standard and accepted practice (HashiCorp, Elastic, and others all made similar transitions). But it means the protection starts from the date of the license change, not retroactively.

---

## Sources

- [FSL Official Website](https://fsl.software/)
- [Sentry Blog: Introducing FSL](https://blog.sentry.io/introducing-the-functional-source-license-freedom-without-free-riding/)
- [FSL License Template (GitHub)](https://github.com/getsentry/fsl.software)
- [SPDX: FSL-1.1-ALv2](https://spdx.org/licenses/FSL-1.1-ALv2.html)
- [BSL 1.1 Official Text (MariaDB)](https://mariadb.com/bsl11/)
- [BSL 1.1 FOSSA Analysis](https://fossa.com/blog/business-source-license-requirements-provisions-history/)
- [HashiCorp BSL Adoption](https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license)
- [Elastic License 2.0 Text](https://www.elastic.co/licensing/elastic-license)
- [Elastic License FAQ](https://www.elastic.co/licensing/elastic-license/faq)
- [Apollo GraphQL ELv2 Adoption](https://www.apollographql.com/trust/licensing)
- [Airbyte ELv2 Adoption](https://airbyte.com/blog/move-to-elv2)
- [Creative Commons FAQ: Not for Software](https://creativecommons.org/faq/)
- [TLDRLegal: FSL Explained](https://www.tldrlegal.com/license/functional-source-license-fsl)
- [Fair Source Movement](https://fair.io/licenses/)
- [GitButler Fair Source Announcement](https://blog.gitbutler.com/gitbutler-is-now-fair-source/)
- [TechCrunch: Fair Source Movement](https://techcrunch.com/2024/09/22/some-startups-are-going-fair-source-to-avoid-the-pitfalls-of-open-source-licensing/)
- [Armin Ronacher: FSL vs AGPL](https://lucumr.pocoo.org/2024/9/23/fsl-agpl-open-source-businesses/)
- [Keygen Fair Source](https://keygen.sh/blog/keygen-is-now-fair-source/)
- [Fair Core License (FCL)](https://fcl.dev/)
- [Claude Code LICENSE.md](https://github.com/anthropics/claude-code/blob/main/LICENSE.md)

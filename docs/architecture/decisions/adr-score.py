#!/usr/bin/env python3
"""Recompute ADR decision matrices and run the sensitivity check.

Usage: python3 -I adr-score.py ADR.md
Reads every "## Dn" section's matrix (Option | Gates | 5 new scores | New |
4 legacy scores | Legacy), verifies the printed totals, and prints per
decision: winner, margin, tie set, robustness, flips at +-0.05 and +-0.10,
equal and ROC winners, critical weight, and the legacy winner. Stdlib only.
Exit 1 when a printed total does not match the computed one.
"""
import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

NEW = [0.30, 0.25, 0.20, 0.15, 0.10]   # Eff, Ver, Pars, Neut, SecM
LEGACY = [0.35, 0.30, 0.20, 0.15]      # Sec, Feas, Phil, Maint
ROC = [0.457, 0.257, 0.157, 0.090, 0.040]
EQUAL = [0.2] * 5
NAMES = ["Eff", "Ver", "Pars", "Neut", "SecM"]
TIE_MARGIN = 0.20

Row = Tuple[Optional[List[float]], List[float], str, str]


def total(w: List[float], s: List[float]) -> float:
    return sum(a * b for a, b in zip(w, s))


def shift(w: List[float], i: int, d: float) -> List[float]:
    """Change weight i by d, renormalise the others proportionally."""
    new_wi = min(max(w[i] + d, 0.0), 1.0)
    rest = sum(w) - w[i]
    return [new_wi if j == i else x * (1 - new_wi) / rest for j, x in enumerate(w)]


def winner(opts: Dict[str, List[float]], w: List[float]) -> str:
    return max(opts, key=lambda k: total(w, opts[k]))


def flips(opts: Dict[str, List[float]], d: float) -> List[str]:
    """Winners other than the base winner when any weight moves by +-d."""
    base = winner(opts, NEW)
    found = {winner(opts, shift(NEW, i, s)) for i in range(len(NEW)) for s in (d, -d)}
    return sorted(found - {base})


def critical(opts: Dict[str, List[float]]) -> str:
    base = winner(opts, NEW)
    for step in range(1, 101):
        for i in range(len(NEW)):
            for sign in (1, -1):
                if winner(opts, shift(NEW, i, sign * step / 100)) != base:
                    return f"{sign * step / 100:+.2f} {NAMES[i]}"
    return "none"


def num(cell: str) -> str:
    return cell.replace("*", "").strip()


def parse(path: Path) -> Dict[str, Dict[str, Row]]:
    sections: Dict[str, Dict[str, Row]] = {}
    section: Optional[str] = None
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("## "):
                m = re.match(r"## (D\d+)", line)
                section = m.group(1) if m else None
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if section and len(cells) == 13 and cells[1].split(" ")[0] in ("pass", "fail"):
                new = None if cells[1].startswith("fail") else [float(num(c)) for c in cells[2:7]]
                legacy = [float(num(c)) for c in cells[8:12]]
                sections.setdefault(section, {})[num(cells[0])] = (new, legacy, num(cells[7]), num(cells[12]))
    return sections


def report(section: str, rows: Dict[str, Row]) -> int:
    rc = 0
    for name, (new, leg, p_new, p_leg) in rows.items():
        if new and f"{total(NEW, new):.2f}" != p_new:
            print(f"{section}: {name}: printed {p_new}, computed {total(NEW, new):.2f}")
            rc = 1
        if f"{total(LEGACY, leg):.2f}" != p_leg:
            print(f"{section}: {name}: legacy printed {p_leg}, computed {total(LEGACY, leg):.2f}")
            rc = 1
    opts = {k: v[0] for k, v in rows.items() if v[0]}
    ranked = sorted(opts, key=lambda k: -total(NEW, opts[k]))
    win = ranked[0]
    top = total(NEW, opts[win])
    margin = top - total(NEW, opts[ranked[1]]) if len(ranked) > 1 else 9.0
    f05, f10 = flips(opts, 0.05), flips(opts, 0.10)
    # Tie set: within TIE_MARGIN of the top score, or winning under a +-0.05 shift
    ties = [k for k in ranked if round(top - total(NEW, opts[k]), 2) < TIE_MARGIN] + f05
    tie_set = sorted(set(ties), key=lambda k: -total(NEW, opts[k]))
    alt = [winner(opts, EQUAL), winner(opts, ROC)]
    robust = "Robust" if len(tie_set) == 1 and win in alt else "Tie"
    leg_win = max(rows, key=lambda k: total(LEGACY, rows[k][1]))
    print(f"{section}\tnew={win} ({top:.2f}, margin {margin:.2f})\t{robust}"
          f"\ttie set={' | '.join(f'{k} ({total(NEW, opts[k]):.2f})' for k in tie_set)}"
          f"\tflips +-0.05={f05 or 'none'}\tflips +-0.10={f10 or 'none'}"
          f"\tequal={alt[0]}\tROC={alt[1]}\tcritical={critical(opts)}"
          f"\tlegacy={leg_win} ({total(LEGACY, rows[leg_win][1]):.2f})")
    return rc


def main() -> int:
    parser = argparse.ArgumentParser(description="Recompute ADR decision matrices.")
    parser.add_argument("adr", type=Path, help="ADR markdown file")
    args = parser.parse_args()
    rc = 0
    for section, rows in parse(args.adr).items():
        rc |= report(section, rows)
    return rc


if __name__ == "__main__":
    sys.exit(main())

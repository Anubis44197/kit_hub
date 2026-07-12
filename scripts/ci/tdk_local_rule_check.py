#!/usr/bin/env python3
"""Deterministic local Turkish writing-rule checks.

This is not an official TDK dictionary/provider check. It catches hard,
repeatable problems that must not reach DOCX export: encoding corruption,
question-mark replacement, punctuation spacing, obvious question-particle
attachment, and common proper-name apostrophe omissions.

The source file intentionally stays ASCII-only and uses Unicode escapes for
Turkish patterns so Windows code pages cannot corrupt the checker itself.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


TR_LOWER = "a-z\\u00e7\\u011f\\u0131\\u00f6\\u015f\\u00fc"
TR_UPPER = "A-Z\\u00c7\\u011e\\u0130\\u00d6\\u015e\\u00dc"
TR_WORD = f"{TR_LOWER}{TR_UPPER}"

MOJIBAKE_RE = re.compile(r"[ÃÅÄ]|�")
QUESTION_CORRUPTION_RE = re.compile(r"\w\?\w|\?\w", re.UNICODE)
REPEATED_QUESTION_RE = re.compile(r"\?{2,}")
SUSPICIOUS_LATIN_RE = re.compile(r"[\u0111\u00f0\u00fe\u00d0\u00de]")
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+[,.!?;:]")
NO_SPACE_AFTER_PUNCT_RE = re.compile(r"[,.!?;:](?=[^\s\d\"'\u201d\u2019)\]}])")
ATTACHED_QUESTION_PARTICLE_RE = re.compile(
    rf"\b[{TR_WORD}]+(?:m\u0131|mi|mu|m\u00fc)\?",
    re.IGNORECASE,
)
COMMON_PROPER_APOSTROPHE_RE = re.compile(
    rf"\b(Atat\u00fcrk|T\u00fcrkiye|\u0130stanbul|Ankara|Pera|Yusuf|Emine|Mahir|Rasit|Hatice)([{TR_LOWER}]{{2,}})\b"
)
ASCII_TRANSLITERATION_WORDS = {
    "cok": "\u00e7ok",
    "icin": "i\u00e7in",
    "degil": "de\u011fil",
    "gore": "g\u00f6re",
    "koy": "k\u00f6y",
    "ogretmen": "\u00f6\u011fretmen",
    "gecmis": "ge\u00e7mi\u015f",
    "soyledi": "s\u00f6yledi",
    "cikti": "\u00e7\u0131kt\u0131",
    "basladi": "ba\u015flad\u0131",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def collect_files(project_root: Path) -> list[Path]:
    candidates: list[Path] = []
    for pattern in [
        "episode/ep*.md",
        "revision/_workspace/11_front-matter_*.md",
        "revision/_workspace/12_cover-design_*.md",
    ]:
        candidates.extend(project_root.glob(pattern))
    return sorted(p for p in candidates if p.is_file())


def line_col(text: str, offset: int) -> tuple[int, int]:
    prefix = text[:offset]
    line = prefix.count("\n") + 1
    col = offset - prefix.rfind("\n")
    return line, col


def add_regex_findings(
    findings: list[dict],
    text: str,
    file_rel: str,
    pattern: re.Pattern,
    code: str,
    severity: str,
    message: str,
    limit: int,
) -> None:
    if len(findings) >= limit:
        return
    for match in pattern.finditer(text):
        line, col = line_col(text, match.start())
        findings.append(
            {
                "file": file_rel,
                "line": line,
                "column": col,
                "code": code,
                "severity": severity,
                "message": message,
                "excerpt": text[max(0, match.start() - 24) : match.end() + 24],
            }
        )
        if len(findings) >= limit:
            return


def main() -> int:
    parser = argparse.ArgumentParser(description="Local Turkish writing-rule gate.")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--max-findings", type=int, default=100)
    parser.add_argument("--fail-on-warning", action="store_true")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    files = collect_files(project_root)
    out_dir = project_root / "revision" / "_workspace"
    out_dir.mkdir(parents=True, exist_ok=True)
    report_path = out_dir / f"tdk-local-rule-check_{args.phase}.json"

    findings: list[dict] = []
    for path in files:
        text = read_text(path)
        rel = path.relative_to(project_root).as_posix()
        add_regex_findings(findings, text, rel, MOJIBAKE_RE, "encoding.mojibake", "critical", "Mojibake or replacement character detected.", args.max_findings)
        add_regex_findings(findings, text, rel, QUESTION_CORRUPTION_RE, "encoding.question_replacement", "critical", "Question-mark replacement corruption detected inside a word.", args.max_findings)
        add_regex_findings(findings, text, rel, REPEATED_QUESTION_RE, "encoding.repeated_question_marks", "critical", "Repeated question marks indicate likely replacement or corrupted text.", args.max_findings)
        add_regex_findings(findings, text, rel, SUSPICIOUS_LATIN_RE, "encoding.suspicious_latin", "critical", "Suspicious non-Turkish Latin character detected in Turkish prose.", args.max_findings)
        add_regex_findings(findings, text, rel, SPACE_BEFORE_PUNCT_RE, "punctuation.space_before", "warning", "Unexpected space before punctuation.", args.max_findings)
        add_regex_findings(findings, text, rel, NO_SPACE_AFTER_PUNCT_RE, "punctuation.no_space_after", "warning", "Missing space after punctuation.", args.max_findings)
        add_regex_findings(findings, text, rel, ATTACHED_QUESTION_PARTICLE_RE, "particle.question_spacing", "warning", "Possible attached Turkish question particle; review mi/mi/mu/mu spacing.", args.max_findings)
        add_regex_findings(findings, text, rel, COMMON_PROPER_APOSTROPHE_RE, "apostrophe.proper_name", "warning", "Possible missing apostrophe after a proper name.", args.max_findings)
        for bad, suggestion in ASCII_TRANSLITERATION_WORDS.items():
            pattern = re.compile(rf"\b{re.escape(bad)}\b", re.IGNORECASE)
            add_regex_findings(findings, text, rel, pattern, "diacritics.ascii_transliteration", "warning", f"Possible ASCII transliteration; consider '{suggestion}'.", args.max_findings)
        if len(findings) >= args.max_findings:
            break

    critical_count = sum(1 for f in findings if f["severity"] == "critical")
    warning_count = sum(1 for f in findings if f["severity"] == "warning")
    status = "blocked" if critical_count else ("review_required" if warning_count else "pass")

    report = {
        "run_id": args.run_id,
        "phase": args.phase,
        "generated_at": now_iso(),
        "provider": "local-deterministic-rules",
        "official_tdk_claim_allowed": False,
        "status": status,
        "checked_files": [p.relative_to(project_root).as_posix() for p in files],
        "critical_count": critical_count,
        "warning_count": warning_count,
        "findings": findings,
        "notes": [
            "This is a local deterministic rule gate, not official TDK dictionary verification.",
            "Official TDK verification requires separate provider/source evidence.",
        ],
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[tdk-local-rule-check] status={status} critical={critical_count} warnings={warning_count} report={report_path}")
    if critical_count:
        return 2
    if warning_count and args.fail_on_warning:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

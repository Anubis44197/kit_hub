#!/usr/bin/env python3
"""
Optional dictionary verification utility for Turkish episode text.

Behavior:
- Reads episode text files.
- Extracts candidate words.
- If `tdk-py` is available, validates unknown words against TDK suggestions/index.
- Writes a JSON report under revision/_workspace.

This script is designed to be fail-safe for CI/runner usage:
- Missing provider (`tdk-py`) is reported as "skipped" unless --require-provider is set.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


WORD_RE = re.compile(r"[A-Za-zÇĞİÖŞÜçğıöşü]{3,}")


@dataclass
class Finding:
    word: str
    reason: str
    suggestion: str | None = None


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def collect_episode_files(project_root: Path) -> list[Path]:
    episode_dir = project_root / "episode"
    if not episode_dir.exists():
        return []
    files = sorted(episode_dir.glob("ep*.md"))
    return [p for p in files if p.is_file()]


def tokenize(text: str) -> Iterable[str]:
    for token in WORD_RE.findall(text):
        yield token.lower()


def build_allowlist() -> set[str]:
    # Conservative baseline to avoid false positives on common function words.
    return {
        "ve", "ile", "ama", "fakat", "gibi", "icin", "için", "kadar", "daha", "cok", "çok",
        "bir", "bu", "su", "şu", "o", "da", "de", "ki", "mi", "mı", "mu", "mü",
    }


def resolve_output_path(project_root: Path, phase: str) -> Path:
    out_dir = project_root / "revision" / "_workspace"
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir / f"10_tdk-dictionary-check_{phase}.json"


def main() -> int:
    parser = argparse.ArgumentParser(description="Optional TDK dictionary verification layer.")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--require-provider", action="store_true")
    parser.add_argument("--max-findings", type=int, default=50)
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    episode_files = collect_episode_files(project_root)
    report_path = resolve_output_path(project_root, args.phase)

    report: dict = {
        "run_id": args.run_id,
        "phase": args.phase,
        "generated_at": now_iso(),
        "provider": "tdk-py",
        "status": "ok",
        "checked_files": [str(p.relative_to(project_root)) for p in episode_files],
        "checked_word_count": 0,
        "findings": [],
        "notes": [],
    }

    if not episode_files:
        report["status"] = "skipped"
        report["notes"].append("No episode files found under episode/.")
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[tdk-dict-check] skipped: no episode files ({report_path})")
        return 0

    try:
        import tdk  # type: ignore
    except Exception as exc:  # pragma: no cover
        report["status"] = "skipped"
        report["notes"].append(f"Provider unavailable: {exc}")
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[tdk-dict-check] skipped: provider unavailable ({report_path})")
        return 2 if args.require_provider else 0

    allowlist = build_allowlist()
    findings: list[Finding] = []
    seen: set[str] = set()

    for file_path in episode_files:
        text = read_text(file_path)
        for word in tokenize(text):
            report["checked_word_count"] += 1
            if word in allowlist or word in seen:
                continue
            seen.add(word)

            try:
                results = tdk.search_gts_sync(word)
            except Exception:
                # Provider error is non-fatal in optional mode.
                continue

            if results:
                continue

            suggestion = None
            try:
                suggestions = tdk.get_gts_suggestions_sync(word)
                if suggestions:
                    suggestion = suggestions[0]
            except Exception:
                suggestion = None

            findings.append(Finding(word=word, reason="not_found_in_gts", suggestion=suggestion))
            if len(findings) >= args.max_findings:
                break
        if len(findings) >= args.max_findings:
            break

    report["findings"] = [
        {
            "word": f.word,
            "reason": f.reason,
            "suggestion": f.suggestion,
        }
        for f in findings
    ]
    if findings:
        report["status"] = "review_required"
        report["notes"].append("Dictionary findings detected. Manual editorial review recommended.")

    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[tdk-dict-check] report: {report_path}")
    print(f"[tdk-dict-check] status: {report['status']}, findings={len(findings)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())


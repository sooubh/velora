"""
Helpers to keep LLM payloads compact and token-efficient.
"""
from __future__ import annotations

from typing import Any, Dict, List


def estimate_tokens(text: str) -> int:
    """
    Rough token estimate for English-like text.
    Uses ~4 chars/token heuristic.
    """
    value = (text or "").strip()
    if not value:
        return 0
    return max(1, int(len(value) / 4))


def truncate_text(text: str, max_chars: int) -> str:
    value = (text or "").strip()
    if len(value) <= max_chars:
        return value
    return value[: max_chars - 3].rstrip() + "..."


def compact_sources(
    sources: List[Dict[str, Any]],
    max_rows: int = 10,
    text_chars: int = 280,
) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for row in sources[:max_rows]:
        rows.append(
            {
                "title": truncate_text(str(row.get("title", "")), 140),
                "url": truncate_text(str(row.get("url", "")), 320),
                "source": truncate_text(str(row.get("source", "")), 80),
                "text": truncate_text(
                    str(row.get("description", row.get("content", ""))),
                    text_chars,
                ),
            }
        )
    return rows


def compact_matches(
    matches: List[Dict[str, Any]],
    max_rows: int = 6,
    text_chars: int = 220,
) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for match in matches[:max_rows]:
        metadata = match.get("metadata", {}) if isinstance(match, dict) else {}
        rows.append(
            {
                "score": round(float(match.get("score", 0.0)), 4)
                if isinstance(match, dict)
                else 0.0,
                "agent": truncate_text(str(metadata.get("agent", "")), 60),
                "title": truncate_text(str(metadata.get("title", "")), 140),
                "url": truncate_text(str(metadata.get("url", "")), 320),
                "text": truncate_text(str(metadata.get("text", "")), text_chars),
            }
        )
    return rows


def compact_analysis(analysis: Dict[str, Any]) -> Dict[str, Any]:
    insights = analysis.get("insights", [])
    conflicts = analysis.get("conflicts", [])
    consensus = analysis.get("credible_consensus", "")

    return {
        "insights": [truncate_text(str(i), 220) for i in insights[:10]],
        "conflicts": [truncate_text(str(c), 240) for c in conflicts[:8]],
        "credible_consensus": truncate_text(str(consensus), 400),
        "conflict_resolution": analysis.get("conflict_resolution", {}),
    }

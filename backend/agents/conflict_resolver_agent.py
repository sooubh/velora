"""
Conflict Resolver Agent - resolves contradictory evidence using credibility and recency.
"""
from typing import Dict, Any, List
import json

from services.gemini_service import parse_json_response
from utils.prompt_templates import PromptTemplates
from utils.payload_optimizer import compact_sources, compact_matches, compact_analysis, truncate_text


class ConflictResolverAgent:
    def __init__(self):
        self.name = "Conflict Resolver Agent"
        self.system_prompt = PromptTemplates.CONFLICT_RESOLVER_SYSTEM

    async def resolve(
        self,
        query: str,
        analysis: Dict[str, Any],
        raw_sources: List[Dict[str, Any]],
        pinecone_matches: List[Dict[str, Any]],
        model: str | None = None,
    ) -> Dict[str, Any]:
        """
        Resolve conflicting claims and rank evidence quality.
        """
        payload = {
            "query": truncate_text(query, 240),
            "analysis": compact_analysis(analysis),
            "raw_sources": compact_sources(raw_sources, max_rows=10, text_chars=220),
            "pinecone_matches": compact_matches(pinecone_matches, max_rows=6, text_chars=180),
        }

        prompt = PromptTemplates.CONFLICT_RESOLVER_PROMPT.format(
            payload=json.dumps(payload, ensure_ascii=True)
        )

        try:
            resolved = await parse_json_response(self.system_prompt, prompt, model=model)
            return {
                "success": True,
                "resolved": resolved,
            }
        except Exception as exc:
            return {
                "success": True,
                "warning": str(exc),
                "resolved": {
                    "resolved_conflicts": analysis.get("conflicts", []),
                    "source_rankings": [
                        {
                            "source": src.get("url", ""),
                            "credibility_score": 0.5,
                            "reason": "Fallback ranking",
                        }
                        for src in raw_sources[:5]
                    ],
                    "decision_notes": "Fallback conflict resolver output due to parsing failure.",
                    "recommended_consensus": analysis.get("credible_consensus", ""),
                },
            }

"""
Conflict Resolver Agent - resolves contradictory evidence using credibility and recency.
"""
from typing import Dict, Any, List

from services.gemini_service import parse_json_response
from utils.prompt_templates import PromptTemplates


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
    ) -> Dict[str, Any]:
        """
        Resolve conflicting claims and rank evidence quality.
        """
        payload = {
            "query": query,
            "analysis": analysis,
            "raw_sources": raw_sources[:20],
            "pinecone_matches": pinecone_matches[:10],
        }

        prompt = PromptTemplates.CONFLICT_RESOLVER_PROMPT.format(payload=str(payload))

        try:
            resolved = await parse_json_response(self.system_prompt, prompt)
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

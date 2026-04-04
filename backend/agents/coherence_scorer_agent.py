"""
Coherence Scorer Agent - evaluates report quality and decides if it passes threshold.
"""
from typing import Dict, Any

from services.gemini_service import parse_json_response
from utils.prompt_templates import PromptTemplates


class CoherenceScorerAgent:
    def __init__(self):
        self.name = "Coherence Scorer"
        self.system_prompt = PromptTemplates.COHERENCE_SCORER_SYSTEM

    async def score(self, query: str, report_text: str) -> Dict[str, Any]:
        prompt = PromptTemplates.COHERENCE_SCORER_PROMPT.format(
            query=query,
            report_text=report_text,
        )

        try:
            result = await parse_json_response(self.system_prompt, prompt)
            score = float(result.get("score", 0))
            return {
                "success": True,
                "score": max(0.0, min(100.0, score)),
                "feedback": str(result.get("feedback", "")),
                "gaps": result.get("gaps", []),
            }
        except Exception as exc:
            fallback = self._fallback_score(report_text)
            return {
                "success": True,
                "warning": str(exc),
                **fallback,
            }

    @staticmethod
    def _fallback_score(report_text: str) -> Dict[str, Any]:
        text = (report_text or "").strip()
        length = len(text)
        headers = text.count("##")
        score = 60.0
        if length > 1200:
            score += 15.0
        if length > 2500:
            score += 10.0
        if headers >= 3:
            score += 10.0
        return {
            "score": min(95.0, score),
            "feedback": "Fallback coherence scoring used.",
            "gaps": [],
        }

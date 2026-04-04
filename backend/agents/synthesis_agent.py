"""
Synthesis Agent - builds the final report from conflict-resolved analysis.
"""
from typing import Dict, Any, List

from services.gemini_service import ask
from utils.prompt_templates import PromptTemplates
from models.research_model import ReportSection


class SynthesisAgent:
    def __init__(self):
        self.name = "Synthesis Agent"
        self.system_prompt = PromptTemplates.SYNTHESIS_SYSTEM

    async def synthesize(
        self,
        query: str,
        analysis: Dict[str, Any],
        raw_sources: List[Dict[str, Any]] | None = None,
        additional_guidance: str = "",
    ) -> Dict[str, Any]:
        prompt = PromptTemplates.SYNTHESIS_PROMPT.format(
            query=query,
            analysis=str(analysis),
            additional_guidance=additional_guidance,
        )

        try:
            report_text = await ask(self.system_prompt, prompt)
            sections = self._parse_report_sections(report_text, raw_sources or [])
            return {
                "success": True,
                "query": query,
                "raw_report": report_text,
                "sections": sections,
                "summary": self._extract_summary(report_text),
            }
        except Exception as exc:
            return {
                "success": False,
                "error": str(exc),
                "summary": f"Synthesis error: {exc}",
                "raw_report": "",
                "sections": [],
            }

    @staticmethod
    def _parse_report_sections(report_text: str, sources: List[Dict[str, Any]]) -> List[ReportSection]:
        sections: List[ReportSection] = []
        lines = report_text.split("\n")
        current_section = None
        current_content: List[str] = []

        for line in lines:
            if line.startswith("##") or line.startswith("- "):
                if current_section:
                    sections.append(
                        ReportSection(
                            title=current_section,
                            content="\n".join(current_content).strip(),
                            sources=[s.get("url", "") for s in sources[:4]],
                        )
                    )
                current_section = line.strip("# ").strip("- ")
                current_content = []
            else:
                current_content.append(line)

        if current_section:
            sections.append(
                ReportSection(
                    title=current_section,
                    content="\n".join(current_content).strip(),
                    sources=[s.get("url", "") for s in sources[:4]],
                )
            )

        if not sections:
            sections.append(
                ReportSection(
                    title="Research Synthesis",
                    content=report_text,
                    sources=[s.get("url", "") for s in sources[:4]],
                )
            )

        return sections

    @staticmethod
    def _extract_summary(report_text: str) -> str:
        parts = report_text.split("\n\n")
        return parts[0] if parts else report_text[:220]

"""
Synthesis Agent - builds the final report from conflict-resolved analysis.
"""
from typing import Dict, Any, List
import json
import re

from services.gemini_service import ask
from utils.prompt_templates import PromptTemplates
from models.research_model import ReportSection
from utils.payload_optimizer import compact_analysis, compact_sources, truncate_text


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
        model: str | None = None,
    ) -> Dict[str, Any]:
        compact_payload = {
            "query": truncate_text(query, 240),
            "analysis": compact_analysis(analysis),
            "guidance": truncate_text(additional_guidance, 320),
            "source_hints": compact_sources(raw_sources or [], max_rows=8, text_chars=160),
        }

        prompt = PromptTemplates.SYNTHESIS_PROMPT.format(
            query=truncate_text(query, 240),
            analysis=json.dumps(compact_payload["analysis"], ensure_ascii=True),
            additional_guidance=json.dumps(
                {
                    "guidance": compact_payload["guidance"],
                    "source_hints": compact_payload["source_hints"],
                },
                ensure_ascii=True,
            ),
        )

        try:
            report_text = await ask(self.system_prompt, prompt, model=model)
            sections = self._parse_report_sections(report_text, raw_sources or [])
            return {
                "success": True,
                "query": query,
                "raw_report": report_text,
                "sections": sections,
                "summary": self._extract_summary(report_text),
                "citations": self._extract_citations(report_text),
                "image_urls": self._extract_images(report_text),
                "table_count": report_text.count("|"),
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
        heading_pattern = re.compile(r"^##\s+(.+)$", re.MULTILINE)
        matches = list(heading_pattern.finditer(report_text))

        if matches:
            for idx, match in enumerate(matches):
                title = match.group(1).strip()
                start = match.end()
                end = matches[idx + 1].start() if idx + 1 < len(matches) else len(report_text)
                body = report_text[start:end].strip()
                if body:
                    sections.append(
                        ReportSection(
                            title=title,
                            content=body,
                            sources=[s.get("url", "") for s in sources[:6]],
                        )
                    )

        if not sections:
            sections.append(
                ReportSection(
                    title="Research Synthesis",
                    content=report_text,
                    sources=[s.get("url", "") for s in sources[:6]],
                )
            )

        return sections

    @staticmethod
    def _extract_summary(report_text: str) -> str:
        parts = report_text.split("\n\n")
        return parts[0] if parts else report_text[:220]

    @staticmethod
    def _extract_citations(report_text: str) -> List[str]:
        urls = re.findall(r"https?://[^\s\)\]]+", report_text)
        seen = set()
        ordered: List[str] = []
        for url in urls:
            if url not in seen:
                seen.add(url)
                ordered.append(url)
        return ordered[:30]

    @staticmethod
    def _extract_images(report_text: str) -> List[str]:
        md_images = re.findall(r"!\[[^\]]*\]\((https?://[^\)]+)\)", report_text)
        seen = set()
        ordered: List[str] = []
        for url in md_images:
            if url not in seen:
                seen.add(url)
                ordered.append(url)
        return ordered[:12]

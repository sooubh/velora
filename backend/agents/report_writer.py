"""
Report Writer Agent - Creates the final polished research report.
"""
from typing import Dict, Any, List
from services.gemini_service import ask
from utils.prompt_templates import PromptTemplates
from models.research_model import ReportSection

class ReportWriterAgent:
    def __init__(self):
        self.name = "Report Writer Agent"
        self.system_prompt = PromptTemplates.REPORT_WRITER_SYSTEM
    
    async def write_report(self, query: str, analysis: Dict[str, Any], raw_sources: List[Dict] = None) -> Dict[str, Any]:
        """
        Create a professional research report from analysis.
        
        Args:
            query: Original research query
            analysis: Analyzed insights from Analyzer Agent
            raw_sources: Original search results for citation
            
        Returns:
            Polished research report with sections
        """
        prompt = PromptTemplates.REPORT_WRITER_PROMPT.format(
            analysis=str(analysis)
        )
        
        try:
            report_text = await ask(self.system_prompt, prompt)
            
            # Parse report into sections
            sections = self._parse_report_sections(report_text, raw_sources or [])
            
            return {
                "success": True,
                "query": query,
                "raw_report": report_text,
                "sections": sections,
                "summary": self._extract_summary(report_text)
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "summary": f"Error generating report: {str(e)}"
            }
    
    @staticmethod
    def _parse_report_sections(report_text: str, sources: List[Dict]) -> List[ReportSection]:
        """
        Parse report text into structured sections.
        
        Args:
            report_text: Raw report from Gemini
            sources: Source URLs for citing
            
        Returns:
            List of structured report sections
        """
        sections = []
        
        # Simple section parsing
        lines = report_text.split('\n')
        current_section = None
        current_content = []
        
        for line in lines:
            if line.startswith('##') or line.startswith('- '):
                if current_section:
                    sections.append(ReportSection(
                        title=current_section,
                        content='\n'.join(current_content).strip(),
                        sources=[s.get('url', '') for s in sources[:3]]
                    ))
                current_section = line.strip('# ').strip('- ')
                current_content = []
            else:
                current_content.append(line)
        
        # Add last section
        if current_section:
            sections.append(ReportSection(
                title=current_section,
                content='\n'.join(current_content).strip(),
                sources=[s.get('url', '') for s in sources[:3]]
            ))
        
        return sections if sections else [ReportSection(
            title="Research Summary",
            content=report_text,
            sources=[s.get('url', '') for s in sources[:3]]
        )]
    
    @staticmethod
    def _extract_summary(report_text: str) -> str:
        """Extract first paragraph as summary"""
        paragraphs = report_text.split('\n\n')
        return paragraphs[0] if paragraphs else report_text[:200]

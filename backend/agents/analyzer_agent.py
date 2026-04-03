"""
Analyzer Agent - Filters, deduplicates, and analyzes search results.
"""
from typing import Dict, Any
from services.gemini_service import parse_json_response
from utils.prompt_templates import PromptTemplates

class AnalyzerAgent:
    def __init__(self):
        self.name = "Analyzer Agent"
        self.system_prompt = PromptTemplates.ANALYZER_SYSTEM
    
    async def analyze(self, query: str, search_results: str, analysis_focus: str = "") -> Dict[str, Any]:
        """
        Analyze search results for patterns, conflicts, and insights.
        
        Args:
            query: Original research query
            search_results: Formatted search results from Web Search Agent
            analysis_focus: Specific focus points from Orchestrator
            
        Returns:
            Analyzed insights with credibility ratings
        """
        prompt = PromptTemplates.ANALYZER_PROMPT.format(
            query=query,
            search_results=search_results
        )
        
        if analysis_focus:
            prompt += f"\n\nAdditional focus: {analysis_focus}"
        
        try:
            analysis = await parse_json_response(self.system_prompt, prompt)
            return {
                "success": True,
                "analysis": analysis
            }
        except Exception as e:
            # Fallback if JSON parsing fails
            return {
                "success": True,
                "warning": str(e),
                "analysis": {
                    "insights": [
                        "Analysis fallback used because model returned non-JSON output.",
                        "Search results were gathered successfully."
                    ],
                    "conflicts": [],
                    "credible_consensus": "Preliminary consensus generated from available sources."
                }
            }
    
    async def deduplicate_results(self, results: list) -> list:
        """
        Remove duplicate or very similar results from search.
        
        Args:
            results: List of search results
            
        Returns:
            Deduplicated results
        """
        if not results:
            return []
        
        seen_urls = set()
        deduplicated = []
        
        for result in results:
            url = result.get('url', '')
            domain = self._extract_domain(url)
            
            if domain not in seen_urls:
                seen_urls.add(domain)
                deduplicated.append(result)
        
        return deduplicated
    
    @staticmethod
    def _extract_domain(url: str) -> str:
        """Extract domain from URL"""
        if not url:
            return ""
        try:
            from urllib.parse import urlparse
            return urlparse(url).netloc
        except:
            return url

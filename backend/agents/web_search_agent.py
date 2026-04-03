"""
Web Search Agent - Searches the web and summarizes results.
"""
from typing import Dict, List, Any
from services.gemini_service import ask
from services.search_service import get_search_service
from utils.prompt_templates import PromptTemplates

class WebSearchAgent:
    def __init__(self):
        self.name = "Web Search Agent"
        self.system_prompt = PromptTemplates.WEB_SEARCH_SYSTEM
        self.search_service = get_search_service()
    
    async def search_and_summarize(self, query: str, max_results: int = 5) -> Dict[str, Any]:
        """
        Search for information and summarize credible sources.
        
        Args:
            query: Search query
            max_results: Maximum search results to fetch
            
        Returns:
            Summarized search results with sources
        """
        try:
            # Perform web search
            search_results = await self.search_service.search(query, num_results=max_results)
            
            if not search_results:
                return {
                    "success": False,
                    "error": "No search results found",
                    "results": []
                }
            
            # Format search results for summarization
            results_text = self._format_results(search_results)
            
            # Ask Gemini to summarize
            prompt = PromptTemplates.WEB_SEARCH_PROMPT.format(
                query=query,
                search_results=results_text
            )
            
            summary = await ask(self.system_prompt, prompt)
            
            return {
                "success": True,
                "query": query,
                "raw_results": search_results,
                "summary": summary,
                "result_count": len(search_results)
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "results": []
            }
    
    @staticmethod
    def _format_results(results: List[Dict[str, str]]) -> str:
        """Format search results for prompt"""
        formatted = []
        for i, result in enumerate(results, 1):
            formatted.append(
                f"{i}. Title: {result.get('title', '')}\n"
                f"   Description: {result.get('description', '')}\n"
                f"   Source: {result.get('url', '')}"
            )
        return "\n\n".join(formatted)

"""
Search Agent - broad web search specialist.
"""
from typing import Dict, Any

from agents.web_search_agent import WebSearchAgent


class SearchAgent:
    def __init__(self):
        self.name = "Search Agent"
        self._worker = WebSearchAgent()

    async def run(self, query: str) -> Dict[str, Any]:
        result = await self._worker.search_and_summarize(query, max_results=6)
        result["agent_name"] = self.name
        return result

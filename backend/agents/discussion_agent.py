"""
Discussion Agent - gathers community opinions and discussions.
"""
from typing import Dict, Any

from agents.web_search_agent import WebSearchAgent


class DiscussionAgent:
    def __init__(self):
        self.name = "Discussion Agent"
        self._worker = WebSearchAgent()

    async def run(self, query: str) -> Dict[str, Any]:
        scoped_query = f"{query} reddit forum discussion opinions"
        result = await self._worker.search_and_summarize(scoped_query, max_results=6)
        result["agent_name"] = self.name
        return result

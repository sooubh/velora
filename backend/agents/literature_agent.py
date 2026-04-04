"""
Literature Agent - targets academic and scholarly sources.
"""
from typing import Dict, Any

from agents.web_search_agent import WebSearchAgent


class LiteratureAgent:
    def __init__(self):
        self.name = "Literature Agent"
        self._worker = WebSearchAgent()

    async def run(self, query: str) -> Dict[str, Any]:
        scoped_query = (
            f"{query} (arxiv OR pubmed OR openalex OR core.ac.uk OR research paper)"
        )
        result = await self._worker.search_and_summarize(scoped_query, max_results=6)
        result["agent_name"] = self.name
        return result

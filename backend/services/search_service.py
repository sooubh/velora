import os
import asyncio
from urllib.parse import urlparse
from typing import List, Dict, Any

from duckduckgo_search import DDGS
from tavily import TavilyClient

class SearchService:
    """Web search wrapper using Tavily + DuckDuckGo."""
    
    def __init__(self):
        self.tavily_api_key = os.environ.get('TAVILY_API_KEY')
        self.tavily_client = TavilyClient(api_key=self.tavily_api_key) if self.tavily_api_key else None

        if not self.tavily_client:
            print(
                "Warning: TAVILY_API_KEY not set. Using DuckDuckGo-only fallback search."
            )

    def provider_status(self) -> Dict[str, Any]:
        """Return provider configuration/availability for diagnostics."""
        providers = {
            "tavily": bool(self.tavily_client),
            "duckduckgo": True,
        }
        active = [name for name, enabled in providers.items() if enabled]
        return {
            "providers": providers,
            "active": active,
            "primary": "tavily" if providers["tavily"] else "duckduckgo",
        }
    
    async def search(self, query: str, num_results: int = 10) -> List[Dict[str, Any]]:
        """
        Perform search via Tavily and DuckDuckGo.
        
        Args:
            query: Search query string
            num_results: Number of results to return
            
        Returns:
            List of search results with title, description, link
        """
        limit = max(1, min(num_results, 10))

        tavily_task = self._tavily_search(query, limit) if self.tavily_client else None
        ddg_task = self._duckduckgo_search(query, limit)

        tasks = [ddg_task] if tavily_task is None else [tavily_task, ddg_task]

        try:
            results_by_provider = await asyncio.gather(*tasks, return_exceptions=True)
            merged: List[Dict[str, Any]] = []

            for provider_result in results_by_provider:
                if isinstance(provider_result, Exception):
                    print(f"Search provider error: {provider_result}")
                    continue
                merged.extend(provider_result)

            return self._deduplicate_results(merged)[:limit]
        except Exception as e:
            print(f"Search error: {e}")
            return []

    async def _tavily_search(self, query: str, limit: int) -> List[Dict[str, Any]]:
        def _run() -> List[Dict[str, Any]]:
            response = self.tavily_client.search(
                query=query,
                max_results=limit,
                topic="general",
                include_answer=False,
                include_images=False,
                search_depth="basic",
            )
            items = response.get("results", [])
            parsed = []
            for item in items:
                url = item.get("url", "")
                parsed.append({
                    "title": item.get("title", ""),
                    "description": item.get("content", ""),
                    "url": url,
                    "source": self._extract_source(url),
                })
            return parsed

        return await asyncio.to_thread(_run)

    async def _duckduckgo_search(self, query: str, limit: int) -> List[Dict[str, Any]]:
        def _run() -> List[Dict[str, Any]]:
            backends = ["html", "lite", "api"]
            last_error = None

            for backend in backends:
                try:
                    parsed = []
                    with DDGS() as ddgs:
                        for item in ddgs.text(query, max_results=limit, backend=backend):
                            url = item.get("href", "")
                            parsed.append({
                                "title": item.get("title", ""),
                                "description": item.get("body", ""),
                                "url": url,
                                "source": self._extract_source(url),
                            })

                    if parsed:
                        return parsed
                except Exception as exc:
                    last_error = exc

            if last_error:
                raise last_error
            return []

        return await asyncio.to_thread(_run)

    @staticmethod
    def _extract_source(url: str) -> str:
        if not url:
            return ""
        try:
            return urlparse(url).netloc
        except Exception:
            return ""

    @staticmethod
    def _deduplicate_results(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        seen = set()
        deduped = []
        for item in results:
            url = (item.get("url") or "").strip()
            if not url or url in seen:
                continue
            seen.add(url)
            deduped.append(item)
        return deduped

# Singleton instance
_search_service = None

def get_search_service() -> SearchService:
    """Get or create search service instance"""
    global _search_service
    if _search_service is None:
        _search_service = SearchService()
    return _search_service


def get_search_provider_status() -> Dict[str, Any]:
    """Get current search provider status for health/diagnostics."""
    return get_search_service().provider_status()

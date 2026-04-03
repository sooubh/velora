import os
import aiohttp
from typing import List, Dict, Any

class SearchService:
    """Google Search API wrapper for web search"""
    
    def __init__(self):
        # Support common env var aliases to reduce setup friction.
        self.api_key = (
            os.environ.get('GOOGLE_SEARCH_API_KEY')
            or os.environ.get('GOOGLE_API_KEY')
        )
        self.search_engine_id = (
            os.environ.get('GOOGLE_SEARCH_ENGINE_ID')
            or os.environ.get('GOOGLE_CSE_ID')
        )
        self.enabled = bool(self.api_key and self.search_engine_id)

        if not self.enabled:
            print(
                "Warning: Google Search is disabled. Set GOOGLE_SEARCH_API_KEY and "
                "GOOGLE_SEARCH_ENGINE_ID in backend/.env to enable web search."
            )
    
    async def search(self, query: str, num_results: int = 10) -> List[Dict[str, Any]]:
        """
        Perform a Google search.
        
        Args:
            query: Search query string
            num_results: Number of results to return
            
        Returns:
            List of search results with title, description, link
        """
        if not self.enabled:
            return []

        url = "https://www.googleapis.com/customsearch/v1"
        params = {
            "q": query,
            "key": self.api_key,
            "cx": self.search_engine_id,
            "num": min(num_results, 10)
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._parse_results(data)
                    else:
                        return []
        except Exception as e:
            print(f"Search error: {e}")
            return []
    
    @staticmethod
    def _parse_results(data: Dict) -> List[Dict[str, Any]]:
        """Parse Google Search API response"""
        results = []
        if 'items' in data:
            for item in data['items']:
                results.append({
                    'title': item.get('title', ''),
                    'description': item.get('snippet', ''),
                    'url': item.get('link', ''),
                    'source': item.get('displayLink', '')
                })
        return results

# Singleton instance
_search_service = None

def get_search_service() -> SearchService:
    """Get or create search service instance"""
    global _search_service
    if _search_service is None:
        _search_service = SearchService()
    return _search_service

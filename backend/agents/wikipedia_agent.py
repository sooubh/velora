"""
Wikipedia Agent - fetches background definitions from Wikipedia API.
"""
from __future__ import annotations

import asyncio
import json
from typing import Dict, Any, List
from urllib.parse import quote
from urllib.request import urlopen


class WikipediaAgent:
    def __init__(self):
        self.name = "Wikipedia Agent"

    async def run(self, query: str) -> Dict[str, Any]:
        try:
            pages = await asyncio.to_thread(self._search_and_fetch, query)
            if not pages:
                return {
                    "success": False,
                    "agent_name": self.name,
                    "error": "No Wikipedia pages found",
                    "raw_results": [],
                    "summary": "",
                    "result_count": 0,
                }

            summary_lines = []
            for idx, page in enumerate(pages, 1):
                summary_lines.append(
                    f"{idx}. {page['title']}: {page['description']}\nSource: {page['url']}"
                )

            return {
                "success": True,
                "agent_name": self.name,
                "raw_results": pages,
                "summary": "\n\n".join(summary_lines),
                "result_count": len(pages),
            }
        except Exception as exc:
            return {
                "success": False,
                "agent_name": self.name,
                "error": str(exc),
                "raw_results": [],
                "summary": "",
                "result_count": 0,
            }

    def _search_and_fetch(self, query: str) -> List[Dict[str, str]]:
        search_url = (
            "https://en.wikipedia.org/w/api.php"
            f"?action=query&list=search&srsearch={quote(query)}&format=json&srlimit=3"
        )

        with urlopen(search_url, timeout=12) as response:
            payload = json.loads(response.read().decode("utf-8"))

        items = payload.get("query", {}).get("search", [])
        pages: List[Dict[str, str]] = []

        for item in items:
            title = item.get("title", "")
            if not title:
                continue

            summary_url = (
                "https://en.wikipedia.org/api/rest_v1/page/summary/"
                f"{quote(title.replace(' ', '_'))}"
            )

            try:
                with urlopen(summary_url, timeout=12) as response:
                    details = json.loads(response.read().decode("utf-8"))
            except Exception:
                continue

            extract = details.get("extract", "")
            page_url = details.get("content_urls", {}).get("desktop", {}).get("page", "")
            pages.append(
                {
                    "title": title,
                    "description": extract[:600],
                    "url": page_url,
                    "source": "wikipedia.org",
                }
            )

        return pages

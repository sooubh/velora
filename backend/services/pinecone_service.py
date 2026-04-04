"""
Pinecone vector memory service helpers.
Handles env validation plus vector upsert/query via Pinecone data-plane API.
"""
from __future__ import annotations

import os
import json
import uuid
import asyncio
from typing import Dict, Any
from urllib import request

from services.gemini_service import embed_texts


def get_pinecone_config() -> Dict[str, str]:
    return {
        "api_key": os.environ.get("PINECONE_API_KEY", "").strip(),
        "host": os.environ.get("PINECONE_HOST", "").strip(),
        "index": os.environ.get("PINECONE_INDEX", "velora-research").strip(),
        "namespace": os.environ.get("PINECONE_NAMESPACE", "default").strip(),
    }


def get_pinecone_status() -> Dict[str, Any]:
    cfg = get_pinecone_config()
    has_api_key = bool(cfg["api_key"])
    has_host = bool(cfg["host"])

    return {
        "configured": has_api_key and has_host,
        "has_api_key": has_api_key,
        "has_host": has_host,
        "index": cfg["index"],
        "namespace": cfg["namespace"],
        "host": cfg["host"] if has_host else "",
    }


def is_pinecone_configured() -> bool:
    status = get_pinecone_status()
    return bool(status["configured"])


def _host_url(path: str) -> str:
    cfg = get_pinecone_config()
    host = cfg["host"].rstrip("/")
    return f"{host}{path}"


def _post_json(url: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    cfg = get_pinecone_config()
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(
        url=url,
        data=body,
        method="POST",
        headers={
            "Api-Key": cfg["api_key"],
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    with request.urlopen(req, timeout=20) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def _truncate_text(text: str, limit: int = 1200) -> str:
    value = (text or "").strip()
    if len(value) <= limit:
        return value
    return value[:limit]


async def upsert_evidence_chunks(
    research_id: str,
    chunks: list[Dict[str, Any]],
) -> Dict[str, Any]:
    if not is_pinecone_configured():
        return {
            "success": False,
            "reason": "pinecone_not_configured",
            "upserted": 0,
        }

    if not chunks:
        return {"success": True, "upserted": 0}

    texts = [_truncate_text(str(c.get("text", ""))) for c in chunks]
    try:
        vectors = await embed_texts(texts)
    except Exception as exc:
        return {
            "success": False,
            "reason": f"embedding_failed: {exc}",
            "upserted": 0,
        }

    cfg = get_pinecone_config()
    records = []
    for idx, (chunk, values) in enumerate(zip(chunks, vectors, strict=False)):
        records.append(
            {
                "id": f"{research_id}-{idx}-{uuid.uuid4().hex[:10]}",
                "values": values,
                "metadata": {
                    "research_id": research_id,
                    "agent": str(chunk.get("agent", "")),
                    "title": str(chunk.get("title", ""))[:200],
                    "url": str(chunk.get("url", ""))[:600],
                    "source": str(chunk.get("source", ""))[:200],
                    "text": _truncate_text(str(chunk.get("text", ""))),
                },
            }
        )

    payload = {
        "vectors": records,
        "namespace": cfg["namespace"],
    }

    try:
        await asyncio.to_thread(_post_json, _host_url("/vectors/upsert"), payload)
        return {"success": True, "upserted": len(records)}
    except Exception as exc:
        return {
            "success": False,
            "reason": f"upsert_failed: {exc}",
            "upserted": 0,
        }


async def query_evidence(
    query_text: str,
    research_id: str,
    top_k: int = 8,
) -> Dict[str, Any]:
    if not is_pinecone_configured():
        return {
            "success": False,
            "reason": "pinecone_not_configured",
            "matches": [],
        }

    try:
        vector = (await embed_texts([_truncate_text(query_text, limit=1000)]))[0]
    except Exception as exc:
        return {
            "success": False,
            "reason": f"embedding_failed: {exc}",
            "matches": [],
        }

    cfg = get_pinecone_config()
    payload = {
        "vector": vector,
        "topK": top_k,
        "includeMetadata": True,
        "namespace": cfg["namespace"],
        "filter": {
            "research_id": {
                "$eq": research_id,
            }
        },
    }

    try:
        result = await asyncio.to_thread(_post_json, _host_url("/query"), payload)
        matches = result.get("matches", []) if isinstance(result, dict) else []
        return {
            "success": True,
            "matches": matches,
        }
    except Exception as exc:
        return {
            "success": False,
            "reason": f"query_failed: {exc}",
            "matches": [],
        }

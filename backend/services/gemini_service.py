import os
import asyncio
import time
import hashlib
from google import genai
from google.genai import types

_client = None
_cache: dict[str, tuple[float, str]] = {}
_cache_hits = 0
_cache_misses = 0


def _default_generation_model() -> str:
    return os.environ.get('GENERATION_MODEL', 'gemini-2.5-flash')


def _default_embedding_model() -> str:
    return os.environ.get('EMBEDDING_MODEL', 'text-embedding-004')


def _cache_enabled() -> bool:
    return os.environ.get('ENABLE_LLM_CACHE', 'true').lower() == 'true'


def _cache_ttl_seconds() -> int:
    return int(os.environ.get('CACHE_TTL_SECONDS', '1800'))


def _cache_max_items() -> int:
    return int(os.environ.get('CACHE_MAX_ITEMS', '512'))


def _cache_key(model_name: str, system_prompt: str, user_message: str) -> str:
    raw = f"{model_name}\n{system_prompt}\n{user_message}".encode('utf-8', errors='ignore')
    return hashlib.sha256(raw).hexdigest()


def _cache_get(key: str) -> str | None:
    global _cache_hits, _cache_misses
    if not _cache_enabled():
        _cache_misses += 1
        return None
    row = _cache.get(key)
    if not row:
        _cache_misses += 1
        return None
    expires_at, value = row
    if time.time() >= expires_at:
        _cache.pop(key, None)
        _cache_misses += 1
        return None
    _cache_hits += 1
    return value


def _cache_set(key: str, value: str):
    if not _cache_enabled():
        return
    if len(_cache) >= _cache_max_items():
        # Drop one arbitrary key to keep overhead low.
        _cache.pop(next(iter(_cache)))
    _cache[key] = (time.time() + _cache_ttl_seconds(), value)


def get_cache_stats() -> dict:
    return {
        'enabled': _cache_enabled(),
        'size': len(_cache),
        'hits': _cache_hits,
        'misses': _cache_misses,
        'ttl_seconds': _cache_ttl_seconds(),
    }

def get_client():
    """Get or create Gemini client instance"""
    global _client
    if _client is None:
        api_key = os.environ.get('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set in environment")
        _client = genai.Client(api_key=api_key)
    return _client

async def ask(system_prompt: str, user_message: str, model: str | None = None, retries: int = 3) -> str:
    """
    Ask Gemini a question with system prompt and retry logic.
    
    Args:
        system_prompt: System instruction for the model
        user_message: The user's message/query
        model: Which Gemini model to use
        retries: Number of retry attempts
        
    Returns:
        The model's response text
    """
    model_name = model or _default_generation_model()
    key = _cache_key(model_name, system_prompt, user_message)
    cached = _cache_get(key)
    if cached is not None:
        return cached

    for attempt in range(retries):
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(
                    get_client().models.generate_content,
                    model=model_name,
                    config=types.GenerateContentConfig(
                        system_instruction=system_prompt,
                    ),
                    contents=user_message,
                ),
                timeout=45,
            )
            text = response.text or ""
            _cache_set(key, text)
            return text
        except Exception as e:
            if attempt == retries - 1:
                raise
            await asyncio.sleep(1)

async def ask_with_context(system_prompt: str, user_message: str, context: str = "", model: str | None = None) -> str:
    """
    Ask Gemini with additional context.
    
    Args:
        system_prompt: System instruction
        user_message: User query
        context: Additional context/history
        model: Model to use
        
    Returns:
        Model response
    """
    full_prompt = f"{context}\n\n{user_message}" if context else user_message
    return await ask(system_prompt, full_prompt, model)

async def parse_json_response(system_prompt: str, user_message: str, model: str | None = None) -> dict:
    """
    Ask Gemini and parse JSON response.
    
    Args:
        system_prompt: System instruction (should instruct to return JSON)
        user_message: User query
        model: Model to use
        
    Returns:
        Parsed JSON response as dict
    """
    import json

    def _extract_json_candidate(text: str) -> str:
        candidate = text.strip()

        # Try fenced markdown blocks first.
        if "```json" in candidate:
            candidate = candidate.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in candidate:
            candidate = candidate.split("```", 1)[1].split("```", 1)[0].strip()

        # If still not a plain object/array, try slicing from first { to last }.
        if candidate and not (candidate.startswith("{") or candidate.startswith("[")):
            start_obj = candidate.find("{")
            end_obj = candidate.rfind("}")
            if start_obj != -1 and end_obj != -1 and end_obj > start_obj:
                candidate = candidate[start_obj:end_obj + 1].strip()

        return candidate

    response_text = await ask(system_prompt, user_message, model)
    candidate = _extract_json_candidate(response_text)

    if not candidate:
        raise ValueError("Gemini returned empty response for JSON parsing")

    return json.loads(candidate)


async def embed_texts(
    texts: list[str],
    model: str | None = None,
    output_dimensionality: int = 768,
) -> list[list[float]]:
    """
    Generate embeddings for a list of input texts using Gemini embeddings.

    Returns:
        List of embedding vectors in the same order as input texts.
    """
    if not texts:
        return []

    model_name = model or _default_embedding_model()

    def _extract_vectors(response_obj) -> list[list[float]]:
        vectors: list[list[float]] = []

        embeddings = getattr(response_obj, 'embeddings', None)
        if embeddings is None and isinstance(response_obj, dict):
            embeddings = response_obj.get('embeddings', [])

        if not embeddings:
            raise ValueError('No embeddings returned from Gemini')

        for item in embeddings:
            values = getattr(item, 'values', None)
            if values is None and isinstance(item, dict):
                values = item.get('values')
            if not values:
                raise ValueError('Embedding item missing values')
            vectors.append([float(v) for v in values])

        return vectors

    for attempt in range(3):
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(
                    get_client().models.embed_content,
                    model=model_name,
                    contents=texts,
                    config=types.EmbedContentConfig(
                        output_dimensionality=output_dimensionality,
                    ),
                ),
                timeout=45,
            )
            vectors = _extract_vectors(response)
            if len(vectors) != len(texts):
                raise ValueError('Embedding count mismatch from Gemini response')
            return vectors
        except Exception:
            if attempt == 2:
                raise
            await asyncio.sleep(1)

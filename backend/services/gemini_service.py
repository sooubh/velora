import os
import asyncio
from google import genai
from google.genai import types

_client = None

def get_client():
    """Get or create Gemini client instance"""
    global _client
    if _client is None:
        api_key = os.environ.get('GEMINI_API_KEY')
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set in environment")
        _client = genai.Client(api_key=api_key)
    return _client

async def ask(system_prompt: str, user_message: str, model: str = 'gemini-2.5-flash', retries: int = 3) -> str:
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
    for attempt in range(retries):
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(
                    get_client().models.generate_content,
                    model=model,
                    config=types.GenerateContentConfig(
                        system_instruction=system_prompt,
                    ),
                    contents=user_message,
                ),
                timeout=45,
            )
            return response.text or ""
        except Exception as e:
            if attempt == retries - 1:
                raise
            await asyncio.sleep(1)

async def ask_with_context(system_prompt: str, user_message: str, context: str = "", model: str = 'gemini-2.5-flash') -> str:
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

async def parse_json_response(system_prompt: str, user_message: str, model: str = 'gemini-2.5-flash') -> dict:
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
    model: str = 'text-embedding-004',
    output_dimensionality: int = 768,
) -> list[list[float]]:
    """
    Generate embeddings for a list of input texts using Gemini embeddings.

    Returns:
        List of embedding vectors in the same order as input texts.
    """
    if not texts:
        return []

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
                    model=model,
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

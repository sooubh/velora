# Services package
from .gemini_service import get_client, ask, ask_with_context, parse_json_response
from .search_service import get_search_service
from .firebase_service import init_firebase, get_firestore, save_research, get_research, get_user_research_history
from .pinecone_service import (
    get_pinecone_config,
    get_pinecone_status,
    is_pinecone_configured,
    upsert_evidence_chunks,
    query_evidence,
)

__all__ = [
    'get_client',
    'ask',
    'ask_with_context',
    'parse_json_response',
    'get_search_service',
    'get_pinecone_config',
    'get_pinecone_status',
    'is_pinecone_configured',
    'upsert_evidence_chunks',
    'query_evidence',
    'init_firebase',
    'get_firestore',
    'save_research',
    'get_research',
    'get_user_research_history'
]

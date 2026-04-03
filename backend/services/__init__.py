# Services package
from .gemini_service import get_client, ask, ask_with_context, parse_json_response
from .search_service import get_search_service
from .firebase_service import init_firebase, get_firestore, save_research, get_research, get_user_research_history

__all__ = [
    'get_client',
    'ask',
    'ask_with_context',
    'parse_json_response',
    'get_search_service',
    'init_firebase',
    'get_firestore',
    'save_research',
    'get_research',
    'get_user_research_history'
]

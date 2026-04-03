import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from typing import Dict, Any, Optional

_db = None

def init_firebase():
    """Initialize Firebase Admin SDK"""
    global _db
    if _db is None:
        creds_path = os.environ.get('FIREBASE_CREDENTIALS_PATH', './firebase-key.json')
        
        try:
            cred = credentials.Certificate(creds_path)
            firebase_admin.initialize_app(cred)
            _db = firestore.client()
        except Exception as e:
            print(f"Firebase init error: {e}")
            raise

def get_firestore():
    """Get Firestore client instance"""
    global _db
    if _db is None:
        init_firebase()
    return _db

async def save_research(research_id: str, user_id: str, query: str, report: Dict[str, Any]) -> bool:
    """
    Save research report to Firestore.
    
    Args:
        research_id: Unique research ID
        user_id: User's Firebase UID
        query: Original research query
        report: Completed research report
        
    Returns:
        Success status
    """
    try:
        db = get_firestore()
        db.collection('users').document(user_id).collection('research').document(research_id).set({
            'query': query,
            'report': report,
            'created_at': datetime.now().isoformat(),
            'status': 'completed'
        })
        return True
    except Exception as e:
        print(f"Firestore save error: {e}")
        return False

async def get_research(research_id: str, user_id: str) -> Optional[Dict[str, Any]]:
    """
    Retrieve research report from Firestore.
    
    Args:
        research_id: Research ID to retrieve
        user_id: User's Firebase UID
        
    Returns:
        Research report or None if not found
    """
    try:
        db = get_firestore()
        doc = db.collection('users').document(user_id).collection('research').document(research_id).get()
        if doc.exists:
            return doc.to_dict()
        return None
    except Exception as e:
        print(f"Firestore get error: {e}")
        return None

async def get_user_research_history(user_id: str, limit: int = 20) -> list:
    """
    Get user's research history.
    
    Args:
        user_id: User's Firebase UID
        limit: Max number of records
        
    Returns:
        List of research records
    """
    try:
        db = get_firestore()
        docs = db.collection('users').document(user_id).collection('research')\
            .order_by('created_at', direction=firestore.Query.DESCENDING)\
            .limit(limit).stream()
        
        return [doc.to_dict() for doc in docs]
    except Exception as e:
        print(f"Firestore history error: {e}")
        return []

from pydantic import BaseModel
from typing import List, Optional
from enum import Enum

class ResearchStatus(str, Enum):
    PENDING = "pending"
    ORCHESTRATING = "orchestrating"
    SEARCHING = "searching"
    ANALYZING = "analyzing"
    WRITING = "writing"
    COMPLETED = "completed"
    FAILED = "failed"

class ResearchRequest(BaseModel):
    query: str
    user_id: str
    research_id: Optional[str] = None

class AgentProgress(BaseModel):
    agent_name: str
    status: ResearchStatus
    message: str
    progress_percent: int

class ReportSection(BaseModel):
    title: str
    content: str
    sources: List[str]

class ResearchReport(BaseModel):
    research_id: str
    query: str
    status: ResearchStatus
    sections: List[ReportSection]
    summary: str
    created_at: str
    completed_at: Optional[str] = None

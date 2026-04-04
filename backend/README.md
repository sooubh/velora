# Velora Backend API

FastAPI backend with 4 coordinated AI agents for intelligent web research.

## Architecture

```
FastAPI (Port 8000)
    ├── Orchestrator Agent → Plans research strategy
    ├── Web Search Agent → Searches and summarizes web results  
    ├── Analyzer Agent → Deduplicates and finds patterns
    └── Report Writer Agent → Creates polished documents

Real-time SSE streaming for live progress updates
Firebase Firestore for report persistence
Gemini 2.5 Flash for all AI reasoning
```

## Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment

Create `.env` file (copy from `.env.example`):

```bash
# Required
GEMINI_API_KEY=sk-proj-xxxxxxxxxxxxx
TAVILY_API_KEY=tvly-xxxxxxxxxxxxx

# Firebase
FIREBASE_PROJECT_ID=velora-xxx
FIREBASE_CREDENTIALS_PATH=./firebase-key.json

# Pinecone
PINECONE_API_KEY=pcsk-xxxxxxxxxxxxx
PINECONE_HOST=https://your-index-xxxxxxxx.svc.region.pinecone.io
PINECONE_INDEX=velora-research
PINECONE_NAMESPACE=default
```

### 3. Set Up Firebase

1. Go to Firebase Console → Create project
2. Download service account key
3. Save as `backend/firebase-key.json`

### 4. Get API Keys

**Gemini API:**
- https://aistudio.google.com/
- Get API key from settings

**Tavily API:**
- https://app.tavily.com/
- Create API key from dashboard

**DuckDuckGo Search:**
- No API key required (used as additional/fallback source)

## Running the Server

```bash
cd backend
python main.py
```

Server runs on `http://localhost:8000`

## API Endpoints

### Start Research
```bash
POST /research/start
{
  "query": "Latest developments in quantum computing",
  "user_id": "user123"
}
```

Response:
```json
{
  "research_id": "abc-123-def",
  "status": "started",
  "message": "Research session created..."
}
```

### Stream Progress (SSE)
```bash
GET /research/stream/{research_id}
```

Streams events:
- `status` - Phase updates (orchestration, searching, analyzing, writing)
- `search_complete` - Individual search task results
- `analysis_complete` - Analysis summary
- `report_complete` - Final report
- `error` - Any failures

### Get Final Report
```bash
GET /research/{research_id}
```

Response:
```json
{
  "research_id": "abc-123-def",
  "query": "...",
  "status": "completed",
  "report": {
    "summary": "...",
    "sections": [...]
  }
}
```

## Agent Workflow

1. **Orchestrator** breaks query into 3-5 focused subtasks
2. **Web Search Agent** searches for each subtask in parallel
3. **Analyzer Agent** deduplicates results and finds patterns
4. **Report Writer Agent** creates a professional report with citations

All steps stream real-time progress via SSE.

## File Structure

```
backend/
├── main.py                  # FastAPI app + routes
├── requirements.txt         # Python dependencies
├── .env.example            # Environment template
├── agents/
│   ├── orchestrator.py      # Task planning
│   ├── web_search_agent.py  # Web search
│   ├── analyzer_agent.py    # Pattern finding
│   └── report_writer.py     # Report generation
├── services/
│   ├── gemini_service.py    # Gemini client
│   ├── search_service.py    # Tavily + DuckDuckGo search wrapper
│   └── firebase_service.py  # Firestore wrapper
├── models/
│   └── research_model.py    # Pydantic models
└── utils/
    └── prompt_templates.py  # All Gemini prompts
```

## Notes

- Agents run in serial phases (orchestrate → search → analyze → write)
- Each search task is concurrent within Phase 2
- SSE streaming provides real-time progress to Flutter app
- Firebase stores completed reports for history
- All Gemini calls include retry logic with exponential backoff

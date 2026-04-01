# 🔬 SWARM AI — Complete AI Vibe Coding Build Plan
**Personal Research Assistant | Flutter + FastAPI + Firebase + Gemini**

> This plan is written for AI-agent vibe coding. Every task is small, isolated, and independently buildable. Follow phases in order. Do not skip phases.

---

## 📐 APP OVERVIEW (MVP Scope)

| Item | Detail |
|---|---|
| **App Name** | Swarm AI |
| **Platform** | Flutter Android (MVP) |
| **Backend** | Python FastAPI |
| **Database** | Firebase Firestore |
| **Auth** | Firebase Auth (Google Sign-In) |
| **AI Engine** | Google Gemini 1.5 Flash |
| **Agent Count** | 4 agents (MVP, expandable to 8) |
| **Package Name** | `com.sooubh.swarm-ai` |

### MVP Core Flow
```
User types query → Backend spins up 4 agents → 
Live progress shown in app → Structured report generated → 
User can view + save report
```

### 4 MVP Agents
| Agent | Role |
|---|---|
| **Orchestrator** | Breaks query into sub-tasks, manages agent flow |
| **Web Search Agent** | Searches Google/web for real-time data |
| **Analyzer Agent** | Filters, deduplicates, resolves conflicts |
| **Report Writer Agent** | Writes final structured cited report |

---

## 🗂️ PROJECT STRUCTURE

### Flutter App
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   ├── constants/
│   │   └── api_constants.dart
│   └── utils/
│       └── date_utils.dart
├── features/
│   ├── auth/
│   │   ├── data/firebase_auth_service.dart
│   │   └── presentation/login_screen.dart
│   ├── research/
│   │   ├── data/research_api.dart
│   │   ├── domain/research_model.dart
│   │   └── presentation/
│   │       ├── home_screen.dart
│   │       ├── progress_screen.dart
│   │       └── report_screen.dart
│   └── history/
│       ├── data/history_repository.dart
│       └── presentation/history_screen.dart
└── shared/
    └── widgets/
        ├── agent_card.dart
        ├── loading_shimmer.dart
        └── report_section_card.dart
```

### Python Backend
```
backend/
├── main.py                  # FastAPI app entry
├── requirements.txt
├── .env
├── agents/
│   ├── orchestrator.py      # Main coordinator agent
│   ├── web_search_agent.py  # Live web search
│   ├── analyzer_agent.py    # Filter + deduplicate
│   └── report_writer.py     # Final report generation
├── models/
│   ├── research_request.py
│   └── report_model.py
├── services/
│   ├── gemini_service.py    # Gemini API wrapper
│   ├── firebase_service.py  # Firestore read/write
│   └── search_service.py    # Google Search API
└── utils/
    └── prompt_templates.py  # All Gemini prompts
```

---

## 🔑 ENVIRONMENT SETUP

### Flutter `pubspec.yaml` — Key Packages
```yaml
dependencies:
  flutter_riverpod: ^2.5.0
  go_router: ^13.0.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  google_sign_in: ^6.2.0
  dio: ^5.4.0
  gap: ^3.0.0
  google_fonts: ^6.2.0
  flutter_markdown: ^0.7.0
  lottie: ^3.1.0
  shimmer: ^3.0.0
```

### Python `requirements.txt`
```
fastapi==0.111.0
uvicorn==0.30.0
google-generativeai==0.7.0
firebase-admin==6.5.0
python-dotenv==1.0.0
httpx==0.27.0
pydantic==2.7.0
googlesearch-python==1.2.3
beautifulsoup4==4.12.3
```

### `.env` (Backend)
```
GEMINI_API_KEY=your_key
GOOGLE_SEARCH_API_KEY=your_key
GOOGLE_CSE_ID=your_cse_id
FIREBASE_CREDENTIALS_PATH=./serviceAccount.json
```

---

## 🚀 PHASE 1 — Backend Foundation
> Build the FastAPI skeleton with Firebase connection. No agents yet.

### Task B1 — Create FastAPI App Skeleton
**File:** `backend/main.py`
```
- Create FastAPI app
- Add CORS middleware (allow all origins for dev)
- Add health check route: GET /health → {"status": "ok"}
- Add placeholder POST /research route returning {"job_id": "test123"}
- Run on port 8000
```

### Task B2 — Research Data Models
**File:** `backend/models/research_request.py`
```
Pydantic models:
- ResearchRequest: { query: str, user_id: str }
- AgentStatus: { agent_name: str, status: str, message: str }
- ResearchJob: { job_id: str, query: str, status: str, agents: List[AgentStatus], created_at: datetime }
- ReportSection: { title: str, content: str, sources: List[str] }
- FinalReport: { job_id: str, query: str, sections: List[ReportSection], summary: str, total_sources: int }
```

### Task B3 — Firebase Admin Setup
**File:** `backend/services/firebase_service.py`
```
- Initialize Firebase Admin SDK from serviceAccount.json
- Function: save_job(job_id, job_data) → saves to Firestore /research/{job_id}
- Function: update_job_status(job_id, status, agent_updates) → updates specific fields
- Function: save_report(job_id, report_data) → saves to Firestore /reports/{job_id}
- Function: get_job(job_id) → returns job dict
```

### Task B4 — Gemini Service Wrapper
**File:** `backend/services/gemini_service.py`
```
- Initialize Gemini 1.5 Flash model
- Function: ask(system_prompt: str, user_message: str) → returns str response
- Add retry logic (max 3 retries on failure)
- Add simple logging of each call
```

### Task B5 — Search Service
**File:** `backend/services/search_service.py`
```
- Function: search_web(query: str, num_results: int = 5) → List[{title, url, snippet}]
- Use Google Custom Search API (httpx)
- Fallback: if API fails, use googlesearch-python library
- Function: fetch_page_content(url: str) → str (use httpx + BeautifulSoup, extract main text only, max 2000 chars)
```

---

## 🤖 PHASE 2 — Agent System
> Build each agent as a standalone Python function. Each takes input, calls Gemini, returns structured output.

### Task B6 — Prompt Templates
**File:** `backend/utils/prompt_templates.py`
```python
ORCHESTRATOR_PROMPT = """
You are a research orchestrator. Given a user query, break it into 3-5 specific search sub-queries.
Return ONLY a JSON array of strings. Example: ["query1", "query2", "query3"]
User query: {query}
"""

ANALYZER_PROMPT = """
You are a research analyst. Given raw search results, extract the most relevant facts.
Remove duplicates. Resolve conflicts by noting both sides.
Format as bullet points with source URLs.
Query: {query}
Raw data: {raw_data}
"""

REPORT_WRITER_PROMPT = """
You are a research report writer. Write a structured research report.
Format with these sections: Executive Summary, Key Findings, Detailed Analysis, Conclusion.
Include source citations inline as [Source: URL].
Query: {query}
Analyzed data: {analyzed_data}
"""
```

### Task B7 — Orchestrator Agent
**File:** `backend/agents/orchestrator.py`
```
- Function: run(query: str) → List[str] (list of sub-queries)
- Call gemini_service.ask() with ORCHESTRATOR_PROMPT
- Parse JSON response
- Return 3-5 sub-queries
- On parse failure: return [query] as fallback
```

### Task B8 — Web Search Agent
**File:** `backend/agents/web_search_agent.py`
```
- Function: run(sub_queries: List[str]) → List[{query, results}]
- For each sub-query: call search_service.search_web()
- For top 2 results per query: call search_service.fetch_page_content()
- Return all raw results combined
- Run searches sequentially (no parallel for MVP)
```

### Task B9 — Analyzer Agent
**File:** `backend/agents/analyzer_agent.py`
```
- Function: run(query: str, raw_results: list) → str (analyzed markdown text)
- Convert raw_results to string
- Call gemini_service.ask() with ANALYZER_PROMPT
- Return the analyzed text string
```

### Task B10 — Report Writer Agent
**File:** `backend/agents/report_writer.py`
```
- Function: run(query: str, analyzed_data: str) → dict
- Call gemini_service.ask() with REPORT_WRITER_PROMPT
- Return { summary: str, full_report: str, sections: parsed list }
- Simple section parsing: split by "##" headers
```

### Task B11 — Research Orchestration Pipeline
**File:** `backend/main.py` (update)
```
- POST /research endpoint:
  1. Create job_id (uuid4)
  2. Save initial job to Firestore with status="running"
  3. Run in background (FastAPI BackgroundTasks):
     a. Update status → "agent_1_running" (Orchestrator)
     b. Run orchestrator.run(query) → sub_queries
     c. Update status → "agent_2_running" (Web Search)
     d. Run web_search_agent.run(sub_queries) → raw_results
     e. Update status → "agent_3_running" (Analyzer)
     f. Run analyzer_agent.run(query, raw_results) → analyzed
     g. Update status → "agent_4_running" (Report Writer)
     h. Run report_writer.run(query, analyzed) → report
     i. Save report to Firestore
     j. Update job status → "completed"
  4. Return {"job_id": job_id} immediately

- GET /research/{job_id}/status → return job from Firestore
- GET /research/{job_id}/report → return report from Firestore
```

---

## 📱 PHASE 3 — Flutter App Foundation

### Task F1 — Project Setup
```
- Create Flutter project: flutter create swarm-ai --org com.sooubh
- Add all packages from pubspec.yaml above
- Setup Firebase: flutterfire configure
- Create folder structure as defined above
- Add google-services.json
```

### Task F2 — Theme & Colors
**File:** `lib/core/theme/app_colors.dart` + `app_theme.dart`
```
Colors (Dark theme — premium look):
- Primary: #7C3AED (deep violet)
- Secondary: #06B6D4 (cyan)
- Background: #0F0F1A (near black)
- Surface: #1A1A2E (dark navy)
- Card: #16213E
- Text Primary: #FFFFFF
- Text Secondary: #9CA3AF
- Success: #10B981
- Warning: #F59E0B

Font: Google Fonts Poppins (headings) + Inter (body)
Full dark MaterialTheme with Material 3
```

### Task F3 — API Constants + Dio Setup
**File:** `lib/core/constants/api_constants.dart` + `lib/features/research/data/research_api.dart`
```
- Base URL constant (point to local: http://10.0.2.2:8000 for emulator)
- Dio instance with base options
- Function: startResearch(query, userId) → returns jobId
- Function: getJobStatus(jobId) → returns ResearchJob model
- Function: getReport(jobId) → returns FinalReport model
```

### Task F4 — Firebase Auth Service
**File:** `lib/features/auth/data/firebase_auth_service.dart`
```
- Google Sign-In function → returns User
- Sign out function
- Get current user
- Auth state stream
```

### Task F5 — Data Models (Dart)
**File:** `lib/features/research/domain/research_model.dart`
```dart
class ResearchJob {
  final String jobId;
  final String query;
  final String status; // running, completed, failed
  final DateTime createdAt;
}

class AgentProgress {
  final String agentName;
  final String status; // waiting, running, done
  final String message;
}

class ReportSection {
  final String title;
  final String content;
  final List<String> sources;
}

class FinalReport {
  final String jobId;
  final String query;
  final String summary;
  final List<ReportSection> sections;
  final int totalSources;
}
```

---

## 📱 PHASE 4 — Flutter Screens

### Task F6 — Splash Screen
**File:** `lib/features/auth/presentation/splash_screen.dart`
```
- Full screen dark background with Swarm AI logo (text + icon)
- Check Firebase auth state
- If logged in → go to HomeScreen
- If not → go to LoginScreen
- 2 second delay with fade animation
```

### Task F7 — Login Screen
**File:** `lib/features/auth/presentation/login_screen.dart`
```
- Dark full-screen layout
- Swarm AI logo at top center
- Tagline: "Research powered by AI agents"
- Google Sign-In button (white button, Google icon)
- Loading state during sign-in
- On success → navigate to HomeScreen
- Error snackbar on failure
```

### Task F8 — Home Screen
**File:** `lib/features/research/presentation/home_screen.dart`
```
UI Layout:
- AppBar: "Swarm AI" title + user avatar (top right) with logout option
- Greeting text: "What do you want to research?"
- Large text input field (multiline, max 500 chars) with violet border
- Submit button: "Start Research" (full width, violet gradient)
- Section below: "Recent Research" 
- List of past research from Firestore (user's history)
- Each history item: query text + date + status chip + tap to view report

State:
- Riverpod provider for query text
- Riverpod provider for research history list (stream from Firestore)
- On submit: call API, navigate to ProgressScreen with jobId
```

### Task F9 — Progress Screen
**File:** `lib/features/research/presentation/progress_screen.dart`
```
UI Layout:
- AppBar: "Researching..." + back button
- Query text displayed at top
- 4 Agent Cards in vertical list:
  [Card] 🎯 Orchestrator — "Breaking down your query"
  [Card] 🔍 Web Search Agent — "Searching the web"
  [Card] 🧠 Analyzer Agent — "Analyzing results"
  [Card] ✍️ Report Writer — "Writing your report"

Each card shows:
- Agent name + emoji icon
- Status: Waiting (gray) / Running (cyan pulse animation) / Done (green checkmark)
- Status message text

Logic:
- Poll GET /research/{jobId}/status every 2 seconds
- Map status string to which agent is active
- Status mapping:
  "running" → agent 1 running
  "agent_2_running" → agent 2 running
  "agent_3_running" → agent 3 running  
  "agent_4_running" → agent 4 running
  "completed" → all done → auto-navigate to ReportScreen
  "failed" → show error + retry button
```

### Task F10 — Report Screen
**File:** `lib/features/research/presentation/report_screen.dart`
```
UI Layout:
- AppBar: "Research Report" + share icon
- Summary card at top (violet gradient card, summary text)
- "Key Sections" label
- List of ReportSection cards, each with:
  - Section title (bold)
  - Content text (markdown rendered using flutter_markdown)
  - Sources list (tappable URLs, show in-app webview or open browser)
- Bottom: "Total sources: N" text

State:
- Fetch report on screen init using jobId
- Loading shimmer while fetching
- Error state with retry
```

### Task F11 — Shared Widgets
**Files:** `lib/shared/widgets/`
```
agent_card.dart:
- Takes: agentName, emoji, status (waiting/running/done), message
- Visual: dark card, left border color based on status
- Animated pulsing dot when status = running

loading_shimmer.dart:
- Shimmer effect cards for loading states
- Use shimmer package

report_section_card.dart:
- Card with title + markdown content + sources
```

---

## 🔀 PHASE 5 — Routing & State Management

### Task F12 — Router Setup
**File:** `lib/app/router.dart`
```
GoRouter with these routes:
/ → SplashScreen
/login → LoginScreen
/home → HomeScreen (redirect to /login if not authenticated)
/progress/:jobId → ProgressScreen
/report/:jobId → ReportScreen
/history → HistoryScreen (optional)

Auth redirect: if not logged in and route is not /login → redirect to /login
```

### Task F13 — Riverpod Providers
**File:** create providers inside each feature's presentation folder
```
auth_provider.dart:
- authStateProvider (StreamProvider) → Firebase auth state
- userProvider (derived from authStateProvider)

research_provider.dart:
- researchQueryProvider (StateProvider<String>)
- activeJobIdProvider (StateProvider<String?>)
- jobStatusProvider(jobId) (FutureProvider, auto-refreshes every 2s)
- reportProvider(jobId) (FutureProvider)

history_provider.dart:
- researchHistoryProvider (StreamProvider from Firestore)
```

---

## 💾 PHASE 6 — Firebase Firestore Structure

### Collections
```
/users/{userId}
  - email: string
  - displayName: string
  - createdAt: timestamp

/research/{jobId}
  - userId: string
  - query: string
  - status: string
  - agentStatuses: map
  - createdAt: timestamp
  - completedAt: timestamp (optional)

/reports/{jobId}
  - jobId: string
  - userId: string
  - query: string
  - summary: string
  - sections: array of {title, content, sources}
  - totalSources: number
  - createdAt: timestamp
```

### Task B12 — Firestore Security Rules
```
- Users can only read/write their own /research and /reports documents
- Match by userId field == request.auth.uid
- No public reads
```

---

## 🧪 PHASE 7 — Integration & Testing

### Task T1 — Local Backend Test
```
- Run backend: uvicorn main:app --reload --port 8000
- Test with curl or Postman:
  POST /research {"query": "AI ethics in India", "user_id": "test123"}
  GET /research/{jobId}/status
  GET /research/{jobId}/report
- Verify Firestore gets updated in Firebase console
```

### Task T2 — Flutter + Backend Integration Test
```
- Run Flutter on Android emulator
- Point API to http://10.0.2.2:8000
- Test full flow: Login → Enter query → See progress → View report
- Fix any CORS issues in FastAPI
```

### Task T3 — End-to-End Polish
```
- Add error handling for network failures
- Add empty state for no research history
- Test on real Android device (use ngrok to expose local backend)
- Check all loading states work correctly
```

---

## 🚢 PHASE 8 — Deployment (Optional for MVP)

### Backend Deployment Options
```
Option A (Easiest): Railway.app
- Push to GitHub
- Connect to Railway → auto-deploy Python
- Set env vars in Railway dashboard
- Get public URL → update Flutter API base URL

Option B: Google Cloud Run
- Containerize with Dockerfile
- Deploy to Cloud Run
- Scales to zero when not used
```

### Flutter Release Build
```bash
flutter build apk --release
# or for Play Store:
flutter build appbundle --release
```

---

## 📋 MASTER TASK CHECKLIST

### Backend Tasks (12 tasks)
- [ ] B1 — FastAPI skeleton + health check
- [ ] B2 — Pydantic data models
- [ ] B3 — Firebase Admin service
- [ ] B4 — Gemini service wrapper
- [ ] B5 — Google Search service
- [ ] B6 — Prompt templates
- [ ] B7 — Orchestrator agent
- [ ] B8 — Web Search agent
- [ ] B9 — Analyzer agent
- [ ] B10 — Report Writer agent
- [ ] B11 — Full research pipeline in FastAPI
- [ ] B12 — Firestore security rules

### Flutter Tasks (13 tasks)
- [ ] F1 — Project setup + Firebase config
- [ ] F2 — Theme + colors + fonts
- [ ] F3 — API constants + Dio client
- [ ] F4 — Firebase Auth service
- [ ] F5 — Dart data models
- [ ] F6 — Splash screen
- [ ] F7 — Login screen
- [ ] F8 — Home screen
- [ ] F9 — Progress screen (with agent cards)
- [ ] F10 — Report screen
- [ ] F11 — Shared widgets (agent_card, shimmer, report_card)
- [ ] F12 — GoRouter setup
- [ ] F13 — Riverpod providers

### Testing Tasks (3 tasks)
- [ ] T1 — Backend curl tests
- [ ] T2 — Flutter + backend integration
- [ ] T3 — Polish + error handling

**Total: 28 small tasks → Complete MVP Swarm AI App**

---

## ⚡ QUICK START ORDER FOR AI AGENT

```
1. B1 → B2 → B3 → B4 → B5 (infrastructure)
2. B6 → B7 → B8 → B9 → B10 (agents)
3. B11 → B12 (pipeline + rules)
4. F1 → F2 → F3 → F4 → F5 (flutter setup)
5. F6 → F7 → F8 (auth + home)
6. F11 → F9 → F10 (widgets + research screens)
7. F12 → F13 (routing + state)
8. T1 → T2 → T3 (testing)
```

---

## 🎯 MVP SUCCESS CRITERIA

| Feature | Must Work |
|---|---|
| Google Sign-In | ✅ |
| Enter research query | ✅ |
| See 4 agents working in real-time | ✅ |
| View structured report | ✅ |
| Save report history | ✅ |
| Dark theme, clean UI | ✅ |
| Works on Android | ✅ |

**OUT OF SCOPE FOR MVP:** Voice input, multilingual, PDF export, collaborative research, iOS build, Pinecone vector DB

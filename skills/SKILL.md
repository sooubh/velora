---
name: velora-app
description: >
  Complete AI agent skill for building Velora — a Personal Research Assistant Swarm app.
  Use this skill for EVERY task in the Velora build: backend Python/FastAPI, agent pipeline,
  Flutter screens, Firebase integration, SSE streaming, and Gemini AI calls.
  Always read this file before writing any Velora code.
---

# Velora App Skill
**Stack: Flutter + FastAPI + Firebase + Gemini 2.5 Flash**
**Package: com.sooubh.velora | State: Riverpod | Backend port: 8000**

---

## GEMINI AI — Correct SDK (2025)

> ⚠️ `google-generativeai` is DEPRECATED. Use the new unified SDK: `google-genai`

```bash
pip install google-genai
```

```python
# CORRECT — New unified SDK
from google import genai

client = genai.Client(api_key='GEMINI_API_KEY')  # or set env var GEMINI_API_KEY

response = client.models.generate_content(
    model='gemini-2.5-flash',
    contents='Your prompt here'
)
print(response.text)
```

### With system prompt (for agents):
```python
from google import genai
from google.genai import types

client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])

response = client.models.generate_content(
    model='gemini-2.5-flash',
    config=types.GenerateContentConfig(
        system_instruction='You are a research orchestrator...',
    ),
    contents='User query here'
)
return response.text
```

### Gemini service wrapper (copy this exactly):
```python
# backend/services/gemini_service.py
import os
from google import genai
from google.genai import types

_client = None

def get_client():
    global _client
    if _client is None:
        _client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])
    return _client

async def ask(system_prompt: str, user_message: str, retries: int = 3) -> str:
    for attempt in range(retries):
        try:
            response = get_client().models.generate_content(
                model='gemini-2.5-flash',
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                ),
                contents=user_message
            )
            return response.text
        except Exception as e:
            if attempt == retries - 1:
                raise
            await asyncio.sleep(1)
```

---

## FASTAPI — Agent Pipeline with SSE Streaming

> Real-time agent progress uses SSE (Server-Sent Events), NOT polling. SSE is cleaner for agent status.

```bash
pip install fastapi uvicorn sse-starlette
```

### SSE endpoint pattern for agent progress:
```python
# backend/main.py
import asyncio
import uuid
from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory job store (Firestore is the persistent store)
job_queues: dict[str, asyncio.Queue] = {}

@app.post("/research")
async def start_research(request: ResearchRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())
    job_queues[job_id] = asyncio.Queue()
    
    # Save initial job to Firestore
    await firebase_service.save_job(job_id, {
        "userId": request.user_id,
        "query": request.query,
        "status": "running",
        "createdAt": datetime.utcnow().isoformat()
    })
    
    # Run pipeline in background — returns job_id immediately
    background_tasks.add_task(run_pipeline, job_id, request.query, request.user_id)
    return {"job_id": job_id}

@app.get("/research/{job_id}/stream")
async def stream_progress(job_id: str):
    """SSE endpoint — Flutter listens to this for live agent updates"""
    async def event_generator():
        queue = job_queues.get(job_id)
        if not queue:
            yield {"event": "error", "data": json.dumps({"message": "Job not found"})}
            return
        while True:
            try:
                event = await asyncio.wait_for(queue.get(), timeout=30.0)
                yield {"event": event["type"], "data": json.dumps(event["data"])}
                if event["type"] == "completed" or event["type"] == "failed":
                    break
            except asyncio.TimeoutError:
                yield {"event": "ping", "data": "{}"}  # Keep-alive
    return EventSourceResponse(event_generator())

@app.get("/research/{job_id}/report")
async def get_report(job_id: str):
    return await firebase_service.get_report(job_id)

async def run_pipeline(job_id: str, query: str, user_id: str):
    """Background pipeline — pushes SSE events as each agent finishes"""
    queue = job_queues[job_id]
    try:
        # Agent 1: Orchestrator
        await queue.put({"type": "agent_update", "data": {"agent": "orchestrator", "status": "running", "message": "Breaking down your query..."}})
        sub_queries = await orchestrator.run(query)

        # Agent 2: Web Search
        await queue.put({"type": "agent_update", "data": {"agent": "orchestrator", "status": "done", "message": "Done"}})
        await queue.put({"type": "agent_update", "data": {"agent": "web_search", "status": "running", "message": "Searching the web..."}})
        raw_results = await web_search_agent.run(sub_queries)

        # Agent 3: Analyzer
        await queue.put({"type": "agent_update", "data": {"agent": "web_search", "status": "done", "message": "Done"}})
        await queue.put({"type": "agent_update", "data": {"agent": "analyzer", "status": "running", "message": "Analyzing results..."}})
        analyzed = await analyzer_agent.run(query, raw_results)

        # Agent 4: Report Writer
        await queue.put({"type": "agent_update", "data": {"agent": "analyzer", "status": "done", "message": "Done"}})
        await queue.put({"type": "agent_update", "data": {"agent": "report_writer", "status": "running", "message": "Writing your report..."}})
        report = await report_writer.run(query, analyzed)

        # Save report to Firestore
        await firebase_service.save_report(job_id, {**report, "userId": user_id, "query": query})
        await firebase_service.update_job_status(job_id, "completed")

        await queue.put({"type": "completed", "data": {"job_id": job_id}})

    except Exception as e:
        await firebase_service.update_job_status(job_id, "failed")
        await queue.put({"type": "failed", "data": {"error": str(e)}})
    finally:
        # Cleanup queue after 5 min
        await asyncio.sleep(300)
        job_queues.pop(job_id, None)
```

### requirements.txt (exact versions that work):
```
fastapi==0.111.0
uvicorn==0.30.0
sse-starlette==2.1.0
google-genai==0.8.0
firebase-admin==6.5.0
python-dotenv==1.0.0
httpx==0.27.0
pydantic==2.7.0
googlesearch-python==1.2.3
beautifulsoup4==4.12.3
```

### Run command:
```bash
uvicorn main:app --reload --port 8000 --host 0.0.0.0
```

---

## FIREBASE ADMIN (Python Backend)

```python
# backend/services/firebase_service.py
import firebase_admin
from firebase_admin import credentials, firestore
import asyncio

_db = None

def init_firebase():
    global _db
    if not firebase_admin._apps:
        cred = credentials.Certificate('./serviceAccount.json')
        firebase_admin.initialize_app(cred)
    _db = firestore.client()

def get_db():
    if _db is None:
        init_firebase()
    return _db

async def save_job(job_id: str, data: dict):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, lambda: get_db().collection('research').document(job_id).set(data))

async def update_job_status(job_id: str, status: str):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, lambda: get_db().collection('research').document(job_id).update({'status': status}))

async def save_report(job_id: str, report: dict):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, lambda: get_db().collection('reports').document(job_id).set(report))

async def get_report(job_id: str) -> dict:
    loop = asyncio.get_event_loop()
    doc = await loop.run_in_executor(None, lambda: get_db().collection('reports').document(job_id).get())
    return doc.to_dict() if doc.exists else {}
```

> ⚠️ Firestore Admin SDK is sync. Always wrap in `run_in_executor` for async FastAPI routes.

---

## FLUTTER — SSE Client for Agent Progress

> Use `flutter_client_sse` package — best for Android + iOS SSE with auth headers.

```yaml
# pubspec.yaml
dependencies:
  flutter_client_sse: ^0.0.9
  # OR use flutter_http_sse for more control:
  flutter_http_sse: ^1.0.0
```

### SSE stream in Riverpod (research_provider.dart):
```dart
import 'dart:convert';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Streams agent progress events from backend
final agentProgressProvider = StreamProvider.family<AgentEvent, String>((ref, jobId) {
  final token = ref.watch(authTokenProvider).value ?? '';
  
  return SSEClient.subscribeToSSE(
    method: SSERequestType.GET,
    url: '${ApiConstants.baseUrl}/research/$jobId/stream',
    header: {
      'Authorization': 'Bearer $token',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    },
  ).map((event) {
    final data = jsonDecode(event.data ?? '{}');
    return AgentEvent.fromJson(data);
  });
});
```

### AgentEvent model:
```dart
// lib/features/research/domain/research_model.dart

enum AgentStatus { waiting, running, done, failed }

class AgentEvent {
  final String agent;  // orchestrator | web_search | analyzer | report_writer
  final AgentStatus status;
  final String message;

  AgentEvent({required this.agent, required this.status, required this.message});

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      agent: json['agent'] ?? '',
      status: _parseStatus(json['status']),
      message: json['message'] ?? '',
    );
  }

  static AgentStatus _parseStatus(String? s) {
    switch (s) {
      case 'running': return AgentStatus.running;
      case 'done': return AgentStatus.done;
      case 'failed': return AgentStatus.failed;
      default: return AgentStatus.waiting;
    }
  }
}
```

---

## FLUTTER — Firebase + Riverpod Patterns

### Auth provider:
```dart
// lib/features/auth/data/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authTokenProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  return user?.getIdToken();
});
```

### Firestore history stream (user's past research):
```dart
// lib/features/history/data/history_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final researchHistoryProvider = StreamProvider<List<ResearchJob>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('research')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ResearchJob.fromFirestore(doc))
          .toList());
});
```

### Always handle AsyncValue in UI:
```dart
// In any ConsumerWidget build():
final history = ref.watch(researchHistoryProvider);

return history.when(
  data: (jobs) => ListView.builder(...),
  loading: () => const LoadingShimmer(),
  error: (e, _) => ErrorWidget(message: e.toString(), onRetry: () => ref.refresh(researchHistoryProvider)),
);
```

---

## FLUTTER — Progress Screen (Core Screen)

```dart
// lib/features/research/presentation/progress_screen.dart
class ProgressScreen extends ConsumerStatefulWidget {
  final String jobId;
  const ProgressScreen({required this.jobId});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final Map<String, AgentStatus> _agentStatuses = {
    'orchestrator': AgentStatus.waiting,
    'web_search': AgentStatus.waiting,
    'analyzer': AgentStatus.waiting,
    'report_writer': AgentStatus.waiting,
  };

  @override
  Widget build(BuildContext context) {
    // Listen to SSE stream
    ref.listen(agentProgressProvider(widget.jobId), (_, next) {
      next.whenData((event) {
        setState(() => _agentStatuses[event.agent] = event.status);
        
        // Auto-navigate when complete
        if (event.agent == 'report_writer' && event.status == AgentStatus.done) {
          Future.delayed(const Duration(milliseconds: 500), () {
            context.go('/report/${widget.jobId}');
          });
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Researching...')),
      body: Column(
        children: [
          AgentCard(name: '🎯 Orchestrator', status: _agentStatuses['orchestrator']!),
          AgentCard(name: '🔍 Web Search', status: _agentStatuses['web_search']!),
          AgentCard(name: '🧠 Analyzer', status: _agentStatuses['analyzer']!),
          AgentCard(name: '✍️ Report Writer', status: _agentStatuses['report_writer']!),
        ],
      ),
    );
  }
}
```

---

## FLUTTER — pubspec.yaml (Complete)

```yaml
name: velora
description: Personal Research Assistant powered by AI agents
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  # Firebase
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.0
  cloud_firestore: ^5.2.0
  google_sign_in: ^6.2.1
  # State Management
  flutter_riverpod: ^2.5.1
  # Navigation
  go_router: ^14.2.0
  # Networking
  dio: ^5.4.3
  flutter_client_sse: ^0.0.9
  # UI
  google_fonts: ^6.2.1
  gap: ^3.0.1
  shimmer: ^3.0.0
  lottie: ^3.1.2
  flutter_markdown: ^0.7.3
  # Utils
  shared_preferences: ^2.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## FLUTTER — Theme (Copy Exactly)

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFF7C3AED);   // Violet
  static const secondaryColor = Color(0xFF06B6D4); // Cyan
  static const bgColor = Color(0xFF0F0F1A);        // Near black
  static const surfaceColor = Color(0xFF1A1A2E);   // Dark navy
  static const cardColor = Color(0xFF16213E);      // Card bg
  static const successColor = Color(0xFF10B981);
  static const errorColor = Color(0xFFEF4444);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: bgColor,
    cardColor: cardColor,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  );
}
```

---

## API CONSTANTS

```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  // Emulator: 10.0.2.2 | Real device: your LAN IP | Production: Railway URL
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  static String researchEndpoint = '$baseUrl/research';
  static String streamEndpoint(String jobId) => '$baseUrl/research/$jobId/stream';
  static String reportEndpoint(String jobId) => '$baseUrl/research/$jobId/report';
}
```

---

## FIRESTORE SECURITY RULES

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /research/{jobId} {
      allow read, write: if request.auth != null && 
        (resource == null || resource.data.userId == request.auth.uid);
    }
    match /reports/{jobId} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow write: if false; // Only backend writes reports
    }
  }
}
```

---

## COMMON PITFALLS — MUST AVOID

| Pitfall | Fix |
|---|---|
| Using `google-generativeai` (deprecated) | Use `google-genai` package |
| Firestore Admin sync calls blocking async FastAPI | Wrap in `run_in_executor` |
| Polling for agent status instead of SSE | Use SSE stream endpoint |
| Calling `get_client()` on every Gemini call | Singleton client with lazy init |
| Flutter SSE with Dio (doesn't work for SSE) | Use `flutter_client_sse` package |
| Missing CORS on FastAPI | Add `CORSMiddleware` allow_origins=["*"] |
| `10.0.2.2` for real device testing | Use LAN IP like `192.168.x.x` |
| Riverpod `ref.watch` in async functions | Use `ref.read` inside callbacks/async |
| Not disposing SSE stream | Use `ref.onDispose()` to cancel subscription |

---

## TESTING COMMANDS

```bash
# Backend health check
curl http://localhost:8000/health

# Start research job
curl -X POST http://localhost:8000/research \
  -H "Content-Type: application/json" \
  -d '{"query": "AI ethics in India", "user_id": "test123"}'

# Listen to SSE stream (replace JOB_ID)
curl -N http://localhost:8000/research/JOB_ID/stream

# Get report
curl http://localhost:8000/research/JOB_ID/report

# Flutter run on emulator
flutter run -d emulator-5554

# Expose local backend to real device (install ngrok)
ngrok http 8000
# Then update ApiConstants.baseUrl with the ngrok URL
```

---

## BUILD ORDER FOR AI AGENT

```
PHASE 1 — Backend Core
  backend/main.py (skeleton + CORS + health)
  backend/models/research_request.py
  backend/services/firebase_service.py
  backend/services/gemini_service.py
  backend/services/search_service.py

PHASE 2 — Agents
  backend/utils/prompt_templates.py
  backend/agents/orchestrator.py
  backend/agents/web_search_agent.py
  backend/agents/analyzer_agent.py
  backend/agents/report_writer.py

PHASE 3 — Wire Pipeline
  backend/main.py (add SSE + pipeline)
  firestore.rules

PHASE 4 — Flutter Foundation
  pubspec.yaml
  lib/main.dart
  lib/core/theme/app_theme.dart
  lib/core/constants/api_constants.dart
  lib/features/auth/data/ (Firebase auth)
  lib/features/research/domain/ (models)

PHASE 5 — Flutter Screens
  lib/features/auth/presentation/splash_screen.dart
  lib/features/auth/presentation/login_screen.dart
  lib/shared/widgets/ (agent_card, shimmer, report_card)
  lib/features/research/presentation/home_screen.dart
  lib/features/research/presentation/progress_screen.dart
  lib/features/research/presentation/report_screen.dart

PHASE 6 — State + Routing
  lib/app/router.dart (GoRouter)
  lib/features/auth/data/auth_provider.dart
  lib/features/research/data/research_provider.dart
  lib/features/history/data/history_provider.dart
```

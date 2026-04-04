"""
Velora FastAPI Backend - Research Swarm Orchestrator
Coordinates 4 AI agents for intelligent web research with real-time SSE streaming.
"""
import os
import uuid
import asyncio
import json
import traceback
from datetime import datetime
from typing import AsyncGenerator, Optional
from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sse_starlette.sse import EventSourceResponse
import uvicorn

# Load environment variables
load_dotenv()

# Import agents and services
from agents.orchestrator import OrchestratorAgent
from agents.search_agent import SearchAgent
from agents.literature_agent import LiteratureAgent
from agents.wikipedia_agent import WikipediaAgent
from agents.news_agent import NewsAgent
from agents.discussion_agent import DiscussionAgent
from agents.analyzer_agent import AnalyzerAgent
from agents.conflict_resolver_agent import ConflictResolverAgent
from agents.synthesis_agent import SynthesisAgent
from agents.coherence_scorer_agent import CoherenceScorerAgent
from services.firebase_service import save_research, get_research
from services.search_service import get_search_provider_status
from services.pinecone_service import get_pinecone_status, upsert_evidence_chunks, query_evidence
from models.research_model import ResearchRequest, ResearchReport, ResearchStatus

# Initialize FastAPI
app = FastAPI(
    title="Velora Research API",
    description="AI-powered research swarm with 4 agents",
    version="1.0.0"
)

DEBUG_MODE = os.environ.get("DEBUG", "false").lower() == "true"
SERVER_PORT = int(os.environ.get("PORT", 8000))

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize agents
orchestrator = OrchestratorAgent()
search_agent = SearchAgent()
literature_agent = LiteratureAgent()
wikipedia_agent = WikipediaAgent()
news_agent = NewsAgent()
discussion_agent = DiscussionAgent()
analyzer = AnalyzerAgent()
conflict_resolver = ConflictResolverAgent()
synthesis_agent = SynthesisAgent()
coherence_scorer = CoherenceScorerAgent()

# In-memory session storage (for dev; replace with Redis in production)
active_sessions = {}


def _build_agent_progress(phase: str, phase_message: str, status: str, error_message: Optional[str] = None):
    """Create per-agent progress payload for UI status cards."""
    order = [
        ("Orchestrator", "orchestration"),
        ("Specialist Agents", "searching"),
        ("Analyzer Agent", "analyzing"),
        ("Conflict Resolver", "resolving"),
        ("Synthesis Agent", "synthesis"),
        ("Coherence Scorer", "coherence"),
    ]

    phase_index = {name: idx for idx, (_, name) in enumerate(order)}.get(phase, -1)
    phase_messages = {
        "orchestration": "Planning research strategy",
        "searching": "Searching and summarizing sources",
        "analyzing": "Analyzing evidence and conflicts",
        "resolving": "Resolving source contradictions",
        "synthesis": "Synthesizing final report",
        "coherence": "Checking report coherence",
        "completed": "Finished",
        "failed": "Stopped due to error",
    }

    agents = []
    for idx, (agent_name, agent_phase) in enumerate(order):
        if status == ResearchStatus.COMPLETED or str(status) == "completed":
            agent_status = "done"
        elif phase_index > idx:
            agent_status = "done"
        elif phase_index == idx and str(status) not in {"failed", ResearchStatus.FAILED}:
            agent_status = "running"
        else:
            agent_status = "waiting"

        msg = phase_messages.get(agent_phase, "Waiting")
        if phase == agent_phase and phase_message:
            msg = phase_message
        if (status == ResearchStatus.FAILED or str(status) == "failed") and phase == agent_phase and error_message:
            msg = f"Failed: {error_message}"

        agents.append({
            "agent_name": agent_name,
            "status": agent_status,
            "message": msg,
        })

    return agents

class ResearchResponse(BaseModel):
    research_id: str
    status: str
    message: str

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    payload = {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "service": "velora-backend",
        "port": SERVER_PORT,
        "debug": DEBUG_MODE,
        "search": get_search_provider_status(),
        "pinecone": get_pinecone_status(),
    }
    if DEBUG_MODE:
        print(f"[DEBUG] /health status=ok port={SERVER_PORT}")
    return payload

@app.post("/research/start")
async def start_research(request: ResearchRequest) -> ResearchResponse:
    """
    Start a new research request.
    Returns research_id to stream progress with.
    
    Args:
        request: ResearchRequest with query and user_id
        
    Returns:
        research_id for SSE streaming
    """
    research_id = request.research_id or str(uuid.uuid4())
    
    # Create session
    active_sessions[research_id] = {
        "created_at": datetime.now().isoformat(),
        "query": request.query,
        "user_id": request.user_id,
        "status": ResearchStatus.PENDING,
        "phase": "pending",
        "message": "Research request accepted",
        "events": [],
        "running": False,
        "progress": 0,
        "report": None,
        "error": None,
        "debug_report": {
            "started_at": datetime.now().isoformat(),
            "steps": [],
            "errors": []
        }
    }

    # Start processing immediately so clients polling /research/{id} can see progress
    # without requiring an active SSE connection.
    asyncio.create_task(_run_research_pipeline(research_id))
    
    return ResearchResponse(
        research_id=research_id,
        status="started",
        message="Research session created and processing started."
    )


def _append_event(session: dict, event_type: str, data: dict):
    """Store events so SSE clients can replay and follow live progress."""
    session["events"].append({"type": event_type, "data": data, "ts": datetime.now().isoformat()})


async def _run_research_pipeline(research_id: str):
    session = active_sessions.get(research_id)
    if not session:
        return

    if session.get("running") or session.get("status") in {ResearchStatus.COMPLETED, ResearchStatus.FAILED}:
        return

    session["running"] = True
    query = session['query']
    user_id = session['user_id']

    def _track_step(phase: str, message: str, progress: int, metadata: Optional[dict] = None):
        session['status'] = phase
        session['phase'] = phase
        session['message'] = message
        session['progress'] = progress
        payload = {
            "phase": phase,
            "message": message,
            "progress": progress
        }
        session['debug_report']['steps'].append({
            "timestamp": datetime.now().isoformat(),
            **payload,
            "metadata": metadata or {}
        })
        _append_event(session, "status", payload)

    try:
        # === PHASE 1: ORCHESTRATION ===
        _track_step("orchestration", "Planning research strategy...", 10)

        try:
            plan_result = await asyncio.wait_for(orchestrator.plan_research(query), timeout=45)
        except asyncio.TimeoutError:
            plan_result = {
                "success": False,
                "error": "Orchestrator timeout",
                "fallback_plan": {
                    "main_topic": query,
                    "subtasks": [
                        {
                            "id": 1,
                            "task": f"Search for general information about {query}",
                            "keywords": query.split()[:3]
                        }
                    ],
                    "analysis_focus": f"Key insights and trends about {query}",
                    "final_output_format": "Executive summary with key findings"
                }
            }

        if plan_result.get('success'):
            plan = plan_result['plan']
        else:
            plan = plan_result.get('fallback_plan')
            if not plan:
                raise Exception(plan_result.get('error', 'Orchestration failed'))

        assignments = await orchestrator.coordinate_agents(plan)
        _track_step(
            "orchestration",
            "Research plan prepared",
            20,
            {"task_count": len(assignments['web_search_tasks'])}
        )

        # === PHASE 2: SPECIALIST AGENTS (PARALLEL) ===
        _track_step("searching", "Running specialist agents in parallel...", 30)

        specialist_specs = [
            ("Search Agent", search_agent.run(query)),
            ("Literature Agent", literature_agent.run(query)),
            ("Wikipedia Agent", wikipedia_agent.run(query)),
            ("News Agent", news_agent.run(query)),
            ("Discussion Agent", discussion_agent.run(query)),
        ]

        specialist_results = []
        pending_tasks = {
            asyncio.create_task(coro): agent_name
            for agent_name, coro in specialist_specs
        }

        completed_count = 0
        total_specialists = len(pending_tasks)

        for completed in asyncio.as_completed(list(pending_tasks.keys())):
            agent_name = pending_tasks[completed]
            result = await completed
            completed_count += 1

            if result.get('success'):
                specialist_results.append(result)
            _append_event(session, "specialist_complete", {
                "agent": agent_name,
                "success": result.get('success', False),
                "result_count": result.get('result_count', 0),
                "error": result.get('error'),
            })

            progress = 30 + completed_count / max(total_specialists, 1) * 30
            _track_step(
                "searching",
                f"Completed specialist {completed_count}/{total_specialists}: {agent_name}",
                int(progress),
                {
                    "agent": agent_name,
                    "search_success": result.get('success', False),
                    "search_error": result.get('error'),
                }
            )

        # Persist specialist evidence to Pinecone vector memory (best-effort).
        evidence_chunks = []
        for result in specialist_results:
            agent_name = result.get("agent_name", "Specialist")
            raw_rows = result.get("raw_results", []) or []
            if raw_rows:
                for row in raw_rows[:6]:
                    evidence_chunks.append(
                        {
                            "agent": agent_name,
                            "title": row.get("title", ""),
                            "url": row.get("url", ""),
                            "source": row.get("source", ""),
                            "text": row.get("description", row.get("content", "")),
                        }
                    )
            else:
                evidence_chunks.append(
                    {
                        "agent": agent_name,
                        "title": f"{agent_name} summary",
                        "url": "",
                        "source": agent_name,
                        "text": result.get("summary", ""),
                    }
                )

        pinecone_upsert = await upsert_evidence_chunks(
            research_id=research_id,
            chunks=[c for c in evidence_chunks if str(c.get("text", "")).strip()],
        )
        _append_event(session, "vector_memory_upsert", pinecone_upsert)

        # === PHASE 3: ANALYSIS ===
        _track_step("analyzing", "Analyzing and synthesizing results...", 60)

        combined_results = "\n\n---\n\n".join([
            f"[{s.get('agent_name', 'Specialist')}]\n{s.get('summary', '')}"
            for s in specialist_results
            if s.get('summary')
        ])

        if not combined_results.strip():
            combined_results = "No specialist data available. Please use fallback analysis."

        # Retrieve nearest evidence from Pinecone to strengthen analysis context.
        pinecone_query = await query_evidence(
            query_text=query,
            research_id=research_id,
            top_k=8,
        )
        _append_event(session, "vector_memory_query", {
            "success": pinecone_query.get("success", False),
            "matches": len(pinecone_query.get("matches", [])),
            "reason": pinecone_query.get("reason"),
        })

        memory_context = ""
        if pinecone_query.get("success") and pinecone_query.get("matches"):
            lines = []
            for idx, match in enumerate(pinecone_query.get("matches", [])[:8], 1):
                metadata = match.get("metadata", {}) if isinstance(match, dict) else {}
                lines.append(
                    f"{idx}. [{metadata.get('agent', 'Unknown')}] "
                    f"{metadata.get('title', '')}\n"
                    f"   Source: {metadata.get('url', '')}\n"
                    f"   Text: {metadata.get('text', '')}"
                )
            memory_context = "\n\nPINECONE MEMORY CONTEXT\n" + "\n\n".join(lines)

        analysis_input = combined_results + memory_context

        analysis_result = await analyzer.analyze(
            query=query,
            search_results=analysis_input,
            analysis_focus=assignments['analysis_focus']
        )

        if analysis_result.get('warning'):
            _track_step(
                "analyzing",
                "Analyzer returned fallback output",
                68,
                {"warning": analysis_result.get('warning')}
            )

        _track_step(
            "analyzing",
            "Analysis complete",
            70,
            {
                "insights_count": len(analysis_result['analysis'].get('insights', [])),
                "conflicts_count": len(analysis_result['analysis'].get('conflicts', []))
            }
        )
        _append_event(session, "analysis_complete", {
            "insights_count": len(analysis_result['analysis'].get('insights', [])),
            "conflicts_count": len(analysis_result['analysis'].get('conflicts', [])),
            "consensus": analysis_result['analysis'].get('credible_consensus', '')[:200]
        })

        # === PHASE 3.5: CONFLICT RESOLUTION ===
        _track_step("resolving", "Resolving source conflicts and ranking credibility...", 73)

        raw_sources = []
        for result in specialist_results:
            raw_sources.extend(result.get('raw_results', []))

        conflict_result = await conflict_resolver.resolve(
            query=query,
            analysis=analysis_result.get('analysis', {}),
            raw_sources=raw_sources,
            pinecone_matches=pinecone_query.get('matches', []),
        )

        resolved_analysis = {
            **analysis_result.get('analysis', {}),
            "conflict_resolution": conflict_result.get('resolved', {}),
        }

        _append_event(session, "conflict_resolved", {
            "success": conflict_result.get("success", False),
            "warning": conflict_result.get("warning"),
            "resolved_conflicts": len(
                conflict_result.get("resolved", {}).get("resolved_conflicts", [])
            ),
            "ranked_sources": len(
                conflict_result.get("resolved", {}).get("source_rankings", [])
            ),
        })

        # === PHASE 4: SYNTHESIS ===
        _track_step("synthesis", "Synthesizing final report...", 80)

        report_result = await synthesis_agent.synthesize(
            query=query,
            analysis=resolved_analysis,
            raw_sources=raw_sources
        )

        if not report_result.get('success'):
            report_error = report_result.get('error', 'Synthesis failed')
            _track_step(
                "synthesis",
                "Synthesis failed, using fallback report",
                85,
                {"error": report_error}
            )
            report_result = {
                "success": True,
                "query": query,
                "raw_report": "",
                "sections": [],
                "summary": f"Report fallback used because synthesis failed: {report_error}"
            }

        # === PHASE 5: COHERENCE GATE ===
        _track_step("coherence", "Scoring coherence and quality gate...", 90)
        coherence_threshold = float(os.environ.get("COHERENCE_THRESHOLD", "90"))
        first_score = await coherence_scorer.score(
            query=query,
            report_text=report_result.get("raw_report", "") or report_result.get("summary", ""),
        )

        retry_used = False
        final_score = first_score

        if float(first_score.get("score", 0.0)) < coherence_threshold:
            retry_used = True
            _append_event(session, "coherence_retry", {
                "reason": "score_below_threshold",
                "first_score": first_score.get("score", 0.0),
                "threshold": coherence_threshold,
            })

            retry_guidance = (
                "Improve structure and consistency. Address these gaps: "
                + ", ".join(first_score.get("gaps", [])[:5])
            )

            retry_report = await synthesis_agent.synthesize(
                query=query,
                analysis=resolved_analysis,
                raw_sources=raw_sources,
                additional_guidance=retry_guidance,
            )

            if retry_report.get("success"):
                retry_score = await coherence_scorer.score(
                    query=query,
                    report_text=retry_report.get("raw_report", "") or retry_report.get("summary", ""),
                )

                if float(retry_score.get("score", 0.0)) >= float(first_score.get("score", 0.0)):
                    report_result = retry_report
                    final_score = retry_score
                else:
                    final_score = first_score

        coherence_passed = float(final_score.get("score", 0.0)) >= coherence_threshold
        _append_event(session, "coherence_scored", {
            "passed": coherence_passed,
            "score": final_score.get("score", 0.0),
            "threshold": coherence_threshold,
            "retry_used": retry_used,
        })

        report_data = {
            "query": query,
            "status": ResearchStatus.COMPLETED,
            "summary": report_result['summary'],
            "specialist_outputs": [
                {
                    "agent": r.get("agent_name", "Unknown Agent"),
                    "result_count": r.get("result_count", 0),
                    "success": r.get("success", False),
                }
                for r in specialist_results
            ],
            "vector_memory": {
                "upsert": pinecone_upsert,
                "query": {
                    "success": pinecone_query.get("success", False),
                    "matches": len(pinecone_query.get("matches", [])),
                    "reason": pinecone_query.get("reason"),
                },
            },
            "conflict_resolution": {
                "success": conflict_result.get("success", False),
                "warning": conflict_result.get("warning"),
                "resolved_conflicts": len(
                    conflict_result.get("resolved", {}).get("resolved_conflicts", [])
                ),
                "ranked_sources": len(
                    conflict_result.get("resolved", {}).get("source_rankings", [])
                ),
                "details": conflict_result.get("resolved", {}),
            },
            "coherence": {
                "threshold": coherence_threshold,
                "passed": coherence_passed,
                "retry_used": retry_used,
                "score": final_score.get("score", 0.0),
                "feedback": final_score.get("feedback", ""),
                "gaps": final_score.get("gaps", []),
            },
            "sections": [
                {
                    "title": s.title,
                    "content": s.content,
                    "sources": s.sources
                }
                for s in report_result['sections']
            ],
            "created_at": datetime.now().isoformat(),
            "completed_at": datetime.now().isoformat()
        }

        await save_research(research_id, user_id, query, report_data)
        _track_step(
            "coherence",
            "Report complete",
            96,
            {"sections": len(report_result['sections'])}
        )
        _append_event(session, "report_complete", {
            "sections": len(report_result['sections']),
            "summary": report_result['summary']
        })

        # === COMPLETION ===
        _track_step("completed", "Research complete!", 100)

        session['report'] = report_result
        session['status'] = ResearchStatus.COMPLETED
        session['debug_report']['completed_at'] = datetime.now().isoformat()

    except Exception as e:
        print(f"Pipeline error: {e}")
        trace = traceback.format_exc()
        error_payload = {
            "timestamp": datetime.now().isoformat(),
            "message": str(e),
            "error_type": type(e).__name__,
            "traceback": trace
        }
        session['error'] = error_payload
        session['debug_report']['errors'].append(error_payload)
        session['debug_report']['failed_at'] = datetime.now().isoformat()
        session['status'] = ResearchStatus.FAILED
        session['phase'] = session.get('phase', 'failed')
        session['message'] = f"Research failed: {str(e)}"
        _append_event(session, "error", {
            "message": f"Research failed: {str(e)}",
            "error_type": type(e).__name__,
            "debug_report": session['debug_report']
        })
    finally:
        session['running'] = False

@app.get("/research/stream/{research_id}")
async def stream_research(research_id: str) -> EventSourceResponse:
    """
    Stream research progress via Server-Sent Events (SSE).
    
    Args:
        research_id: Research session ID
        
    Returns:
        SSE stream of progress updates
    """
    if research_id not in active_sessions:
        raise HTTPException(status_code=404, detail="Research session not found")
    
    async def event_generator() -> AsyncGenerator:
        session = active_sessions[research_id]

        if not session.get("running") and session.get("status") == ResearchStatus.PENDING:
            asyncio.create_task(_run_research_pipeline(research_id))

        idx = 0
        while True:
            while idx < len(session["events"]):
                evt = session["events"][idx]
                idx += 1
                yield _sse_event(evt["type"], evt["data"])

            status = str(session.get("status", ""))
            if status in {ResearchStatus.COMPLETED, ResearchStatus.FAILED, "completed", "failed"}:
                break

            await asyncio.sleep(0.5)
    
    return EventSourceResponse(event_generator())

@app.get("/research/{research_id}")
async def get_research_status(research_id: str):
    """Get research status and report"""
    if research_id not in active_sessions:
        raise HTTPException(status_code=404, detail="Research session not found")
    
    session = active_sessions[research_id]
    steps = session.get('debug_report', {}).get('steps', [])
    recent_logs = [
        f"[{step.get('phase', 'unknown')}] {step.get('message', '')}"
        for step in steps[-10:]
    ]
    error_payload = session.get('error') or {}
    error_message = error_payload.get('message') if isinstance(error_payload, dict) else None
    phase = session.get('phase', str(session.get('status', 'pending')))
    message = session.get('message')
    agents = _build_agent_progress(
        phase=phase,
        phase_message=message or "",
        status=str(session.get('status', 'pending')),
        error_message=error_message,
    )

    return {
        "research_id": research_id,
        "query": session['query'],
        "created_at": session.get('created_at'),
        "status": session['status'],
        "phase": phase,
        "message": message,
        "progress": session['progress'],
        "agents": agents,
        "logs": recent_logs,
        "error_message": error_message,
        "report": session['report'],
        "error": session.get('error'),
        "debug_report": session.get('debug_report')
    }

@app.delete("/research/{research_id}")
async def cleanup_research(research_id: str):
    """Clean up research session"""
    if research_id in active_sessions:
        del active_sessions[research_id]
        return {"message": "Session cleaned up"}
    return {"message": "Session not found"}

def _sse_event(event_type: str, data: dict) -> str:
    """Format data as SSE event"""
    return f"event: {event_type}\ndata: {json.dumps(data)}\n\n"

if __name__ == "__main__":
    if DEBUG_MODE:
        print(f"[DEBUG] Starting Velora backend on port {SERVER_PORT}")
    uvicorn.run("main:app", host="0.0.0.0", port=SERVER_PORT, reload=DEBUG_MODE)

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
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sse_starlette.sse import EventSourceResponse
import uvicorn

# Load environment variables
load_dotenv()

# Import agents and services
from agents.orchestrator import OrchestratorAgent
from agents.web_search_agent import WebSearchAgent
from agents.analyzer_agent import AnalyzerAgent
from agents.report_writer import ReportWriterAgent
from services.firebase_service import save_research, get_research
from models.research_model import ResearchRequest, ResearchReport, ResearchStatus

# Initialize FastAPI
app = FastAPI(
    title="Velora Research API",
    description="AI-powered research swarm with 4 agents",
    version="1.0.0"
)

# Initialize agents
orchestrator = OrchestratorAgent()
web_search = WebSearchAgent()
analyzer = AnalyzerAgent()
report_writer = ReportWriterAgent()

# In-memory session storage (for dev; replace with Redis in production)
active_sessions = {}


def _build_agent_progress(phase: str, phase_message: str, status: str, error_message: Optional[str] = None):
    """Create per-agent progress payload for UI status cards."""
    order = [
        ("Orchestrator", "orchestration"),
        ("Web Search Agent", "searching"),
        ("Analyzer Agent", "analyzing"),
        ("Report Writer", "writing"),
    ]

    phase_index = {name: idx for idx, (_, name) in enumerate(order)}.get(phase, -1)
    phase_messages = {
        "orchestration": "Planning research strategy",
        "searching": "Searching and summarizing sources",
        "analyzing": "Analyzing evidence and conflicts",
        "writing": "Writing final report",
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
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

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

        # === PHASE 2: WEB SEARCH ===
        _track_step("searching", "Searching the web for information...", 30)

        all_search_results = []
        web_tasks = assignments.get('web_search_tasks', [])

        async def _run_search_task(task: dict) -> dict:
            result = await web_search.search_and_summarize(task['query'])
            return {"task": task, "result": result}

        pending_tasks = [asyncio.create_task(_run_search_task(task)) for task in web_tasks]
        completed_count = 0

        for completed in asyncio.as_completed(pending_tasks):
            task_result = await completed
            task = task_result["task"]
            search_result = task_result["result"]
            completed_count += 1

            if search_result['success']:
                all_search_results.append(search_result)
                _append_event(session, "search_complete", {
                    "task_id": task['id'],
                    "query": task['query'],
                    "result_count": search_result['result_count'],
                    "summary": search_result['summary'][:200]
                })

            progress = 30 + completed_count / max(len(web_tasks), 1) * 30
            _track_step(
                "searching",
                f"Completed search task {completed_count}/{len(web_tasks)}",
                int(progress),
                {
                    "task_id": task['id'],
                    "query": task['query'],
                    "search_success": search_result.get('success', False),
                    "search_error": search_result.get('error')
                }
            )

        # === PHASE 3: ANALYSIS ===
        _track_step("analyzing", "Analyzing and synthesizing results...", 60)

        combined_results = "\n\n---\n\n".join([
            s.get('summary', '') for s in all_search_results
        ])

        analysis_result = await analyzer.analyze(
            query=query,
            search_results=combined_results,
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

        # === PHASE 4: REPORT WRITING ===
        _track_step("writing", "Crafting final report...", 75)

        raw_sources = []
        for result in all_search_results:
            raw_sources.extend(result.get('raw_results', []))

        report_result = await report_writer.write_report(
            query=query,
            analysis=analysis_result.get('analysis', {}),
            raw_sources=raw_sources
        )

        if not report_result.get('success'):
            report_error = report_result.get('error', 'Report writing failed')
            _track_step(
                "writing",
                "Report writer failed, using fallback report",
                85,
                {"error": report_error}
            )
            report_result = {
                "success": True,
                "query": query,
                "raw_report": "",
                "sections": [],
                "summary": f"Report fallback used because report writer failed: {report_error}"
            }

        report_data = {
            "query": query,
            "status": ResearchStatus.COMPLETED,
            "summary": report_result['summary'],
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
            "writing",
            "Report complete",
            90,
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
    port = int(os.environ.get("PORT", 8000))
    debug = os.environ.get("DEBUG", "false").lower() == "true"
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=debug)

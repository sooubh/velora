"""
Orchestrator Agent - The leader of the research swarm.
Breaks user query into subtasks and coordinates other agents.
"""
import json
from typing import Dict, List, Any
from services.gemini_service import parse_json_response
from utils.prompt_templates import PromptTemplates

class OrchestratorAgent:
    def __init__(self):
        self.name = "Orchestrator"
        self.system_prompt = PromptTemplates.ORCHESTRATOR_SYSTEM
    
    async def plan_research(self, query: str) -> Dict[str, Any]:
        """
        Analyze user query and break into subtasks.
        
        Args:
            query: User's research query
            
        Returns:
            Research plan with subtasks, keywords, and format
        """
        prompt = PromptTemplates.ORCHESTRATOR_PROMPT.format(query=query)
        
        try:
            plan = await parse_json_response(self.system_prompt, prompt)
            return {
                "success": True,
                "plan": plan
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
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
    
    async def coordinate_agents(self, plan: Dict[str, Any]) -> Dict[str, List[str]]:
        """
        Assign subtasks to other agents based on plan.
        Returns task assignments for Web Search, Analyzer, and Report Writer.
        """
        assignments = {
            "web_search_tasks": [],
            "analysis_focus": plan.get('analysis_focus', ''),
            "report_format": plan.get('final_output_format', '')
        }
        
        for subtask in plan.get('subtasks', []):
            assignments['web_search_tasks'].append({
                'id': subtask['id'],
                'query': subtask['task'],
                'keywords': subtask.get('keywords', [])
            })
        
        return assignments

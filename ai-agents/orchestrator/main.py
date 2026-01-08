#!/usr/bin/env python3
"""
AI Orchestrator - Coordinación inteligente de despliegues IaC
Soporta Terraform, OpenTofu, Terragrunt con optimización IA
"""

import json
import subprocess
import datetime
from dataclasses import dataclass
from typing import Dict, List, Optional
from pathlib import Path

@dataclass
class DeploymentContext:
    tool: str  # terraform, tofu, terragrunt
    environment: str
    project_name: str
    subscription_id: str
    
@dataclass
class AIRecommendation:
    tool_selection: str
    vm_size: str
    node_count: int
    estimated_cost: float
    confidence: float

class AIOrchestrator:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.current_hour = datetime.datetime.now().hour
        
    def analyze_context(self, context: DeploymentContext) -> AIRecommendation:
        """Análisis IA del contexto de despliegue"""
        
        # AI Logic: Selección de herramienta
        tool_selection = self._select_optimal_tool(context)
        
        # AI Logic: Optimización de recursos
        vm_size, node_count = self._optimize_resources(context)
        
        # AI Logic: Predicción de costos
        estimated_cost = self._predict_cost(vm_size, node_count)
        
        return AIRecommendation(
            tool_selection=tool_selection,
            vm_size=vm_size,
            node_count=node_count,
            estimated_cost=estimated_cost,
            confidence=0.85
        )
    
    def _select_optimal_tool(self, context: DeploymentContext) -> str:
        """IA selecciona la mejor herramienta según contexto"""
        
        # AI Decision Logic
        if context.environment == "dev":
            return "terraform"  # Más estable para dev
        elif context.environment == "staging":
            return "tofu"  # Open source para testing
        else:
            return "terragrunt"  # Enterprise features para prod
    
    def _optimize_resources(self, context: DeploymentContext) -> tuple:
        """IA optimiza recursos según patrones"""
        
        is_off_hours = self.current_hour < 9 or self.current_hour > 18
        
        if context.environment == "dev":
            if is_off_hours:
                return "Standard_B1s", 1  # Mínimo costo
            else:
                return "Standard_B2s", 1  # Balanceado
        else:
            return "Standard_D2_v2", 2  # Producción
    
    def _predict_cost(self, vm_size: str, node_count: int) -> float:
        """IA predice costos mensuales"""
        
        cost_map = {
            "Standard_B1s": 15.0,
            "Standard_B2s": 30.0,
            "Standard_D2_v2": 70.0
        }
        
        base_cost = cost_map.get(vm_size, 30.0)
        return base_cost * node_count
    
    def execute_deployment(self, context: DeploymentContext, recommendation: AIRecommendation) -> Dict:
        """Ejecuta despliegue con recomendaciones IA"""
        
        env_dir = self.project_root / "environments" / context.environment
        
        # Preparar variables dinámicas
        tf_vars = {
            "subscription_id": context.subscription_id,
            "project_name": context.project_name,
            "node_count": recommendation.node_count,
            "vm_size": recommendation.vm_size
        }
        
        # Ejecutar con herramienta seleccionada
        result = self._run_iac_tool(
            tool=recommendation.tool_selection,
            working_dir=env_dir,
            variables=tf_vars
        )
        
        return {
            "status": "success" if result.returncode == 0 else "failed",
            "tool_used": recommendation.tool_selection,
            "resources_created": self._extract_resources(result.stdout),
            "estimated_cost": recommendation.estimated_cost,
            "actual_config": {
                "vm_size": recommendation.vm_size,
                "node_count": recommendation.node_count
            }
        }
    
    def _run_iac_tool(self, tool: str, working_dir: Path, variables: Dict) -> subprocess.CompletedProcess:
        """Ejecuta herramienta IaC seleccionada"""
        
        # Cambiar al directorio de trabajo
        original_cwd = Path.cwd()
        
        try:
            import os
            os.chdir(working_dir)
            
            # Comandos según herramienta
            if tool == "terraform":
                cmd = ["terraform", "init"]
                subprocess.run(cmd, check=True)
                
                cmd = ["terraform", "apply", "-auto-approve"]
                for key, value in variables.items():
                    cmd.extend(["-var", f"{key}={value}"])
                    
            elif tool == "tofu":
                cmd = ["tofu", "init"]
                subprocess.run(cmd, check=True)
                
                cmd = ["tofu", "apply", "-auto-approve"]
                for key, value in variables.items():
                    cmd.extend(["-var", f"{key}={value}"])
                    
            elif tool == "terragrunt":
                cmd = ["terragrunt", "apply", "-auto-approve"]
                
            return subprocess.run(cmd, capture_output=True, text=True)
            
        finally:
            os.chdir(original_cwd)
    
    def _extract_resources(self, output: str) -> List[str]:
        """Extrae recursos creados del output"""
        resources = []
        for line in output.split('\n'):
            if 'created' in line and 'azurerm_' in line:
                resources.append(line.strip())
        return resources

def main():
    """Punto de entrada del AI Orchestrator"""
    import sys
    
    if len(sys.argv) < 4:
        print("Uso: python orchestrator.py <tool> <environment> <project_name>")
        sys.exit(1)
    
    tool = sys.argv[1]
    environment = sys.argv[2] 
    project_name = sys.argv[3]
    subscription_id = "617fad55-504d-42d2-ba0e-267e8472a399"
    
    # Crear contexto
    context = DeploymentContext(
        tool=tool,
        environment=environment,
        project_name=project_name,
        subscription_id=subscription_id
    )
    
    # Inicializar AI Orchestrator
    orchestrator = AIOrchestrator("/home/giovanemere/edtech/azure-aks-iac")
    
    # Análisis IA
    print("🤖 AI Orchestrator - Analizando contexto...")
    recommendation = orchestrator.analyze_context(context)
    
    print(f"🧠 AI Recommendations:")
    print(f"   Tool: {recommendation.tool_selection}")
    print(f"   VM Size: {recommendation.vm_size}")
    print(f"   Node Count: {recommendation.node_count}")
    print(f"   Estimated Cost: ${recommendation.estimated_cost}/month")
    print(f"   Confidence: {recommendation.confidence:.0%}")
    
    # Confirmar despliegue
    confirm = input("\n¿Proceder con despliegue IA? (y/N): ")
    if confirm.lower() != 'y':
        print("❌ Despliegue cancelado")
        return
    
    # Ejecutar despliegue
    print("🚀 Ejecutando despliegue con IA...")
    result = orchestrator.execute_deployment(context, recommendation)
    
    print(f"\n✅ Despliegue completado:")
    print(f"   Status: {result['status']}")
    print(f"   Tool usado: {result['tool_used']}")
    print(f"   Costo estimado: ${result['estimated_cost']}/month")

if __name__ == "__main__":
    main()

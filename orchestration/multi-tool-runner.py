#!/usr/bin/env python3
"""
Multi-Tool Runner - Ejecutor unificado para Terraform, OpenTofu, Terragrunt
"""

import subprocess
import json
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class ToolResult:
    tool: str
    success: bool
    output: str
    error: str
    resources_created: List[str]
    execution_time: float

class MultiToolRunner:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.supported_tools = ["terraform", "tofu", "terragrunt"]
    
    def check_tool_availability(self) -> Dict[str, bool]:
        """Verifica qué herramientas están disponibles"""
        availability = {}
        
        for tool in self.supported_tools:
            try:
                result = subprocess.run([tool, "--version"], 
                                      capture_output=True, text=True, timeout=10)
                availability[tool] = result.returncode == 0
            except (subprocess.TimeoutExpired, FileNotFoundError):
                availability[tool] = False
        
        return availability
    
    def execute_with_tool(self, tool: str, environment: str, 
                         variables: Dict, action: str = "apply") -> ToolResult:
        """Ejecuta acción con herramienta específica"""
        
        import time
        start_time = time.time()
        
        env_dir = self.project_root / "environments" / environment
        
        if not env_dir.exists():
            return ToolResult(
                tool=tool,
                success=False,
                output="",
                error=f"Environment directory {env_dir} not found",
                resources_created=[],
                execution_time=0
            )
        
        try:
            # Cambiar al directorio del entorno
            original_cwd = Path.cwd()
            import os
            os.chdir(env_dir)
            
            # Ejecutar según herramienta
            if tool == "terraform":
                result = self._run_terraform(action, variables)
            elif tool == "tofu":
                result = self._run_opentofu(action, variables)
            elif tool == "terragrunt":
                result = self._run_terragrunt(action, variables)
            else:
                raise ValueError(f"Unsupported tool: {tool}")
            
            execution_time = time.time() - start_time
            
            return ToolResult(
                tool=tool,
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr,
                resources_created=self._extract_resources(result.stdout),
                execution_time=execution_time
            )
            
        except Exception as e:
            return ToolResult(
                tool=tool,
                success=False,
                output="",
                error=str(e),
                resources_created=[],
                execution_time=time.time() - start_time
            )
        finally:
            os.chdir(original_cwd)
    
    def _run_terraform(self, action: str, variables: Dict) -> subprocess.CompletedProcess:
        """Ejecuta comandos Terraform"""
        
        # Init
        init_result = subprocess.run(["terraform", "init"], 
                                   capture_output=True, text=True)
        if init_result.returncode != 0:
            return init_result
        
        # Validate
        validate_result = subprocess.run(["terraform", "validate"], 
                                       capture_output=True, text=True)
        if validate_result.returncode != 0:
            return validate_result
        
        # Plan/Apply
        cmd = ["terraform", action]
        if action == "apply":
            cmd.append("-auto-approve")
        
        # Agregar variables
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])
        
        return subprocess.run(cmd, capture_output=True, text=True)
    
    def _run_opentofu(self, action: str, variables: Dict) -> subprocess.CompletedProcess:
        """Ejecuta comandos OpenTofu"""
        
        # Init
        init_result = subprocess.run(["tofu", "init"], 
                                   capture_output=True, text=True)
        if init_result.returncode != 0:
            return init_result
        
        # Apply/Plan
        cmd = ["tofu", action]
        if action == "apply":
            cmd.append("-auto-approve")
        
        # Agregar variables
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])
        
        return subprocess.run(cmd, capture_output=True, text=True)
    
    def _run_terragrunt(self, action: str, variables: Dict) -> subprocess.CompletedProcess:
        """Ejecuta comandos Terragrunt"""
        
        cmd = ["terragrunt", action]
        if action == "apply":
            cmd.append("-auto-approve")
        
        return subprocess.run(cmd, capture_output=True, text=True)
    
    def _extract_resources(self, output: str) -> List[str]:
        """Extrae recursos creados del output"""
        resources = []
        for line in output.split('\n'):
            if any(keyword in line for keyword in ['created', 'modified', 'destroyed']):
                if 'azurerm_' in line:
                    resources.append(line.strip())
        return resources
    
    def get_tool_recommendation(self, environment: str, complexity: str) -> str:
        """IA recomienda mejor herramienta según contexto"""
        
        availability = self.check_tool_availability()
        
        # AI Logic para selección de herramienta
        if environment == "dev":
            # Desarrollo: priorizar estabilidad
            if availability.get("terraform", False):
                return "terraform"
            elif availability.get("tofu", False):
                return "tofu"
        
        elif environment == "staging":
            # Staging: probar open source
            if availability.get("tofu", False):
                return "tofu"
            elif availability.get("terraform", False):
                return "terraform"
        
        elif environment == "prod":
            # Producción: features enterprise
            if availability.get("terragrunt", False):
                return "terragrunt"
            elif availability.get("terraform", False):
                return "terraform"
        
        # Fallback al primer disponible
        for tool in self.supported_tools:
            if availability.get(tool, False):
                return tool
        
        raise RuntimeError("No IaC tools available")

def main():
    """Ejecutar multi-tool runner"""
    import sys
    
    if len(sys.argv) < 3:
        print("Uso: python multi-tool-runner.py <environment> <action>")
        sys.exit(1)
    
    environment = sys.argv[1]
    action = sys.argv[2]
    
    runner = MultiToolRunner("/home/giovanemere/edtech/azure-aks-iac")
    
    # Verificar herramientas disponibles
    availability = runner.check_tool_availability()
    print("🔧 Herramientas disponibles:")
    for tool, available in availability.items():
        status = "✅" if available else "❌"
        print(f"   {status} {tool}")
    
    # Obtener recomendación IA
    recommended_tool = runner.get_tool_recommendation(environment, "simple")
    print(f"\n🤖 IA recomienda: {recommended_tool}")
    
    # Variables de ejemplo
    variables = {
        "subscription_id": "617fad55-504d-42d2-ba0e-267e8472a399",
        "project_name": "aks-demo"
    }
    
    # Ejecutar
    print(f"\n🚀 Ejecutando {action} con {recommended_tool}...")
    result = runner.execute_with_tool(recommended_tool, environment, variables, action)
    
    print(f"\n📊 Resultado:")
    print(f"   Tool: {result.tool}")
    print(f"   Success: {'✅' if result.success else '❌'}")
    print(f"   Execution time: {result.execution_time:.2f}s")
    print(f"   Resources: {len(result.resources_created)}")
    
    if not result.success:
        print(f"   Error: {result.error}")

if __name__ == "__main__":
    main()

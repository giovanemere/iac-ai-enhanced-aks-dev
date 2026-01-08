#!/usr/bin/env python3
"""
Backup AI Agent - Gestión inteligente de backups para AKS
"""

import json
import subprocess
import datetime
from dataclasses import dataclass
from typing import Dict, List, Optional

@dataclass
class BackupRecommendation:
    frequency: str
    retention_days: int
    estimated_cost: float
    critical_resources: List[str]
    excluded_namespaces: List[str]

class BackupAIAgent:
    def __init__(self):
        self.cost_per_gb_month = 0.05  # Azure snapshot cost
        self.vault_base_cost = 5.0     # Backup vault base cost
        
    def analyze_cluster_for_backup(self) -> BackupRecommendation:
        """Analiza el cluster y recomienda estrategia de backup"""
        
        # Obtener información del cluster
        cluster_info = self._get_cluster_info()
        
        # Análisis IA de criticidad
        critical_resources = self._identify_critical_resources(cluster_info)
        
        # Calcular frecuencia óptima
        frequency = self._calculate_optimal_frequency(cluster_info)
        
        # Calcular retención
        retention = self._calculate_retention_policy(cluster_info)
        
        # Estimar costos
        estimated_cost = self._estimate_backup_costs(cluster_info)
        
        # Namespaces a excluir
        excluded_namespaces = ["kube-system", "kube-public", "gatekeeper-system"]
        
        return BackupRecommendation(
            frequency=frequency,
            retention_days=retention,
            estimated_cost=estimated_cost,
            critical_resources=critical_resources,
            excluded_namespaces=excluded_namespaces
        )
    
    def _get_cluster_info(self) -> Dict:
        """Obtiene información del cluster"""
        try:
            # Obtener PVCs
            pvcs_result = subprocess.run(
                ["kubectl", "get", "pvc", "--all-namespaces", "-o", "json"],
                capture_output=True, text=True
            )
            
            # Obtener deployments
            deployments_result = subprocess.run(
                ["kubectl", "get", "deployments", "--all-namespaces", "-o", "json"],
                capture_output=True, text=True
            )
            
            # Obtener namespaces
            namespaces_result = subprocess.run(
                ["kubectl", "get", "namespaces", "-o", "json"],
                capture_output=True, text=True
            )
            
            return {
                "pvcs": json.loads(pvcs_result.stdout) if pvcs_result.returncode == 0 else {"items": []},
                "deployments": json.loads(deployments_result.stdout) if deployments_result.returncode == 0 else {"items": []},
                "namespaces": json.loads(namespaces_result.stdout) if namespaces_result.returncode == 0 else {"items": []}
            }
        except Exception as e:
            print(f"Error obteniendo info del cluster: {e}")
            return {"pvcs": {"items": []}, "deployments": {"items": []}, "namespaces": {"items": []}}
    
    def _identify_critical_resources(self, cluster_info: Dict) -> List[str]:
        """Identifica recursos críticos que necesitan backup"""
        critical = []
        
        # PVCs son siempre críticos
        for pvc in cluster_info["pvcs"]["items"]:
            name = pvc["metadata"]["name"]
            namespace = pvc["metadata"]["namespace"]
            critical.append(f"PVC: {namespace}/{name}")
        
        # Deployments con datos persistentes
        for deployment in cluster_info["deployments"]["items"]:
            name = deployment["metadata"]["name"]
            namespace = deployment["metadata"]["namespace"]
            
            # Verificar si tiene volúmenes persistentes
            spec = deployment.get("spec", {})
            template = spec.get("template", {})
            pod_spec = template.get("spec", {})
            volumes = pod_spec.get("volumes", [])
            
            has_persistent_volume = any(
                "persistentVolumeClaim" in volume for volume in volumes
            )
            
            if has_persistent_volume:
                critical.append(f"Deployment: {namespace}/{name}")
        
        return critical
    
    def _calculate_optimal_frequency(self, cluster_info: Dict) -> str:
        """Calcula frecuencia óptima de backup"""
        
        pvc_count = len(cluster_info["pvcs"]["items"])
        deployment_count = len(cluster_info["deployments"]["items"])
        
        # Lógica IA para frecuencia
        if pvc_count == 0 and deployment_count <= 2:
            return "weekly"  # Cluster simple
        elif pvc_count <= 2 and deployment_count <= 5:
            return "daily"   # Cluster moderado
        else:
            return "twice-daily"  # Cluster complejo
    
    def _calculate_retention_policy(self, cluster_info: Dict) -> int:
        """Calcula política de retención óptima"""
        
        pvc_count = len(cluster_info["pvcs"]["items"])
        
        # Lógica IA para retención
        if pvc_count == 0:
            return 3   # Sin datos persistentes
        elif pvc_count <= 2:
            return 7   # Pocos datos
        else:
            return 14  # Más datos críticos
    
    def _estimate_backup_costs(self, cluster_info: Dict) -> float:
        """Estima costos mensuales de backup"""
        
        # Costo base del vault
        total_cost = self.vault_base_cost
        
        # Estimar tamaño de datos (aproximado)
        pvc_count = len(cluster_info["pvcs"]["items"])
        estimated_gb_per_pvc = 10  # Estimación conservadora
        
        total_gb = pvc_count * estimated_gb_per_pvc
        snapshot_cost = total_gb * self.cost_per_gb_month
        
        total_cost += snapshot_cost
        
        return round(total_cost, 2)
    
    def generate_backup_strategy(self) -> Dict:
        """Genera estrategia completa de backup"""
        
        recommendation = self.analyze_cluster_for_backup()
        
        current_hour = datetime.datetime.now().hour
        
        # Horario óptimo (off-peak)
        optimal_hour = 2 if current_hour < 12 else 14
        
        strategy = {
            "ai_analysis": {
                "frequency": recommendation.frequency,
                "retention_days": recommendation.retention_days,
                "estimated_monthly_cost": recommendation.estimated_cost,
                "critical_resources_count": len(recommendation.critical_resources),
                "excluded_namespaces": recommendation.excluded_namespaces
            },
            "schedule": {
                "backup_time": f"{optimal_hour:02d}:00",
                "timezone": "UTC",
                "cron_expression": f"0 {optimal_hour} * * *"
            },
            "cost_optimization": {
                "vault_redundancy": "LocallyRedundant",
                "retention_policy": "Tiered",
                "snapshot_frequency": recommendation.frequency
            },
            "critical_resources": recommendation.critical_resources,
            "recommendations": [
                f"Backup {recommendation.frequency} a las {optimal_hour:02d}:00 UTC",
                f"Retener por {recommendation.retention_days} días",
                f"Costo estimado: ${recommendation.estimated_cost}/mes",
                "Excluir namespaces del sistema para reducir costos",
                "Usar LocallyRedundant para mínimo costo"
            ]
        }
        
        return strategy

def main():
    """Ejecutar análisis de backup con IA"""
    
    print("🤖 Backup AI Agent - Analizando cluster...")
    
    agent = BackupAIAgent()
    strategy = agent.generate_backup_strategy()
    
    print(f"\n📊 Estrategia de Backup IA:")
    print(f"   Frecuencia: {strategy['ai_analysis']['frequency']}")
    print(f"   Retención: {strategy['ai_analysis']['retention_days']} días")
    print(f"   Costo estimado: ${strategy['ai_analysis']['estimated_monthly_cost']}/mes")
    print(f"   Recursos críticos: {strategy['ai_analysis']['critical_resources_count']}")
    
    print(f"\n⏰ Programación Óptima:")
    print(f"   Horario: {strategy['schedule']['backup_time']} UTC")
    print(f"   Cron: {strategy['schedule']['cron_expression']}")
    
    print(f"\n🎯 Recomendaciones IA:")
    for rec in strategy['recommendations']:
        print(f"   • {rec}")
    
    if strategy['critical_resources']:
        print(f"\n🔒 Recursos Críticos Detectados:")
        for resource in strategy['critical_resources'][:5]:  # Mostrar primeros 5
            print(f"   • {resource}")
        
        if len(strategy['critical_resources']) > 5:
            print(f"   ... y {len(strategy['critical_resources']) - 5} más")

if __name__ == "__main__":
    main()

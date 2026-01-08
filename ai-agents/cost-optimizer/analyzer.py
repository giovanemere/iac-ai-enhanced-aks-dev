#!/usr/bin/env python3
"""
Cost Optimizer Agent - Optimización automática de costos con IA
"""

import json
import requests
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import Dict, List

@dataclass
class CostAnalysis:
    current_cost: float
    predicted_cost: float
    optimization_potential: float
    recommendations: List[str]

class CostOptimizerAgent:
    def __init__(self):
        self.cost_thresholds = {
            "dev": 50.0,      # $50/month max para dev
            "staging": 200.0,  # $200/month max para staging  
            "prod": 1000.0     # $1000/month max para prod
        }
    
    def analyze_current_usage(self, environment: str) -> CostAnalysis:
        """Analiza uso actual y predice optimizaciones"""
        
        # Simular análisis de costos (en producción usaría Azure Cost Management API)
        current_hour = datetime.now().hour
        
        # AI Logic: Análisis de patrones de uso
        if environment == "dev":
            if current_hour < 9 or current_hour > 18:
                # Off-hours: uso mínimo
                current_cost = 15.0
                predicted_cost = 12.0
                recommendations = [
                    "Cambiar a Standard_B1s durante off-hours",
                    "Implementar auto-shutdown nocturno",
                    "Usar spot instances para cargas no críticas"
                ]
            else:
                # Business hours: uso normal
                current_cost = 30.0
                predicted_cost = 25.0
                recommendations = [
                    "Mantener Standard_B2s en horario laboral",
                    "Considerar reserved instances para ahorro a largo plazo"
                ]
        else:
            current_cost = 100.0
            predicted_cost = 80.0
            recommendations = [
                "Implementar auto-scaling inteligente",
                "Optimizar storage tier"
            ]
        
        optimization_potential = current_cost - predicted_cost
        
        return CostAnalysis(
            current_cost=current_cost,
            predicted_cost=predicted_cost,
            optimization_potential=optimization_potential,
            recommendations=recommendations
        )
    
    def get_rightsizing_recommendations(self, current_vm: str, usage_pattern: str) -> Dict:
        """IA recomienda rightsizing basado en patrones de uso"""
        
        rightsizing_map = {
            "Standard_D2_v2": {
                "low_usage": "Standard_B2s",
                "medium_usage": "Standard_B2s", 
                "high_usage": "Standard_D2_v2"
            },
            "Standard_B2s": {
                "low_usage": "Standard_B1s",
                "medium_usage": "Standard_B2s",
                "high_usage": "Standard_D2_v2"
            },
            "Standard_B1s": {
                "low_usage": "Standard_B1s",
                "medium_usage": "Standard_B2s",
                "high_usage": "Standard_D2_v2"
            }
        }
        
        recommended_vm = rightsizing_map.get(current_vm, {}).get(usage_pattern, current_vm)
        
        cost_savings = self._calculate_savings(current_vm, recommended_vm)
        
        return {
            "current_vm": current_vm,
            "recommended_vm": recommended_vm,
            "monthly_savings": cost_savings,
            "usage_pattern": usage_pattern
        }
    
    def _calculate_savings(self, current_vm: str, recommended_vm: str) -> float:
        """Calcula ahorros potenciales"""
        
        vm_costs = {
            "Standard_B1s": 15.0,
            "Standard_B2s": 30.0,
            "Standard_D2_v2": 70.0
        }
        
        current_cost = vm_costs.get(current_vm, 30.0)
        recommended_cost = vm_costs.get(recommended_vm, 30.0)
        
        return max(0, current_cost - recommended_cost)
    
    def generate_cost_report(self, environment: str) -> Dict:
        """Genera reporte completo de costos con IA"""
        
        analysis = self.analyze_current_usage(environment)
        
        # Simular datos históricos
        historical_costs = [25.0, 28.0, 32.0, 30.0, 27.0]  # Últimos 5 días
        
        # AI Prediction: Tendencia de costos
        trend = "increasing" if historical_costs[-1] > historical_costs[0] else "decreasing"
        
        return {
            "environment": environment,
            "current_analysis": {
                "monthly_cost": analysis.current_cost,
                "predicted_optimized": analysis.predicted_cost,
                "potential_savings": analysis.optimization_potential,
                "savings_percentage": (analysis.optimization_potential / analysis.current_cost) * 100
            },
            "recommendations": analysis.recommendations,
            "historical_trend": {
                "direction": trend,
                "last_5_days": historical_costs
            },
            "threshold_status": {
                "limit": self.cost_thresholds[environment],
                "current": analysis.current_cost,
                "status": "within_limit" if analysis.current_cost < self.cost_thresholds[environment] else "over_limit"
            },
            "ai_insights": [
                f"Patrón de uso detectado: {'off-hours' if datetime.now().hour < 9 else 'business-hours'}",
                f"Potencial de ahorro: {analysis.optimization_potential:.0f}%",
                f"Recomendación principal: {analysis.recommendations[0] if analysis.recommendations else 'Mantener configuración actual'}"
            ]
        }

def main():
    """Ejecutar análisis de costos"""
    import sys
    
    environment = sys.argv[1] if len(sys.argv) > 1 else "dev"
    
    print(f"💰 Cost Optimizer Agent - Analizando {environment}")
    
    optimizer = CostOptimizerAgent()
    report = optimizer.generate_cost_report(environment)
    
    print(f"\n📊 Reporte de Costos:")
    print(f"   Costo actual: ${report['current_analysis']['monthly_cost']}/mes")
    print(f"   Costo optimizado: ${report['current_analysis']['predicted_optimized']}/mes")
    print(f"   Ahorro potencial: ${report['current_analysis']['potential_savings']}/mes ({report['current_analysis']['savings_percentage']:.1f}%)")
    
    print(f"\n🤖 AI Insights:")
    for insight in report['ai_insights']:
        print(f"   • {insight}")
    
    print(f"\n💡 Recomendaciones:")
    for rec in report['recommendations']:
        print(f"   • {rec}")

if __name__ == "__main__":
    main()

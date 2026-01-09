#!/usr/bin/env python3
"""
AI Agent para gestión automatizada de horarios AKS
Detiene servicios hasta 2:45 PM y los reinicia automáticamente
"""

import os
import sys
import json
import subprocess
from datetime import datetime, time
import schedule
import time as time_module
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AKSScheduleManager:
    def __init__(self):
        self.resource_group = "rg-aks-demo-dev"
        self.cluster_name = "aks-aks-demo-dev"
        self.stop_time = time(14, 45)  # 2:45 PM
        self.start_time = time(8, 0)   # 8:00 AM (configurable)
        
    def is_business_hours(self):
        """Verificar si estamos en horario laboral"""
        now = datetime.now().time()
        return self.start_time <= now <= self.stop_time
    
    def backup_before_stop(self):
        """Crear backup antes de detener servicios"""
        logger.info("🛡️ Creando backup antes de detener servicios...")
        try:
            # Crear backup con timestamp
            backup_name = f"pre-stop-backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            
            kubectl_cmd = f"""
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: {backup_name}
  namespace: dataprotection-microsoft
  labels:
    backup-type: pre-stop
    automated: "true"
spec:
  includedNamespaces: ["default"]
  storageLocation: default
  ttl: 168h0m0s
  snapshotVolumes: true
EOF"""
            
            result = subprocess.run(kubectl_cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                logger.info(f"✅ Backup creado: {backup_name}")
                return backup_name
            else:
                logger.error(f"❌ Error creando backup: {result.stderr}")
                return None
        except Exception as e:
            logger.error(f"❌ Error en backup: {e}")
            return None
    
    def scale_down_workloads(self):
        """Escalar workloads a 0 réplicas"""
        logger.info("⬇️ Escalando workloads a 0 réplicas...")
        try:
            # Obtener deployments
            cmd = "kubectl get deployments -n default -o json"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                deployments = json.loads(result.stdout)
                scaled_deployments = []
                
                for deployment in deployments.get('items', []):
                    name = deployment['metadata']['name']
                    current_replicas = deployment['spec']['replicas']
                    
                    if current_replicas > 0:
                        # Guardar estado actual
                        scaled_deployments.append({
                            'name': name,
                            'replicas': current_replicas
                        })
                        
                        # Escalar a 0
                        scale_cmd = f"kubectl scale deployment {name} --replicas=0 -n default"
                        subprocess.run(scale_cmd, shell=True)
                        logger.info(f"📉 {name}: {current_replicas} → 0 réplicas")
                
                # Guardar estado para restaurar después
                with open('/tmp/aks-scaled-state.json', 'w') as f:
                    json.dump(scaled_deployments, f)
                
                logger.info(f"✅ {len(scaled_deployments)} deployments escalados")
                return True
            else:
                logger.error(f"❌ Error obteniendo deployments: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error escalando workloads: {e}")
            return False
    
    def scale_up_workloads(self):
        """Restaurar workloads a su estado original"""
        logger.info("⬆️ Restaurando workloads...")
        try:
            if not os.path.exists('/tmp/aks-scaled-state.json'):
                logger.warning("⚠️ No se encontró estado guardado")
                return False
            
            with open('/tmp/aks-scaled-state.json', 'r') as f:
                deployments = json.load(f)
            
            for deployment in deployments:
                name = deployment['name']
                replicas = deployment['replicas']
                
                scale_cmd = f"kubectl scale deployment {name} --replicas={replicas} -n default"
                result = subprocess.run(scale_cmd, shell=True, capture_output=True, text=True)
                
                if result.returncode == 0:
                    logger.info(f"📈 {name}: 0 → {replicas} réplicas")
                else:
                    logger.error(f"❌ Error escalando {name}: {result.stderr}")
            
            # Limpiar archivo de estado
            os.remove('/tmp/aks-scaled-state.json')
            logger.info("✅ Workloads restaurados")
            return True
            
        except Exception as e:
            logger.error(f"❌ Error restaurando workloads: {e}")
            return False
    
    def stop_node_pools(self):
        """Detener node pools (opcional - más agresivo)"""
        logger.info("🛑 Deteniendo node pools...")
        try:
            cmd = f"az aks nodepool scale --resource-group {self.resource_group} --cluster-name {self.cluster_name} --name agentpool --node-count 0"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info("✅ Node pools detenidos")
                return True
            else:
                logger.error(f"❌ Error deteniendo node pools: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            return False
    
    def start_node_pools(self):
        """Iniciar node pools"""
        logger.info("🚀 Iniciando node pools...")
        try:
            cmd = f"az aks nodepool scale --resource-group {self.resource_group} --cluster-name {self.cluster_name} --name agentpool --node-count 2"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info("✅ Node pools iniciados")
                # Esperar que los nodos estén listos
                time_module.sleep(120)
                return True
            else:
                logger.error(f"❌ Error iniciando node pools: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            return False
    
    def execute_stop_sequence(self):
        """Secuencia completa de parada"""
        logger.info("🔄 Iniciando secuencia de parada...")
        
        # 1. Backup
        backup_name = self.backup_before_stop()
        
        # 2. Escalar workloads
        if self.scale_down_workloads():
            logger.info("✅ Servicios detenidos exitosamente")
            
            # Guardar información del backup
            with open('/tmp/aks-stop-info.json', 'w') as f:
                json.dump({
                    'stopped_at': datetime.now().isoformat(),
                    'backup_name': backup_name,
                    'restart_time': '14:45'
                }, f)
        else:
            logger.error("❌ Error deteniendo servicios")
    
    def execute_start_sequence(self):
        """Secuencia completa de inicio"""
        logger.info("🔄 Iniciando secuencia de arranque...")
        
        # 1. Restaurar workloads
        if self.scale_up_workloads():
            logger.info("✅ Servicios iniciados exitosamente")
            
            # Limpiar información de parada
            if os.path.exists('/tmp/aks-stop-info.json'):
                os.remove('/tmp/aks-stop-info.json')
        else:
            logger.error("❌ Error iniciando servicios")
    
    def schedule_operations(self):
        """Programar operaciones automáticas"""
        logger.info("📅 Configurando horarios automáticos...")
        
        # Programar parada a las 2:45 PM
        schedule.every().day.at("14:45").do(self.execute_stop_sequence)
        
        # Programar inicio a las 8:00 AM (día siguiente)
        schedule.every().day.at("08:00").do(self.execute_start_sequence)
        
        logger.info("✅ Horarios configurados:")
        logger.info("   🛑 Parada: 14:45 (2:45 PM)")
        logger.info("   🚀 Inicio: 08:00 (8:00 AM)")
    
    def run_scheduler(self):
        """Ejecutar scheduler principal"""
        logger.info("🤖 AI Schedule Manager iniciado")
        self.schedule_operations()
        
        while True:
            schedule.run_pending()
            time_module.sleep(60)  # Verificar cada minuto

def main():
    if len(sys.argv) > 1:
        action = sys.argv[1]
        manager = AKSScheduleManager()
        
        if action == "stop":
            manager.execute_stop_sequence()
        elif action == "start":
            manager.execute_start_sequence()
        elif action == "schedule":
            manager.run_scheduler()
        elif action == "status":
            if os.path.exists('/tmp/aks-stop-info.json'):
                with open('/tmp/aks-stop-info.json', 'r') as f:
                    info = json.load(f)
                print(f"🛑 Servicios detenidos desde: {info['stopped_at']}")
                print(f"🛡️ Backup creado: {info.get('backup_name', 'N/A')}")
                print(f"🚀 Reinicio programado: {info['restart_time']}")
            else:
                print("✅ Servicios en funcionamiento normal")
        else:
            print("Uso: python3 aks_schedule_manager.py [stop|start|schedule|status]")
    else:
        # Modo interactivo
        manager = AKSScheduleManager()
        manager.run_scheduler()

if __name__ == "__main__":
    main()

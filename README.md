# 🤖 Azure AKS IaC - AI-Enhanced Platform

Plataforma completa de Infrastructure as Code con **agentes de IA integrados** para Azure Kubernetes Service con **optimización automática de costos y backup inteligente**.

## ✅ Estado Actual del Sistema

- **Cluster AKS**: ✅ Desplegado y funcionando (aks-aks-demo-dev)
- **Estado Terraform**: ✅ Migrado correctamente
- **Agentes IA**: ✅ Todos operativos (Orchestrator, Cost Optimizer, Backup Analyzer)
- **Backup System**: ✅ Implementado con IA
- **Documentación**: ✅ Completa con diagramas Mermaid
- **Scripts**: ✅ Todos funcionales y probados

## 🏗️ Arquitectura Consolidada

```
azure-aks-iac/
├── 🤖 ai-agents/              # Agentes de IA
│   ├── orchestrator/          # Coordinador principal
│   ├── cost-optimizer/        # Optimización de costos
│   └── backup-analyzer/       # Análisis inteligente de backup
├── ⚙️  orchestration/         # Multi-tool runner
├── 🌍 environments/dev/       # Configuración de desarrollo
├── 📦 modules/aks/            # Módulo AKS con IA + Backup
├── 🔧 scripts/                # Scripts automatizados completos
├── 📚 docs/                   # Documentación completa
└── 🏗️  ARCHITECTURE.md        # Arquitectura detallada
```

## 🚀 Uso

```bash
# Verificar sistema
./scripts/ai-orchestrator.sh dev status

# Análisis de costos con IA
./scripts/ai-orchestrator.sh dev cost-analysis

# Despliegue inteligente
./scripts/ai-orchestrator.sh dev deploy

# Destrucción con análisis IA
./scripts/ai-orchestrator.sh dev destroy
```

### Métodos de Destrucción

```bash
# Con AI Orchestrator (recomendado)
./scripts/ai-orchestrator.sh dev destroy

# Tradicional
./scripts/destroy.sh dev terraform
./scripts/destroy.sh dev tofu
./scripts/destroy.sh dev terragrunt
```

## 🔄 Backup & Recovery

### AI-Enhanced Backup Strategy
- **Backup AI Agent**: Análisis automático de recursos críticos
- **Azure Native Backup**: Backup Vault con políticas optimizadas
- **Volume Snapshots**: Snapshots automáticos de discos persistentes
- **Configuration Backup**: Backup de YAML y configuraciones

### Comandos de Backup
```bash
# Análisis IA de backup
./scripts/ai-orchestrator.sh dev backup-ai
python3 ai-agents/backup-analyzer/main.py

# Operaciones de backup
./scripts/ai-orchestrator.sh dev backup     # Estado de backups
./scripts/backup-manager.sh backup         # Backup manual completo
./scripts/backup-manager.sh status         # Estado detallado
./scripts/backup-manager.sh schedule       # Programar automático
./scripts/backup-manager.sh restore <file> # Restaurar

# Aplicar backup nativo Azure
terraform apply  # Configura Backup Vault
```

### Costos de Backup
- **Backup Vault**: ~$5/mes
- **Volume Snapshots**: ~$0.05/GB/mes  
- **Retención optimizada**: 7 días (mínimo costo)
- **Total estimado**: $5-10/mes

📚 **Documentación**: [Backup Strategy](./docs/backup-strategy.md)

## 🤖 Agentes IA

- **AI Orchestrator**: Coordinación inteligente de despliegues
- **Cost Optimizer**: Optimización automática 24/7
- **Multi-Tool Runner**: Terraform + OpenTofu + Terragrunt

## 💰 Optimización Dinámica

- **Off-hours** (19:00-08:59): Standard_B1s → ~$15/mes
- **Business** (09:00-18:59): Standard_B2s → ~$30/mes
- **Ahorro automático**: 20-40% vs configuración estática

---

**🤖 Powered by AI Agents | 💰 Cost-Optimized | 🚀 Enterprise Ready**

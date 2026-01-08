# 🤖 Azure AKS IaC - AI-Enhanced

Plataforma de Infrastructure as Code con **agentes de IA integrados** para Azure Kubernetes Service.

## 🏗️ Arquitectura

```
azure-aks-iac/
├── 🤖 ai-agents/              # Agentes de IA
│   ├── orchestrator/          # Coordinador principal
│   └── cost-optimizer/        # Optimización de costos
├── ⚙️  orchestration/         # Multi-tool runner
├── 🌍 environments/dev/       # Configuración de desarrollo
├── 📦 modules/aks/            # Módulo AKS con IA
├── 🔧 scripts/                # Scripts automatizados
└── 📚 ARCHITECTURE.md         # Arquitectura detallada
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

# AZ-104: Microsoft Azure Administrator

Repositorio de estudo para a certificacao **Microsoft Certified: Azure Administrator Associate**.

## Sobre o Exame

| Item                 | Detalhe                   |
| -------------------- | ------------------------- |
| **Codigo**           | AZ-104                    |
| **Nivel**            | Associate (Intermediario) |
| **Pontuacao minima** | 700/1000                  |
| **Duracao**          | ~120 minutos              |
| **Questoes**         | 40-60                     |

## Dominios

| #   | Dominio                                      | Peso   |
| --- | -------------------------------------------- | ------ |
| 1   | Gerenciar identidades e governanca           | 20-25% |
| 2   | Implementar e gerenciar armazenamento        | 15-20% |
| 3   | Implantar e gerenciar recursos de computacao | 20-25% |
| 4   | Implementar e gerenciar redes virtuais       | 15-20% |
| 5   | Monitorar e manter recursos                  | 10-15% |

## Estrutura do Repositorio

```
az-104/
├── guias/                              # Teoria e notas de estudo
│   └── video-01 a video-22.md         # Notas de 22 video-aulas
│
├── estudos_de_caso/                    # Estudos de caso multi-dominio
│   ├── README.md                       # Indice e ordem sugerida
│   ├── caso1-startup-cloud.md          # Facil: Identity + Storage (6 questoes)
│   ├── caso2-escola-monitoramento.md   # Facil: Compute + Monitoring (6 questoes)
│   ├── caso3-hospital-compliance.md    # Medio: Governance + Networking + Storage (8 questoes)
│   ├── caso4-ecommerce-scaling.md      # Medio: Compute + Networking + Storage (8 questoes)
│   ├── caso5-banco-migracao.md         # Dificil: Todos os 5 dominios (10 questoes)
│   ├── *-solucao.md                    # Gabaritos com explicacoes e [GOTCHA]
│   ├── pratico1-migracao-datacenter.md # Hands-on: migracao de datacenter (~3h)
│   └── pratico2-governanca-corporativa.md # Hands-on: governanca corporativa (~3h)
│
└── labs/                               # Pratica hands-on
    ├── 1-iam-gov-net/                  # IAM, Governance e Networking (Labs 01-06)
    │   ├── README.md                    # Indice do bloco
    │   ├── cenario-contoso.md           # Cenario interconectado (visao geral)
    │   ├── cenario/                     # Blocos individuais do cenario
    │   │   ├── bloco1-identity.md       # Identidade e Entra ID
    │   │   ├── bloco2-governance.md     # RBAC, Policy, Locks
    │   │   ├── bloco3-iac.md            # ARM Templates e Bicep
    │   │   ├── bloco4-networking.md     # VNets, Subnets, NSGs, DNS
    │   │   └── bloco5-connectivity.md   # Peering, VPN, Routing
    │   ├── IaC/
    │   │   ├── powershell.md            # Variante PowerShell
    │   │   ├── arm.md                   # Variante ARM Templates
    │   │   └── bicep.md                 # Variante Bicep
    │   ├── simulado-iam-gov-net.md      # 18 questoes (sem respostas)
    │   └── simulado-iam-gov-net-solucao.md  # Gabarito comentado
    │
    ├── 2-storage-compute/              # Storage e Compute (Labs 07-09c)
    │   ├── README.md                    # Indice do bloco
    │   ├── cenario-contoso.md           # Cenario interconectado (visao geral)
    │   ├── cenario/                     # Blocos individuais do cenario
    │   │   ├── bloco1-storage.md        # Storage Accounts, Blobs, Files
    │   │   ├── bloco2-vms.md            # Virtual Machines, VMSS
    │   │   ├── bloco3-webapps.md        # App Service, Deployment Slots
    │   │   ├── bloco4-aci.md            # Azure Container Instances
    │   │   └── bloco5-container-apps.md # Azure Container Apps
    │   ├── IaC/
    │   │   ├── powershell.md            # Variante PowerShell
    │   │   ├── arm.md                   # Variante ARM Templates
    │   │   └── bicep.md                 # Variante Bicep
    │   ├── simulado-storage-compute.md  # 18 questoes (sem respostas)
    │   └── simulado-storage-compute-solucao.md  # Gabarito comentado
    │
    └── 3-backup-monitoring/            # Backup, Recovery e Monitoring (Labs 10-11)
        ├── README.md                    # Indice do bloco
        ├── cenario-contoso.md           # Cenario interconectado (visao geral)
        ├── cenario/                     # Blocos individuais do cenario
        │   ├── bloco1-vm-backup.md      # Backup de VMs
        │   ├── bloco2-file-blob.md      # Backup de Files e Blobs
        │   ├── bloco3-site-recovery.md  # Azure Site Recovery
        │   ├── bloco4-monitor.md        # Azure Monitor e Alertas
        │   └── bloco5-log-analytics.md  # Log Analytics e KQL
        ├── IaC/
        │   ├── powershell.md            # Variante PowerShell
        │   ├── arm.md                   # Variante ARM Templates
        │   └── bicep.md                 # Variante Bicep
        ├── simulado-backup-monitoring.md      # 18 questoes (sem respostas)
        └── simulado-backup-monitoring-solucao.md  # Gabarito comentado
```

## Material Disponivel

| Recurso                  | Quantidade                                    |
| ------------------------ | --------------------------------------------- |
| Video-aulas documentadas | 22 videos                                     |
| MS Learn - Roteiros      | 6 roteiros                                    |
| MS Learn - Modulos       | 28 modulos                                    |
| Labs praticos            | 14 labs                                       |
| Estudos de caso          | 5 casos (38 questoes) + 2 exercicios praticos |
| Guias de estudo          | 22 notas de video                             |

## Cobertura por Dominio

| Dominio                     | Videos | MS Learn | Labs   |
| --------------------------- | ------ | -------- | ------ |
| 1. Identidades e Governanca | ✅ 100% | ✅ 100%   | ✅ 100% |
| 2. Armazenamento            | ✅ 100% | ✅ 100%   | ✅ 100% |
| 3. Computacao               | ✅ 100% | ✅ 100%   | ✅ 100% |
| 4. Redes Virtuais           | ✅ 100% | ✅ 100%   | ✅ 100% |
| 5. Monitoramento            | ✅ 100% | ✅ 100%   | ✅ 100% |

## Como Usar

### Ordem de estudo sugerida

1. **Teoria** — Ler o guia de estudo e assistir os videos correspondentes ao dominio
2. **MS Learn** — Completar os modulos do roteiro de aprendizagem
3. **Labs** — Praticar no Portal, depois repetir com IaC (PowerShell/ARM/Bicep)
4. **Simulado** — Fazer as questoes sem consultar, depois conferir o gabarito
5. **Estudos de caso** — Resolver cenarios multi-dominio (do facil ao dificil)

### Ordem dos labs

```
Bloco 1: 1-iam-gov-net (Dominios 1 e 4)
  1. cenario/bloco1-identity.md      → Identity e Entra ID
  2. cenario/bloco2-governance.md    → RBAC, Policy, Locks
  3. cenario/bloco3-iac.md           → ARM Templates e Bicep
  4. cenario/bloco4-networking.md    → VNets, Subnets, NSGs, DNS
  5. cenario/bloco5-connectivity.md  → Peering, VPN, Routing
  6. IaC/powershell.md       ─┐
  7. IaC/bicep.md             ├──── Escolha 1+ para praticar IaC
  8. IaC/arm.md              ─┘
  9. simulado-iam-gov-net.md         → Validacao final

Bloco 2: 2-storage-compute (Dominios 2 e 3)
  1. cenario/bloco1-storage.md       → Storage Accounts, Blobs, Files
  2. cenario/bloco2-vms.md           → Virtual Machines, VMSS
  3. cenario/bloco3-webapps.md       → App Service, Deployment Slots
  4. cenario/bloco4-aci.md           → Azure Container Instances
  5. cenario/bloco5-container-apps.md → Azure Container Apps
  6-8. IaC/ (mesma sequencia)
  9. simulado-storage-compute.md     → Validacao final

Bloco 3: 3-backup-monitoring (Dominios 2 e 5)
  1. cenario/bloco1-vm-backup.md     → Backup de VMs
  2. cenario/bloco2-file-blob.md     → Backup de Files e Blobs
  3. cenario/bloco3-site-recovery.md → Azure Site Recovery
  4. cenario/bloco4-monitor.md       → Azure Monitor e Alertas
  5. cenario/bloco5-log-analytics.md → Log Analytics e KQL
  6-8. IaC/ (mesma sequencia)
  9. simulado-backup-monitoring.md   → Validacao final
```

## Links Uteis

| Recurso               | URL                                                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Guia oficial do exame | https://learn.microsoft.com/pt-br/credentials/certifications/resources/study-guides/az-104                                                                                           |
| Curso AZ-104T00       | https://learn.microsoft.com/pt-br/training/courses/az-104t00                                                                                                                         |
| Simulado oficial      | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/practice/assessment?assessment-type=practice&assessmentId=21&practice-assessment-type=certification |
| Agendar exame         | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/                                                                                                    |
| Area restrita (demo)  | https://aka.ms/examdemo                                                                                                                                                              |

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
│   ├── guia_estudo_az-104.md           # Topicos oficiais do exame
│   ├── treinamento_az-104t00.md        # Curso AZ-104T00 (6 roteiros, 28 modulos)
│   ├── analise-cobertura-az104.md      # Mapeamento material vs exame
│   ├── guia-complementar-az104.md      # Material complementar
│   ├── laboratorios_az-104.md          # Lista de labs oficiais
│   └── video-01 a video-22.md         # Notas de 22 video-aulas
│
└── labs/                               # Pratica hands-on
    ├── iam-gov-net/                    # IAM, Governance e Networking (Labs 01-06)
    │   ├── lab-blocos-independentes.md  # Conceitos via Portal
    │   ├── lab-cenario-contoso.md       # Cenario interconectado
    │   ├── lab-iac-powershell.md        # Variante PowerShell
    │   ├── lab-iac-arm.md               # Variante ARM Templates
    │   ├── lab-iac-bicep.md             # Variante Bicep
    │   ├── simulado-iam-gov-net.md      # 18 questoes (sem respostas)
    │   └── simulado-iam-gov-net-solucao.md  # Gabarito comentado
    │
    ├── storage-compute/                # Storage e Compute (Labs 07-09c)
    │   ├── lab-blocos-independentes.md  # Conceitos via Portal
    │   ├── lab-cenario-contoso.md       # Cenario interconectado
    │   ├── lab-iac-powershell.md        # Variante PowerShell
    │   ├── lab-iac-arm.md               # Variante ARM Templates
    │   ├── lab-iac-bicep.md             # Variante Bicep
    │   ├── simulado-storage-compute.md  # 18 questoes (sem respostas)
    │   └── simulado-storage-compute-solucao.md  # Gabarito comentado
    │
    └── backup-monitoring/              # Backup, Recovery e Monitoring (Labs 10-11)
        ├── lab-blocos-independentes.md  # Conceitos via Portal
        ├── lab-cenario-contoso.md       # Cenario interconectado
        ├── lab-iac-powershell.md        # Variante PowerShell
        ├── lab-iac-arm.md               # Variante ARM Templates
        ├── lab-iac-bicep.md             # Variante Bicep
        ├── simulado-backup-monitoring.md      # 18 questoes (sem respostas)
        └── simulado-backup-monitoring-solucao.md  # Gabarito comentado
```

## Material Disponivel

| Recurso                  | Quantidade   |
| ------------------------ | ------------ |
| Video-aulas documentadas | 22 videos    |
| MS Learn - Roteiros      | 6 roteiros   |
| MS Learn - Modulos       | 28 modulos   |
| Labs praticos            | 14 labs      |
| Guias de estudo          | 3 documentos |

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

### Ordem dos labs

```
Bloco 1: iam-gov-net (Dominios 1 e 4)
  1. lab-blocos-independentes.md    → Primeira passagem (conceitos via Portal)
  2. lab-cenario-contoso.md         → Segunda passagem (cenario interconectado)
  3. lab-iac-powershell.md  ─┐
  4. lab-iac-bicep.md        ├──── Escolha 1+ para praticar IaC
  5. lab-iac-arm.md         ─┘
  6. simulado-iam-gov-net.md       → Validacao final

Bloco 2: storage-compute (Dominios 2 e 3)
  1-6. Mesma sequencia acima com arquivos do storage-compute/
  7. simulado-storage-compute.md   → Validacao final

Bloco 3: backup-monitoring (Dominios 2 e 5)
  1-6. Mesma sequencia acima com arquivos do backup-monitoring/
  7. simulado-backup-monitoring.md → Validacao final
```

## Links Uteis

| Recurso               | URL                                                                                                  |
| --------------------- | ---------------------------------------------------------------------------------------------------- |
| Guia oficial do exame | https://learn.microsoft.com/pt-br/credentials/certifications/resources/study-guides/az-104           |
| Curso AZ-104T00       | https://learn.microsoft.com/pt-br/training/courses/az-104t00                                         |
| Simulado oficial      | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/practice/assessment |
| Agendar exame         | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/                    |
| Area restrita (demo)  | https://aka.ms/examdemo                                                                              |

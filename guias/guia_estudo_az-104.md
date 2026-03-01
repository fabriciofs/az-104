# Guia de Estudo - Exame AZ-104: Administrador do Microsoft Azure

> **Versão das habilidades medidas:** 18 de abril de 2025

---

## Objetivo do Documento

Este guia de estudo explica o que esperar do exame AZ-104 e inclui:

- Resumo dos tópicos abordados
- Links para recursos adicionais
- Informações e materiais para ajudar na preparação

---

## Informações Gerais do Exame

| Item                     | Descrição                                                          |
| ------------------------ | ------------------------------------------------------------------ |
| **Pontuação mínima**     | 700 pontos ou mais                                                 |
| **Tipo de certificação** | Associate (Associado)                                              |
| **Renovação**            | Anual (avaliação online gratuita no Microsoft Learn)               |
| **Idiomas disponíveis**  | Múltiplos (30 minutos extras disponíveis se não houver seu idioma) |

---

## Links Úteis

| Recurso                                                                                                                                                                                                             | Descrição                                         |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| [Como obter a certificação](https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/)                                                                                                      | Requisitos para certificação                      |
| [Renovação de certificação](https://learn.microsoft.com/pt-br/credentials/certifications/renew-your-microsoft-certification)                                                                                        | Processo de renovação anual gratuita              |
| [Perfil Microsoft Learn](https://learn.microsoft.com/pt-br/users/)                                                                                                                                                  | Agendar/renovar exames, compartilhar certificados |
| [Pontuação e relatórios](https://learn.microsoft.com/pt-br/credentials/certifications/exam-scoring-reports)                                                                                                         | Sistema de pontuação                              |
| [Área restrita do exame](https://aka.ms/examdemo)                                                                                                                                                                   | Ambiente virtual para familiarização              |
| [Solicitação de acomodações](https://learn.microsoft.com/pt-br/credentials/certifications/request-accommodations)                                                                                                   | Tempo extra ou modificações                       |
| [Avaliação simulada gratuita](https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/practice/assessment?assessment-type=practice&assessmentId=21&practice-assessment-type=certification) | Perguntas de prática                              |

---

## Perfil do Público-Alvo

### Experiência Necessária

O candidato deve ter experiência em:

- Implementação, gerenciamento e monitoramento do ambiente Microsoft Azure
- Redes virtuais, armazenamento, computação, identidade, segurança e governança

### Conhecimentos Esperados

**Familiaridade com:**

- Sistemas operacionais
- Redes
- Servidores
- Virtualização

**Experiência prática com:**

- PowerShell
- CLI do Azure
- Portal do Azure
- Modelos do Azure Resource Manager (ARM)
- Microsoft Entra ID

### Papel do Administrador do Azure

- Geralmente faz parte de uma equipe maior para implementação de infraestrutura de nuvem
- Coordena com outras funções: rede, segurança, banco de dados, desenvolvimento de aplicativos e DevOps

---

## Distribuição das Habilidades Medidas

| Domínio                                               | Peso    |
| ----------------------------------------------------- | ------- |
| Gerenciar identidades e governança do Azure           | 20%–25% |
| Implementar e gerenciar o armazenamento               | 15%–20% |
| Implantar e gerenciar recursos de computação do Azure | 20%–25% |
| Implementar e gerenciar redes virtuais                | 15%–20% |
| Monitorar e manter os recursos do Azure               | 10%–15% |

---

## Domínio 1: Gerenciar Identidades e Governança do Azure (20%–25%)

### 1.1 Gerenciar Usuários e Grupos do Microsoft Entra

- Criar usuários e grupos
- Gerenciar propriedades do usuário e do grupo
- Gerenciar licenças no Microsoft Entra ID
- Gerenciar usuários externos
- Configurar SSPR (Redefinição de Senha por Autoatendimento)

### 1.2 Gerenciar o Acesso aos Recursos do Azure

- Gerenciar funções internas do Azure (RBAC)
- Atribuir funções em escopos diferentes
- Interpretar atribuições de acesso

### 1.3 Gerenciar Assinaturas e Governança do Azure

- Implementar e gerenciar o Azure Policy
- Configurar bloqueios de recursos
- Aplicar e gerenciar marcas (tags) em recursos
- Gerenciar grupos de recursos
- Gerenciar assinaturas
- Gerenciar custos usando alertas, orçamentos e recomendações do Assistente do Azure
- Configurar grupos de gerenciamento

---

## Domínio 2: Implementar e Gerenciar o Armazenamento (15%–20%)

### 2.1 Configurar o Acesso ao Armazenamento

- Configurar redes virtuais e firewalls do Armazenamento do Azure
- Criar e usar tokens SAS (Assinatura de Acesso Compartilhado)
- Configurar políticas de acesso armazenadas
- Gerenciar chaves de acesso
- Configurar o acesso baseado em identidade para Arquivos do Azure

### 2.2 Configurar e Gerenciar Contas de Armazenamento

- Criar e configurar contas de armazenamento
- Configurar a redundância do Armazenamento do Azure
- Configurar a replicação de objeto
- Configurar a criptografia de conta de armazenamento
- Gerenciar dados usando o Gerenciador de Armazenamento do Azure e AzCopy

### 2.3 Configurar Arquivos do Azure e Armazenamento de Blobs

- Criar e configurar um compartilhamento de arquivos no Armazenamento do Azure
- Criar e configurar um contêiner no Armazenamento de Blobs
- Configurar camadas de armazenamento (tiers)
- Configurar a exclusão reversível (soft delete) para blobs e contêineres
- Configurar instantâneos e exclusão temporária para Arquivos do Azure
- Configurar o gerenciamento do ciclo de vida de blobs
- Configurar o controle de versão de blobs

---

## Domínio 3: Implantar e Gerenciar Recursos de Computação (20%–25%)

### 3.1 Automatizar Implantação de Recursos (ARM/Bicep)

- Interpretar um modelo Azure Resource Manager ou arquivo Bicep
- Modificar um modelo ARM existente
- Modificar um arquivo Bicep existente
- Implantar recursos usando modelo ARM ou arquivo Bicep
- Exportar implantação como modelo ARM ou converter para Bicep

### 3.2 Criar e Configurar Máquinas Virtuais

- Criar uma máquina virtual
- Configurar o Azure Disk Encryption
- Mover VM para outro grupo de recursos, assinatura ou região
- Gerenciar tamanhos de máquinas virtuais
- Gerenciar discos de máquinas virtuais
- Implantar VMs em zonas de disponibilidade e conjuntos de disponibilidade
- Implantar e configurar Conjuntos de Dimensionamento de Máquinas Virtuais (VMSS)

### 3.3 Provisionar e Gerenciar Contêineres

- Criar e gerenciar um registro de contêiner do Azure (ACR)
- Provisionar um contêiner usando Instâncias de Contêiner do Azure (ACI)
- Provisionar um contêiner usando Aplicativos de Contêiner do Azure
- Gerenciar dimensionamento e escala para contêineres (ACI e Container Apps)

### 3.4 Criar e Configurar o Serviço de Aplicativo do Azure

- Provisionar um plano do Serviço de Aplicativo
- Configurar a escala para um Plano do Serviço de Aplicativo
- Criar um Serviço de Aplicativo
- Configurar certificados e TLS para um serviço de aplicativo
- Mapear um nome DNS personalizado existente para um Serviço de Aplicativo
- Configurar backup para um Serviço de Aplicativo
- Definir configurações de rede para um serviço de aplicativo
- Configurar slots de implantação para um Serviço de Aplicativo

---

## Domínio 4: Implementar e Gerenciar Redes Virtuais (15%–20%)

### 4.1 Configurar e Gerenciar Redes Virtuais no Azure

- Criar e configurar redes virtuais e sub-redes
- Criar e configurar emparelhamento de rede virtual (VNet Peering)
- Configurar endereços IP públicos
- Configurar rotas de rede definidas pelo usuário (UDR)
- Solucionar problemas de conectividade de rede

### 4.2 Configurar Acesso Seguro às Redes Virtuais

- Criar e configurar NSGs (Grupos de Segurança de Rede) e ASGs (Grupos de Segurança de Aplicativo)
- Avaliar regras de segurança efetivas nos NSGs
- Implementar o Azure Bastion
- Configurar pontos de extremidade de serviço (Service Endpoints) para PaaS do Azure
- Configurar pontos de extremidade privados (Private Endpoints) para PaaS do Azure

### 4.3 Configurar Resolução de Nomes e Balanceamento de Carga

- Configurar o DNS do Azure
- Configurar um balanceador de carga interno ou público
- Solucionar problemas de balanceamento de carga

---

## Domínio 5: Monitorar e Manter Recursos do Azure (10%–15%)

### 5.1 Monitorar Recursos no Azure

- Interpretar métricas no Azure Monitor
- Definir configurações de log no Azure Monitor
- Consultar e analisar logs no Azure Monitor
- Configurar regras de alerta, grupos de ações e regras de processamento de alertas
- Configurar e interpretar monitoramento de VMs, contas de armazenamento e redes usando Azure Monitor Insights
- Usar o Observador de Rede (Network Watcher) e Monitor da Conexão do Azure

### 5.2 Implementar Backup e Recuperação

- Criar um cofre dos Serviços de Recuperação
- Criar um cofre de Backup do Azure
- Criar e configurar uma política de backup
- Executar operações de backup e restauração usando o Backup do Azure
- Configurar o Azure Site Recovery para recursos do Azure
- Executar failover para uma região secundária usando o Site Recovery
- Configurar e interpretar relatórios e alertas para backups

---

## Recursos de Estudo Recomendados

### Treinamento

| Recurso                                | Link                                                                                                                                                       |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Módulos e roteiros de aprendizagem     | [Escolher entre módulos individuais ou curso com instrutor](https://learn.microsoft.com/pt-br/credentials/certifications/exams/az-104#two-ways-to-prepare) |
| Roteiro AZ-104: Armazenamento no Azure | [Training](https://learn.microsoft.com/pt-br/training/paths/az-104-manage-storage/)                                                                        |

### Documentação Oficial

| Tópico                       | Link                                                                                                            |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Documentação do Azure        | [Azure Docs](https://learn.microsoft.com/pt-br/azure/?product=featured)                                         |
| Microsoft Entra ID           | [Entra ID Docs](https://learn.microsoft.com/pt-br/azure/active-directory/)                                      |
| Azure Policy                 | [Policy Docs](https://learn.microsoft.com/pt-br/azure/governance/policy/)                                       |
| Armazenamento do Azure       | [Storage Docs](https://learn.microsoft.com/pt-br/azure/storage/)                                                |
| Gerenciador de Armazenamento | [Storage Explorer](https://learn.microsoft.com/pt-br/azure/vs-azure-tools-storage-manage-with-storage-explorer) |
| Armazenamento de Blobs       | [Blob Storage Docs](https://learn.microsoft.com/pt-br/azure/storage/blobs/)                                     |
| Modelos ARM                  | [ARM Templates](https://learn.microsoft.com/pt-br/azure/azure-resource-manager/templates/)                      |
| Instâncias de Contêiner      | [ACI Docs](https://learn.microsoft.com/pt-br/azure/container-instances/)                                        |
| Aplicativos de Contêiner     | [Container Apps Docs](https://learn.microsoft.com/pt-br/azure/container-apps/)                                  |
| Serviço de Aplicativo        | [App Service Docs](https://learn.microsoft.com/pt-br/azure/app-service/)                                        |
| DNS do Azure                 | [Azure DNS Docs](https://learn.microsoft.com/pt-br/azure/dns/)                                                  |
| Azure Bastion                | [Bastion Docs](https://learn.microsoft.com/pt-br/azure/bastion/)                                                |
| Gateway de Aplicativo        | [App Gateway Docs](https://learn.microsoft.com/pt-br/azure/application-gateway/)                                |
| Azure Monitor                | [Monitor Docs](https://learn.microsoft.com/pt-br/azure/azure-monitor/)                                          |
| Observador de Rede           | [Network Watcher Docs](https://learn.microsoft.com/pt-br/azure/network-watcher/)                                |
| Azure Site Recovery          | [Site Recovery Docs](https://learn.microsoft.com/pt-br/azure/site-recovery/)                                    |
| Backup do Azure              | [Backup Docs](https://learn.microsoft.com/pt-br/azure/backup/)                                                  |

### Comunidade e Suporte

| Recurso                        | Link                                                                                         |
| ------------------------------ | -------------------------------------------------------------------------------------------- |
| Microsoft Q&A                  | [Perguntas e Respostas](https://learn.microsoft.com/pt-br/answers/products/)                 |
| Suporte da Comunidade Azure    | [Azure Community](https://azure.microsoft.com/support/community/)                            |
| Microsoft Learn Tech Community | [Tech Community](https://techcommunity.microsoft.com/t5/microsoft-learn/ct-p/MicrosoftLearn) |

### Vídeos

| Recurso                          | Link                                                                                             |
| -------------------------------- | ------------------------------------------------------------------------------------------------ |
| Zona de Preparação para o Exame  | [Exam Readiness Zone](https://learn.microsoft.com/pt-br/shows/exam-readiness-zone/?terms=az-104) |
| Sextas-feiras do Azure           | [Azure Friday](https://azure.microsoft.com/resources/videos/azure-friday/)                       |
| Outros Programas Microsoft Learn | [Browse Shows](https://learn.microsoft.com/pt-br/shows/browse)                                   |

---

## Log de Alterações

### Atualização de 18 de abril de 2025

| Área Anterior                                         | Área Atual                                            | Mudança           |
| ----------------------------------------------------- | ----------------------------------------------------- | ----------------- |
| Implementar e gerenciar o armazenamento               | Implementar e gerenciar o armazenamento               | Nenhuma alteração |
| Configurar Arquivos do Azure e Armazenamento de Blobs | Configurar Arquivos do Azure e Armazenamento de Blobs | Secundária        |

---

## Observações Importantes

1. **Formato do Exame:** A maioria das perguntas aborda recursos em GA (disponibilidade geral), mas pode incluir perguntas sobre recursos em Versão Prévia se forem comumente usados.

2. **Atualização dos Exames:** A versão em inglês é sempre atualizada primeiro. Versões localizadas são atualizadas aproximadamente 8 semanas após.

3. **Tempo Extra:** Se o exame não estiver disponível no seu idioma preferencial, você pode solicitar 30 minutos adicionais.

4. **Prática:** É altamente recomendado obter experiência prática antes de fazer o exame, combinando estudo teórico com laboratórios hands-on.

---

## Resumo Visual das Competências

```
AZ-104: Administrador do Microsoft Azure
├── Identidades e Governança (20-25%)
│   ├── Microsoft Entra ID (usuários, grupos, licenças, SSPR)
│   ├── RBAC (funções, escopos, atribuições)
│   └── Governança (Policy, bloqueios, tags, custos)
│
├── Armazenamento (15-20%)
│   ├── Acesso (firewalls, SAS, chaves)
│   ├── Contas (redundância, replicação, criptografia)
│   └── Blobs/Files (tiers, soft delete, lifecycle)
│
├── Computação (20-25%)
│   ├── ARM/Bicep (templates, implantação)
│   ├── VMs (criação, discos, VMSS, zonas)
│   ├── Contêineres (ACR, ACI, Container Apps)
│   └── App Service (planos, slots, TLS, backup)
│
├── Redes Virtuais (15-20%)
│   ├── VNets (sub-redes, peering, IPs, rotas)
│   ├── Segurança (NSG, ASG, Bastion, endpoints)
│   └── DNS e Load Balancer
│
└── Monitoramento (10-15%)
    ├── Azure Monitor (métricas, logs, alertas)
    └── Backup/Recovery (cofres, políticas, Site Recovery)
```

---

**Boa sorte nos estudos e no exame!**

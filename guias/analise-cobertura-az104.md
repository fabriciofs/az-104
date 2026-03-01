# Análise de Cobertura - Material AZ-104 vs Requisitos do Exame

> **Objetivo:** Mapear o material disponível contra os requisitos oficiais do exame AZ-104

---

## Visão Geral do Exame AZ-104

| Aspecto                | Detalhe                                            |
| ---------------------- | -------------------------------------------------- |
| **Nome**               | Microsoft Certified: Azure Administrator Associate |
| **Código**             | AZ-104                                             |
| **Pontuação Mínima**   | 700 de 1000 pontos                                 |
| **Nível**              | Associate (Intermediário)                          |
| **Número de Questões** | 40-60 questões                                     |

---

## Distribuição dos Domínios

| #   | Domínio                                      | Peso   |
| --- | -------------------------------------------- | ------ |
| 1   | Gerenciar identidades e governança do Azure  | 20-25% |
| 2   | Implementar e gerenciar o armazenamento      | 15-20% |
| 3   | Implantar e gerenciar recursos de computação | 20-25% |
| 4   | Implementar e gerenciar redes virtuais       | 15-20% |
| 5   | Monitorar e manter os recursos do Azure      | 10-15% |

---

## Material Disponível

### Recursos de Estudo

| Recurso                 | Quantidade  |
| ----------------------- | ----------- |
| **Playlist YouTube**    | 22 vídeos   |
| **MS Learn - Roteiros** | 6 roteiros  |
| **MS Learn - Módulos**  | 28 módulos  |
| **Labs Práticos**       | 14 labs     |
| **Guia de Estudos**     | 1 documento |

---

## Domínio 1: Gerenciar Identidades e Governança (20-25%)

### Tópicos do Exame

| Tópico                                     | Playlist   | MS Learn   | Labs    | Status |
| ------------------------------------------ | ---------- | ---------- | ------- | ------ |
| **1.1 Gerenciar Usuários e Grupos**        |            |            |         |        |
| Criar usuários e grupos                    | Vídeos 3-4 | Módulo 2.2 | Lab 01  | ✅      |
| Gerenciar propriedades do usuário          | Vídeos 3-4 | Módulo 2.2 | Lab 01  | ✅      |
| Gerenciar licenças no Entra ID             | Vídeo 4    | Módulo 2.2 | Lab 01  | ✅      |
| Gerenciar usuários externos                | Vídeo 4    | Módulo 2.2 | Lab 01  | ✅      |
| Configurar SSPR                            | Vídeo 5    | Módulo 2.6 | -       | ✅      |
| **1.2 Gerenciar Acesso aos Recursos**      |            |            |         |        |
| Gerenciar funções Azure (RBAC)             | Vídeo 6    | Módulo 2.5 | Lab 02a | ✅      |
| Atribuir funções em escopos                | Vídeo 6    | Módulo 2.5 | Lab 02a | ✅      |
| Interpretar atribuições de acesso          | Vídeo 6    | Módulo 2.5 | Lab 02a | ✅      |
| **1.3 Gerenciar Assinaturas e Governança** |            |            |         |        |
| Implementar Azure Policy                   | Vídeo 7    | Módulo 2.4 | Lab 02b | ✅      |
| Configurar bloqueios de recursos           | Vídeo 7    | Módulo 2.4 | Lab 02b | ✅      |
| Aplicar e gerenciar tags                   | Vídeo 7    | Módulo 2.4 | Lab 02b | ✅      |
| Gerenciar resource groups                  | Vídeo 7    | Módulo 2.3 | Lab 02b | ✅      |
| Gerenciar assinaturas                      | Vídeo 7    | Módulo 2.3 | Lab 02a | ✅      |
| Gerenciar custos (alertas, orçamentos)     | Vídeo 7    | Módulo 3.1 | -       | ✅      |
| Configurar management groups               | Vídeo 7    | Módulo 2.4 | Lab 02a | ✅      |

**Cobertura Domínio 1:** 100%

---

## Domínio 2: Implementar e Gerenciar Armazenamento (15-20%)

### Tópicos do Exame

| Tópico                                        | Playlist   | MS Learn   | Labs   | Status |
| --------------------------------------------- | ---------- | ---------- | ------ | ------ |
| **2.1 Configurar Acesso ao Armazenamento**    |            |            |        |        |
| Configurar firewalls de Storage               | Vídeos 8-9 | Módulo 4.3 | Lab 07 | ✅      |
| Criar e usar tokens SAS                       | Vídeos 8-9 | Módulo 4.3 | Lab 07 | ✅      |
| Configurar políticas de acesso                | Vídeos 8-9 | Módulo 4.3 | Lab 07 | ✅      |
| Gerenciar chaves de acesso                    | Vídeos 8-9 | Módulo 4.3 | Lab 07 | ✅      |
| Acesso baseado em identidade (Files)          | Vídeo 10   | Módulo 4.4 | Lab 07 | ✅      |
| **2.2 Configurar Storage Accounts**           |            |            |        |        |
| Criar e configurar storage accounts           | Vídeo 8    | Módulo 4.1 | Lab 07 | ✅      |
| Configurar redundância                        | Vídeo 8    | Módulo 4.1 | Lab 07 | ✅      |
| Configurar replicação de objeto               | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |
| Configurar criptografia                       | Vídeo 8    | Módulo 4.1 | Lab 07 | ✅      |
| Gerenciar com Storage Explorer/AzCopy         | Vídeos 8-9 | Módulo 4.2 | Lab 07 | ✅      |
| **2.3 Configurar Azure Files e Blob Storage** |            |            |        |        |
| Criar file shares                             | Vídeo 10   | Módulo 4.4 | Lab 07 | ✅      |
| Criar containers de blob                      | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |
| Configurar camadas de acesso                  | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |
| Configurar soft delete                        | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |
| Configurar snapshots                          | Vídeo 10   | Módulo 4.4 | Lab 07 | ✅      |
| Configurar lifecycle management               | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |
| Configurar blob versioning                    | Vídeo 9    | Módulo 4.2 | Lab 07 | ✅      |

**Cobertura Domínio 2:** 100%

---

## Domínio 3: Implantar e Gerenciar Recursos de Computação (20-25%)

### Tópicos do Exame

| Tópico                                      | Playlist     | MS Learn   | Labs    | Status |
| ------------------------------------------- | ------------ | ---------- | ------- | ------ |
| **3.1 Automatizar Implantação (ARM/Bicep)** |              |            |         |        |
| Interpretar templates ARM/Bicep             | Vídeo 11     | Módulo 1.3 | Lab 03  | ✅      |
| Modificar templates existentes              | Vídeo 11     | Módulo 1.3 | Lab 03  | ✅      |
| Implantar recursos via templates            | Vídeo 11     | Módulo 1.3 | Lab 03  | ✅      |
| Exportar implantação como template          | Vídeo 11     | Módulo 1.3 | Lab 03  | ✅      |
| **3.2 Criar e Configurar VMs**              |              |            |         |        |
| Criar uma máquina virtual                   | Vídeos 12-13 | Módulo 5.1 | Lab 08  | ✅      |
| Configurar Azure Disk Encryption            | Vídeo 13     | Módulo 5.1 | Lab 08  | ✅      |
| Mover VM entre RGs/subscriptions            | Vídeo 13     | Módulo 5.1 | Lab 08  | ✅      |
| Gerenciar tamanhos de VM                    | Vídeo 13     | Módulo 5.2 | Lab 08  | ✅      |
| Gerenciar discos de VM                      | Vídeo 13     | Módulo 5.1 | Lab 08  | ✅      |
| Implantar VMs em zonas/availability sets    | Vídeo 13     | Módulo 5.2 | Lab 08  | ✅      |
| Configurar VM Scale Sets                    | Vídeo 14     | Módulo 5.2 | Lab 08  | ✅      |
| **3.3 Provisionar Contêineres**             |              |            |         |        |
| Criar Azure Container Registry              | Vídeo 15     | Módulo 5.5 | Lab 09b | ✅      |
| Provisionar ACI                             | Vídeo 15     | Módulo 5.5 | Lab 09b | ✅      |
| Provisionar Container Apps                  | Vídeo 15     | Módulo 5.5 | Lab 09c | ✅      |
| Gerenciar scaling de containers             | Vídeo 15     | Módulo 5.5 | Lab 09c | ✅      |
| **3.4 Configurar App Service**              |              |            |         |        |
| Provisionar App Service Plan                | Vídeo 16     | Módulo 5.3 | Lab 09a | ✅      |
| Configurar scaling do App Service           | Vídeo 16     | Módulo 5.3 | Lab 09a | ✅      |
| Criar App Service                           | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |
| Configurar certificados e TLS               | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |
| Mapear domínio personalizado                | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |
| Configurar backup do App Service            | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |
| Configurar rede do App Service              | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |
| Configurar slots de implantação             | Vídeo 16     | Módulo 5.4 | Lab 09a | ✅      |

**Cobertura Domínio 3:** 100%

---

## Domínio 4: Implementar e Gerenciar Redes Virtuais (15-20%)

### Tópicos do Exame

| Tópico                                 | Playlist | MS Learn   | Labs   | Status |
| -------------------------------------- | -------- | ---------- | ------ | ------ |
| **4.1 Configurar Redes Virtuais**      |          |            |        |        |
| Criar VNets e subnets                  | Vídeo 17 | Módulo 3.1 | Lab 04 | ✅      |
| Configurar VNet Peering                | Vídeo 17 | Módulo 3.4 | Lab 05 | ✅      |
| Configurar IPs públicos                | Vídeo 17 | Módulo 3.1 | Lab 04 | ✅      |
| Configurar UDR (rotas)                 | Vídeo 18 | Módulo 3.5 | Lab 06 | ✅      |
| Solucionar problemas de rede           | Vídeo 18 | Módulo 3.8 | Lab 04 | ✅      |
| **4.2 Configurar Acesso Seguro**       |          |            |        |        |
| Criar NSGs e ASGs                      | Vídeo 17 | Módulo 3.2 | Lab 04 | ✅      |
| Avaliar regras de segurança            | Vídeo 17 | Módulo 3.2 | Lab 04 | ✅      |
| Implementar Azure Bastion              | Vídeo 18 | Módulo 3.2 | Lab 04 | ✅      |
| Configurar Service Endpoints           | Vídeo 18 | Módulo 3.2 | Lab 04 | ✅      |
| Configurar Private Endpoints           | Vídeo 18 | Módulo 3.2 | Lab 04 | ✅      |
| **4.3 Configurar DNS e Load Balancer** |          |            |        |        |
| Configurar Azure DNS                   | Vídeo 19 | Módulo 3.3 | Lab 04 | ✅      |
| Configurar Load Balancer               | Vídeo 19 | Módulo 3.6 | Lab 06 | ✅      |
| Solucionar problemas de load balancing | Vídeo 19 | Módulo 3.6 | Lab 06 | ✅      |

**Cobertura Domínio 4:** 100%

---

## Domínio 5: Monitorar e Manter Recursos (10-15%)

### Tópicos do Exame

| Tópico                                   | Playlist | MS Learn   | Labs   | Status |
| ---------------------------------------- | -------- | ---------- | ------ | ------ |
| **5.1 Monitorar Recursos**               |          |            |        |        |
| Interpretar métricas no Azure Monitor    | Vídeo 20 | Módulo 6.1 | Lab 11 | ✅      |
| Configurar logs no Azure Monitor         | Vídeo 20 | Módulo 6.1 | Lab 11 | ✅      |
| Consultar e analisar logs                | Vídeo 20 | Módulo 6.1 | Lab 11 | ✅      |
| Configurar alertas e action groups       | Vídeo 20 | Módulo 6.1 | Lab 11 | ✅      |
| Configurar VM Insights                   | Vídeo 20 | Módulo 6.1 | Lab 11 | ✅      |
| Usar Network Watcher                     | Vídeo 20 | Módulo 3.8 | Lab 11 | ✅      |
| **5.2 Implementar Backup e Recuperação** |          |            |        |        |
| Criar Recovery Services Vault            | Vídeo 21 | Módulo 6.2 | Lab 10 | ✅      |
| Criar Backup Vault                       | Vídeo 21 | Módulo 6.2 | Lab 10 | ✅      |
| Criar e configurar política de backup    | Vídeo 21 | Módulo 6.2 | Lab 10 | ✅      |
| Executar backup e restore                | Vídeo 21 | Módulo 6.2 | Lab 10 | ✅      |
| Configurar Azure Site Recovery           | Vídeo 22 | Módulo 6.2 | Lab 10 | ✅      |
| Executar failover                        | Vídeo 22 | Módulo 6.2 | Lab 10 | ✅      |
| Configurar relatórios de backup          | Vídeo 22 | Módulo 6.2 | Lab 10 | ✅      |

**Cobertura Domínio 5:** 100%

---

## Resumo da Cobertura

| Domínio                     | Peso   | Cobertura Vídeos | Cobertura MS Learn | Cobertura Labs |
| --------------------------- | ------ | ---------------- | ------------------ | -------------- |
| 1. Identidades e Governança | 20-25% | ✅ 100%           | ✅ 100%             | ✅ 100%         |
| 2. Armazenamento            | 15-20% | ✅ 100%           | ✅ 100%             | ✅ 100%         |
| 3. Computação               | 20-25% | ✅ 100%           | ✅ 100%             | ✅ 100%         |
| 4. Redes Virtuais           | 15-20% | ✅ 100%           | ✅ 100%             | ✅ 100%         |
| 5. Monitoramento            | 10-15% | ✅ 100%           | ✅ 100%             | ✅ 100%         |

### Cobertura Total: 100%

---

## Mapeamento de Recursos por Vídeo

| Vídeo | Título Estimado              | Domínio Principal |
| ----- | ---------------------------- | ----------------- |
| 1     | Prévia do Curso              | Introdução        |
| 2     | Course Introduction          | Introdução        |
| 3     | Microsoft Entra ID (Parte 1) | Domínio 1         |
| 4     | Microsoft Entra ID (Parte 2) | Domínio 1         |
| 5     | SSPR                         | Domínio 1         |
| 6     | RBAC                         | Domínio 1         |
| 7     | Azure Policy e Governança    | Domínio 1         |
| 8     | Storage Accounts             | Domínio 2         |
| 9     | Blob Storage                 | Domínio 2         |
| 10    | Azure Files                  | Domínio 2         |
| 11    | ARM Templates e Bicep        | Domínio 3         |
| 12-13 | Virtual Machines             | Domínio 3         |
| 14    | VM Scale Sets                | Domínio 3         |
| 15    | Containers                   | Domínio 3         |
| 16    | App Service                  | Domínio 3         |
| 17    | Virtual Networks             | Domínio 4         |
| 18    | Network Security             | Domínio 4         |
| 19    | DNS e Load Balancer          | Domínio 4         |
| 20    | Azure Monitor                | Domínio 5         |
| 21    | Azure Backup                 | Domínio 5         |
| 22    | Site Recovery                | Domínio 5         |

---

## Mapeamento Labs Oficiais → Labs Hands-on do Repositorio

| Lab Oficial | Descricao                        | Bloco do Repositorio           | Diretorio              |
| ----------- | -------------------------------- | ------------------------------ | ---------------------- |
| Lab 01      | Manage Entra ID Identities       | Bloco 1 - Identity             | `labs/1-iam-gov-net/`    |
| Lab 02a     | Manage Subscriptions and RBAC    | Bloco 2 - Governance           | `labs/1-iam-gov-net/`    |
| Lab 02b     | Manage Governance via Policy     | Bloco 2 - Governance           | `labs/1-iam-gov-net/`    |
| Lab 03      | Manage Azure Resources (IaC)     | Bloco 3 - IaC                  | `labs/1-iam-gov-net/`    |
| Lab 04      | Manage Virtual Networking        | Bloco 4 - Networking           | `labs/1-iam-gov-net/`    |
| Lab 05      | Manage Intersite Connectivity    | Bloco 5 - Connectivity         | `labs/1-iam-gov-net/`    |
| Lab 06      | Manage Network Traffic           | Bloco 5 - Connectivity         | `labs/1-iam-gov-net/`    |
| Lab 07      | Manage Azure Storage             | Bloco 1 - Storage              | `labs/2-storage-compute/`|
| Lab 08      | Manage Virtual Machines          | Bloco 2 - VMs                  | `labs/2-storage-compute/`|
| Lab 09a     | Manage Web Apps                  | Bloco 3 - Web Apps             | `labs/2-storage-compute/`|
| Lab 09b     | Manage Container Instances       | Bloco 4 - ACI                  | `labs/2-storage-compute/`|
| Lab 09c     | Manage Container Apps            | Bloco 5 - Container Apps       | `labs/2-storage-compute/`|
| Lab 10      | Manage Data Protection           | Blocos 1-3 - Backup/Recovery   | `labs/3-backup-monitoring/`|
| Lab 11      | Manage Monitoring                | Blocos 4-5 - Monitor/Analytics | `labs/3-backup-monitoring/`|

---

## Recursos Adicionais Recomendados

### Para Aprofundamento

| Recurso                | Quando Usar                             |
| ---------------------- | --------------------------------------- |
| **Documentação Azure** | Dúvidas específicas sobre serviços      |
| **Azure Fridays**      | Vídeos curtos sobre tópicos específicos |
| **Microsoft Q&A**      | Perguntas da comunidade                 |
| **Simulados Oficiais** | Avaliação antes do exame                |

### Links Importantes

| Recurso                | URL                                                                                                  |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| Avaliação Simulada     | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/practice/assessment |
| Área Restrita do Exame | https://aka.ms/examdemo                                                                              |
| Agendar Exame          | https://learn.microsoft.com/pt-br/credentials/certifications/azure-administrator/                    |

---

## Recomendações de Estudo

### Ordem Sugerida

1. **Semana 1-2:** Domínio 1 (Identidades) + Domínio 2 (Armazenamento)
2. **Semana 3-4:** Domínio 3 (Computação)
3. **Semana 5:** Domínio 4 (Redes)
4. **Semana 6:** Domínio 5 (Monitoramento)
5. **Semana 7:** Revisão + Simulados

### Para Cada Domínio

1. Assistir vídeos da playlist
2. Completar módulos do MS Learn
3. Fazer labs práticos
4. Revisar documentação
5. Fazer perguntas de prática

---

## Conclusão

O material disponível na pasta `az-104/` oferece **cobertura completa** de todos os domínios do exame AZ-104. A combinação de:

- **22 vídeos** da playlist oficial
- **28 módulos** do Microsoft Learn
- **14 labs práticos**
- **Guias de estudo** detalhados

Fornece uma base sólida para aprovação no exame. A prática hands-on com os labs é essencial para consolidar o conhecimento teórico.

---

*Análise gerada em 01/01/2026*

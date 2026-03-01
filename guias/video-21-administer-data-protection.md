# Video 21: Administer Data Protection AZ-104

## Informacoes Gerais

| Propriedade             | Valor                             |
| ----------------------- | --------------------------------- |
| **Titulo**              | Administer Data Protection AZ-104 |
| **Canal**               | Microsoft Learn                   |
| **Inscritos no Canal**  | 88,7 mil                          |
| **Visualizacoes**       | 2.800+                            |
| **Data de Publicacao**  | 4 de junho de 2025                |
| **Posicao na Playlist** | Episodio 21 de 22                 |
| **Idioma**              | Ingles                            |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=qIAjziOk9LU                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Este modulo aborda as estrategias e servicos de protecao de dados no Azure. Voce aprendera sobre Azure Backup, Recovery Services Vault, politicas de backup e Azure Site Recovery para garantir a continuidade dos negocios e recuperacao de desastres.

### O que voce aprendera

- Azure Backup e seus componentes
- Configuracao de Recovery Services Vault
- Politicas de backup e retencao
- Azure Site Recovery (ASR)
- Recuperacao de VMs e arquivos
- Soft delete e seguranca de backups

---

## Topicos Abordados

### 1. Azure Backup - Visao Geral

| Componente                  | Descricao                               |
| --------------------------- | --------------------------------------- |
| **Recovery Services Vault** | Container que armazena dados de backup  |
| **Backup Policy**           | Define frequencia e retencao            |
| **MARS Agent**              | Microsoft Azure Recovery Services Agent |
| **Backup Center**           | Gerenciamento centralizado de backups   |

### 2. O que pode ser feito backup

| Recurso              | Metodo                  |
| -------------------- | ----------------------- |
| **Azure VMs**        | Backup nativo via vault |
| **Azure Files**      | Snapshots via vault     |
| **SQL Server in VM** | Backup integrado        |
| **SAP HANA**         | Backup integrado        |
| **On-premises**      | MARS Agent ou MABS      |
| **Blobs**            | Operational backup      |

### 3. Recovery Services Vault

| Configuracao             | Descricao                                 |
| ------------------------ | ----------------------------------------- |
| **Storage Replication**  | LRS, GRS, ZRS                             |
| **Soft Delete**          | 14 dias de retencao apos delete           |
| **Cross Region Restore** | Restaurar em regiao secundaria (GRS)      |
| **Encryption**           | Platform-managed ou customer-managed keys |

### 4. Politicas de Backup

| Tipo de Backup  | Frequencia                           |
| --------------- | ------------------------------------ |
| **Full**        | Diario ou semanal                    |
| **Incremental** | Somente mudancas desde ultimo backup |
| **Diferencial** | Mudancas desde ultimo full           |

#### Retencao

| Periodo     | Duracao Maxima |
| ----------- | -------------- |
| **Diario**  | 9999 dias      |
| **Semanal** | 5163 semanas   |
| **Mensal**  | 1188 meses     |
| **Anual**   | 99 anos        |

### 5. Azure Site Recovery (ASR)

| Cenario               | Descricao              |
| --------------------- | ---------------------- |
| **Azure to Azure**    | DR entre regioes Azure |
| **VMware to Azure**   | Migrar/DR de VMware    |
| **Hyper-V to Azure**  | Migrar/DR de Hyper-V   |
| **Physical to Azure** | Servidores fisicos     |

#### Componentes ASR

| Componente             | Funcao                      |
| ---------------------- | --------------------------- |
| **Replication Policy** | Define RPO e retention      |
| **Recovery Plan**      | Orquestra failover          |
| **Test Failover**      | Validar DR sem impacto      |
| **Failover**           | Ativacao do site secundario |
| **Failback**           | Retorno ao site primario    |

### 6. Recuperacao de Dados

| Tipo de Recuperacao      | Uso                                |
| ------------------------ | ---------------------------------- |
| **Restore VM**           | Criar nova VM do backup            |
| **Replace existing**     | Substituir disco da VM existente   |
| **Restore disks**        | Restaurar apenas discos            |
| **File recovery**        | Montar volume e recuperar arquivos |
| **Cross Region Restore** | Restaurar em regiao pareada        |

---

## Conceitos-Chave para o Exame

1. **Recovery Services Vault**

   - Deve estar na mesma regiao dos recursos (exceto CRR)
   - Suporta multiplos tipos de backup
   - Soft delete habilitado por padrao

2. **Storage Replication Types**

   - LRS: 3 copias no mesmo datacenter
   - GRS: 6 copias (3 local + 3 regiao pareada)
   - ZRS: 3 copias em zones diferentes

3. **RPO vs RTO**

   - RPO (Recovery Point Objective): Quanto dado pode perder
   - RTO (Recovery Time Objective): Tempo para recuperar

4. **Instant Restore**

   - VMs: Snapshots permitem restauracao rapida
   - Retencao padrao de 2 dias (max 5)

5. **Azure Site Recovery**
   - RPO minimo: 30 segundos para Azure-to-Azure
   - Test failover nao afeta producao
   - Replication nao e backup (diferentes propositos)

---

## Peso no Exame AZ-104

| Dominio                                       | Peso   |
| --------------------------------------------- | ------ |
| Monitorar e fazer backup de recursos do Azure | 10-15% |

Backup e recuperacao sao topicos essenciais para o exame e para operacoes reais.

---

## Recursos Complementares

| Recurso                     | Link                                                                                         |
| --------------------------- | -------------------------------------------------------------------------------------------- |
| **Azure Backup**            | https://learn.microsoft.com/en-us/azure/backup/                                              |
| **Recovery Services Vault** | https://learn.microsoft.com/en-us/azure/backup/backup-azure-recovery-services-vault-overview |
| **Azure Site Recovery**     | https://learn.microsoft.com/en-us/azure/site-recovery/                                       |

---

## Video Anterior

**Video 20:** Administer PaaS Compute Options (Part 2)

- Azure Container Instances
- Azure Kubernetes Service
- Azure Functions
- Comparacao de servicos

## Proximo Video

**Video 22:** Administer Monitoring AZ-104

- Azure Monitor
- Log Analytics
- Alertas e metricas
- Application Insights
- Network Watcher

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

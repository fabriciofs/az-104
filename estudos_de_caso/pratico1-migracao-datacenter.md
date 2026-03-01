# Exercicio Pratico 1 — Migracao de Datacenter para Azure

**Tipo:** Hands-on (executar no portal) | **Duracao:** ~3 horas | **Dominios:** D3 Compute + D4 Networking + D2 Storage + D5 Monitoring

> **Diferenca dos estudos de caso:**
> Este exercicio e **pratico** — voce vai desenhar, planejar e documentar uma arquitetura completa.
> Os estudos de caso (caso1 a caso5) testam **raciocinio** com questoes estilo exame.
> Faca este exercicio **apos** completar os labs e simulados dos blocos 2 e 3.

---

## Cenario

A **Contoso Ltd** possui um datacenter on-premises em Sao Paulo que precisa ser migrado para o Azure. A infraestrutura atual consiste em:

- **20 VMs Windows Server** — 12 web servers (IIS), 5 database servers (SQL Server), 3 application servers
- **5 VMs Linux** — 3 application servers (Node.js), 2 utility servers (cron jobs, scripts)
- **Storage:** 10 TB total — 6 TB em file shares (departamentais) + 4 TB em backups
- **Rede:** Segmentada em 3 VLANs:
  - VLAN 10: Frontend (web servers) — 192.168.10.0/24
  - VLAN 20: Backend (app + db servers) — 192.168.20.0/24
  - VLAN 30: Management (admin, backup) — 192.168.30.0/24

### Requisitos

- Regiao primaria: **Brazil South**
- Regiao de DR: **South Central US**
- Disponibilidade: **99.95%** para web servers
- RPO: **4 horas** | RTO: **8 horas**
- Orcamento: Moderado — priorizar custo-beneficio

---

## Tarefa 1 — Planejamento de Rede (45 min)

Desenhe a arquitetura de rede no Azure que substitua as 3 VLANs atuais.

### Entregaveis

1. **Diagrama de VNets e subnets** (pode ser ASCII, draw.io ou papel)
   - Quantas VNets voce criaria? Justifique.
   - Defina address spaces e subnets (com CIDRs)
   - Nomeie cada subnet de acordo com sua funcao

2. **Plano de NSGs**
   - Quais NSGs voce criaria?
   - Para cada NSG, liste pelo menos 3 regras inbound essenciais
   - Considere: separacao frontend/backend, acesso de gerenciamento, comunicacao entre tiers

3. **Conectividade**
   - Como os web servers vao receber trafego da internet?
   - Como o backend vai se comunicar com o frontend?
   - Voce usaria peering, ou tudo em uma unica VNet? Justifique.

### Criterios de avaliacao

- [ ] Address spaces nao se sobrepoe
- [ ] Subnets tem tamanho adequado (lembre dos 5 IPs reservados pelo Azure)
- [ ] NSGs seguem principio de least privilege
- [ ] Ha subnet separada para servicos gerenciados (Application Gateway, etc.)

---

## Tarefa 2 — Migracao de VMs (45 min)

Planeje a migracao das 25 VMs para o Azure.

### Entregaveis

1. **Tabela de sizing** — Para cada grupo de VMs, defina:

   | Grupo                 | Qtd | Serie/Tamanho sugerido | Justificativa |
   | --------------------- | --- | ---------------------- | ------------- |
   | Web servers (IIS)     | 12  | ?                      | ?             |
   | DB servers (SQL)      | 5   | ?                      | ?             |
   | App servers (Windows) | 3   | ?                      | ?             |
   | App servers (Linux)   | 3   | ?                      | ?             |
   | Utility servers       | 2   | ?                      | ?             |

2. **Estrategia de disponibilidade**
   - Quais VMs devem usar Availability Sets? Quais Availability Zones?
   - Algum grupo de VMs seria melhor como VMSS? Qual?
   - Qual SLA voce atingiria com a configuracao escolhida?

3. **Estrategia de migracao**
   - Quais VMs fariam lift-and-shift (rehost)?
   - Alguma VM seria candidata a modernizacao (replatform para PaaS)?
   - Os web servers IIS poderiam ser migrados para App Service? Quais trade-offs?

### Criterios de avaliacao

- [ ] Sizing adequado por workload (memoria para SQL, burstable para utility, etc.)
- [ ] Alta disponibilidade configurada para web servers (requisito 99.95%)
- [ ] Pelo menos 1 candidato a modernizacao identificado
- [ ] Custo justificado (nao usar VMs oversized)

---

## Tarefa 3 — Storage Migration (30 min)

Planeje a migracao dos 10 TB de dados.

### Entregaveis

1. **Storage Accounts** — Quantos e quais criar:

   | Storage Account | Tipo | Redundancia | Finalidade                  |
   | --------------- | ---- | ----------- | --------------------------- |
   | ?               | ?    | ?           | File shares departamentais  |
   | ?               | ?    | ?           | Backups                     |
   | ?               | ?    | ?           | Discos de VM (se aplicavel) |

2. **Azure Files vs Blob Storage**
   - Os 6 TB de file shares devem usar Azure Files ou Blob Storage? Justifique.
   - Qual tier de Azure Files voce usaria (Transaction Optimized, Hot, Cool)?
   - Como os usuarios acessariam os file shares? (SMB, REST, portal)

3. **Plano de transferencia**
   - Calcule o tempo de transferencia de 10 TB assumindo 500 Mbps de bandwidth
   - Qual ferramenta voce usaria? (AzCopy, Azure Data Box, Storage Explorer)
   - A transferencia pode ser feita durante horario comercial ou precisa ser fora do expediente?

### Criterios de avaliacao

- [ ] Redundancia proporcional a criticidade dos dados
- [ ] Azure Files escolhido para file shares (suporte SMB)
- [ ] Calculo de tempo de transferencia correto
- [ ] Ferramenta de migracao adequada ao volume

---

## Tarefa 4 — Backup e DR (30 min)

Configure a estrategia de protecao de dados.

### Entregaveis

1. **Recovery Services Vault**
   - Em qual regiao criar o vault?
   - Qual tipo de redundancia do vault (LRS vs GRS)?

2. **Politicas de backup**

   | Recurso                    | Frequencia | Retencao | Tipo |
   | -------------------------- | ---------- | -------- | ---- |
   | VMs de producao (web + db) | ?          | ?        | ?    |
   | VMs de dev/utility         | ?          | ?        | ?    |
   | Azure Files                | ?          | ?        | ?    |
   | SQL Server databases       | ?          | ?        | ?    |

3. **Plano de DR**
   - Quais VMs devem ser replicadas para South Central US via ASR?
   - Desenhe o fluxo de failover (o que acontece quando Brazil South cai)
   - Como voce testaria o plano de DR sem afetar producao?

### Criterios de avaliacao

- [ ] Vault com GRS para cenario de DR cross-region
- [ ] Backup mais frequente para recursos criticos (DB) do que para utility
- [ ] ASR configurado para VMs criticas com RPO <= 4h
- [ ] Test failover mencionado como validacao

---

## Tarefa 5 — Revisao e Documentacao (30 min)

### Entregaveis

1. **Diagrama final de arquitetura** — Consolide tudo em um unico diagrama:
   - VNets, subnets, NSGs
   - VMs com sizing
   - Storage Accounts
   - Recovery Services Vault
   - Conexoes (peering, gateway, etc.)

2. **Tabela de custos estimados** (use a calculadora do Azure):

   | Recurso    | Quantidade | SKU      | Custo mensal estimado |
   | ---------- | ---------- | -------- | --------------------- |
   | VMs        | 25         | Diversos | ?                     |
   | Storage    | 10 TB      | Diversos | ?                     |
   | Networking | —          | —        | ?                     |
   | Backup     | —          | —        | ?                     |
   | **Total**  | —          | —        | **?**                 |

3. **Lista de decisoes** — Documente pelo menos 5 decisoes arquiteturais que voce tomou e por que:
   - Ex: "Escolhi 1 VNet com 3 subnets em vez de 3 VNets porque..."
   - Ex: "Recomendei migrar web servers para App Service porque..."

### Criterios de avaliacao

- [ ] Diagrama completo e legivel
- [ ] Estimativa de custo realista
- [ ] Decisoes documentadas com justificativa
- [ ] Arquitetura atende os requisitos (disponibilidade, RPO/RTO, orcamento)

---

## Autoavaliacao

Apos completar, verifique:

| Criterio                                           | Atendido? |
| -------------------------------------------------- | --------- |
| Rede segmentada com NSGs adequados                 |           |
| VMs com sizing correto por workload                |           |
| Alta disponibilidade para web servers (99.95%)     |           |
| Storage com redundancia proporcional               |           |
| Backup configurado para todos os recursos criticos |           |
| DR com ASR para VMs criticas                       |           |
| Pelo menos 1 candidato a modernizacao (PaaS)       |           |
| Custo estimado e justificado                       |           |

**Labs relacionados:** `labs/1-iam-gov-net/cenario/bloco4-networking.md`, `labs/1-iam-gov-net/cenario/bloco5-connectivity.md`, `labs/2-storage-compute/cenario/bloco1-storage.md`, `labs/2-storage-compute/cenario/bloco2-vms.md`, `labs/3-backup-monitoring/cenario/bloco1-vm-backup.md`

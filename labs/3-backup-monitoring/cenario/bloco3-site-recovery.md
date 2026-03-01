> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 4 - Monitor & Alerts](bloco4-monitor.md)

# Bloco 3 - Site Recovery (DR)

**Origem:** Lab 10 (Site Recovery) + Disaster Recovery Planning
**Resource Groups utilizados:** `az104-rg-dr` (vault DR na regiao secundaria) + `az104-rg7` (VMs da Semana 2)

## Contexto

O backup (Blocos 1-2) protege contra perda de dados, mas nao garante disponibilidade em caso de falha regional. Agora voce configura **Azure Site Recovery (ASR)** para replicar VMs criticas da Semana 2 para uma regiao secundaria, criando um plano de DR completo.

## Diagrama

```
┌────────────────────────────────────────┐     ┌──────────────────────────────────────┐
│          East US (Primaria)            │     │         West US (DR)                 │
│                                        │     │                                      │
│  ┌──────────────────────────────────┐  │     │  ┌──────────────────────────────────┐│
│  │ az104-rg7 (Semana 2)            │  │     │  │ az104-rg-dr                      ││
│  │                                  │  │     │  │                                  ││
│  │ ┌──────────────┐                │  │     │  │ Recovery Services Vault:          ││
│  │ │az104-vm-win  │────replicacao──│──│─────│──│─► az104-rsv-dr                    ││
│  │ │(Windows)     │                │  │     │  │                                  ││
│  │ └──────────────┘                │  │     │  │ Replicated Items:                ││
│  │                                  │  │     │  │ ├─ az104-vm-win (replicada)      ││
│  │ VNet da Semana 1 ◄──────────────│──│─────│──│─► VNet DR (auto-created)          ││
│  │                                  │  │     │  │                                  ││
│  │ Storage (Semana 2) ◄────────────│──│─────│──│─► Cache Storage (auto-created)    ││
│  └──────────────────────────────────┘  │     │  │                                  ││
│                                        │     │  │ Recovery Plans:                  ││
│  az104-rg-backup (Bloco 1)            │     │  │ └─ contoso-recovery-plan          ││
│  └─ az104-rsv (backup local)          │     │  └──────────────────────────────────┘│
│                                        │     │                                      │
└────────────────────────────────────────┘     └──────────────────────────────────────┘
```

> **Nota:** Site Recovery gera custos de replicacao e storage. Configure e teste rapidamente, depois faca cleanup.

---

### Task 3.1: Criar Recovery Services Vault na regiao de DR

Para Site Recovery, o vault deve estar na **regiao de destino** (DR), diferente do vault de backup (regiao primaria).

1. Pesquise e selecione **Recovery Services vaults** > **+ Create**

2. Preencha as configuracoes:

   | Setting        | Value                              |
   | -------------- | ---------------------------------- |
   | Subscription   | *sua subscription*                 |
   | Resource group | `az104-rg-dr` (crie se necessario) |
   | Vault name     | `az104-rsv-dr`                     |
   | Region         | **West US**                        |

   > **Conceito:** O vault de Site Recovery deve estar na regiao de **destino** (DR), nao na regiao de origem. Isso garante que o vault permanece acessivel mesmo se a regiao primaria ficar indisponivel.

3. Clique em **Review + create** > **Create** > **Go to resource**

   > **Conexao com Bloco 1:** Note a diferenca: o vault do Bloco 1 (`az104-rsv`, East US) e para backup local. Este vault (`az104-rsv-dr`, West US) e para DR cross-region. Sao propositos diferentes com vaults separados.

---

### Task 3.2: Habilitar replicacao para az104-vm-win

> **Cobranca:** A replicacao ASR gera cobranca continua por VM replicada. Nao pode ser pausada — so desabilitada.

1. No vault **az104-rsv-dr** (West US), va para **Getting started** > **Site Recovery**

2. Em **Azure virtual machines**, clique em **Enable replication**

3. Aba **Source**:

   | Setting              | Value                     |
   | -------------------- | ------------------------- |
   | Region               | **East US**               |
   | Subscription         | *sua subscription*        |
   | Resource group       | `az104-rg7`               |
   | Virtual machine deployment model | **Resource Manager** |

4. Clique em **Next**

5. Aba **Virtual machines**: selecione **az104-vm-win**

   > **Conexao com Semana 2:** Voce esta configurando DR para a mesma VM que esta protegida por backup no Bloco 1. Backup e Site Recovery sao complementares: backup protege dados, ASR protege disponibilidade.

6. Clique em **Next**

7. Aba **Replication settings** — revise:

   | Setting                    | Value                          |
   | -------------------------- | ------------------------------ |
   | Target location            | **West US** (auto)             |
   | Target resource group      | `az104-rg7-asr` (auto-created) |
   | Failover virtual network   | auto-created ou selecione uma  |
   | Target availability        | *aceite default*               |
   | Replication policy         | `24-hour-retention-policy` (default) |

   > **Conceito:** O ASR cria automaticamente recursos na regiao de destino: RG, VNet, storage account para cache. A replication policy define RPO (Recovery Point Objective) e retencao de recovery points.

8. Revise a aba **Manage** — note as opcoes de automation (runbooks, scripts pre/pos failover)

9. Clique em **Next** > **Enable replication**

10. Monitore em **Protected items** > **Replicated items**

11. Aguarde ate o status mudar para **Protected** (pode levar 15-30 minutos para a sincronizacao inicial)

    > **Dica AZ-104:** Na prova, saiba que a sincronizacao inicial pode levar horas dependendo do tamanho dos discos. O RPO comeca a ser medido apos a sincronizacao completar.

---

### Task 3.3: Criar Recovery Plan

Um Recovery Plan define a ordem e agrupamento de VMs para failover coordenado.

1. No vault **az104-rsv-dr** > **Manage** > **Recovery Plans (Site Recovery)**

2. Clique em **+ Recovery Plan**

3. Configure:

   | Setting        | Value                    |
   | -------------- | ------------------------ |
   | Name           | `contoso-recovery-plan`  |
   | Source         | **East US**              |
   | Target         | **West US**              |
   | Allow items with deployment model | **Resource Manager** |

4. Em **Select items**, selecione **az104-vm-win** > **OK**

5. Clique em **Create**

6. Selecione **contoso-recovery-plan** > observe a estrutura:

   ```
   Group 1: Start
     └─ az104-vm-win
   ```

   > **Conceito:** Recovery Plans permitem agrupar VMs em grupos que fazem failover em sequencia (Group 1 primeiro, depois Group 2, etc.). Voce pode adicionar scripts pre/pos cada grupo para automacao (ex: atualizar DNS, notificar equipe).

---

### Task 3.4: Executar Test Failover

Test Failover valida a replicacao sem afetar a producao.

> **Pre-requisito:** A VM deve estar com status **Protected** em Replicated items.

1. No vault **az104-rsv-dr** > **Protected items** > **Replicated items**

2. Selecione **az104-vm-win**

3. Clique em **Test Failover**

4. Configure:

   | Setting               | Value                                          |
   | --------------------- | ---------------------------------------------- |
   | Recovery Point        | **Latest processed** (mais recente)             |
   | Azure virtual network | *selecione a VNet auto-created ou crie uma de teste* |

   > **Conceito:** Use uma VNet isolada para test failover para evitar conflitos de IP com a VM de producao. O "Latest processed" usa o recovery point mais recente ja processado pelo ASR.

5. Clique em **OK**

6. Monitore em **Monitoring** > **Site Recovery Jobs**

7. Quando completar, navegue para **Virtual Machines** na regiao **West US** e verifique que a VM de teste foi criada

   > **IMPORTANTE:** A VM de teste consome recursos e gera custos. Voce DEVE fazer cleanup do test failover.

---

### Task 3.5: Cleanup Test Failover

1. Volte para **Replicated items** > **az104-vm-win**

2. Note o aviso: **"Test failover cleanup pending"**

3. Clique em **Cleanup test failover**

4. Marque **"Testing is complete. Delete test failover virtual machine(s)"**

5. Digite suas notas (ex: "Test failover validated successfully")

6. Clique em **OK**

7. Monitore em **Site Recovery Jobs** ate o cleanup completar

8. Verifique que a VM de teste foi removida de **Virtual Machines** na regiao West US

   > **Conexao com Semanas 1-2:** O test failover validou que a VM criada na Semana 2, nas VNets da Semana 1, pode ser recuperada na regiao de DR. Em producao, o failover real redirecionaria o trafego para a regiao secundaria.

---

### Task 3.6: Revisar RPO e metricas de replicacao

1. No vault **az104-rsv-dr** > **Protected items** > **Replicated items** > **az104-vm-win**

2. Revise o blade **Overview**:

   | Metrica                  | Descricao                                              |
   | ------------------------ | ------------------------------------------------------ |
   | **Replication health**   | Healthy/Warning/Critical                               |
   | **RPO**                  | Tempo desde o ultimo recovery point (minutos)          |
   | **Latest recovery point**| Timestamp do ponto mais recente                        |
   | **Failover health**      | Se a VM esta pronta para failover                      |

3. Va para **Compute and Network** — revise as configuracoes da VM na regiao de destino

4. Va para **Disks** — verifique quais discos estao sendo replicados

   > **Conceito:** RPO (Recovery Point Objective) indica a perda de dados maxima aceitavel. Um RPO de 5 minutos significa que, no pior caso, voce perde ate 5 minutos de dados. RTO (Recovery Time Objective) depende do tamanho da VM e complexidade do recovery plan.

---

## Modo Desafio - Bloco 3

- [ ] Criar vault `az104-rsv-dr` em **West US** (regiao de DR)
- [ ] Habilitar replicacao de `az104-vm-win` **(Semana 2)** para West US
- [ ] Aguardar status **Protected**
- [ ] Criar Recovery Plan `contoso-recovery-plan`
- [ ] Executar **Test Failover** → verificar VM de teste na regiao DR
- [ ] **Cleanup** Test Failover → remover VM de teste
- [ ] Revisar RPO, replication health e failover health

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa configurar Site Recovery para uma VM em East US. Em qual regiao o Recovery Services Vault deve ser criado?**

A) East US (mesma regiao da VM)
B) Na regiao de destino (ex: West US)
C) Em qualquer regiao — nao importa
D) Central US (regiao intermediaria)

<details>
<summary>Ver resposta</summary>

**Resposta: B) Na regiao de destino (ex: West US)**

O vault de Site Recovery deve estar na regiao de **destino** (DR). Isso garante que o vault permanece acessivel durante uma falha na regiao de origem. O vault de backup (diferente do de DR) fica na mesma regiao dos recursos protegidos.

</details>

### Questao 3.2
**Qual a diferenca entre RPO e RTO no contexto de Site Recovery?**

A) RPO e o tempo de recuperacao, RTO e a perda de dados aceitavel
B) RPO e a perda de dados maxima aceitavel (em tempo), RTO e o tempo para restaurar o servico
C) RPO e RTO sao a mesma coisa
D) RPO se aplica a VMs, RTO se aplica a storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) RPO e a perda de dados maxima aceitavel (em tempo), RTO e o tempo para restaurar o servico**

- **RPO (Recovery Point Objective):** Quanto de dados voce pode perder (ex: RPO 5 min = ate 5 min de dados perdidos)
- **RTO (Recovery Time Objective):** Quanto tempo leva para restaurar o servico (ex: RTO 1h = servico restaurado em ate 1 hora)

</details>

### Questao 3.3
**Voce executou um test failover e a VM de teste foi criada na regiao de DR. O que acontece com a VM de producao durante o test failover?**

A) A VM de producao e pausada
B) A VM de producao continua funcionando normalmente — test failover nao afeta producao
C) A VM de producao e desligada automaticamente
D) A replicacao e interrompida durante o teste

<details>
<summary>Ver resposta</summary>

**Resposta: B) A VM de producao continua funcionando normalmente — test failover nao afeta producao**

O test failover cria uma **copia isolada** da VM na regiao de DR, sem afetar a VM de producao ou a replicacao em andamento. Por isso e recomendado usar uma VNet isolada para o teste, evitando conflitos de IP.

</details>

### Questao 3.4
**Voce tem um Recovery Plan com 3 grupos. O Group 1 tem o banco de dados, Group 2 tem o app server, Group 3 tem o web server. Em que ordem ocorre o failover?**

A) Todos os grupos fazem failover simultaneamente
B) Group 1 primeiro, depois Group 2, depois Group 3 (sequencial)
C) A ordem e aleatoria
D) O Azure decide a ordem baseado na dependencia

<details>
<summary>Ver resposta</summary>

**Resposta: B) Group 1 primeiro, depois Group 2, depois Group 3 (sequencial)**

Recovery Plans executam grupos em **sequencia numerica**. VMs dentro do mesmo grupo fazem failover em paralelo. Isso permite orquestrar a ordem correta: banco de dados primeiro, depois aplicacao, depois frontend.

</details>

---


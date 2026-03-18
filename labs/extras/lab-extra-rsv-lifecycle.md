# Lab Extra - Recovery Services Vault: Lifecycle e Exclusao

**Objetivo:** Praticar o ciclo de vida completo de um Recovery Services Vault — criar, proteger VM, soft delete, purge e deletar vault. Foco nos passos obrigatorios para exclusao que caem no AZ-104.
**Tempo estimado:** 45min
**Custo:** ~$0.30 (1 VM B1s + RSV por ~45min)

> **IMPORTANTE:** Este lab cria recursos do zero. Faca cleanup ao final para evitar custos.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────────┐
│                       rg-lab-rsv                                       │
│                                                                        │
│  ┌──────────────────────────┐      ┌──────────────────────────────┐   │
│  │ vm-rsv-test              │      │ rsv-lab-test                 │   │
│  │ (Ubuntu B1s)             │ ───► │ Recovery Services Vault      │   │
│  │                          │      │                              │   │
│  │                          │      │ Backup Policy: daily-7d     │   │
│  │                          │      │ Soft Delete: Enabled (14d)  │   │
│  └──────────────────────────┘      └──────────────────────────────┘   │
│                                                                        │
│  Pratica:                                                              │
│  1. Criar vault + policy + proteger VM                                │
│  2. Executar backup manual                                            │
│  3. Tentar deletar vault (vai FALHAR — itens protegidos)             │
│  4. Stop backup → tentar deletar (FALHA — soft delete)               │
│  5. Disable soft delete → purge → deletar vault (SUCESSO)            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Parte 1: Setup — Criar Vault e proteger VM

### Task 1.1: Criar Resource Group, VNet e VM

```bash
RG="rg-lab-rsv"
LOCATION="eastus"
VAULT="rsv-lab-test"

# Criar RG
az group create --name $RG --location $LOCATION

# Criar VM simples (para ter algo para proteger)
az vm create \
  --resource-group $RG \
  --name vm-rsv-test \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-address "" \
  --nsg ""

echo "VM criada"
```

### Task 1.2: Criar Recovery Services Vault

```bash
# Criar o vault
az backup vault create \
  --resource-group $RG \
  --name $VAULT \
  --location $LOCATION

echo "Recovery Services Vault criado: $VAULT"
```

### Task 1.3: Verificar que Soft Delete esta habilitado por padrao

```bash
# Verificar propriedades de seguranca do vault
az backup vault backup-properties show \
  --resource-group $RG \
  --name $VAULT \
  --query "{softDelete: softDeleteFeatureState, softDeleteRetention: softDeleteRetentionPeriodInDays}" \
  -o table
```

> **Resultado esperado:** softDelete = **Enabled**, retencao = **14 dias**. Soft delete vem habilitado por padrao em todos os vaults novos — isso e o que impede a exclusao rapida.

### Task 1.4: Criar backup policy simples

```bash
# Listar a policy padrao
az backup policy list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[].{name:name, type:properties.backupManagementType}" -o table
```

> A policy padrao **DefaultPolicy** ja existe — backup diario as 19:00 UTC com retencao de 30 dias. Vamos usa-la.

### Task 1.5: Habilitar backup da VM

```bash
# Proteger a VM com a DefaultPolicy
az backup protection enable-for-vm \
  --resource-group $RG \
  --vault-name $VAULT \
  --vm vm-rsv-test \
  --policy-name DefaultPolicy

echo "Backup habilitado para vm-rsv-test"
```

### Task 1.6: Executar backup manual (ad-hoc)

```bash
# Disparar backup imediato (nao esperar o schedule)
az backup protection backup-now \
  --resource-group $RG \
  --vault-name $VAULT \
  --container-name "iaasvmcontainerv2;${RG};vm-rsv-test" \
  --item-name "vm;iaasvmcontainerv2;${RG};vm-rsv-test" \
  --retain-until $(date -u -d "+7 days" '+%d-%m-%Y' 2>/dev/null || date -u -v+7d '+%d-%m-%Y')

echo "Backup manual disparado — pode levar 10-15 minutos"
```

> **Nota:** Se o comando acima falhar por causa do nome do container, use o portal: Vault > Backup items > Azure Virtual Machine > vm-rsv-test > **Backup now**

### Task 1.7: Verificar status do backup

```bash
# Verificar itens protegidos
az backup item list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[].{name:properties.friendlyName, status:properties.protectionStatus, state:properties.protectionState, lastBackup:properties.lastBackupTime}" \
  -o table
```

> Aguarde ate o status mostrar **Healthy** e lastBackup preenchido antes de prosseguir. Pode levar 10-15 minutos.

---

## Parte 2: Tentar deletar vault (vai FALHAR)

> **Objetivo:** Provar que o vault NAO pode ser deletado enquanto tem itens protegidos.

### Task 2.1: Tentar deletar vault com backup ativo

```bash
# Isso VAI FALHAR — vault tem itens protegidos
az backup vault delete \
  --resource-group $RG \
  --name $VAULT \
  --yes 2>&1 || true

echo "ESPERADO: falha acima — vault tem backup items"
```

> **Resultado esperado:** Erro informando que o vault contem itens protegidos e nao pode ser deletado.

### Task 2.2: Tentar pelo portal tambem

1. Portal > **rsv-lab-test** > **Overview** > **Delete**
2. Observe a mensagem de erro — lista os motivos que impedem a exclusao

> **Conceito:** O Azure impede a exclusao de vaults com dados protegidos para evitar perda acidental. Voce PRECISA remover toda a protecao primeiro.

---

## Parte 3: Stop Backup (Passo 1 da exclusao)

### Task 3.1: Interromper backup da VM

```bash
# Obter o nome do container e item
CONTAINER=$(az backup container list \
  --resource-group $RG \
  --vault-name $VAULT \
  --backup-management-type AzureIaasVM \
  --query "[0].name" -o tsv)

ITEM=$(az backup item list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[0].name" -o tsv)

# Stop backup E deletar dados (delete data)
az backup protection disable \
  --resource-group $RG \
  --vault-name $VAULT \
  --container-name "$CONTAINER" \
  --item-name "$ITEM" \
  --delete-backup-data true \
  --yes

echo "Backup interrompido e dados marcados para exclusao"
```

> **Dois modos de Stop Backup:**
> | Modo | O que faz | Quando usar |
> |---|---|---|
> | **Stop and retain data** | Para o backup mas mantem os recovery points | Pausa temporaria |
> | **Stop and delete data** | Para o backup E marca dados para exclusao | Preparar para deletar vault |
>
> Usamos "delete data" porque queremos deletar o vault.

### Task 3.2: Tentar deletar vault novamente

```bash
# Tentar novamente — ainda vai FALHAR se soft delete estiver ativo
az backup vault delete \
  --resource-group $RG \
  --name $VAULT \
  --yes 2>&1 || true

echo "ESPERADO: pode falhar — itens em soft delete"
```

> **Resultado esperado:** Pode ainda falhar! Os dados nao foram realmente deletados — estao em estado **soft-deleted** (lixeira de 14 dias). Soft delete impede a exclusao permanente.

---

## Parte 4: Desabilitar Soft Delete e Purgar (Passos 2 e 3)

### Task 4.1: Verificar itens em soft-deleted state

```bash
# Listar itens (incluindo soft-deleted)
az backup item list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[].{name:properties.friendlyName, state:properties.protectionState, isDeleted:properties.isScheduledForDeferredDelete}" \
  -o table
```

> **Resultado esperado:** protectionState = **SoftDeleted**. Os dados existem mas estao marcados para exclusao apos 14 dias.

### Task 4.2: Desabilitar Soft Delete no vault

```bash
# Desabilitar soft delete
az backup vault backup-properties set \
  --resource-group $RG \
  --name $VAULT \
  --soft-delete-feature-state Disable

echo "Soft delete desabilitado"
```

> **Conceito:** Desabilitar soft delete nao deleta os itens que ja estao em soft-deleted state. Voce ainda precisa purga-los manualmente. Desabilitar apenas permite que a proxima exclusao seja permanente.

### Task 4.3: Reverter soft delete (undelete) e deletar permanentemente

```bash
# Primeiro, desfazer o soft delete (undelete)
az backup protection undelete \
  --resource-group $RG \
  --vault-name $VAULT \
  --container-name "$CONTAINER" \
  --item-name "$ITEM" \
  --backup-management-type AzureIaasVM \
  --workload-type VM

echo "Item restaurado do soft delete"
```

```bash
# Agora sim, deletar permanentemente (soft delete esta desabilitado)
az backup protection disable \
  --resource-group $RG \
  --vault-name $VAULT \
  --container-name "$CONTAINER" \
  --item-name "$ITEM" \
  --delete-backup-data true \
  --yes

echo "Dados deletados PERMANENTEMENTE"
```

> **Por que 2 passos?** Itens em soft-deleted state nao podem ser deletados diretamente. Voce precisa: (1) undelete (tirar do soft delete), (2) deletar novamente (agora permanente porque soft delete esta desabilitado).

### Task 4.4: Alternativa — Purgar pelo portal (mais simples)

Se os comandos CLI forem complexos, faca pelo portal:

1. Portal > **rsv-lab-test** > **Backup items** > **Azure Virtual Machine**
2. Se o item mostrar estado **Soft deleted**: clique > **Undelete**
3. Apos undelete, clique novamente > **Stop backup** > **Delete backup data**
4. Confirme digitando o nome do item

> **Dica:** O portal mostra claramente o estado (Protected, Soft Deleted, Stopped). Pela CLI os estados podem confundir.

### Task 4.5: Verificar que o vault esta vazio

```bash
# Verificar que nao tem mais itens
az backup item list \
  --resource-group $RG \
  --vault-name $VAULT \
  -o table

echo "Se vazio, vault pode ser deletado"
```

---

## Parte 5: Deletar o Vault (AGORA funciona!)

### Task 5.1: Deletar o vault

```bash
# Agora SIM — vault vazio, sem soft delete
az backup vault delete \
  --resource-group $RG \
  --name $VAULT \
  --yes

echo "Vault deletado com sucesso!"
```

> **Se ainda falhar**, verifique:
> - Backup items restantes: `az backup item list --resource-group $RG --vault-name $VAULT`
> - Containers registrados: `az backup container list --resource-group $RG --vault-name $VAULT --backup-management-type AzureIaasVM`
> - Private endpoints associados ao vault
> - Resource locks no vault

### Task 5.2: Deletar pelo portal (alternativa)

1. Portal > **rsv-lab-test** > **Overview** > **Delete**
2. Digite o nome do vault para confirmar
3. **Delete**

---

## Parte 6: Resumo visual (DECORE para prova!)

```
┌─────────────────────────────────────────────────────────────────────┐
│         DELETAR UM RECOVERY SERVICES VAULT — 4 PASSOS              │
│                                                                     │
│  Estado inicial:                                                    │
│  Vault com VMs protegidas + Soft Delete habilitado                 │
│                                                                     │
│  PASSO 1: Interromper backup de TODOS os itens                     │
│  ─────────────────────────────────────────────                     │
│  Stop backup → Delete backup data                                  │
│  (itens vao para estado Soft Deleted)                              │
│                                                                     │
│  PASSO 2: Desabilitar Soft Delete                                  │
│  ─────────────────────────────────                                 │
│  Vault > Properties > Soft Delete > Disable                        │
│  (permite exclusao permanente)                                     │
│                                                                     │
│  PASSO 3: Purgar itens em soft-deleted state                       │
│  ─────────────────────────────────────────                         │
│  Undelete → Delete novamente (agora permanente)                    │
│  OU aguardar 14 dias (expira sozinho)                              │
│                                                                     │
│  PASSO 4: Deletar o vault                                          │
│  ─────────────────────────────                                     │
│  Vault vazio → Delete funciona                                     │
│                                                                     │
│  ❌ NAO PRECISA:                                                   │
│  • Deletar as VMs (so parar o backup)                              │
│  • Criar novo vault                                                │
│  • Colocar lock (lock IMPEDE exclusao!)                            │
│  • Deletar o Resource Group primeiro                               │
└─────────────────────────────────────────────────────────────────────┘
```

### O que cada distrator faz (prova)

```
"Excluir as VMs"
  → NAO necessario. Stop backup e suficiente.
    Deletar VMs nao remove os backup items do vault.

"Habilitar bloqueio de leitura (Read Lock)"
  → OPOSTO do que voce quer. Lock impede modificacoes/exclusao.

"Criar novo vault e mover backups"
  → NAO e possivel mover backup items entre vaults.

"Desabilitar soft delete"
  → NECESSARIO (faz parte do processo), mas sozinho nao basta.
```

---

## Cleanup

```bash
# Deletar tudo
az group delete --name rg-lab-rsv --yes --no-wait
echo "Resource group sendo deletado"
```

---

## Modo Desafio

Faca sem olhar os comandos acima:

- [ ] Criar vault + habilitar backup de uma VM
- [ ] Executar backup manual e aguardar completar
- [ ] Tentar deletar vault (provar que falha)
- [ ] Stop backup com delete data
- [ ] Tentar deletar vault novamente (provar que falha — soft delete)
- [ ] Desabilitar soft delete
- [ ] Undelete + deletar permanentemente
- [ ] Deletar vault (provar que agora funciona)
- [ ] Cleanup

---

## Questoes de Prova - RSV Lifecycle

### Questao R.1
**Voce tem VMs protegidas em um Recovery Services Vault. Precisa deletar o vault. Quais 3 acoes voce deve executar? (Cada resposta e parte da solucao)**

A) Excluir as VMs
B) Desabilitar soft delete e excluir todos os dados
C) Remover permanentemente itens em soft-deleted state
D) Interromper o backup das VMs
E) Habilitar bloqueio de leitura no vault

<details>
<summary>Ver resposta</summary>

**Resposta: B, C e D**

**D) Interromper backup** — vault com protecao ativa nao pode ser deletado.
**B) Desabilitar soft delete** — permite exclusao permanente dos dados.
**C) Remover itens soft-deleted** — purga os dados que estao na "lixeira".

**A) Errada:** Nao precisa deletar VMs — so parar o backup.
**E) Errada:** Lock IMPEDE exclusao — e o oposto do que voce quer.

</details>

### Questao R.2
**Voce executou "Stop backup and delete data" em todos os itens de um vault. Ao tentar deletar o vault, ainda recebe erro. Qual e a causa mais provavel?**

A) As VMs protegidas ainda estao em execucao
B) Os itens de backup estao em estado soft-deleted
C) O vault tem um Resource Lock
D) O vault esta em outra regiao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Itens em soft-deleted state**

Soft delete (habilitado por padrao) mantem os dados por 14 dias apos "exclusao". O vault nao pode ser deletado enquanto existem itens em soft-deleted state. Voce precisa desabilitar soft delete e purgar os itens.

**A) Errada:** O estado das VMs nao impede exclusao do vault — o que impede sao os backup items.
**C) Possivel** mas menos provavel — a questao diz que voce ja fez stop backup, entao nao ha lock mencionado.

</details>

### Questao R.3
**Um administrador deletou acidentalmente um backup item de VM no vault. Soft delete esta habilitado com retencao de 14 dias. O que acontece?**

A) O backup e permanentemente excluido
B) O backup fica em estado soft-deleted por 14 dias e pode ser restaurado
C) O backup e movido para outro vault
D) O vault e automaticamente excluido

<details>
<summary>Ver resposta</summary>

**Resposta: B) Soft-deleted por 14 dias, pode ser restaurado**

Com soft delete habilitado, dados "deletados" ficam retidos por 14 dias. Durante esse periodo, voce pode fazer **Undelete** para restaurar a protecao. Apos 14 dias, os dados sao permanentemente excluidos.

Soft delete e uma rede de seguranca contra exclusao acidental — e por isso vem habilitado por padrao.

</details>

### Questao R.4
**Voce quer impedir que qualquer usuario (mesmo Global Admin) delete backups de producao por 6 meses. Qual recurso voce deve usar?**

A) Soft delete com retencao de 180 dias
B) Resource Lock (CanNotDelete) no vault
C) Immutability (WORM) no vault
D) Azure Policy com efeito Deny

<details>
<summary>Ver resposta</summary>

**Resposta: C) Immutability (WORM) no vault**

Immutability no vault impede que QUALQUER usuario (incluindo admins) delete ou modifique backups durante o periodo configurado. Resource Lock pode ser removido por Owner. Soft delete so protege por 14 dias (padrao). Azure Policy governa criacao de recursos, nao protecao de dados.

**Conceito:** Immutability no RSV = mesma logica de Immutability no Blob Storage — WORM (Write Once, Read Many).

</details>

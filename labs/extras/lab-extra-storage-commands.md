# Lab Extra - Comandos de Storage (Migracao e Transferencia)

**Objetivo:** Praticar os comandos de upload, copia e sync de blobs/files que caem no AZ-104 — AzCopy, PowerShell e CLI.
**Tempo estimado:** 1h
**Custo:** ~$0.10 (2 Storage Accounts LRS por ~1h)

> **IMPORTANTE:** Este lab cria recursos do zero. Faca cleanup ao final para evitar custos.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────────┐
│                       rg-lab-storage-cmds                              │
│                                                                        │
│  ┌──────────────────────────┐      ┌──────────────────────────────┐   │
│  │ stlabcmdssrc<id>         │      │ stlabcmdsdest<id>            │   │
│  │ (ORIGEM)                 │      │ (DESTINO)                    │   │
│  │                          │      │                              │   │
│  │ Container: images        │ ───► │ Container: images-replica    │   │
│  │ Container: logs          │ ───► │ Container: logs-backup       │   │
│  │ File Share: docs         │      │                              │   │
│  └──────────────────────────┘      └──────────────────────────────┘   │
│                                                                        │
│  Ferramentas praticadas:                                               │
│  • AzCopy copy / sync                                                  │
│  • Set-AzStorageBlobContent (PowerShell)                               │
│  • Get-ChildItem | Set-AzStorageBlobContent (upload em massa)          │
│  • az storage blob upload / upload-batch (CLI)                         │
│  • Start-AzStorageBlobCopy (server-to-server PowerShell)               │
│  • az storage blob copy start-batch (server-to-server CLI)             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Parte 1: Setup do ambiente

### Task 1.1: Criar Resource Group e Storage Accounts

Abra o **Cloud Shell** (Bash ou PowerShell — indicaremos qual usar em cada task).

**No Cloud Shell (Bash):**

```bash
# Variaveis — ajuste o sufixo para ser unico
SUFFIX=$RANDOM
RG="rg-lab-storage-cmds"
LOCATION="eastus"
SRC="stlabcmdssrc${SUFFIX}"
DEST="stlabcmdsdest${SUFFIX}"

# Criar resource group
az group create --name $RG --location $LOCATION

# Criar storage account de ORIGEM
az storage account create \
  --name $SRC \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Criar storage account de DESTINO
az storage account create \
  --name $DEST \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

echo "ORIGEM: $SRC | DESTINO: $DEST"
```

> **Anote os nomes das contas** — voce vai usa-los em todas as tasks.

### Task 1.2: Criar containers e arquivos de teste

```bash
# Obter connection string da origem
SRC_CONN=$(az storage account show-connection-string --name $SRC --resource-group $RG --query connectionString -o tsv)

# Criar containers na origem
az storage container create --name images --connection-string "$SRC_CONN"
az storage container create --name logs --connection-string "$SRC_CONN"

# Criar containers no destino
DEST_CONN=$(az storage account show-connection-string --name $DEST --resource-group $RG --query connectionString -o tsv)
az storage container create --name images-replica --connection-string "$DEST_CONN"
az storage container create --name logs-backup --connection-string "$DEST_CONN"

# Criar arquivos de teste locais (simula \\server1\images)
mkdir -p ~/labfiles/images ~/labfiles/logs

for i in 1 2 3 4 5; do
  echo "imagem-corporativa-$i conteudo $(date)" > ~/labfiles/images/foto$i.txt
done

for i in 1 2 3; do
  echo "log-entry-$i $(date)" > ~/labfiles/logs/app-log-$i.txt
done

echo "Arquivos criados:"
ls -la ~/labfiles/images/
ls -la ~/labfiles/logs/
```

### Task 1.3: Criar File Share na origem

```bash
az storage share-rm create \
  --name docs \
  --storage-account $SRC \
  --resource-group $RG \
  --quota 1
```

---

## Parte 2: Upload local → Blob (PowerShell)

> **Contexto de prova:** Questoes como a da imagem pedem "copiar conteudo de pasta local para container". As opcoes envolvem `Set-AzStorageBlobContent` e `Get-ChildItem | Set-AzStorageBlobContent`.

**Troque o Cloud Shell para PowerShell** (clique no dropdown no topo do Cloud Shell).

### Task 2.1: Upload de arquivo unico com Set-AzStorageBlobContent

```powershell
# Definir variaveis (ajuste com os nomes reais das suas contas)
$rg = "rg-lab-storage-cmds"
$srcAccount = "<seu-stlabcmdssrc>"  # substitua!

# Obter contexto da storage account
$ctx = (Get-AzStorageAccount -ResourceGroupName $rg -Name $srcAccount).Context

# Upload de um unico arquivo
Set-AzStorageBlobContent `
  -File "$HOME/labfiles/images/foto1.txt" `
  -Container "images" `
  -Blob "foto1.txt" `
  -Context $ctx
```

> **O que aconteceu:** `Set-AzStorageBlobContent` faz upload de **um arquivo por vez**. O parametro `-Blob` define o nome no destino. Se omitido, usa o nome original.

> **Dica prova:** A opcao `Set-AzStorageBlobContent -Container "X" -File "caminho" -Blob "nome"` faz upload de **um** arquivo. NAO faz upload recursivo — por isso NAO e resposta quando o cenario pede "copiar todos os arquivos".

### Task 2.2: Upload em massa com Get-ChildItem (resposta classica de prova!)

```powershell
# Upload de TODOS os arquivos da pasta — ESTA E A RESPOSTA CLASSICA
Get-ChildItem -Path "$HOME/labfiles/images" -Recurse |
  Set-AzStorageBlobContent -Container "images" -Context $ctx -Force
```

> **Por que esta e resposta de prova:** `Get-ChildItem -Recurse` lista todos os arquivos recursivamente e o pipe `|` envia cada um para `Set-AzStorageBlobContent`. O `-Force` sobrescreve sem perguntar. E a forma PowerShell de fazer upload em massa.

**Verifique o resultado:**

```powershell
Get-AzStorageBlob -Container "images" -Context $ctx | Select-Object Name, Length
```

> Voce deve ver os 5 arquivos (foto1.txt a foto5.txt) listados.

### Task 2.3: Upload em massa para o container logs

```powershell
# Agora faca o mesmo para logs
Get-ChildItem -Path "$HOME/labfiles/logs" -Recurse |
  Set-AzStorageBlobContent -Container "logs" -Context $ctx -Force

# Verificar
Get-AzStorageBlob -Container "logs" -Context $ctx | Select-Object Name, Length
```

---

## Parte 3: Upload local → Blob (AzCopy)

> **Contexto de prova:** `azcopy copy` com `--recursive` e a outra resposta classica para "migrar todo o conteudo de uma pasta".

**Troque o Cloud Shell para Bash.**

### Task 3.1: Autenticar o AzCopy

```bash
# Opcao 1: Login com Entra ID (recomendado)
azcopy login

# Opcao 2: Usar SAS token (gere pelo portal se preferir)
# Navegue para a Storage Account > Shared access signature > Generate
```

> **Na prova:** AzCopy aceita 3 formas de autenticacao: (1) Entra ID (`azcopy login`), (2) SAS token na URL, (3) Variavel de ambiente com connection string. SAS e a forma mais cobrada em questoes.

### Task 3.2: AzCopy copy — upload recursivo (resposta classica!)

```bash
# Upload de pasta local inteira para container
# Esta e a OUTRA resposta classica de prova
azcopy copy \
  "$HOME/labfiles/images/*" \
  "https://${SRC}.blob.core.windows.net/images" \
  --recursive
```

> **Se nao fez azcopy login**, use SAS token:
> ```bash
> azcopy copy \
>   "$HOME/labfiles/images/*" \
>   "https://${SRC}.blob.core.windows.net/images?<SAS-TOKEN>" \
>   --recursive
> ```

> **O que --recursive faz:** Copia todos os arquivos incluindo subpastas. Sem `--recursive`, copia apenas arquivos no nivel raiz da pasta.

### Task 3.3: Entender a diferenca entre copy e sync

```bash
# Primeiro, delete um arquivo local para simular diferenca
rm ~/labfiles/images/foto3.txt

# SYNC: sincroniza origem → destino (apenas adiciona/atualiza, NAO deleta no destino)
azcopy sync \
  "$HOME/labfiles/images" \
  "https://${SRC}.blob.core.windows.net/images" \
  --recursive

# Verifique: foto3.txt AINDA existe no blob (sync nao deleta por padrao)
az storage blob list --container-name images --connection-string "$SRC_CONN" --query "[].name" -o tsv
```

```bash
# SYNC com --delete-destination: agora SIM remove blobs que nao existem na origem
azcopy sync \
  "$HOME/labfiles/images" \
  "https://${SRC}.blob.core.windows.net/images" \
  --recursive \
  --delete-destination true

# Verifique: foto3.txt FOI removida do blob
az storage blob list --container-name images --connection-string "$SRC_CONN" --query "[].name" -o tsv
```

> **REGRA AZ-104:**
> | Comando | Comportamento | Quando usar |
> |---------|--------------|-------------|
> | `azcopy copy` | Copia tudo, sempre. Sobrescreve. | Migracao unica, copia completa |
> | `azcopy sync` | Copia apenas diferencas (por timestamp/tamanho) | Sincronizacao continua, backup incremental |
> | `azcopy sync --delete-destination` | Sincroniza e remove extras no destino | Espelho exato (mirror) |

---

## Parte 4: Copia server-to-server (entre Storage Accounts)

> **Contexto de prova:** "Copiar blobs entre storage accounts sem baixar localmente" — a resposta e AzCopy copy (URL→URL) ou `Start-AzStorageBlobCopy`.

### Task 4.1: AzCopy copy entre storage accounts (server-to-server)

```bash
# Recriar foto3 para ter dados completos
echo "imagem-corporativa-3 conteudo $(date)" > ~/labfiles/images/foto3.txt
azcopy copy "$HOME/labfiles/images/foto3.txt" "https://${SRC}.blob.core.windows.net/images"

# Copiar container inteiro: origem → destino (server-to-server!)
azcopy copy \
  "https://${SRC}.blob.core.windows.net/images" \
  "https://${DEST}.blob.core.windows.net/images-replica" \
  --recursive
```

> **O que aconteceu:** Os dados foram de storage account para storage account pelo backbone Azure. Nada passou pelo Cloud Shell. Isso e **server-to-server copy** — muito mais rapido para volumes grandes.

**Verifique no destino:**

```bash
az storage blob list --container-name images-replica --connection-string "$DEST_CONN" --query "[].name" -o tsv
```

### Task 4.2: Start-AzStorageBlobCopy (PowerShell server-to-server)

**Troque para PowerShell:**

```powershell
$rg = "rg-lab-storage-cmds"
$srcAccount = "<seu-stlabcmdssrc>"
$destAccount = "<seu-stlabcmdsdest>"

$srcCtx = (Get-AzStorageAccount -ResourceGroupName $rg -Name $srcAccount).Context
$destCtx = (Get-AzStorageAccount -ResourceGroupName $rg -Name $destAccount).Context

# Copiar TODOS os blobs de um container para outro (server-to-server)
Get-AzStorageBlob -Container "logs" -Context $srcCtx | Start-AzStorageBlobCopy `
  -DestContainer "logs-backup" `
  -DestContext $destCtx -Force

# Verificar
Get-AzStorageBlob -Container "logs-backup" -Context $destCtx | Select-Object Name, Length
```

> **Dica prova:** `Start-AzStorageBlobCopy` e a resposta PowerShell para copia server-to-server. O pipe com `Get-AzStorageBlob` permite copiar todos os blobs de um container. Sem pipe, copia um blob especifico com `-SrcBlob`.

### Task 4.3: az storage blob copy (CLI server-to-server)

**Troque para Bash:**

```bash
# Copia server-to-server via CLI (um blob especifico)
az storage blob copy start \
  --destination-blob "foto1.txt" \
  --destination-container "images-replica" \
  --connection-string "$DEST_CONN" \
  --source-uri "https://${SRC}.blob.core.windows.net/images/foto1.txt"

# Copia em batch (todos os blobs de um container)
az storage blob copy start-batch \
  --destination-container "logs-backup" \
  --connection-string "$DEST_CONN" \
  --source-container "logs" \
  --source-account-name $SRC \
  --source-account-key $(az storage account keys list --account-name $SRC --resource-group $RG --query "[0].value" -o tsv)
```

---

## Parte 5: Object Replication — Pre-requisitos na pratica

> **Contexto de prova:** "Quais recursos devem ser habilitados ANTES de configurar Object Replication?" — versioning em AMBAS as contas + change feed na ORIGEM. Essa questao cai sempre. Voce vai habilitar cada um manualmente e ver o erro quando falta algum.

### Task 5.1: Tentar criar Object Replication SEM pre-requisitos (vai falhar!)

```bash
# Tentar configurar replicacao sem habilitar nada — observe o ERRO
az storage account or-policy create \
  --account-name $DEST \
  --resource-group $RG \
  --source-account $SRC \
  --destination-account $DEST \
  --source-container "images" \
  --destination-container "images-replica" \
  --min-creation-time "2020-01-01T00:00:00Z" 2>&1 || true
```

> **Resultado esperado:** ERRO. O Azure rejeita porque faltam os pre-requisitos. Leia a mensagem de erro — ela indica exatamente o que esta faltando.

### Task 5.2: Habilitar Blob Versioning em AMBAS as contas

```bash
# Habilitar versioning na ORIGEM (obrigatorio)
az storage account blob-service-properties update \
  --account-name $SRC \
  --resource-group $RG \
  --enable-versioning true

# Habilitar versioning no DESTINO (obrigatorio)
az storage account blob-service-properties update \
  --account-name $DEST \
  --resource-group $RG \
  --enable-versioning true

echo "Versioning habilitado em ambas as contas"
```

> **Por que versioning em AMBAS?** Object Replication rastreia mudancas por versao. A origem precisa criar versoes para detectar o que mudou. O destino precisa de versioning para receber as versoes replicadas e manter o historico consistente.

### Task 5.3: Habilitar Change Feed na ORIGEM

```bash
# Habilitar change feed APENAS na origem (obrigatorio)
az storage account blob-service-properties update \
  --account-name $SRC \
  --resource-group $RG \
  --enable-change-feed true

echo "Change feed habilitado na origem"
```

> **Por que change feed so na origem?** Change feed e o "log de eventos" que registra todas as operacoes em blobs (create, update, delete). A replicacao usa esse log para saber O QUE replicar. O destino nao precisa porque ele so RECEBE — nao precisa rastrear mudancas proprias para fins de replicacao.

> **Dica prova:** Change feed no destino NAO e pre-requisito. A questao da imagem mostra "feed de alteracoes para armazenamento2" como INCORRETA — so a origem precisa.

### Task 5.4: Verificar o estado dos pre-requisitos

```bash
echo "=== ORIGEM ($SRC) ==="
az storage account blob-service-properties show \
  --account-name $SRC \
  --resource-group $RG \
  --query "{versioning: isVersioningEnabled, changeFeed: changeFeed.enabled}" -o table

echo "=== DESTINO ($DEST) ==="
az storage account blob-service-properties show \
  --account-name $DEST \
  --resource-group $RG \
  --query "{versioning: isVersioningEnabled, changeFeed: changeFeed.enabled}" -o table
```

> **Resultado esperado:**
> | Conta | Versioning | Change Feed |
> |-------|-----------|-------------|
> | ORIGEM | true | true |
> | DESTINO | true | false (ou true, nao importa) |

### Task 5.5: Agora SIM criar Object Replication (vai funcionar!)

```bash
# Criar a politica de replicacao
az storage account or-policy create \
  --account-name $DEST \
  --resource-group $RG \
  --source-account $SRC \
  --destination-account $DEST \
  --source-container "images" \
  --destination-container "images-replica" \
  --min-creation-time "2020-01-01T00:00:00Z"

echo "Object Replication configurada com sucesso!"
```

### Task 5.6: Testar a replicacao

```bash
# Criar um novo arquivo e fazer upload na origem
echo "arquivo-novo-para-replicacao $(date)" > ~/labfiles/images/repl-test.txt

az storage blob upload \
  --account-name $SRC \
  --container-name images \
  --name "repl-test.txt" \
  --file ~/labfiles/images/repl-test.txt \
  --auth-mode key \
  --account-key $(az storage account keys list --account-name $SRC --resource-group $RG --query "[0].value" -o tsv)

echo "Blob uploaded na origem. Aguarde 1-2 minutos para replicacao..."
```

```bash
# Apos 1-2 minutos, verificar se apareceu no destino
az storage blob list \
  --account-name $DEST \
  --container-name images-replica \
  --auth-mode key \
  --account-key $(az storage account keys list --account-name $DEST --resource-group $RG --query "[0].value" -o tsv) \
  --query "[].name" -o tsv
```

> **Nota:** Object Replication e **assincrona** — pode levar de segundos a minutos. Se o blob nao aparecer imediatamente, aguarde e tente novamente.

### Task 5.7: Verificar pelo Portal (visual)

1. Navegue para a storage account **destino** > **Data management** > **Object replication**
2. Voce vera a politica criada com status
3. Navegue para **Containers** > **images-replica** e confirme o blob replicado

### Resumo visual dos pre-requisitos

```
┌─────────────────────────────────────────────────────────────────────┐
│              Object Replication: PRE-REQUISITOS                     │
│                                                                     │
│   ORIGEM (source)              DESTINO (destination)                │
│   ┌─────────────────────┐     ┌─────────────────────┐              │
│   │ ✅ Blob Versioning  │     │ ✅ Blob Versioning  │              │
│   │ ✅ Change Feed      │     │ ❌ Change Feed      │ ← opcional  │
│   └─────────────────────┘     │    (nao obrigatorio) │              │
│                               └─────────────────────┘              │
│                                                                     │
│   ❌ Point-in-time restore NAO e pre-requisito                     │
│   ❌ Imutability NAO e pre-requisito                               │
│   ❌ HNS (Data Lake) NAO pode estar habilitado                     │
│                                                                     │
│   REGRA: Versioning = ambas | Change Feed = so origem              │
└─────────────────────────────────────────────────────────────────────┘
```

> **PEGADINHA AZ-104 (caiu 3x nos simulados!):**
> - "Restauracao pontual" (point-in-time restore) NAO e pre-requisito — e um recurso separado
> - "Change feed no destino" NAO e obrigatorio — so a origem precisa
> - HNS (namespace hierarquico / Data Lake Gen2) **IMPEDE** Object Replication — contas com HNS nao suportam
> - Blob Versioning e obrigatorio em **AMBAS**, nao so na origem

---

## Parte 6: Immutability — Bloquear modificacao e exclusao

> **Contexto de prova:** "Garantir que dados nao sejam modificados ou excluidos por X meses" → Immutability policy (time-based retention). "Bloquear exclusao indefinidamente por investigacao legal" → Legal Hold. A questao da imagem pede "nao modificar/excluir por 6 meses" = time-based retention.

### Task 6.1: Criar Immutability Policy (time-based retention) via CLI

```bash
# Criar um container dedicado para testar imutabilidade
az storage container create \
  --name "confidencial" \
  --connection-string "$SRC_CONN"

# Upload de arquivo de teste
echo "dados-sensiveis-$(date)" > ~/labfiles/confidencial.txt
az storage blob upload \
  --container-name "confidencial" \
  --name "relatorio.txt" \
  --file ~/labfiles/confidencial.txt \
  --connection-string "$SRC_CONN"

# Criar politica de imutabilidade: 180 dias (6 meses) — exatamente como na questao
az storage container immutability-policy create \
  --container-name "confidencial" \
  --connection-string "$SRC_CONN" \
  --period 180

echo "Immutability policy criada: 180 dias"
```

> **O que aconteceu:** O container agora tem uma politica que impede modificacao e exclusao de blobs por 180 dias apos a ultima modificacao. A policy esta no estado **unlocked** — pode ser alterada ou removida.

### Task 6.2: Testar a protecao — tentar deletar (vai falhar!)

```bash
# Tentar deletar o blob — deve FALHAR
az storage blob delete \
  --container-name "confidencial" \
  --name "relatorio.txt" \
  --connection-string "$SRC_CONN" 2>&1 || true
```

> **Resultado esperado:** Erro indicando que o blob esta protegido pela politica de imutabilidade. Voce nao consegue deletar nem sobrescrever o blob ate a policy expirar ou ser removida (enquanto estiver unlocked).

### Task 6.3: Entender os 3 estados da policy

```bash
# Ver o estado atual da policy
az storage container immutability-policy show \
  --container-name "confidencial" \
  --connection-string "$SRC_CONN" \
  --query "{period: immutabilityPeriodSinceCreationInDays, state: state}" -o table
```

> **Os 3 estados:**
> | Estado | Pode alterar? | Pode remover? | Pode deletar container? |
> |--------|:------------:|:-------------:|:----------------------:|
> | **Unlocked** | Sim (aumentar/diminuir periodo) | Sim | Nao (se tem blobs) |
> | **Locked** | Apenas aumentar periodo | NAO (irreversivel!) | Nao |
> | **Expired** | Nao | Nao | Sim (pode deletar blobs) |
>
> **CUIDADO:** Fazer **lock** e IRREVERSIVEL. Uma vez locked, a policy nao pode ser removida — so o periodo pode ser aumentado. Em lab, NAO faca lock para poder limpar depois.

### Task 6.4: Legal Hold vs Time-based (comparacao pratica)

```bash
# Criar outro container para legal hold
az storage container create \
  --name "legal-docs" \
  --connection-string "$SRC_CONN"

# Upload de arquivo
echo "documento-legal-$(date)" > ~/labfiles/legal.txt
az storage blob upload \
  --container-name "legal-docs" \
  --name "contrato.txt" \
  --file ~/labfiles/legal.txt \
  --connection-string "$SRC_CONN"

# Aplicar Legal Hold (bloqueio indefinido — nao tem prazo!)
az storage container legal-hold set \
  --container-name "legal-docs" \
  --connection-string "$SRC_CONN" \
  --tags "investigacao-2026"

echo "Legal Hold aplicado!"
```

```bash
# Tentar deletar — vai FALHAR
az storage blob delete \
  --container-name "legal-docs" \
  --name "contrato.txt" \
  --connection-string "$SRC_CONN" 2>&1 || true

# Remover o legal hold (para cleanup posterior)
az storage container legal-hold clear \
  --container-name "legal-docs" \
  --connection-string "$SRC_CONN" \
  --tags "investigacao-2026"

echo "Legal Hold removido"
```

> **Diferenca chave para a prova:**
> | | Time-based Retention | Legal Hold |
> |---|---|---|
> | **Prazo** | Definido (ex: 180 dias) | Indefinido (ate remover manualmente) |
> | **Quando usar** | Compliance (SEC, FINRA): "reter por X meses" | Investigacao legal: "bloquear ate segunda ordem" |
> | **Pode coexistir** | Sim, com legal hold no mesmo container | Sim, com time-based no mesmo container |
> | **Questao da imagem** | "nao modificar por 6 meses" = **este** | "bloquear por investigacao" = este |

### Task 6.5: Cleanup do immutability (remover policy unlocked)

```bash
# Remover a policy (so funciona porque esta UNLOCKED)
ETAG=$(az storage container immutability-policy show \
  --container-name "confidencial" \
  --connection-string "$SRC_CONN" \
  --query "etag" -o tsv)

az storage container immutability-policy delete \
  --container-name "confidencial" \
  --connection-string "$SRC_CONN" \
  --if-match "$ETAG"

echo "Immutability policy removida"
```

> **Resumo visual:**
> ```
> "Nao modificar/excluir por X meses"  →  Immutability Policy (time-based retention)
> "Bloquear indefinidamente (legal)"   →  Legal Hold
> "Mover para Cool/Archive apos X dias"→  Lifecycle Management (NAO e imutabilidade!)
> "Impedir exclusao acidental"         →  Soft Delete (DIFERENTE de imutabilidade!)
> ```

---

## Parte 7: Deploy ARM Template de Blob Storage (-TemplateUri vs -TemplateFile)

> **Contexto de prova:** "Voce tem um ARM template em um blob container. Qual parametro usar?" → `-TemplateUri`. Essa questao cai com frequencia e confunde porque existem 3 parametros parecidos. Voce vai praticar os 3.

### Task 7.1: Criar um ARM template simples e fazer upload para blob

```bash
# Criar um ARM template minimo (cria uma storage account)
cat > ~/labfiles/deploy.json << 'ARMEOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageName": {
      "type": "string",
      "defaultValue": "[concat('sttest', uniqueString(resourceGroup().id))]"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "[parameters('storageName')]",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Standard_LRS" },
      "kind": "StorageV2"
    }
  ],
  "outputs": {
    "storageId": {
      "type": "string",
      "value": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageName'))]"
    }
  }
}
ARMEOF

echo "ARM template criado: ~/labfiles/deploy.json"
```

```bash
# Criar container publico para hospedar o template
az storage container create \
  --name "templates" \
  --connection-string "$SRC_CONN" \
  --public-access blob

# Upload do template para blob storage
az storage blob upload \
  --container-name "templates" \
  --name "deploy.json" \
  --file ~/labfiles/deploy.json \
  --connection-string "$SRC_CONN"

# Obter a URL publica do blob
TEMPLATE_URL=$(az storage blob url \
  --container-name "templates" \
  --name "deploy.json" \
  --connection-string "$SRC_CONN" -o tsv)

echo "URL do template: $TEMPLATE_URL"
```

### Task 7.2: Deploy com -TemplateFile (arquivo local)

```bash
# Deploy usando arquivo LOCAL — parametro --template-file
az deployment group create \
  --resource-group $RG \
  --template-file ~/labfiles/deploy.json \
  --parameters storageName="stlocal${SUFFIX}"

echo "Deploy via --template-file concluido!"
```

> **`--template-file`** (CLI) / **`-TemplateFile`** (PowerShell): aponta para um arquivo no disco local. E o parametro mais usado no dia a dia e nos labs.

### Task 7.3: Deploy com -TemplateUri (URL — resposta da questao!)

```bash
# Deploy usando URL do blob — parametro --template-uri
az deployment group create \
  --resource-group $RG \
  --template-uri "$TEMPLATE_URL" \
  --parameters storageName="sturi${SUFFIX}"

echo "Deploy via --template-uri concluido!"
```

> **`--template-uri`** (CLI) / **`-TemplateUri`** (PowerShell): aponta para uma URL — pode ser blob storage, GitHub, qualquer endpoint HTTP acessivel. **Este e o parametro da questao** quando o template esta em um blob container.

### Task 7.4: Deploy com -TemplateUri usando SAS (container privado)

```bash
# Alterar container para privado
az storage container set-permission \
  --name "templates" \
  --connection-string "$SRC_CONN" \
  --public-access off

# Agora a URL publica NAO funciona mais — teste:
az deployment group create \
  --resource-group $RG \
  --template-uri "$TEMPLATE_URL" \
  --parameters storageName="stfail${SUFFIX}" 2>&1 || true

echo "ESPERADO: falha acima — container agora e privado"
```

```bash
# Gerar SAS token para o blob
SAS_TOKEN=$(az storage blob generate-sas \
  --container-name "templates" \
  --name "deploy.json" \
  --connection-string "$SRC_CONN" \
  --permissions r \
  --expiry $(date -u -v+1d '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -d '+1 day' '+%Y-%m-%dT%H:%MZ') \
  -o tsv)

# Deploy com URL + SAS token (funciona mesmo com container privado!)
az deployment group create \
  --resource-group $RG \
  --template-uri "${TEMPLATE_URL}?${SAS_TOKEN}" \
  --parameters storageName="stsas${SUFFIX}"

echo "Deploy via --template-uri + SAS concluido!"
```

> **Dica prova:** Quando o template esta em um container **privado**, voce usa `--template-uri` com a URL + SAS token concatenados. O Azure faz um GET na URL para baixar o template antes de executar o deploy.

### Task 7.5: Mesmo deploy via PowerShell (comparacao)

**Troque para PowerShell:**

```powershell
$rg = "rg-lab-storage-cmds"

# -TemplateFile (arquivo local)
New-AzResourceGroupDeployment `
  -ResourceGroupName $rg `
  -TemplateFile "$HOME/labfiles/deploy.json" `
  -storageName "stpsfile$((Get-Random -Maximum 9999))"

# -TemplateUri (URL do blob)
New-AzResourceGroupDeployment `
  -ResourceGroupName $rg `
  -TemplateUri "<cole-a-URL-com-SAS-aqui>" `
  -storageName "stpsuri$((Get-Random -Maximum 9999))"
```

> **Equivalencia CLI ↔ PowerShell:**
> | Cenario | CLI | PowerShell |
> |---------|-----|------------|
> | Arquivo local | `--template-file` | `-TemplateFile` |
> | URL (blob, GitHub) | `--template-uri` | `-TemplateUri` |
> | Template Spec salvo no Azure | `--template-spec` | `-TemplateSpecId` |
> | Tag (nao existe para deploy) | ❌ | ❌ |

### Task 7.6: Cleanup dos recursos criados pelo deploy

```bash
# Listar as storage accounts criadas pelos deploys de teste
az storage account list --resource-group $RG --query "[].name" -o tsv

# Deletar as accounts de teste (manter as originais src/dest)
az storage account delete --name "stlocal${SUFFIX}" --resource-group $RG --yes 2>/dev/null
az storage account delete --name "sturi${SUFFIX}" --resource-group $RG --yes 2>/dev/null
az storage account delete --name "stsas${SUFFIX}" --resource-group $RG --yes 2>/dev/null
```

### Resumo: qual parametro usar?

```
Template esta onde?          →  Parametro
─────────────────────────────────────────────
Disco local (~/deploy.json)  →  -TemplateFile
URL (blob, GitHub, HTTP)     →  -TemplateUri     ← QUESTAO DA PROVA
Salvo no Azure (Template Spec) → -TemplateSpecId
-Tag                         →  NAO EXISTE para deploy (distrator!)
```

---

## Parte 8: ARM --parameters inline (arrays, objetos, tipos)

> **Contexto de prova:** "Passar uma matriz como parametro inline durante o deploy" → usar `--parameters` no comando. Voce errou isso nos simulados 2 e 3 — este e um ponto CRITICO. Voce vai praticar as 4 formas de passar parametros.

### Task 8.1: Criar ARM template com parametro array

```bash
# Template que aceita um array de nomes de tags
cat > ~/labfiles/deploy-array.json << 'ARMEOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "allowedLocations": {
      "type": "array",
      "defaultValue": ["eastus", "westus"]
    },
    "environment": {
      "type": "string",
      "defaultValue": "dev"
    },
    "tags": {
      "type": "object",
      "defaultValue": {
        "dept": "IT",
        "env": "dev"
      }
    }
  },
  "resources": [],
  "outputs": {
    "locations": {
      "type": "array",
      "value": "[parameters('allowedLocations')]"
    },
    "env": {
      "type": "string",
      "value": "[parameters('environment')]"
    },
    "tagsOut": {
      "type": "object",
      "value": "[parameters('tags')]"
    }
  }
}
ARMEOF

echo "Template com parametros array/string/object criado"
```

### Task 8.2: Passar parametros INLINE (resposta da questao!)

```bash
# FORMA 1: --parameters inline (A RESPOSTA DA PROVA)
# Array usa sintaxe JSON entre aspas
az deployment group create \
  --resource-group $RG \
  --template-file ~/labfiles/deploy-array.json \
  --parameters \
    allowedLocations='["eastus","brazilsouth","westeurope"]' \
    environment="prod" \
    tags='{"dept":"Finance","env":"prod","owner":"joao"}'

echo "Deploy com --parameters inline concluido!"
```

> **ESTA E A RESPOSTA:** Para passar array inline, voce fornece o valor JSON direto no `--parameters`. Note a sintaxe: `parametro='["val1","val2"]'` (aspas simples por fora, JSON por dentro).

### Task 8.3: As 4 formas de passar parametros (comparacao pratica)

```bash
# FORMA 2: Arquivo de parametros separado
cat > ~/labfiles/params.json << 'PEOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "allowedLocations": { "value": ["eastus", "westus2"] },
    "environment": { "value": "staging" },
    "tags": { "value": { "dept": "QA", "env": "staging" } }
  }
}
PEOF

az deployment group create \
  --resource-group $RG \
  --template-file ~/labfiles/deploy-array.json \
  --parameters @~/labfiles/params.json

echo "Deploy com arquivo de parametros concluido!"
```

```bash
# FORMA 3: Misturar arquivo + override inline
az deployment group create \
  --resource-group $RG \
  --template-file ~/labfiles/deploy-array.json \
  --parameters @~/labfiles/params.json \
  --parameters environment="production"

echo "Deploy com arquivo + override inline concluido!"
# 'environment' do arquivo (staging) foi sobrescrito para 'production'
```

> **As 4 formas:**
> | Forma | Sintaxe CLI | Quando usar |
> |-------|-------------|-------------|
> | **Inline** (resposta da prova) | `--parameters key='["a","b"]'` | Arrays/valores rapidos, sem arquivo |
> | Arquivo de parametros | `--parameters @params.json` | Valores reutilizaveis, versionados |
> | Misturado | `--parameters @params.json --parameters key=val` | Arquivo base + override especifico |
> | Defaults do template | (nao passar nada) | Valores padrao definidos no template |

### Task 8.4: Mesmo cenario em PowerShell

**Troque para PowerShell:**

```powershell
$rg = "rg-lab-storage-cmds"

# Inline — note que PowerShell usa @() para arrays e @{} para objetos
New-AzResourceGroupDeployment `
  -ResourceGroupName $rg `
  -TemplateFile "$HOME/labfiles/deploy-array.json" `
  -allowedLocations @("eastus", "brazilsouth") `
  -environment "prod" `
  -tags @{ dept = "HR"; env = "prod" }

# Com arquivo de parametros
New-AzResourceGroupDeployment `
  -ResourceGroupName $rg `
  -TemplateFile "$HOME/labfiles/deploy-array.json" `
  -TemplateParameterFile "$HOME/labfiles/params.json"
```

> **CLI vs PowerShell — sintaxe de array:**
> | | CLI | PowerShell |
> |---|---|---|
> | Array inline | `'["a","b"]'` (JSON) | `@("a","b")` (PS nativo) |
> | Object inline | `'{"k":"v"}'` (JSON) | `@{k="v"}` (hashtable) |
> | Arquivo params | `@params.json` | `-TemplateParameterFile params.json` |

### Resumo visual (DECORE para prova!)

```
"Passar array INLINE no deploy"
  → --parameters allowedLocations='["val1","val2"]'

"Passar parametros de arquivo"
  → --parameters @params.json

"Onde definir defaults"
  → No proprio template (defaultValue)

NAO funciona:
  ✗ --template-file NAO passa parametros (passa o template!)
  ✗ Modificar o template para incluir valores hardcoded (viola parametrizacao)
  ✗ Criar arquivo separado SEM referenciar com @ no comando
```

---

## Parte 9: Upload para Azure Files

> **Contexto de prova:** Questoes sobre montar file share e copiar arquivos via PowerShell/CLI.

### Task 8.1: Upload para File Share (CLI)

```bash
# Upload de arquivo unico para file share
az storage file upload \
  --share-name docs \
  --source "$HOME/labfiles/logs/app-log-1.txt" \
  --connection-string "$SRC_CONN"

# Upload de diretorio inteiro
az storage file upload-batch \
  --destination docs \
  --source "$HOME/labfiles/logs" \
  --connection-string "$SRC_CONN"

# Listar arquivos no share
az storage file list --share-name docs --connection-string "$SRC_CONN" --query "[].name" -o tsv
```

### Task 8.2: Upload para File Share (PowerShell)

**Troque para PowerShell:**

```powershell
$ctx = (Get-AzStorageAccount -ResourceGroupName $rg -Name $srcAccount).Context

# Upload de arquivo unico
Set-AzStorageFileContent `
  -ShareName "docs" `
  -Source "$HOME/labfiles/images/foto1.txt" `
  -Path "foto1.txt" `
  -Context $ctx

# Listar arquivos
Get-AzStorageFile -ShareName "docs" -Context $ctx | Select-Object Name
```

> **Blob vs Files — comandos diferentes!**
> | Operacao | Blob | Files |
> |----------|------|-------|
> | Upload (PS) | `Set-AzStorageBlobContent` | `Set-AzStorageFileContent` |
> | Upload (CLI) | `az storage blob upload` | `az storage file upload` |
> | Upload batch (CLI) | `az storage blob upload-batch` | `az storage file upload-batch` |
> | Download (PS) | `Get-AzStorageBlobContent` | `Get-AzStorageFileContent` |

---

## Parte 10: Tabela de referencia rapida (Prova!)

Depois de praticar, revise esta tabela — ela resume as combinacoes que caem no AZ-104:

| Cenario | Comando correto | Armadilha |
|---------|----------------|-----------|
| Copiar TODOS os arquivos de pasta local para blob | `Get-ChildItem -Recurse \| Set-AzStorageBlobContent` | `Set-AzStorageBlobContent` sozinho faz 1 arquivo |
| Copiar pasta local para blob (CLI) | `azcopy copy "path/*" "url" --recursive` | `azcopy sync` nao e a mesma coisa |
| Sincronizar pasta local com blob | `azcopy sync "path" "url" --recursive` | Sem `--delete-destination`, nao remove extras |
| Copiar blob entre storage accounts | `azcopy copy "url-src" "url-dest" --recursive` | Server-to-server, nao passa pelo local |
| Copiar blob entre contas (PS) | `Start-AzStorageBlobCopy` | NAO e `Set-AzStorageBlobContent` (este e upload local) |
| Upload para File Share (CLI) | `az storage file upload` / `upload-batch` | NAO usar `az storage blob upload` para files |
| Upload para File Share (PS) | `Set-AzStorageFileContent` | NAO usar `Set-AzStorageBlobContent` para files |
| Mover dados em massa (petabytes) | Azure Data Box | AzCopy nao e viavel para petabytes offline |

---

## Cleanup

```bash
# Deletar TUDO de uma vez
az group delete --name rg-lab-storage-cmds --yes --no-wait

# Limpar arquivos locais do Cloud Shell
rm -rf ~/labfiles
```

---

## Modo Desafio

Faca sem olhar os comandos acima:

- [ ] Criar 2 storage accounts (origem e destino) via CLI
- [ ] Criar containers e arquivos de teste locais
- [ ] Upload de arquivo unico com `Set-AzStorageBlobContent`
- [ ] Upload em massa com `Get-ChildItem -Recurse | Set-AzStorageBlobContent`
- [ ] Upload com `azcopy copy --recursive`
- [ ] Testar `azcopy sync` vs `azcopy copy` (entender a diferenca)
- [ ] Testar `azcopy sync --delete-destination` (mirror)
- [ ] Copia server-to-server com `azcopy copy` (URL→URL)
- [ ] Copia server-to-server com `Start-AzStorageBlobCopy` (PowerShell)
- [ ] Copia server-to-server com `az storage blob copy start-batch` (CLI)
- [ ] Tentar criar Object Replication SEM pre-requisitos (ver o erro)
- [ ] Habilitar versioning em AMBAS as contas + change feed na ORIGEM
- [ ] Criar Object Replication e testar com upload de novo blob
- [ ] Criar Immutability Policy (time-based, 180 dias) num container
- [ ] Tentar deletar blob protegido (ver o erro)
- [ ] Criar Legal Hold e entender a diferenca vs time-based
- [ ] Remover policy (unlocked) e legal hold
- [ ] Criar ARM template e upload para blob container
- [ ] Deploy com `--template-file` (local) e verificar que funciona
- [ ] Deploy com `--template-uri` (URL do blob) e verificar
- [ ] Testar `--template-uri` com container privado (falha) e depois com SAS (funciona)
- [ ] Upload para File Share com CLI e PowerShell
- [ ] Cleanup: deletar resource group

---

## Questoes de Prova - Storage Commands

### Questao C.1
**Voce tem uma storage account chamada corpimages e uma pasta compartilhada local \\server1\images. Precisa migrar todo o conteudo de \\server1\images para corpimages. Quais DOIS comandos voce pode usar? (Cada resposta e uma solucao completa)**

A) `Azcopy copy \\server1\images https://corpimages.blob.core.windows.net/public --recursive`
B) `Azcopy sync \\server1\images https://corpimages.blob.core.windows.net/public --recursive`
C) `Get-ChildItem -Path \\server1\images -Recurse | Set-AzStorageBlobContent -Container "corpimages"`
D) `Set-AzStorageBlobContent -Container "ContosoUpload" -File "\\server1\images" -Blob "corporateimages"`

<details>
<summary>Ver resposta</summary>

**Resposta: A e C**

**A)** AzCopy copy com --recursive copia todos os arquivos recursivamente para o blob container. E a ferramenta de alta performance para migracoes.

**C)** Get-ChildItem -Recurse lista todos os arquivos e o pipe envia cada um para Set-AzStorageBlobContent, fazendo upload em massa.

**B) Errada:** azcopy sync sincroniza diferencas, nao "migra tudo". Funcionaria na pratica, mas a questao pede "migrar" — copy e a resposta correta para migracao.

**D) Errada:** Set-AzStorageBlobContent com -File espera um **arquivo**, nao uma pasta. E o container e "ContosoUpload" (diferente do cenario). Nao faz upload recursivo.

</details>

### Questao C.2
**Voce precisa copiar blobs do container "data" na storage account storageA para o container "backup" na storage account storageB. A copia deve ser server-to-server (sem baixar localmente). Qual comando e MAIS eficiente?**

A) `Get-AzStorageBlobContent` seguido de `Set-AzStorageBlobContent`
B) `azcopy copy "https://storageA.../data" "https://storageB.../backup" --recursive`
C) `az storage blob download-batch` seguido de `az storage blob upload-batch`
D) `Start-AzStorageBlobCopy -SrcContainer "data" -DestContainer "backup"`

<details>
<summary>Ver resposta</summary>

**Resposta: B) azcopy copy com URLs de origem e destino**

AzCopy com duas URLs faz copia **server-to-server** pelo backbone Azure — os dados nao passam pelo seu computador. E a opcao mais eficiente para volumes grandes.

**D) Tambem funciona** como server-to-server, mas AzCopy e mais eficiente para grandes volumes (paralelismo automatico, retry, log).

**A e C) Erradas:** Ambas baixam localmente primeiro e depois fazem upload — NAO sao server-to-server.

</details>

### Questao C.3
**Voce executa `azcopy sync` de uma pasta local para um blob container. Posteriormente, voce deleta 3 arquivos da pasta local. Ao executar `azcopy sync` novamente (sem flags adicionais), o que acontece com os 3 blobs correspondentes no container?**

A) Os 3 blobs sao deletados do container
B) Os 3 blobs permanecem no container
C) Os 3 blobs sao movidos para soft delete
D) O comando falha com erro

<details>
<summary>Ver resposta</summary>

**Resposta: B) Os 3 blobs permanecem no container**

Por padrao, `azcopy sync` NAO deleta blobs no destino que nao existem mais na origem. Para espelhar delecoes, voce precisa usar `--delete-destination true`. Sem essa flag, sync apenas adiciona e atualiza — nunca remove.

</details>

### Questao C.4
**Voce precisa fazer upload de um unico arquivo para um Azure File Share chamado "reports" usando PowerShell. Qual cmdlet voce deve usar?**

A) `Set-AzStorageBlobContent`
B) `Set-AzStorageFileContent`
C) `Start-AzStorageBlobCopy`
D) `New-AzStorageShare`

<details>
<summary>Ver resposta</summary>

**Resposta: B) Set-AzStorageFileContent**

Para Azure Files, o cmdlet correto e `Set-AzStorageFileContent`. `Set-AzStorageBlobContent` e para Blob Storage — servico diferente. `Start-AzStorageBlobCopy` e para copiar blobs entre contas. `New-AzStorageShare` cria o share, nao faz upload.

**Macete:** Blob → BlobContent. File → FileContent. Sempre.

</details>

### Questao C.5
**Uma equipe precisa manter um container de blob sincronizado com uma pasta de um servidor on-premises. Novos arquivos devem ser copiados, arquivos modificados devem ser atualizados, e arquivos deletados no servidor devem ser removidos do blob. Qual comando atende a TODOS os requisitos?**

A) `azcopy copy "\\server\data" "https://st.blob.../container" --recursive`
B) `azcopy sync "\\server\data" "https://st.blob.../container" --recursive`
C) `azcopy sync "\\server\data" "https://st.blob.../container" --recursive --delete-destination true`
D) `Get-ChildItem -Recurse | Set-AzStorageBlobContent -Force`

<details>
<summary>Ver resposta</summary>

**Resposta: C) azcopy sync com --recursive e --delete-destination true**

O cenario pede 3 coisas: (1) novos → copiar, (2) modificados → atualizar, (3) deletados → remover. Apenas `azcopy sync --delete-destination true` atende aos 3. Sem `--delete-destination`, os blobs orfaos nao sao removidos. `azcopy copy` sempre copia tudo (nao e incremental). `Set-AzStorageBlobContent` nao remove blobs extras.

</details>

### Questao C.6
**Voce tem duas contas de blob de blocos premium chamadas storage1 e storage2. Precisa configurar a replicacao de objeto de storage1 para storage2. Quais TRES recursos devem ser habilitados antes de configurar a replicacao? (Cada resposta e parte da solucao)**

A) Versionamento de blob para storage1
B) Versionamento de blob para storage2
C) Feed de alteracoes para storage1
D) Feed de alteracoes para storage2
E) Restauracao pontual para containers no storage1
F) Restauracao pontual para containers no storage2

<details>
<summary>Ver resposta</summary>

**Resposta: A, B e C**

**A) Versionamento na origem** — obrigatorio. A replicacao rastreia mudancas por versao.

**B) Versionamento no destino** — obrigatorio. O destino precisa receber e manter as versoes replicadas.

**C) Change feed na origem** — obrigatorio. E o log de eventos que registra quais blobs mudaram para disparar a replicacao.

**D) Errada:** Change feed no destino NAO e pre-requisito. So a origem precisa rastrear mudancas.

**E e F) Erradas:** Point-in-time restore NAO e pre-requisito para Object Replication. Sao recursos independentes.

**Macete:** Versioning = AMBAS | Change Feed = so ORIGEM | Point-in-time restore = NENHUMA

</details>

### Questao C.7
**Voce configurou Object Replication de storageA para storageB. A storage account storageA tem namespace hierarquico (HNS) habilitado. A replicacao nao funciona. Qual e a causa?**

A) HNS requer Premium Block Blobs para replicacao
B) Contas com HNS (Data Lake Gen2) nao suportam Object Replication
C) O change feed nao foi habilitado
D) O versionamento nao foi habilitado no destino

<details>
<summary>Ver resposta</summary>

**Resposta: B) Contas com HNS (Data Lake Gen2) nao suportam Object Replication**

Object Replication NAO e suportada em contas com namespace hierarquico habilitado. Se a conta e Data Lake Gen2, voce precisa usar outra estrategia (ex: AzCopy scheduled, Data Factory). Essa e uma restricao frequentemente testada no AZ-104.

</details>

### Questao C.8
**Voce tem uma storage account storageaccount1 com um container container1 que armazena informacoes confidenciais. Voce precisa garantir que o conteudo do container1 nao seja modificado ou excluido por seis meses apos a data da ultima modificacao. O que voce deve configurar?**

A) Uma funcao de Azure personalizada
B) Gerenciamento de ciclo de vida
C) O fluxo de alteracoes
D) A politica de imutabilidade

<details>
<summary>Ver resposta</summary>

**Resposta: D) A politica de imutabilidade**

Immutability policy (time-based retention) impede modificacao e exclusao de blobs por um periodo definido. Configurando 180 dias (6 meses), os blobs ficam protegidos contra qualquer alteracao ate o prazo expirar.

**A) Errada:** Azure Functions executam codigo, nao protegem dados contra exclusao.

**B) Errada:** Lifecycle Management **move** blobs entre tiers ou **deleta** — e o oposto de proteger contra exclusao.

**C) Errada:** Change feed **registra** eventos (log de alteracoes) — nao impede nada.

**Macete:**
- "Nao modificar/excluir por X meses" → **Immutability (time-based)**
- "Bloquear por investigacao legal" → **Immutability (legal hold)**
- "Mover para Cool/Archive apos X dias" → **Lifecycle Management**
- "Registrar alteracoes" → **Change Feed**

</details>

### Questao C.9
**Voce tem um modelo ARM chamado deploy.json armazenado em um container de blob do Azure. Voce planeja implantar o modelo usando o cmdlet New-AzResourceGroupDeployment. Qual parametro voce deve usar para referenciar o modelo?**

A) `-Tag`
B) `-TemplateFile`
C) `-TemplateSpecId`
D) `-TemplateUri`

<details>
<summary>Ver resposta</summary>

**Resposta: D) -TemplateUri**

O template esta em um **blob container** (URL acessivel via HTTP). `-TemplateUri` aceita URLs de blob storage, GitHub ou qualquer endpoint web.

**A) Errada:** `-Tag` aplica tags ao deployment, nao referencia templates.

**B) Errada:** `-TemplateFile` aponta para arquivo **local** no disco. O template esta em blob storage, nao localmente.

**C) Errada:** `-TemplateSpecId` referencia um Template Spec **salvo no Azure** (recurso gerenciado). Um blob em storage account NAO e Template Spec.

**Macete:** Local = `-TemplateFile` | URL = `-TemplateUri` | Template Spec = `-TemplateSpecId`

</details>

### Questao C.10
**Voce usa modelos ARM para implantar recursos. Precisa passar uma matriz (array) como parametro inline durante a implantacao de um modelo local. O que voce deve fazer?**

A) Modifique o modelo para incluir os valores da matriz
B) Use a opcao --template-file para passar os valores da matriz
C) Forneca os valores da matriz na alternancia --parameters no comando de implantacao
D) Crie um arquivo de parametros separado que inclua os valores da matriz

<details>
<summary>Ver resposta</summary>

**Resposta: C) Forneca os valores na alternancia --parameters**

A questao pede **inline** — ou seja, direto no comando, sem arquivo separado. A sintaxe e:
```bash
az deployment group create \
  --template-file template.json \
  --parameters myArray='["val1","val2","val3"]'
```

**A) Errada:** Modificar o template hardcoda valores — viola o proposito de parametrizacao.

**B) Errada:** `--template-file` referencia o **template**, nao passa parametros.

**C) Correta:** `--parameters` aceita valores inline incluindo arrays em formato JSON.

**D) Errada:** Arquivo separado funciona, mas a questao pede especificamente **inline** (sem arquivo).

</details>

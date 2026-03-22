# Lab Extra - Permissionamento: Entra ID Roles, RBAC e ABAC

**Objetivo:** Praticar os 3 sistemas de permissionamento do Azure — atribuir Entra ID Roles (diretorio), Azure RBAC (recursos) e ABAC (condicoes). Inclui cenarios de troubleshoot para identificar qual sistema usar.
**Tempo estimado:** 45min
**Custo:** ~$0.10 (1 Storage Account + 1 VM B1s por ~30min)

> **IMPORTANTE:** Este lab usa usuarios de teste. Se sua subscription for pessoal com um unico usuario, crie pelo menos 1 usuario de teste no Entra ID para praticar.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ┌─────────────────────────┐    ┌──────────────────────────────────┐  │
│  │ ENTRA ID (Diretorio)    │    │ AZURE (Recursos)                 │  │
│  │                         │    │                                  │  │
│  │ user-web@tenant         │    │ rg-lab-perms                     │  │
│  │ user-db@tenant          │    │ ├── vm-perms-test                │  │
│  │ user-guest (convidado)  │    │ ├── stpermstest<id>              │  │
│  │                         │    │ │   ├── container: public-data   │  │
│  │ Entra ID Roles:         │    │ │   └── container: finance-data  │  │
│  │ • Guest Inviter         │    │ └── tags: dept=IT, env=lab       │  │
│  │ • User Administrator    │    │                                  │  │
│  └─────────────────────────┘    │ RBAC:                            │  │
│                                 │ • user-web → VM Contributor (RG) │  │
│  Pratica:                       │ • user-db → Reader (RG)          │  │
│  1. Entra ID Roles (diretorio)  │ • user-web → Tag Contributor     │  │
│  2. Azure RBAC (recursos)       │                                  │  │
│  3. Azure ABAC (condicoes)      │ ABAC:                            │  │
│  4. Comparar e diagnosticar     │ • Blob Reader + condicao tag     │  │
│                                 └──────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Parte 1: Setup

### Task 1.1: Criar Resource Group e recursos (via Bicep)

> **Usando Bicep para acelerar:** Os pre-requisitos (Storage Account, containers, VM) sao criados de uma vez com um template Bicep. Isso permite focar no que importa: RBAC, Policy e Key Vault.

```bash
RG="rg-lab-perms"
LOCATION="eastus"

# Criar RG com tags
az group create --name $RG --location $LOCATION --tags dept=IT env=lab

# Deploy dos pre-requisitos via Bicep (Storage + containers + VM)
az deployment group create \
  --resource-group $RG \
  --template-file labs/extras/templates/lab-perms-prereqs.bicep \
  --parameters adminPassword="Lab@Perms2026!" \
  --query "properties.outputs" -o table

# Capturar nome da storage account criada
ST=$(az deployment group show --resource-group $RG --name lab-perms-prereqs --query "properties.outputs.storageName.value" -o tsv)

# Upload de blobs de teste com tags (index tags) — precisa ser manual (Bicep nao faz upload de dados)
echo "dados publicos" > /tmp/public.txt
echo "dados financeiros confidenciais" > /tmp/finance.txt

az storage blob upload --container-name public-data --name info.txt --file /tmp/public.txt --account-name $ST --auth-mode login --tags "dept=IT"
az storage blob upload --container-name finance-data --name report.txt --file /tmp/finance.txt --account-name $ST --auth-mode login --tags "dept=Finance"

echo "Recursos criados: RG=$RG, Storage=$ST, VM=vm-perms-test"
```

> **O que o Bicep criou:** Storage Account (Standard_LRS) + 2 containers (public-data, finance-data) + VNet + VM Ubuntu B1s (sem IP publico). Os uploads de blob sao feitos via CLI porque Bicep nao gerencia dados dentro dos containers.

### Task 1.2: Desabilitar Security Defaults (evitar MFA nos usuarios de teste)

> **Por que?** Security Defaults forca MFA para todos os usuarios. Sem desabilitar, os usuarios de teste vao pedir MFA no primeiro login, poluindo seu Authenticator app e gastando tempo. **Reabilite apos o lab!**

**Portal → Entra ID → Properties → Manage security defaults → Disabled → Save**

Ou via CLI:
```bash
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy" \
  --body '{"isEnabled": false}'
```

> **LEMBRETE:** No cleanup do lab (final), reabilitar Security Defaults!

### Task 1.3: Criar usuarios de teste no Entra ID

**Pelo portal:**

1. Portal > **Microsoft Entra ID** > **Users** > **+ New user** > **Create new user**

   | Setting             | User 1                  | User 2                 |
   | ------------------- | ----------------------- | ---------------------- |
   | Display name        | `User Web`              | `User DB`              |
   | User principal name | `user-web@<seu-tenant>` | `user-db@<seu-tenant>` |
   | Password            | Auto-generate           | Auto-generate          |

2. **Create** para cada usuario

**Ou via CLI:**

```bash
# Obter dominio do tenant
DOMAIN=$(az ad signed-in-user show --query "userPrincipalName" -o tsv | cut -d@ -f2)

# Criar usuarios
az ad user create \
  --display-name "User Web" \
  --user-principal-name "user-web@${DOMAIN}" \
  --password "Lab@Perms2026!" \
  --force-change-password-next-sign-in false

az ad user create \
  --display-name "User DB" \
  --user-principal-name "user-db@${DOMAIN}" \
  --password "Lab@Perms2026!" \
  --force-change-password-next-sign-in false

echo "Usuarios criados: user-web@${DOMAIN}, user-db@${DOMAIN}"
```

> **Anote as senhas** — voce vai precisar para testar logins em aba anonima.
> **Teste de login:** Abra aba anonima → portal.azure.com → login com user-web@domain / Lab@Perms2026!

---

## Parte 2: Entra ID Roles (Diretorio)

> **Contexto:** Entra ID Roles controlam o **diretorio** — usuarios, grupos, convites, licencas. NAO controlam recursos Azure (VMs, storage).

### Task 2.1: Atribuir Guest Inviter ao user-web

```bash
# Obter Object ID do user-web
USER_WEB_ID=$(az ad user show --id "user-web@${DOMAIN}" --query id -o tsv)

# Obter o role definition ID do Guest Inviter
# Guest Inviter role ID e fixo: 95e79109-95c0-4d8e-aee3-d01accf2d47a
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
  --body "{\"principalId\": \"${USER_WEB_ID}\", \"roleDefinitionId\": \"95e79109-95c0-4d8e-aee3-d01accf2d47a\", \"directoryScopeId\": \"/\"}"

echo "Guest Inviter atribuido ao user-web"
```

**Ou pelo portal (mais facil):**

1. **Entra ID** > **Roles and administrators** > pesquise **Guest Inviter**
2. **+ Add assignments** > selecione **User Web** > **Add**

### Task 2.2: Verificar que Guest Inviter NAO da acesso a recursos

1. Abra uma janela **anonima/privada** do navegador
2. Acesse **portal.azure.com** e faca login como `user-web@<tenant>`
3. Navegue para **Resource groups** → user-web **NAO ve** rg-lab-perms (ou ve vazio)
4. Navegue para **Entra ID** > **Users** > **+ New guest user** → user-web **CONSEGUE** convidar

> **Aprendizado:** Guest Inviter e uma Entra ID Role — permite convidar externos mas NAO da acesso a recursos Azure. Sao sistemas separados.

### Task 2.3: Comparar com User Administrator

1. Portal > **Entra ID** > **Roles and administrators** > **User Administrator**
2. Observe as permissoes: criar/deletar usuarios, resetar senhas, gerenciar grupos
3. Compare com Guest Inviter: apenas convidar externos

> **Regra para prova:**
> | Necessidade | Entra ID Role | Por que NAO RBAC |
> |---|---|---|
> | Convidar externos | Guest Inviter | Convites sao funcao de diretorio |
> | Resetar senhas | User Administrator | Senhas sao do diretorio |
> | Gerenciar licencas | License Administrator | Licencas sao do diretorio |
> | Gerenciar VMs | ❌ Entra ID NAO faz isso | Usar RBAC |

---

## Parte 3: Azure RBAC (Recursos)

> **Contexto:** RBAC controla o acesso a **recursos Azure** (VMs, storage, VNets). Escopo: MG → Sub → RG → Resource.

### Task 3.1: Atribuir Virtual Machine Contributor ao user-web

**Metodo 1 — Azure CLI:**

```bash
USER_WEB_ID=$(az ad user show --id "user-web@${DOMAIN}" --query id -o tsv)

# RBAC: VM Contributor no escopo do RG
az role assignment create \
  --assignee $USER_WEB_ID \
  --role "Virtual Machine Contributor" \
  --resource-group $RG

echo "VM Contributor atribuido ao user-web no $RG"
```

**Metodo 2 — PowerShell (Az module):**

```powershell
# Obter o usuario
$user = Get-AzADUser -UserPrincipalName "user-web@$Domain"

# Atribuir VM Contributor no RG
New-AzRoleAssignment `
  -ObjectId $user.Id `
  -RoleDefinitionName "Virtual Machine Contributor" `
  -ResourceGroupName "rg-lab-perms"
```

**Metodo 3 — Portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **+ Add role assignment**
2. Role: **Virtual Machine Contributor** > **Next**
3. Members: **+ Select members** > selecione **User Web** > **Select**
4. **Review + assign**

> **Dica:** Os tres metodos produzem exatamente o mesmo resultado — uma role assignment no Azure Resource Manager. A escolha depende da situacao: CLI para scripts rapidos, PowerShell para automacao em Windows, Portal para validacao visual.

### Task 3.2: Atribuir Reader ao user-db

**Metodo 1 — Azure CLI:**

```bash
USER_DB_ID=$(az ad user show --id "user-db@${DOMAIN}" --query id -o tsv)

# RBAC: Reader no escopo do RG
az role assignment create \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --resource-group $RG

echo "Reader atribuido ao user-db no $RG"
```

**Metodo 2 — PowerShell (Az module):**

```powershell
$user = Get-AzADUser -UserPrincipalName "user-db@$Domain"

New-AzRoleAssignment `
  -ObjectId $user.Id `
  -RoleDefinitionName "Reader" `
  -ResourceGroupName "rg-lab-perms"
```

**Metodo 3 — Portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **+ Add role assignment**
2. Role: **Reader** > **Next**
3. Members: **+ Select members** > selecione **User DB** > **Select**
4. **Review + assign**

### Task 3.3: Testar as permissoes RBAC

**Como user-web (VM Contributor):**

1. Login anonimo como user-web
2. Navegue para **rg-lab-perms** > **vm-perms-test** → **consegue** ver e gerenciar
3. Tente **parar** a VM → **funciona** (VM Contributor permite)
4. Tente acessar **Storage Account** > **Containers** → **nao consegue** ver dados (VM Contributor nao da acesso a storage)

**Como user-db (Reader):**

1. Login anonimo como user-db
2. Navegue para **rg-lab-perms** > **vm-perms-test** → **consegue** ver
3. Tente **parar** a VM → **falha** (Reader e somente leitura)
4. Tente **criar** qualquer recurso → **falha**

> **Aprendizado:** RBAC e granular por role. VM Contributor gerencia VMs mas nao storage. Reader ve tudo mas nao modifica nada. Cada role tem permissoes especificas.

### Task 3.4: Atribuir Tag Contributor ao user-web

**Metodo 1 — Azure CLI:**

```bash
# Tag Contributor: pode gerenciar tags SEM acessar recursos
az role assignment create \
  --assignee $USER_WEB_ID \
  --role "Tag Contributor" \
  --resource-group $RG

echo "Tag Contributor atribuido ao user-web"
```

**Metodo 2 — PowerShell (Az module):**

```powershell
New-AzRoleAssignment `
  -ObjectId $user.Id `
  -RoleDefinitionName "Tag Contributor" `
  -ResourceGroupName "rg-lab-perms"
```

**Metodo 3 — Portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **+ Add role assignment**
2. Role: **Tag Contributor** > **Next**
3. Members: **+ Select members** > selecione **User Web** > **Select**
4. **Review + assign**

**Testar como user-web:**

1. Navegue para **vm-perms-test** > **Tags**
2. Adicione tag `owner=web-team` > **Save** → **funciona**
3. Isso e a resposta da questao: "Garantir que usuario possa marcar VMs seguindo privilegio minimo" → **Tag Contributor**

> **Dica prova:** Tag Contributor permite gerenciar tags **sem dar acesso** ao recurso em si. E a resposta para "privilegio minimo para tags".

### Task 3.5: Verificar role assignments pelo portal, CLI e PowerShell

**Azure CLI:**

```bash
# Listar todas as atribuicoes no RG
az role assignment list \
  --resource-group $RG \
  --query "[].{principal:principalName, role:roleDefinitionName, scope:scope}" \
  -o table
```

**PowerShell:**

```powershell
# Listar todas as atribuicoes no RG
Get-AzRoleAssignment -ResourceGroupName "rg-lab-perms" |
  Select-Object DisplayName, RoleDefinitionName, Scope |
  Format-Table
```

**Pelo portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **Role assignments**
2. Observe todos os assignments listados
3. Clique em **Check access** > digite `user-web` > veja as roles atribuidas

### Task 3.6: Entender heranca de escopo

**Metodo 1 — Azure CLI:**

```bash
# Atribuir Reader ao user-db no nivel da SUBSCRIPTION
SUB_ID=$(az account show --query id -o tsv)

az role assignment create \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --scope "/subscriptions/${SUB_ID}"

echo "Reader atribuido ao user-db na subscription inteira"
```

**Metodo 2 — PowerShell (Az module):**

```powershell
$subId = (Get-AzContext).Subscription.Id

New-AzRoleAssignment `
  -ObjectId $user.Id `
  -RoleDefinitionName "Reader" `
  -Scope "/subscriptions/$subId"
```

> **Observe:** No CLI usamos `--scope`, no PowerShell usamos `-Scope`. Ambos aceitam o resource ID completo do escopo.

> **Heranca:** Reader na subscription → user-db ve TODOS os RGs e recursos. Reader no RG → ve apenas aquele RG. Permissoes fluem de cima para baixo:
> ```
> Management Group → Subscription → Resource Group → Resource
>        ↓                ↓               ↓              ↓
>     Herda para      Herda para      Herda para     Escopo final
>     todas subs      todos RGs       todos recursos
> ```

**Remover a atribuicao (CLI):**

```bash
# Remover o Reader da subscription (manter apenas no RG)
az role assignment delete \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --scope "/subscriptions/${SUB_ID}"

echo "Reader removido da subscription"
```

**Remover a atribuicao (PowerShell):**

```powershell
Remove-AzRoleAssignment `
  -ObjectId $user.Id `
  -RoleDefinitionName "Reader" `
  -Scope "/subscriptions/$subId"
```

### Task 3.7: Role Assignment via ARM Template

> **Por que aprender ARM Template para RBAC?** Na prova, questoes podem pedir que voce identifique ou complete um template JSON para atribuir roles. Alem disso, ARM Templates permitem **deployments declarativos e reprodutiveis** — ideal para IaC (Infrastructure as Code).

O recurso `Microsoft.Authorization/roleAssignments` e o tipo ARM que cria role assignments. Veja o template completo abaixo.

**Template ARM — `role-assignment.json`:**

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "principalId": {
      "type": "string",
      "metadata": {
        "description": "Object ID do usuario, grupo ou service principal que recebera a role."
      }
    },
    "roleDefinitionId": {
      "type": "string",
      "metadata": {
        "description": "ID da role definition. Ex: acdd72a7-3385-48ef-bd42-f606fba81ae7 = Reader"
      }
    },
    "principalType": {
      "type": "string",
      "defaultValue": "User",
      "allowedValues": ["User", "Group", "ServicePrincipal"],
      "metadata": {
        "description": "Tipo do principal."
      }
    }
  },
  "variables": {
    "roleAssignmentName": "[guid(resourceGroup().id, parameters('principalId'), parameters('roleDefinitionId'))]"
  },
  "resources": [
    {
      "type": "Microsoft.Authorization/roleAssignments",
      "apiVersion": "2022-04-01",
      "name": "[variables('roleAssignmentName')]",
      "properties": {
        "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', parameters('roleDefinitionId'))]",
        "principalId": "[parameters('principalId')]",
        "principalType": "[parameters('principalType')]"
      }
    }
  ],
  "outputs": {
    "roleAssignmentId": {
      "type": "string",
      "value": "[variables('roleAssignmentName')]"
    }
  }
}
```

> **Pontos-chave do template:**
>
> | Elemento | Explicacao |
> |----------|-----------|
> | `name` | Precisa ser um **GUID**. Usamos `guid()` para gerar deterministicamente |
> | `roleDefinitionId` | Usa `subscriptionResourceId()` — NAO e o ID curto, e o resource ID completo |
> | `principalId` | E o **Object ID** do usuario (nao o UPN/email) |
> | `principalType` | `User`, `Group` ou `ServicePrincipal` |

**Deploy do template (CLI):**

```bash
# Obter IDs necessarios
USER_DB_ID=$(az ad user show --id "user-db@${DOMAIN}" --query id -o tsv)
# Reader role definition ID (fixo em todo Azure):
READER_ROLE="acdd72a7-3385-48ef-bd42-f606fba81ae7"

az deployment group create \
  --resource-group $RG \
  --template-file role-assignment.json \
  --parameters principalId=$USER_DB_ID \
               roleDefinitionId=$READER_ROLE \
               principalType=User
```

**Deploy do template (PowerShell):**

```powershell
$userDbId = (Get-AzADUser -UserPrincipalName "user-db@$Domain").Id
$readerRole = "acdd72a7-3385-48ef-bd42-f606fba81ae7"

New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-lab-perms" `
  -TemplateFile "role-assignment.json" `
  -principalId $userDbId `
  -roleDefinitionId $readerRole `
  -principalType "User"
```

> **IDs de roles built-in mais comuns (fixos em todo Azure):**
>
> | Role | Role Definition ID |
> |------|--------------------|
> | Owner | `8e3af657-a8ff-443c-a75c-2fe8c4bcb635` |
> | Contributor | `b24988ac-6180-42a0-ab88-20f7382dd24c` |
> | Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
> | User Access Administrator | `18d7d88d-d35e-4fb5-a5c3-7773c20a72d9` |
> | Virtual Machine Contributor | `9980e02c-c2be-4d73-94e8-173b1dc7cf3c` |
> | Storage Blob Data Reader | `2a2b9908-6ea1-4ae2-8e65-a410df84e7d1` |
> | Tag Contributor | `4a9ae827-6dc8-4573-8ac7-8239d42aa03f` |

---

## Parte 4: Azure ABAC (RBAC + Condicoes)

> **Contexto:** ABAC e RBAC com condicoes extras — "pode ler blobs, MAS apenas se tag = X". Raramente cai no AZ-104, mas aparece como distrator.

### Task 4.1: Atribuir Storage Blob Data Reader com condicao

**Pelo portal (CLI para ABAC e complexo):**

1. **rg-lab-perms** > **Access control (IAM)** > **+ Add role assignment**
2. Role: **Storage Blob Data Reader**
3. Members: **User DB**
4. Aba **Conditions** > **+ Add condition**
5. Configure:

   | Setting    | Value                                           |
   | ---------- | ----------------------------------------------- |
   | Action     | Read a blob                                     |
   | Expression | **Container name** StringEquals **public-data** |

6. **Save** > **Review + assign**

> **O que fizemos:** user-db pode ler blobs, mas APENAS no container `public-data`. Acesso ao container `finance-data` e bloqueado pela condicao.

### Task 4.2: Testar ABAC — acesso condicionado

**Como user-db:**

1. Portal > Storage Account > **Containers** > **public-data** → **consegue** listar e baixar blobs
2. Portal > Storage Account > **Containers** > **finance-data** → **bloqueado** (condicao nao permite)

> **Aprendizado:** Sem ABAC, Storage Blob Data Reader daria acesso a TODOS os containers. Com ABAC, restringimos a um container especifico. E o "privilegio minimo" levado ao extremo.

### Task 4.3: Comparar RBAC puro vs ABAC

```
RBAC puro:
  "user-db pode ler blobs no storage account X"
  → Acessa public-data ✅ E finance-data ✅

ABAC:
  "user-db pode ler blobs no storage account X,
   MAS apenas no container public-data"
  → Acessa public-data ✅ mas finance-data ❌
```

> **Na prova:** Se a questao menciona "acesso condicional por tag/atributo" ou "apenas blobs com tag X" → ABAC. Se nao menciona condicoes → RBAC puro.

---

## Parte 5: Diagnostico — Qual sistema usar?

> **Objetivo:** Praticar a identificacao rapida de qual sistema (Entra ID, RBAC ou ABAC) usar em cada cenario.

### Task 5.1: Cenarios de decisao (resolva mentalmente, depois confira)

**Cenario A:** "User1 precisa convidar usuarios externos para o tenant."
<details>
<summary>Resposta</summary>

**Entra ID Role: Guest Inviter.** Convites sao funcao de diretorio, nao de infraestrutura.
</details>

**Cenario B:** "User2 precisa criar e deletar VMs no RG-Prod."
<details>
<summary>Resposta</summary>

**Azure RBAC: Virtual Machine Contributor no escopo do RG-Prod.** Envolve recurso Azure (VM).
</details>

**Cenario C:** "User3 precisa ler blobs apenas com tag project=finance."
<details>
<summary>Resposta</summary>

**Azure ABAC: Storage Blob Data Reader + condicao de atributo (tag).** A palavra "apenas" + "tag" = ABAC.
</details>

**Cenario D:** "User4 precisa resetar senhas de outros usuarios."
<details>
<summary>Resposta</summary>

**Entra ID Role: Password Administrator ou Helpdesk Administrator.** Senhas sao do diretorio.
</details>

**Cenario E:** "User5 precisa ver custos e gerenciar budgets sem modificar recursos."
<details>
<summary>Resposta</summary>

**Azure RBAC: Cost Management Contributor.** Custos e budgets sao funcoes de recurso/subscription. Reader NAO gerencia budgets (apenas visualiza).
</details>

**Cenario F:** "User6 precisa marcar todas as VMs com tags de departamento."
<details>
<summary>Resposta</summary>

**Azure RBAC: Tag Contributor.** Permite gerenciar tags sem acesso ao recurso em si. Privilegio minimo para tags.
</details>

**Cenario G:** "User7 precisa gerenciar DNS zones e registros."
<details>
<summary>Resposta</summary>

**Azure RBAC: DNS Zone Contributor.** DNS zones sao recursos Azure.
</details>

### Task 5.2: Checklist rapido para a prova

```
A questao menciona...              → Sistema
──────────────────────────────────────────────
Usuarios, grupos, convites         → Entra ID Role
Licencas, MFA, SSPR, dominios      → Entra ID Role
VMs, Storage, VNets, RGs           → Azure RBAC
"Privilegio minimo" + recurso      → Azure RBAC (role especifica)
"Apenas quando tag/atributo = X"   → ABAC
"Apenas blobs no path /finance"    → ABAC
Tags de recursos                   → RBAC (Tag Contributor)
Custos e budgets                   → RBAC (Cost Management Contributor)
```

---

## Parte 6: Effective Access e Troubleshoot

### Task 6.1: Verificar acesso efetivo de um usuario

**Azure CLI:**

```bash
# Ver TODAS as roles do user-web neste RG
az role assignment list \
  --resource-group $RG \
  --assignee $USER_WEB_ID \
  --query "[].{role:roleDefinitionName, scope:scope}" \
  -o table
```

**PowerShell:**

```powershell
# Ver TODAS as roles do user-web neste RG
Get-AzRoleAssignment `
  -ResourceGroupName "rg-lab-perms" `
  -ObjectId $user.Id |
  Select-Object RoleDefinitionName, Scope |
  Format-Table
```

**Pelo portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **Check access**
2. Digite `user-web` > selecione
3. Veja todas as roles atribuidas e de onde vem (heranca vs direto)

### Task 6.2: Verificar Entra ID Roles de um usuario

1. **Entra ID** > **Users** > **User Web** > **Assigned roles**
2. Lista as Entra ID Roles (ex: Guest Inviter)
3. Compare com a aba **Azure role assignments** (mostra RBAC)

> **Conceito:** Um usuario pode ter Entra ID Roles E RBAC ao mesmo tempo. Sao sistemas independentes. user-web tem Guest Inviter (diretorio) + VM Contributor + Tag Contributor (recursos).

### Task 6.3: Troubleshoot — "User nao consegue fazer X"

**Cenario:** user-db tenta criar uma VM no rg-lab-perms e recebe erro de permissao.

**Azure CLI:**

```bash
# Verificar roles do user-db
az role assignment list \
  --resource-group $RG \
  --assignee $USER_DB_ID \
  --query "[].roleDefinitionName" -o tsv
```

**PowerShell:**

```powershell
(Get-AzRoleAssignment -ResourceGroupName "rg-lab-perms" -ObjectId $userDb.Id).RoleDefinitionName
```

> **Resultado:** Reader. Reader e somente leitura — nao permite criar recursos. Para resolver: atribuir **Contributor** ou **Virtual Machine Contributor** no RG.

**Cenario:** user-web tenta ler blobs no storage account e recebe erro.

> **Causa:** VM Contributor e Tag Contributor NAO dao acesso a dados do storage. Para dados de blob, precisa de **Storage Blob Data Reader/Contributor** (data plane role).

> **Conceito importante:** Roles de **management plane** (Contributor, Owner) gerenciam o recurso. Roles de **data plane** (Storage Blob Data Reader) acessam os **dados dentro** do recurso. Sao camadas diferentes.

```
Management plane: "quem pode criar/deletar o storage account"
  → Contributor, Owner, Storage Account Contributor

Data plane: "quem pode ler/escrever os blobs dentro do storage"
  → Storage Blob Data Reader/Contributor/Owner
```

---

## Cleanup

**Azure CLI:**

```bash
# Remover role assignments
az role assignment delete --assignee $USER_WEB_ID --resource-group $RG
az role assignment delete --assignee $USER_DB_ID --resource-group $RG

# Deletar usuarios de teste
az ad user delete --id "user-web@${DOMAIN}"
az ad user delete --id "user-db@${DOMAIN}"

# Reabilitar Security Defaults (IMPORTANTE!)
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy" \
  --body '{"isEnabled": true}'
echo "Security Defaults reabilitado!"

# Deletar recursos
az group delete --name rg-lab-perms --yes --no-wait

echo "Cleanup completo"
```

**PowerShell:**

```powershell
# Remover role assignments
Get-AzRoleAssignment -ResourceGroupName "rg-lab-perms" -ObjectId $user.Id |
  Remove-AzRoleAssignment
Get-AzRoleAssignment -ResourceGroupName "rg-lab-perms" -ObjectId $userDb.Id |
  Remove-AzRoleAssignment

# Deletar usuarios de teste
Remove-AzADUser -UserPrincipalName "user-web@$Domain" -Force
Remove-AzADUser -UserPrincipalName "user-db@$Domain" -Force

# Deletar recursos
Remove-AzResourceGroup -Name "rg-lab-perms" -Force -AsJob
```

---

## Modo Desafio

- [ ] Criar 2 usuarios de teste no Entra ID
- [ ] Atribuir Guest Inviter (Entra ID Role) e testar que NAO da acesso a recursos
- [ ] Atribuir VM Contributor (RBAC) via CLI e testar que gerencia VMs mas nao storage
- [ ] Repetir atribuicao de VM Contributor via PowerShell (remover antes e reatribuir)
- [ ] Atribuir Tag Contributor e testar que marca recursos sem acessa-los
- [ ] Atribuir Reader via ARM Template e verificar que funciona
- [ ] Configurar ABAC: Storage Blob Data Reader com condicao de container
- [ ] Testar: acessa public-data mas nao finance-data
- [ ] Verificar effective access via portal, CLI e PowerShell
- [ ] Listar role assignments usando os 3 metodos (Portal, CLI, PowerShell)
- [ ] Resolver os 7 cenarios de decisao sem consultar
- [ ] Cleanup usando CLI ou PowerShell

---

## Parte 4 — Governança: Azure Policy e Key Vault

### Task 4.1 — Azure Policy: Escopos Válidos

**Conceito crítico (errado em 2 simulados!):**

Azure Policy pode ser atribuída em **3 escopos apenas**:

| Escopo             | Exemplo           | Válido? |
| ------------------ | ----------------- | ------- |
| Management Group   | Tenant Root Group | ✅ SIM   |
| Subscription       | Sub-Produção      | ✅ SIM   |
| Resource Group     | RG-WebApps        | ✅ SIM   |
| Recurso individual | VM1               | ❌ NÃO   |
| Região             | East US           | ❌ NÃO   |

Para filtrar recurso específico dentro de um escopo, use **condições na policy definition** (ex: `"field": "type", "equals": "Microsoft.Compute/virtualMachines"`), NÃO tente atribuir ao recurso.

**Exemplo — Atribuir Policy via CLI:**
```bash
# Atribuir a policy "Allowed locations" a um Resource Group
az policy assignment create \
  --name "restrict-locations" \
  --policy "e56962a6-4747-49cd-b67b-bf8b01975c4c" \
  --scope "/subscriptions/{sub-id}/resourceGroups/RG-WebApps" \
  --params '{"listOfAllowedLocations": {"value": ["eastus", "westus"]}}'
```

**Exemplo — Atribuir Policy via PowerShell:**
```powershell
$definition = Get-AzPolicyDefinition -Id "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
New-AzPolicyAssignment `
  -Name "restrict-locations" `
  -PolicyDefinition $definition `
  -Scope "/subscriptions/{sub-id}/resourceGroups/RG-WebApps" `
  -PolicyParameterObject @{listOfAllowedLocations=@("eastus","westus")}
```

> **DICA PROVA:** "Em quais escopos Azure Policy pode ser atribuída?" → MG, Subscription, RG. NUNCA recurso individual. NUNCA região.

### Task 4.2 — Key Vault: Acesso para ARM Templates

**Conceito crítico (errado em simulado!):**

Para usar segredos do Key Vault como parâmetros em ARM Templates, é preciso habilitar uma **Access Policy específica** no Key Vault:

```
Key Vault → Properties → Azure Resource Manager for template deployment → Enable
```

| Configuração                                     | O que faz                                    | Quando usar                   |
| ------------------------------------------------ | -------------------------------------------- | ----------------------------- |
| **Enable access to ARM for template deployment** | Permite que ARM leia segredos durante deploy | Senhas de VM em ARM templates |
| Enable access to Azure Disk Encryption           | Permite criptografia de discos               | Disk Encryption com CMK       |
| Enable access to VMs for deployment              | Permite VMs acessarem segredos               | Certificados em VMs           |

**Exemplo — Habilitar via CLI:**
```bash
az keyvault update \
  --name MyKeyVault \
  --resource-group RG1 \
  --enabled-for-template-deployment true
```

**Exemplo — Habilitar via PowerShell:**
```powershell
Set-AzKeyVaultAccessPolicy `
  -VaultName "MyKeyVault" `
  -EnabledForTemplateDeployment
```

**Referência no ARM Template (arquivo de parâmetros):**
```json
{
  "adminPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/{sub-id}/resourceGroups/RG1/providers/Microsoft.KeyVault/vaults/MyKeyVault"
      },
      "secretName": "vmAdminPassword"
    }
  }
}
```

> **DICA PROVA:** "Segredos como parâmetros ARM sem texto simples" → Key Vault + "Enable access to ARM for template deployment". NÃO confundir com Access Keys (conceito de Storage Account).

### Task 4.3 — Conditional Access: Grant Control vs Session Control

**Conceito crítico (errado em simulado!):**

| Tipo de Controle    | O que configura                                  | Exemplos                                                                                                     |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| **Grant Control**   | **Quem pode acessar** (autenticação)             | MFA obrigatório, dispositivo em conformidade, dispositivo ingressado no Entra ID, app aprovado               |
| **Session Control** | **Como a sessão se comporta** (pós-autenticação) | Duração da sessão, persistência de browser, app-enforced restrictions, Conditional Access App Control (MCAS) |

**Regra de ouro:**
- "Exigir MFA" → **Grant Control** ✅
- "Exigir dispositivo ingressado" → **Grant Control** ✅
- "Limitar duração da sessão" → **Session Control**
- "Bloquear download de arquivos" → **Session Control** (via MCAS)

> **DICA PROVA:** MFA, dispositivo, app aprovado = GRANT Control. Duração, persistência, restrições de app = SESSION Control. A prova tenta confundir esses dois!

---

## Comparacao de Metodos para Role Assignments

> **Por que isso importa?** Na prova AZ-104, voce pode encontrar questoes que pedem para escolher o metodo correto de atribuir roles, completar um script, ou identificar erros em templates. Entender os 4 metodos ajuda a responder com confianca.

### Tabela Comparativa

| Aspecto                  | Portal                         | Azure CLI                    | PowerShell                   | ARM Template                     |
| ------------------------ | ------------------------------ | ---------------------------- | ---------------------------- | -------------------------------- |
| **Tipo**                 | Interface grafica              | Linha de comando             | Linha de comando             | Declarativo (JSON)               |
| **Idempotente**          | N/A (manual)                   | Nao (erro se ja existe)      | Nao (erro se ja existe)      | **Sim** (deploy sem erro)        |
| **Automacao**            | Nao                            | Sim (scripts .sh)            | Sim (scripts .ps1)           | Sim (deploy pipeline)            |
| **IaC**                  | Nao                            | Parcial                      | Parcial                      | **Sim** (Infrastructure as Code) |
| **Melhor para**          | Validacao visual, troubleshoot | Scripts rapidos, Linux/macOS | Automacao Windows, pipelines | Deploy reprodutivel, governanca  |
| **Curva de aprendizado** | Baixa                          | Media                        | Media                        | Alta                             |
| **Escopo do deploy**     | Qualquer (interativo)          | Qualquer (`--scope`)         | Qualquer (`-Scope`)          | Definido no deployment           |

### Sintaxe Lado a Lado — Atribuir Reader no RG

**Portal:**
> IAM > Add role assignment > Reader > Selecionar usuario > Review + assign

**CLI:**
```bash
az role assignment create --assignee <OBJECT_ID> --role "Reader" --resource-group <RG>
```

**PowerShell:**
```powershell
New-AzRoleAssignment -ObjectId <OBJECT_ID> -RoleDefinitionName "Reader" -ResourceGroupName <RG>
```

**ARM Template (recurso):**
```json
{
  "type": "Microsoft.Authorization/roleAssignments",
  "apiVersion": "2022-04-01",
  "name": "[guid(resourceGroup().id, parameters('principalId'), 'acdd72a7-3385-48ef-bd42-f606fba81ae7')]",
  "properties": {
    "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')]",
    "principalId": "[parameters('principalId')]",
    "principalType": "User"
  }
}
```

### Sintaxe Lado a Lado — Listar Role Assignments

**CLI:**
```bash
az role assignment list --resource-group <RG> -o table
```

**PowerShell:**
```powershell
Get-AzRoleAssignment -ResourceGroupName <RG> | Format-Table
```

### Sintaxe Lado a Lado — Remover Role Assignment

**CLI:**
```bash
az role assignment delete --assignee <OBJECT_ID> --role "Reader" --resource-group <RG>
```

**PowerShell:**
```powershell
Remove-AzRoleAssignment -ObjectId <OBJECT_ID> -RoleDefinitionName "Reader" -ResourceGroupName <RG>
```

### Mapeamento de Parametros CLI ↔ PowerShell

> Essa tabela e muito util na prova, pois questoes podem trocar os parametros entre CLI e PowerShell para confundir.

| Funcao       | CLI (`az role assignment`)             | PowerShell (`*-AzRoleAssignment`)                        |
| ------------ | -------------------------------------- | -------------------------------------------------------- |
| Quem recebe  | `--assignee` (aceita Object ID ou UPN) | `-ObjectId` (apenas Object ID)                           |
| Qual role    | `--role` (nome ou ID)                  | `-RoleDefinitionName` (nome) ou `-RoleDefinitionId` (ID) |
| Escopo RG    | `--resource-group`                     | `-ResourceGroupName`                                     |
| Escopo livre | `--scope` (resource ID)                | `-Scope` (resource ID)                                   |
| Criar        | `az role assignment create`            | `New-AzRoleAssignment`                                   |
| Listar       | `az role assignment list`              | `Get-AzRoleAssignment`                                   |
| Remover      | `az role assignment delete`            | `Remove-AzRoleAssignment`                                |

### Quando Usar Cada Metodo — Guia de Decisao

```
Preciso atribuir UMA role rapidamente?
├── Sim → CLI ou PowerShell (depende do seu ambiente)
│         ├── Linux/macOS/Cloud Shell bash → CLI
│         └── Windows/Cloud Shell PS → PowerShell
└── Nao, preciso de automacao/reproducao
    ├── Preciso versionar e rastrear mudancas? → ARM Template (ou Bicep)
    ├── Preciso atribuir em massa via script? → CLI ou PowerShell com loop
    └── Preciso validar visualmente? → Portal
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Qual metodo garante deployment idempotente?"
RESPOSTA: ARM Template. Se o role assignment ja existe, o deploy NAO falha.
          CLI e PowerShell retornam ERRO se o assignment ja existir.

PERGUNTA: "Qual parametro identifica o usuario no ARM Template?"
RESPOSTA: principalId (Object ID do usuario, NAO o UPN/email).

PERGUNTA: "Como atribuir role a um grupo via CLI?"
RESPOSTA: Igual ao usuario: --assignee <GROUP_OBJECT_ID>.
          A mesma sintaxe serve para User, Group e Service Principal.

PERGUNTA: "roleDefinitionId no ARM Template e o nome da role?"
RESPOSTA: NAO. E o resource ID completo:
          /subscriptions/{sub}/providers/Microsoft.Authorization/roleDefinitions/{guid}
          Usar subscriptionResourceId() para montar automaticamente.
```

---

## Questoes de Prova - Permissoes

### Questao P.1
**User1 precisa convidar usuarios externos para o tenant e tambem gerenciar VMs no RG-Prod. Quais roles voce deve atribuir?**

A) Global Administrator
B) Guest Inviter + Virtual Machine Contributor
C) User Administrator + Contributor
D) Guest Inviter no RG-Prod

<details>
<summary>Ver resposta</summary>

**Resposta: B) Guest Inviter + Virtual Machine Contributor**

Sao dois sistemas diferentes: Guest Inviter (Entra ID Role) para convites + VM Contributor (RBAC no RG-Prod) para VMs. Global Admin e muito amplo. User Administrator gerencia usuarios, nao convida externos especificamente. Guest Inviter no RG-Prod nao existe — Entra ID Roles sao no nivel do tenant.

</details>

### Questao P.2
**User2 tem a role Contributor no RG. Ele tenta ler dados de um blob no storage account dentro do RG e recebe erro de permissao. Qual e a causa?**

A) Contributor nao tem acesso ao RG
B) O storage account precisa de SAS token
C) Contributor e uma role de management plane — nao da acesso ao data plane (blobs)
D) O NSG esta bloqueando

<details>
<summary>Ver resposta</summary>

**Resposta: C) Contributor e management plane, nao data plane**

Contributor permite criar/deletar o storage account, mas NAO ler os dados dentro dele. Para acessar blobs, precisa de Storage Blob Data Reader/Contributor (data plane roles). Essa e uma pegadinha classica da prova.

</details>

### Questao P.3
**Voce precisa garantir que User3 possa aplicar tags em todas as VMs da subscription sem poder modificar as VMs. Qual role atribuir e em qual escopo?**

A) Tag Contributor na subscription
B) Contributor na subscription
C) Virtual Machine Contributor na subscription
D) Reader na subscription

<details>
<summary>Ver resposta</summary>

**Resposta: A) Tag Contributor na subscription**

Tag Contributor permite gerenciar tags SEM dar acesso aos recursos. Atribuir na subscription = aplica a todos os RGs/recursos por heranca. Contributor e muito amplo. VM Contributor permite modificar VMs. Reader nao pode modificar nada (incluindo tags).

</details>

### Questao P.4
**User4 tem Storage Blob Data Reader no storage account. Voce precisa restringir o acesso para que ele leia apenas blobs com a tag "project=finance". O que voce deve configurar?**

A) Uma Azure Policy com efeito Deny
B) Uma condicao ABAC na role assignment
C) Um NSG na subnet do storage
D) Uma Stored Access Policy no container

<details>
<summary>Ver resposta</summary>

**Resposta: B) Condicao ABAC na role assignment**

ABAC adiciona condicoes a roles RBAC existentes. A condicao filtra por atributo (tag do blob). Azure Policy governa criacao de recursos, nao acesso a dados. NSG filtra rede, nao dados. Stored Access Policy controla SAS tokens, nao RBAC.

</details>

### Questao P.5
**Qual a diferenca entre atribuir Reader no nivel da Subscription vs no nivel do Resource Group?**

A) Nenhuma diferenca
B) Subscription: ve todos os RGs e recursos. RG: ve apenas aquele RG
C) Reader na subscription permite criar recursos
D) Reader no RG permite deletar o RG

<details>
<summary>Ver resposta</summary>

**Resposta: B) Subscription ve tudo, RG ve apenas aquele RG**

RBAC herda de cima para baixo. Reader na subscription se propaga para todos os RGs e recursos. Reader no RG se limita aquele RG e seus recursos. Reader nunca permite criar ou deletar — e somente leitura em qualquer escopo.

</details>

---

## Secao Extra: Conditional Access — Grant vs Session Control

> Adicionado para reforcar erro recorrente nos simulados.

### Controles de Concessao (Grant Controls)

Decidem **SE** o acesso e concedido. Executados ANTES de entrar.

| Controle                           | O que faz                                          |
| ---------------------------------- | -------------------------------------------------- |
| **Require MFA**                    | Exige autenticacao multifator                      |
| **Require device compliant**       | Exige dispositivo marcado como compliant no Intune |
| **Require Hybrid Azure AD joined** | Exige dispositivo ingressado no AD + Azure AD      |
| **Require approved client app**    | Exige app aprovado (ex: Outlook, Teams)            |
| **Block access**                   | Bloqueia completamente                             |

### Controles de Sessao (Session Controls)

Decidem **COMO** a sessao se comporta DEPOIS de concedida.

| Controle                           | O que faz                                               |
| ---------------------------------- | ------------------------------------------------------- |
| **App enforced restrictions**      | Restricoes do app (ex: bloquear download no SharePoint) |
| **Conditional Access App Control** | Proxy via Defender for Cloud Apps                       |
| **Sign-in frequency**              | Forca re-autenticacao a cada X horas                    |
| **Persistent browser session**     | Controla se o browser lembra a sessao                   |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Configurar politica para exigir MFA"
ERRADO: Session control
CERTO:  GRANT control (Require MFA)

PERGUNTA: "Exigir dispositivo ingressado no dominio"
ERRADO: Session control
CERTO:  GRANT control (Require Hybrid Azure AD joined)

PERGUNTA: "Forcar re-autenticacao a cada 4 horas"
ERRADO: Grant control
CERTO:  SESSION control (Sign-in frequency)

REGRA GERAL:
- "Exigir algo PARA entrar" → Grant control
- "Controlar algo DURANTE a sessao" → Session control
```

---

## Secao Extra: Azure Policy — Escopos Validos

> Adicionado para reforcar erro no simulado 6.

### Onde o Azure Policy pode ser atribuido?

| Escopo             |  Pode?  | Heranca                                    |
| ------------------ | :-----: | ------------------------------------------ |
| Management Group   | **Sim** | Propaga para todas as subscriptions abaixo |
| Subscription       | **Sim** | Propaga para todos os RGs abaixo           |
| Resource Group     | **Sim** | Propaga para todos os recursos abaixo      |
| Recurso individual | **Nao** | —                                          |
| Regiao             | **Nao** | —                                          |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Azure Policy pode ser atribuido a recurso individual?"
RESPOSTA: NAO. Somente MG, Subscription, RG.
          Para filtrar recurso especifico, use CONDICOES na policy rule
          (ex: "if name equals 'vm1'")

PERGUNTA: "Azure Policy no nivel do Management Group"
RESPOSTA: SIM. Propaga para TODAS as subscriptions e RGs abaixo.
          Ideal para governanca corporativa.
```

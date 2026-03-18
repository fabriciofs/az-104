# Lab Extra - Permissionamento: Entra ID Roles, RBAC e ABAC

**Objetivo:** Praticar os 3 sistemas de permissionamento do Azure — atribuir Entra ID Roles (diretorio), Azure RBAC (recursos) e ABAC (condicoes). Inclui cenarios de troubleshoot para identificar qual sistema usar.
**Tempo estimado:** 45min
**Custo:** ~$0.10 (1 Storage Account + 1 VM B1s por ~30min)

> **IMPORTANTE:** Este lab usa usuarios de teste. Se sua subscription for pessoal com um unico usuario, crie pelo menos 1 usuario de teste no Entra ID para praticar.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
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
└────────────────────────────────────────────────────────────────────────┘
```

---

## Parte 1: Setup

### Task 1.1: Criar Resource Group e recursos

```bash
RG="rg-lab-perms"
LOCATION="eastus"
SUFFIX=$RANDOM
ST="stpermstest${SUFFIX}"

# Criar RG com tags
az group create --name $RG --location $LOCATION --tags dept=IT env=lab

# Criar Storage Account
az storage account create \
  --name $ST \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Criar containers
CONN=$(az storage account show-connection-string --name $ST --resource-group $RG --query connectionString -o tsv)
az storage container create --name public-data --connection-string "$CONN"
az storage container create --name finance-data --connection-string "$CONN"

# Upload de blobs de teste com tags (index tags)
echo "dados publicos" > /tmp/public.txt
echo "dados financeiros confidenciais" > /tmp/finance.txt

az storage blob upload --container-name public-data --name info.txt --file /tmp/public.txt --connection-string "$CONN" --tags "dept=IT"
az storage blob upload --container-name finance-data --name report.txt --file /tmp/finance.txt --connection-string "$CONN" --tags "dept=Finance"

# Criar VM simples
az vm create \
  --resource-group $RG \
  --name vm-perms-test \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-address "" \
  --nsg "" \
  --no-wait

echo "Recursos criados: RG=$RG, Storage=$ST"
```

### Task 1.2: Criar usuarios de teste no Entra ID

**Pelo portal:**

1. Portal > **Microsoft Entra ID** > **Users** > **+ New user** > **Create new user**

   | Setting | User 1 | User 2 |
   | --- | --- | --- |
   | Display name | `User Web` | `User DB` |
   | User principal name | `user-web@<seu-tenant>` | `user-db@<seu-tenant>` |
   | Password | Auto-generate | Auto-generate |

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

> **Anote as senhas** — voce vai precisar para testar logins.

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

```bash
USER_WEB_ID=$(az ad user show --id "user-web@${DOMAIN}" --query id -o tsv)

# RBAC: VM Contributor no escopo do RG
az role assignment create \
  --assignee $USER_WEB_ID \
  --role "Virtual Machine Contributor" \
  --resource-group $RG

echo "VM Contributor atribuido ao user-web no $RG"
```

### Task 3.2: Atribuir Reader ao user-db

```bash
USER_DB_ID=$(az ad user show --id "user-db@${DOMAIN}" --query id -o tsv)

# RBAC: Reader no escopo do RG
az role assignment create \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --resource-group $RG

echo "Reader atribuido ao user-db no $RG"
```

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

```bash
# Tag Contributor: pode gerenciar tags SEM acessar recursos
az role assignment create \
  --assignee $USER_WEB_ID \
  --role "Tag Contributor" \
  --resource-group $RG

echo "Tag Contributor atribuido ao user-web"
```

**Testar como user-web:**

1. Navegue para **vm-perms-test** > **Tags**
2. Adicione tag `owner=web-team` > **Save** → **funciona**
3. Isso e a resposta da questao: "Garantir que usuario possa marcar VMs seguindo privilegio minimo" → **Tag Contributor**

> **Dica prova:** Tag Contributor permite gerenciar tags **sem dar acesso** ao recurso em si. E a resposta para "privilegio minimo para tags".

### Task 3.5: Verificar role assignments pelo portal e CLI

```bash
# Listar todas as atribuicoes no RG
az role assignment list \
  --resource-group $RG \
  --query "[].{principal:principalName, role:roleDefinitionName, scope:scope}" \
  -o table
```

**Pelo portal:**

1. **rg-lab-perms** > **Access control (IAM)** > **Role assignments**
2. Observe todos os assignments listados
3. Clique em **Check access** > digite `user-web` > veja as roles atribuidas

### Task 3.6: Entender heranca de escopo

```bash
# Atribuir Reader ao user-db no nivel da SUBSCRIPTION
SUB_ID=$(az account show --query id -o tsv)

az role assignment create \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --scope "/subscriptions/${SUB_ID}"

echo "Reader atribuido ao user-db na subscription inteira"
```

> **Heranca:** Reader na subscription → user-db ve TODOS os RGs e recursos. Reader no RG → ve apenas aquele RG. Permissoes fluem de cima para baixo:
> ```
> Management Group → Subscription → Resource Group → Resource
>        ↓                ↓               ↓              ↓
>     Herda para      Herda para      Herda para     Escopo final
>     todas subs      todos RGs       todos recursos
> ```

```bash
# Remover o Reader da subscription (manter apenas no RG)
az role assignment delete \
  --assignee $USER_DB_ID \
  --role "Reader" \
  --scope "/subscriptions/${SUB_ID}"

echo "Reader removido da subscription"
```

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

   | Setting | Value |
   | --- | --- |
   | Action | Read a blob |
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

```bash
# Ver TODAS as roles do user-web neste RG
az role assignment list \
  --resource-group $RG \
  --assignee $USER_WEB_ID \
  --query "[].{role:roleDefinitionName, scope:scope}" \
  -o table
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

```bash
# Verificar roles do user-db
az role assignment list \
  --resource-group $RG \
  --assignee $USER_DB_ID \
  --query "[].roleDefinitionName" -o tsv
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

```bash
# Remover role assignments
az role assignment delete --assignee $USER_WEB_ID --resource-group $RG
az role assignment delete --assignee $USER_DB_ID --resource-group $RG

# Deletar usuarios de teste
az ad user delete --id "user-web@${DOMAIN}"
az ad user delete --id "user-db@${DOMAIN}"

# Deletar recursos
az group delete --name rg-lab-perms --yes --no-wait

echo "Cleanup completo"
```

---

## Modo Desafio

- [ ] Criar 2 usuarios de teste no Entra ID
- [ ] Atribuir Guest Inviter (Entra ID Role) e testar que NAO da acesso a recursos
- [ ] Atribuir VM Contributor (RBAC) e testar que gerencia VMs mas nao storage
- [ ] Atribuir Tag Contributor e testar que marca recursos sem acessa-los
- [ ] Atribuir Reader e testar que ve tudo mas nao modifica nada
- [ ] Configurar ABAC: Storage Blob Data Reader com condicao de container
- [ ] Testar: acessa public-data mas nao finance-data
- [ ] Verificar effective access via portal e CLI
- [ ] Resolver os 7 cenarios de decisao sem consultar
- [ ] Cleanup

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

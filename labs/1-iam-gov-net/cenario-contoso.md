# Lab Unificado AZ-104 - Semana 1 (v2: Exercicios Interconectados)

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce foi contratado como **Azure Administrator** da Contoso Corp, uma empresa em expansao. Sua missao e configurar o ambiente Azure corporativo **do zero**, onde cada etapa depende da anterior:

1. **Identidade** — criar usuarios e grupos que serao usados em todo o ambiente
2. **Governanca** — aplicar RBAC e policies que restringem o que esses usuarios podem fazer
3. **Automacao (IaC)** — provisionar recursos respeitando as policies, validando que a governanca funciona
4. **Rede** — construir a infraestrutura de rede onde os recursos serao implantados
5. **Conectividade** — implantar VMs nas redes criadas, testar comunicacao e validar tudo de ponta a ponta

Ao final, voce tera **um ambiente corporativo funcional** onde identidade, governanca, IaC, networking e compute estao integrados.

---

## Mapa de Dependencias

```
Bloco 1 (Identity)
  │
  ├─ az104-user1 ──────────────────┐
  ├─ Guest user ───────────────────┤
  ├─ IT Lab Administrators ────────┤
  └─ helpdesk ─────────────────────┤
                                   │
                                   ▼
Bloco 2 (Governance) ──────────────────────────────────────┐
  │                                                        │
  ├─ RBAC: VM Contributor → IT Lab Administrators (MG)     │
  ├─ RBAC: Reader → Guest user (az104-rg3)                 │
  ├─ Policy: Require tag (Deny) → az104-rg2 (testada)      │
  ├─ Policy: Inherit tag (Modify) → az104-rg2 + az104-rg3  │
  ├─ Policy: Allowed Locations (Deny) → az104-rg3          │
  ├─ Lock: Delete → az104-rg2                              │
  └─ Cria az104-rg3 com tag Cost Center = 000              │
                                   │                       │
                                   ▼                       │
Bloco 3 (IaC) ◄──── Valida governanca ─────────────────────┘
  │
  ├─ Disks em az104-rg3 → tags herdadas automaticamente ✓
  ├─ Deploy West US → bloqueado por Allowed Locations ✓
  ├─ Guest user → Reader, nao pode criar recursos ✓
  ├─ Cloud Shell configurado ────────────────────────┐
  └─ Skills ARM/Bicep aprendidas ────────────────────┤
                                                     │
                                                     ▼
Bloco 4 (Networking) ◄──── Reusa Cloud Shell e ARM skills
  │
  ├─ CoreServicesVnet (10.20.0.0/16) ──────────────┐
  ├─ ManufacturingVnet (10.30.0.0/16) via ARM ─────┤
  ├─ NSG + ASG na SharedServicesSubnet             │
  ├─ DNS publico: contoso.com (nslookup via Shell) │
  └─ DNS privado: private.contoso.com ─────────────┤
                                                   │
                                                   ▼
Bloco 5 (Connectivity) ◄──── VMs nas VNets do Bloco 4
  │
  ├─ CoreServicesVM na CoreServicesVnet (10.20.0.0/24)
  ├─ ManufacturingVM na ManufacturingVnet (10.30.0.0/24)
  ├─ Peering entre as VNets do Bloco 4
  ├─ DNS privado resolve nome real da VM ✓
  ├─ az104-user1 gerencia VMs (VM Contributor) ✓
  └─ Route table + NVA + custom route
```

---


## Indice

| Bloco | Descricao | Link |
|-------|-----------|------|
| 1 | Identity | [cenario/bloco1-identity.md](cenario/bloco1-identity.md) |
| 2 | Governance & Compliance | [cenario/bloco2-governance.md](cenario/bloco2-governance.md) |
| 3 | Azure Resources & IaC | [cenario/bloco3-iac.md](cenario/bloco3-iac.md) |
| 4 | Virtual Networking | [cenario/bloco4-networking.md](cenario/bloco4-networking.md) |
| 5 | Intersite Connectivity | [cenario/bloco5-connectivity.md](cenario/bloco5-connectivity.md) |

- [Pausar entre Sessoes](#pausar-entre-sessoes)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

### Pausar (parar cobranca de compute)

```bash
# CLI
az vm deallocate -g az104-rg5 -n CoreServicesVM --no-wait
az vm deallocate -g az104-rg5 -n ManufacturingVM --no-wait
```

```powershell
# PowerShell
Stop-AzVM -ResourceGroupName az104-rg5 -Name CoreServicesVM -Force
Stop-AzVM -ResourceGroupName az104-rg5 -Name ManufacturingVM -Force
```

### Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg5 -n CoreServicesVM --no-wait
az vm start -g az104-rg5 -n ManufacturingVM --no-wait
```

> **Nota:** Desalocar a VM para a cobranca de compute mas discos e IPs publicos continuam gerando cobranca. Para zerar completamente, delete o Resource Group.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente as VMs do Bloco 5.

## Via Azure Portal

1. **Remover Resource Locks primeiro:**
   - `az104-rg2` > **Settings** > **Locks** > Delete `rg-lock`

2. **Deletar Policy Assignments:**
   - Policy > Assignments > delete todas as atribuicoes criadas (tag inherit rg2, tag inherit rg3, allowed locations rg3)

3. **Deletar Custom Role:**
   - Management groups > `az104-mg1` > **Access control (IAM)** > **Roles** > `Custom Support Request` > Delete

4. **Remover subscription do Management Group e deletar MG:**
   - Management groups > `az104-mg1` > selecione a subscription > **Remove**
   - Depois: Management groups > `az104-mg1` > **Delete**

5. **Deletar Resource Groups** (prioridade: VMs primeiro):
   - `az104-rg5` (VMs — PRIORIDADE por custo)
   - `az104-rg4` (VNets, DNS, NSG)
   - `az104-rg3` (Disks, Cloud Shell storage)
   - `az104-rg2` (Storage)

6. **Deletar usuarios e grupos do Entra ID:**
   - Users > delete `az104-user1` e o guest user (por Object ID)
   - Groups > delete `IT Lab Administrators` e `helpdesk`

## Via CLI

> **Nota:** Execute os comandos de policy e lock **antes** de deletar os RGs. Use `az policy assignment list --query "[].{name:name, scope:scope}" -o table` para encontrar os nomes reais das assignments (o portal gera nomes internos que podem diferir do display name).

```bash
# Resolver IDs dinamicamente (evita placeholders)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG2_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/az104-rg2"
RG3_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/az104-rg3"

# 1. Deletar policy assignments ANTES dos RGs
#    Removemos por ID (mais robusto que nome/displayName), filtrando apenas os do lab
for ASSIGN_ID in $(az policy assignment list --scope "$RG2_SCOPE" --query "[?contains(displayName, 'Cost Center')].id" -o tsv); do
  az policy assignment delete --ids "$ASSIGN_ID"
done
for ASSIGN_ID in $(az policy assignment list --scope "$RG3_SCOPE" --query "[?contains(displayName, 'Cost Center') || contains(displayName, 'East US')].id" -o tsv); do
  az policy assignment delete --ids "$ASSIGN_ID"
done

# 2. Remover lock antes de deletar az104-rg2
az lock delete --name rg-lock --resource-group az104-rg2

# 3. Deletar RGs (VMs primeiro por custo)
az group delete --name az104-rg5 --yes --no-wait
az group delete --name az104-rg4 --yes --no-wait
az group delete --name az104-rg3 --yes --no-wait
az group delete --name az104-rg2 --yes --no-wait

# 4. Remover subscription do MG antes de deletar
az account management-group subscription remove --name az104-mg1 --subscription "$SUBSCRIPTION_ID"
az account management-group delete --name az104-mg1

# 5. Deletar custom role
az role definition delete --name "Custom Support Request"

# 6. Deletar usuarios e grupos
USER1_ID=$(az ad user list --filter "startsWith(userPrincipalName, 'az104-user1@')" --query "[0].id" -o tsv)
if [ -n "$USER1_ID" ]; then
  az ad user delete --id "$USER1_ID"
fi
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
az ad user list --filter "userType eq 'Guest'" --query "[].{id:id,mail:mail,displayName:displayName}" -o table
az ad group delete --group "IT Lab Administrators"
az ad group delete --group "helpdesk"
```

## Via PowerShell

> **Nota:** Execute os comandos de policy e lock **antes** de deletar os RGs.

```powershell
# Resolver IDs dinamicamente (evita placeholders)
$subscriptionId = (Get-AzContext).Subscription.Id
$rg2Scope = "/subscriptions/$subscriptionId/resourceGroups/az104-rg2"
$rg3Scope = "/subscriptions/$subscriptionId/resourceGroups/az104-rg3"

# 1. Deletar policy assignments
Get-AzPolicyAssignment -Scope $rg2Scope |
Where-Object {
    $_.DisplayName -match 'Cost Center' -or $_.Properties.DisplayName -match 'Cost Center'
} | ForEach-Object {
    Remove-AzPolicyAssignment -Name $_.Name -Scope $rg2Scope -ErrorAction SilentlyContinue
}
Get-AzPolicyAssignment -Scope $rg3Scope |
Where-Object {
    $_.DisplayName -match 'Cost Center|East US' -or $_.Properties.DisplayName -match 'Cost Center|East US'
} | ForEach-Object {
    Remove-AzPolicyAssignment -Name $_.Name -Scope $rg3Scope -ErrorAction SilentlyContinue
}

# 2. Remover lock e deletar RGs
Remove-AzResourceLock -LockName rg-lock -ResourceGroupName az104-rg2 -Force
Remove-AzResourceGroup -Name az104-rg5 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg4 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg3 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg2 -Force -AsJob

# 3. Remover subscription do MG e deletar
Remove-AzManagementGroupSubscription -GroupName az104-mg1 -SubscriptionId $subscriptionId
Remove-AzManagementGroup -GroupName az104-mg1

# 4. Custom role, usuarios e grupos
Remove-AzRoleDefinition -Name "Custom Support Request" -Force
$user1 = Get-AzADUser -Filter "startsWith(userPrincipalName,'az104-user1@')" | Select-Object -First 1
if ($user1) { Remove-AzADUser -ObjectId $user1.Id }
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
Get-AzADUser -Filter "userType eq 'Guest'" | Select-Object Id, Mail, DisplayName | Format-Table
Remove-AzADGroup -DisplayName "IT Lab Administrators"
Remove-AzADGroup -DisplayName "helpdesk"
```

> **Nota:** Ao deletar az104-rg3, o storage account do Cloud Shell tambem sera removido. Execute todos os comandos CLI/PowerShell **antes** de deletar az104-rg3, ou use o portal para os passos finais.

---

# Key Takeaways Consolidados

## Bloco 1 - Identity
- Um **tenant** representa sua organizacao no Microsoft Entra ID
- Usuarios podem ser **Member** (internos) ou **Guest** (B2B externos)
- **Groups** organizam usuarios: Security e Microsoft 365. Membership: Assigned ou Dynamic (P1/P2)
- **Usage location** e obrigatoria para licencas
- **Identidades sao a base de todo o RBAC** — sem usuarios/grupos, nao ha controle de acesso

## Bloco 2 - Governance & Compliance
- **Management Groups** organizam subscriptions e permitem heranca de RBAC/Policy
- **RBAC e aditivo** — permissoes somam entre roles; NotActions remove do conjunto de Actions
- **Azure Policy:** Deny bloqueia, Audit reporta, Modify altera automaticamente
- **Allowed Locations** restringe onde recursos podem ser criados
- **Resource Locks** sobrescrevem QUALQUER permissao, incluindo Owner
- **Governanca preparada antecipadamente** garante compliance desde o primeiro recurso

## Bloco 3 - Azure Resources & IaC
- **ARM Templates** e **Bicep** permitem deploy declarativo e repetivel
- **Modify policy valida automaticamente** — tags herdadas em cada deploy sem intervencao manual
- **Allowed Locations valida automaticamente** — recursos fora da regiao permitida sao bloqueados
- **Reader role** permite visualizar mas nao criar/modificar — RBAC funciona em conjunto com policies
- Cloud Shell configurado uma vez e **reusado** em blocos posteriores

## Bloco 4 - Virtual Networking
- **VNet** e a representacao da rede na cloud. Evite sobreposicao de ranges IP
- Cada **subnet** perde 5 IPs reservados pelo Azure (251 utilizaveis em /24)
- **NSG** se aplica por **subnet** ou NIC, nao por VNet inteira
- **ASG** agrupa VMs logicamente para regras NSG simplificadas
- **DNS publico** resolve na internet; **DNS privado** apenas em VNets linkadas
- **VNets sao estruturas evolutivas** — subnets podem ser adicionadas conforme necessidade

## Bloco 5 - Intersite Connectivity
- VMs podem usar VNets de **outros Resource Groups** (cross-RG)
- VNets diferentes **NAO se comunicam** por padrao — peering habilita conectividade
- Peering **NAO e transitivo** (A↔B + B↔C ≠ A↔C)
- **UDRs** sobrescrevem rotas do sistema; trafego sem next hop alcancavel e descartado
- **DNS privado + VNet links** permitem resolucao de nomes entre VNets
- **RBAC + Locks** funcionam de ponta a ponta: VM Contributor gerencia VMs, Lock protege RGs

## Integracao Geral
- **Identidade (Bloco 1)** e a base de toda governanca e acesso
- **Policies (Bloco 2)** sao validadas automaticamente em cada deploy (Blocos 3-4)
- **IaC (Bloco 3)** e uma skill reutilizavel em todo o ambiente
- **Networking (Bloco 4)** e a infraestrutura onde compute (Bloco 5) vive
- **Tudo se conecta:** um usuario criado no Bloco 1 pode gerenciar VMs no Bloco 5 por causa do RBAC do Bloco 2, em VNets do Bloco 4, com DNS resolvendo nomes reais

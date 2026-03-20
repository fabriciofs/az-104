# Identidade e Governanca

## Usuarios e Grupos (Entra ID)

- **Usage location** e obrigatoria para atribuir licencas ao usuario
- Grupos dinamicos requerem **Entra ID P1/P2**
- Grupos dinamicos: nao permitem adicionar membros manualmente, avaliacao pode levar minutos
- Grupos dinamicos podem ser baseados em **users OU devices** (nao ambos no mesmo grupo)

## SSPR (Self-Service Password Reset)

- SSPR com 2 metodos requeridos e mais seguro
- Security Questions **NAO** podem ser o unico metodo
- SSPR requer Azure AD Free (cloud users) ou P1/P2 (writeback on-premises)
- **Quem pode usar SSPR:** membros (cloud + sync com writeback) = **sim**; convidados (guests) = **nao**
- Com password writeback, usuarios **sincronizados** do AD local tambem podem usar SSPR

## Acesso Condicional (Conditional Access)

**Grant Control vs Session Control — NAO confundir!**

| Controle | O que configura | Exemplos |
| --- | --- | --- |
| **Grant control** | Requisitos para **conceder** acesso | MFA, dispositivo ingressado no Azure AD, app aprovado |
| **Session control** | Restricoes **durante** a sessao | Duracao da sessao, persistencia de browser, app enforced restrictions |

- "Exigir MFA" → **Grant control**
- "Exigir dispositivo Azure AD-joined" → **Grant control**
- "Limitar duracao de sessao" → **Session control**
- Alterar **apenas** Grant control ou **apenas** Session control **NAO** e suficiente para uma politica completa — tambem e necessario configurar Assignments (usuarios/grupos) e Conditions (locais)
- "Alterar session control atende ao objetivo de exigir MFA?" → **NAO**

## Roles Administrativas (privilegio minimo)

| Necessidade                                                   | Role correta                    | NAO usar                     |
| ------------------------------------------------------------- | ------------------------------- | ---------------------------- |
| Convidar usuarios externos                                    | **Guest Inviter**               | Global Admin, Security Admin |
| Exibir recursos (somente leitura)                             | **Reader**                      | Contributor                  |
| Gerenciar tags sem acesso a recursos                          | **Tag Contributor**             | Contributor                  |
| Gerenciar grupos                                              | **Groups Administrator**        | Global Admin                 |
| Gerenciar VMs                                                 | **Virtual Machine Contributor** | Contributor                  |
| Exibir custos + gerenciar orcamentos (sem modificar recursos) | **Cost Management Contributor** | Reader, Colaborador          |

- **Guest Inviter** = role especifica para convidar externos (B2B), privilegio minimo
- **Cost Management Contributor** = ve custos + gerencia budgets, SEM poder modificar recursos
- **Reader** NAO gerencia orcamentos, apenas visualiza. NAO confundir com Cost Mgmt Contributor
- **Tag Contributor** = pode gerenciar tags sem acesso aos recursos em si
- Usuarios convidados: UPN tem formato `user_dominio.com#EXT#@tenant.onmicrosoft.com`

## Licenciamento baseado em grupo

- Licencas sao consumidas por **membros** do grupo, NAO por proprietarios
- Convidados (guest) tambem consomem licenca se forem membros
- Proprietario que nao e membro **NAO** consome licenca

## RBAC - Custom Roles e PowerShell

- Custom Role JSON: **Actions** = permitido, **NotActions** = excluido, **AssignableScopes** = onde pode ser atribuida
- `Microsoft.Compute/*/read` = le TODOS os recursos de compute (VMs, disks, snapshots, etc.)
- `Get-AzRoleDefinition -Name` busca por **nome**; para buscar por ID use `-Id`
- **$RoleName deve conter o NOME** (ex: "CustomRole1"), nao o ID GUID
- `New-AzRoleAssignment` atribui role a um usuario

## RBAC vs Entra ID Roles vs ABAC

| Sistema | Controla | Escopo | Exemplo |
| --- | --- | --- | --- |
| **Entra ID Roles** | Diretorio (usuarios, grupos, apps) | Tenant | Guest Inviter, User Admin |
| **Azure RBAC** | Recursos Azure (VMs, storage, VNets) | MG → Sub → RG → Resource | Owner, Contributor, Reader |
| **Azure ABAC** | RBAC + condicoes por atributos | Mesmo do RBAC | "Ler blobs com tag dept=HR" |

- "Convidar usuarios, gerenciar grupos, licencas" → **Entra ID Role**
- "Gerenciar VMs, storage, VNets" → **Azure RBAC**
- "Acesso condicional por tag/atributo" → **ABAC** (raramente cai no AZ-104)

## Azure Policy

- Informacoes de remediacao ficam na secao **metadata** (campo `RemediationDescription`)
- **mode** define quais recursos sao avaliados (ex: All, Indexed)
- **parameters** sao valores configuraveis na atribuicao
- **policyRule** contem a logica (if/then)

## Bloqueios (Locks)

- **Delete lock** impede exclusao acidental de recursos
- Pode aplicar em: **Subscriptions**, **Resource Groups**, **Recursos individuais** (VMs, etc.)
- **NAO pode** aplicar em: **Management Groups**, dados de storage account
- Bloqueio no RG protege os recursos dentro, mas permite excluir o RG se estiver vazio

## Gestao de Custos

### Budgets vs Policy vs Automation

| Mecanismo          | Funcao                               | Bloqueia recursos?        |
| ------------------ | ------------------------------------ | ------------------------- |
| Budget             | Alerta quando gasto atinge threshold | **Nao** (apenas notifica) |
| Azure Policy       | Restringe criacao (ex: limitar SKUs) | **Sim** (previne)         |
| Automation Runbook | Executa acao (ex: desligar VMs)      | **Sim** (reage)           |
| Spending Limit     | Limita gasto total                   | **Sim** (apenas dev/test) |

- Budgets **alertam** mas **NAO param** recursos automaticamente
- Para controle completo: Policy (prevenir) + Budget (monitorar) + Runbook (reagir)
- Advisor **recomenda**; Budgets **alertam**; Policies **restringem**
- "Forecasted" alerta baseado na tendencia, prevenindo surpresas no fim do mes

## Pegadinhas

- "Membros adicionados automaticamente por departamento" -> **Dynamic user group**
- "Usuario nao consegue resetar senha via SSPR" -> verificar se **registrou os metodos de autenticacao**
- "Convidar externos com privilegio minimo" -> **Guest Inviter** (NAO Security Admin, NAO Global Admin)
- "Marcar VMs por departamento" -> **Tags** (etiquetas)
- "Criar custom role para permissao de marcacao via portal" -> precisa de role com `Microsoft.Compute/virtualMachines/write`
- "Equipe financeira ver custos e gerenciar orcamentos" -> **Cost Management Contributor** (NAO Reader)

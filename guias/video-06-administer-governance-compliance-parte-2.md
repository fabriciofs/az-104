# Video 6: Administer Governance and Compliance (Parte 2) AZ-104

## Informacoes Gerais

| Propriedade | Valor |
|-------------|-------|
| **Titulo** | Administer Governance and Compliance (Part 2) AZ-104 |
| **Canal** | Microsoft Learn |
| **Inscritos no Canal** | 88,7 mil |
| **Visualizacoes** | 7.300+ |
| **Data de Publicacao** | 4 de junho de 2025 |
| **Posicao na Playlist** | Episodio 6 de 22 |
| **Idioma** | Ingles |

---

## Links Importantes

| Recurso | URL |
|---------|-----|
| **Video no YouTube** | https://www.youtube.com/watch?v=6xIBgC-ALCc |
| **Playlist Completa** | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn |

---

## Descricao do Conteudo

Esta e a segunda parte do modulo de Governanca e Conformidade. O video aborda em profundidade o Role-Based Access Control (RBAC), resource locks e Azure Blueprints para garantir governanca adequada dos recursos Azure.

### O que voce aprendera

- Role-Based Access Control (RBAC) em detalhes
- Custom Roles
- Resource Locks
- Azure Blueprints
- Tags e organizacao de recursos

---

## Topicos Abordados

### 1. Role-Based Access Control (RBAC)

| Componente | Descricao |
|------------|-----------|
| **Security Principal** | Quem (user, group, service principal, managed identity) |
| **Role Definition** | O que pode fazer (permissions) |
| **Scope** | Onde pode fazer (MG, Sub, RG, Resource) |
| **Role Assignment** | Combinacao dos tres acima |

#### Built-in Roles Mais Importantes

| Role | Permissoes |
|------|------------|
| **Owner** | Full access + delegate access |
| **Contributor** | Full access, sem delegate |
| **Reader** | Somente leitura |
| **User Access Administrator** | Gerenciar acesso de usuarios |

#### Roles Especificos por Servico

| Role | Uso |
|------|-----|
| **Virtual Machine Contributor** | Gerenciar VMs |
| **Storage Blob Data Contributor** | Acesso a dados de blob |
| **Network Contributor** | Gerenciar recursos de rede |
| **Key Vault Administrator** | Gerenciar Key Vaults |

### 2. Custom Roles

```json
{
  "Name": "Custom Role Name",
  "Description": "Description",
  "Actions": ["Microsoft.Compute/virtualMachines/*"],
  "NotActions": ["Microsoft.Compute/virtualMachines/delete"],
  "AssignableScopes": ["/subscriptions/{sub-id}"]
}
```

| Propriedade | Descricao |
|-------------|-----------|
| **Actions** | Acoes permitidas |
| **NotActions** | Excecoes das acoes |
| **DataActions** | Acoes em dados |
| **NotDataActions** | Excecoes de acoes em dados |
| **AssignableScopes** | Onde a role pode ser atribuida |

### 3. Resource Locks

| Tipo de Lock | Efeito |
|--------------|--------|
| **CanNotDelete** | Permite modificar, bloqueia delete |
| **ReadOnly** | Bloqueia modificacoes e delete |

| Caracteristica | Detalhe |
|----------------|---------|
| **Heranca** | Locks sao herdados por child resources |
| **Override** | Owners podem remover locks |
| **Scope** | Subscription, RG ou Resource |

### 4. Azure Blueprints

| Componente | Funcao |
|------------|--------|
| **Artifacts** | ARM templates, policies, RBAC, RGs |
| **Blueprint Definition** | Conjunto de artifacts |
| **Blueprint Assignment** | Aplicacao a uma subscription |
| **Versioning** | Controle de versao de blueprints |

---

## Conceitos-Chave para o Exame

### 1. RBAC vs Azure Policy

| Aspecto | RBAC | Azure Policy |
|---------|------|--------------|
| **Foco** | Quem pode fazer o que | O que pode ser feito |
| **Escopo** | Usuarios e groups | Recursos |
| **Efeito** | Allow/Deny acoes | Enforce configuracoes |

### 2. Deny Assignments

- Bloqueia acoes especificas
- Mais forte que role assignments
- Usado por Blueprints e Managed Apps

### 3. Heranca de RBAC

```
Subscription (Reader para UserA)
    |
    +-- Resource Group (Contributor para UserA)
            |
            +-- Resource (UserA tem ambos: Reader + Contributor)
```

### 4. Effective Permissions

- RBAC e aditivo (uniao de permissoes)
- Exceto Deny assignments (subtrativo)
- Verificar com "Check Access"

---

## Peso no Exame AZ-104

| Dominio | Peso |
|---------|------|
| Gerenciar identidades e governanca do Azure | 20-25% |

### Questoes Frequentes

1. Diferenca entre Owner, Contributor e Reader
2. Custom roles e AssignableScopes
3. Resource locks e heranca
4. RBAC scope hierarchy
5. Quando usar RBAC vs Azure Policy

---

## Comandos Azure CLI Relevantes

```bash
# Listar role assignments
az role assignment list --scope /subscriptions/{sub-id}

# Criar role assignment
az role assignment create --assignee {user} --role "Contributor" --scope {scope}

# Criar custom role
az role definition create --role-definition role.json

# Listar locks
az lock list --resource-group {rg-name}

# Criar lock
az lock create --name {lock-name} --lock-type CanNotDelete --resource-group {rg}
```

---

## Recursos Complementares

| Recurso | Link |
|---------|------|
| **Azure RBAC** | https://learn.microsoft.com/en-us/azure/role-based-access-control/overview |
| **Custom Roles** | https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles |
| **Resource Locks** | https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources |
| **Azure Blueprints** | https://learn.microsoft.com/en-us/azure/governance/blueprints/overview |

---

## Proximo Video

**Video 7:** Administer Azure Resources
- Azure Resource Manager (ARM)
- ARM Templates
- Bicep
- Azure Portal, CLI, PowerShell
- Resource Groups best practices

---

*Fonte: Microsoft Learn - Canal oficial no YouTube*

# Video 7: Administer Azure Resources AZ-104

## Informacoes Gerais

| Propriedade             | Valor                             |
| ----------------------- | --------------------------------- |
| **Titulo**              | Administer Azure Resources AZ-104 |
| **Canal**               | Microsoft Learn                   |
| **Inscritos no Canal**  | 88,7 mil                          |
| **Visualizacoes**       | 5.900+                            |
| **Data de Publicacao**  | 4 de junho de 2025                |
| **Posicao na Playlist** | Episodio 7 de 22                  |
| **Idioma**              | Ingles                            |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=Ex7EF1chJiA                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Este video aborda a administracao de recursos Azure usando diferentes ferramentas e metodos. Voce aprendera sobre Azure Resource Manager, ARM Templates, Bicep e as melhores praticas para gerenciar recursos.

### O que voce aprendera

- Azure Resource Manager (ARM)
- Ferramentas de gerenciamento (Portal, CLI, PowerShell, Cloud Shell)
- ARM Templates e Bicep
- Resource Groups best practices
- Move resources entre subscriptions

---

## Topicos Abordados

### 1. Azure Resource Manager (ARM)

| Caracteristica | Descricao                                        |
| -------------- | ------------------------------------------------ |
| **Definicao**  | Camada de gerenciamento do Azure                 |
| **Funcao**     | Processa todas as requisicoes (Portal, CLI, API) |
| **Beneficios** | Consistencia, dependencias, tags, RBAC, locks    |

### 2. Ferramentas de Gerenciamento

| Ferramenta           | Uso                                      |
| -------------------- | ---------------------------------------- |
| **Azure Portal**     | Interface grafica, explorar e configurar |
| **Azure CLI**        | Linha de comando, scripts bash           |
| **Azure PowerShell** | Cmdlets, automacao Windows               |
| **Cloud Shell**      | CLI/PowerShell no browser                |
| **Azure Mobile App** | Gerenciamento mobile                     |
| **REST API**         | Integracao programatica                  |

### 3. Resource Groups

| Caracteristica       | Detalhe                                               |
| -------------------- | ----------------------------------------------------- |
| **Container logico** | Agrupa recursos relacionados                          |
| **Lifecycle**        | Deletar RG deleta todos os recursos                   |
| **Escopo RBAC**      | Permissoes aplicadas ao RG                            |
| **Regiao**           | Metadados do RG, recursos podem ser em outras regioes |

#### Best Practices para Resource Groups

1. **Agrupar por lifecycle** - Recursos criados/deletados juntos
2. **Ambiente** - Dev, Test, Prod separados
3. **Aplicacao** - Um RG por aplicacao
4. **Billing** - Facilitar alocacao de custos
5. **Naming convention** - Padronizacao de nomes

### 4. ARM Templates

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [],
  "outputs": {}
}
```

| Secao          | Proposito                   |
| -------------- | --------------------------- |
| **parameters** | Valores de entrada          |
| **variables**  | Valores calculados          |
| **resources**  | Recursos a serem deployados |
| **outputs**    | Valores de retorno          |
| **functions**  | Funcoes customizadas        |

### 5. Bicep

| Caracteristica      | Vantagem                   |
| ------------------- | -------------------------- |
| **Sintaxe simples** | Menos verbose que JSON     |
| **Modulos**         | Reutilizacao de codigo     |
| **Transpilacao**    | Converte para ARM template |
| **Intellisense**    | Suporte em VS Code         |

```bicep
param location string = resourceGroup().location
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
```

---

## Conceitos-Chave para o Exame

### 1. Mover Recursos

| Move Type                 | Suporte                             |
| ------------------------- | ----------------------------------- |
| **Entre Resource Groups** | Maioria dos recursos                |
| **Entre Subscriptions**   | Alguns recursos                     |
| **Entre Regions**         | Limitado, usar Azure Resource Mover |

#### Validacao de Move

```bash
az resource invoke-action \
  --action validateMoveResources \
  --ids {resource-ids} \
  --request-body '{"targetResourceGroup": "/subscriptions/{sub}/resourceGroups/{rg}"}'
```

### 2. Tags

| Uso                 | Exemplo         |
| ------------------- | --------------- |
| **Cost allocation** | CostCenter: IT  |
| **Environment**     | Env: Production |
| **Owner**           | Owner: TeamA    |
| **Application**     | App: WebApp     |

| Limite               | Valor          |
| -------------------- | -------------- |
| **Tags por recurso** | 50             |
| **Nome da tag**      | 512 caracteres |
| **Valor da tag**     | 256 caracteres |

### 3. Deployment Modes

| Modo            | Comportamento                                  |
| --------------- | ---------------------------------------------- |
| **Incremental** | Adiciona/atualiza, mantem existentes (default) |
| **Complete**    | Deleta recursos nao no template                |

### 4. What-if e Validation

```bash
# Validar template
az deployment group validate --resource-group {rg} --template-file template.json

# What-if analysis
az deployment group what-if --resource-group {rg} --template-file template.json
```

---

## Peso no Exame AZ-104

| Dominio                                      | Peso   |
| -------------------------------------------- | ------ |
| Gerenciar identidades e governanca do Azure  | 20-25% |
| Implantar e gerenciar recursos de computacao | 20-25% |

### Questoes Frequentes

1. Estrutura de ARM templates
2. Mover recursos entre RGs/subscriptions
3. Deployment modes (incremental vs complete)
4. Tags e limites
5. Resource Groups best practices

---

## Comandos Essenciais

### Azure CLI

```bash
# Listar resource groups
az group list --output table

# Criar resource group
az group create --name {name} --location {region}

# Deploy ARM template
az deployment group create \
  --resource-group {rg} \
  --template-file template.json \
  --parameters @parameters.json

# Exportar template
az group export --name {rg} > template.json

# Aplicar tags
az resource tag --tags "Env=Prod" "CostCenter=IT" --ids {resource-id}
```

### PowerShell

```powershell
# Listar resource groups
Get-AzResourceGroup

# Criar resource group
New-AzResourceGroup -Name {name} -Location {region}

# Deploy ARM template
New-AzResourceGroupDeployment `
  -ResourceGroupName {rg} `
  -TemplateFile template.json

# Mover recursos
Move-AzResource -DestinationResourceGroupName {dest-rg} -ResourceId {id}
```

---

## Recursos Complementares

| Recurso             | Link                                                                                                           |
| ------------------- | -------------------------------------------------------------------------------------------------------------- |
| **ARM Templates**   | https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview                              |
| **Bicep**           | https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview                                  |
| **Move Resources**  | https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-resource-group-and-subscription |
| **Resource Naming** | https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging |

---

## Proximo Video

**Video 8:** Administer Virtual Networking (Parte 1)

- Virtual Networks (VNets)
- Subnets
- IP addressing
- Network Security Groups (NSGs)

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

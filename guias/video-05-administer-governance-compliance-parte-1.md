# Video 5: Administer Governance and Compliance (Parte 1) AZ-104

## Informacoes Gerais

| Propriedade             | Valor                                                |
| ----------------------- | ---------------------------------------------------- |
| **Titulo**              | Administer Governance and Compliance (Part 1) AZ-104 |
| **Canal**               | Microsoft Learn                                      |
| **Inscritos no Canal**  | 88,7 mil                                             |
| **Visualizacoes**       | 10.000+                                              |
| **Data de Publicacao**  | 4 de junho de 2025                                   |
| **Posicao na Playlist** | Episodio 5 de 22                                     |
| **Idioma**              | Ingles                                               |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=jsI0lkUcq2U                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Este video aborda a administracao de governanca e conformidade no Azure. Voce aprendera sobre a hierarquia de recursos, Azure Policy, RBAC e como manter a conformidade organizacional.

### O que voce aprendera

- Hierarquia de gerenciamento do Azure
- Management Groups
- Azure Subscriptions
- Azure Policy
- Introducao ao RBAC

---

## Topicos Abordados

### 1. Hierarquia de Recursos do Azure

```
Management Groups
    |
    +-- Subscriptions
            |
            +-- Resource Groups
                    |
                    +-- Resources
```

| Nivel                 | Descricao                    | Limite                     |
| --------------------- | ---------------------------- | -------------------------- |
| **Management Groups** | Agrupa subscriptions         | 6 niveis de profundidade   |
| **Subscriptions**     | Container de billing         | 10.000 por tenant          |
| **Resource Groups**   | Container logico de recursos | Ilimitado por subscription |
| **Resources**         | Servicos individuais         | Varia por tipo             |

### 2. Management Groups

| Caracteristica              | Detalhe                       |
| --------------------------- | ----------------------------- |
| **Root Management Group**   | Criado automaticamente        |
| **Heranca**                 | Policies e RBAC sao herdados  |
| **Profundidade**            | Ate 6 niveis (excluindo root) |
| **Subscriptions por grupo** | Ilimitado                     |

### 3. Azure Subscriptions

| Tipo                     | Uso                        |
| ------------------------ | -------------------------- |
| **Free**                 | Avaliacao, credito inicial |
| **Pay-As-You-Go**        | Pagamento por uso          |
| **Enterprise Agreement** | Grandes organizacoes       |
| **CSP**                  | Parceiros Microsoft        |

### 4. Azure Policy

| Componente            | Funcao                 |
| --------------------- | ---------------------- |
| **Policy Definition** | Regra individual       |
| **Policy Initiative** | Conjunto de policies   |
| **Policy Assignment** | Aplicacao a um escopo  |
| **Compliance**        | Status de conformidade |

#### Efeitos de Policy

| Efeito                | Acao                            |
| --------------------- | ------------------------------- |
| **Deny**              | Bloqueia a criacao/modificacao  |
| **Audit**             | Registra mas permite            |
| **Append**            | Adiciona campos                 |
| **Modify**            | Modifica recursos existentes    |
| **DeployIfNotExists** | Deploya recursos complementares |
| **AuditIfNotExists**  | Audita ausencia de recursos     |
| **Disabled**          | Policy desabilitada             |

---

## Conceitos-Chave para o Exame

### 1. Heranca de Policies

```
Management Group (Policy A)
    |
    +-- Subscription (Herda Policy A + Policy B)
            |
            +-- Resource Group (Herda A + B + Policy C)
```

### 2. Built-in Policies Importantes

| Policy                  | Descricao                   |
| ----------------------- | --------------------------- |
| **Allowed locations**   | Restringe regioes           |
| **Allowed VM SKUs**     | Limita tamanhos de VM       |
| **Require tag**         | Exige tags em recursos      |
| **Inherit tag from RG** | Herda tag do Resource Group |

### 3. Compliance e Remediation

| Conceito             | Descricao                        |
| -------------------- | -------------------------------- |
| **Compliance State** | Compliant, Non-compliant, Exempt |
| **Remediation Task** | Corrige recursos existentes      |
| **Exemption**        | Excecao temporaria ou permanente |

### 4. Cost Management

- Tags para alocacao de custos
- Budgets e alertas
- Cost analysis por resource group

---

## Peso no Exame AZ-104

| Dominio                                     | Peso   |
| ------------------------------------------- | ------ |
| Gerenciar identidades e governanca do Azure | 20-25% |

### Questoes Frequentes

1. Hierarquia de management groups
2. Efeitos de Azure Policy
3. Heranca de policies entre escopos
4. Remediation de recursos non-compliant
5. Subscription limits e quotas

---

## Recursos Complementares

| Recurso                   | Link                                                                                                        |
| ------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Azure Policy Overview** | https://learn.microsoft.com/en-us/azure/governance/policy/overview                                          |
| **Management Groups**     | https://learn.microsoft.com/en-us/azure/governance/management-groups/overview                               |
| **Subscription Limits**   | https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits |

---

## Proximo Video

**Video 6:** Administer Governance and Compliance (Parte 2)

- Role-Based Access Control (RBAC) em detalhes
- Custom roles
- Resource locks
- Azure Blueprints

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

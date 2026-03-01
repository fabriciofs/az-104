# Exercicio Pratico 2 — Governanca Corporativa

**Tipo:** Hands-on (executar no portal) | **Duracao:** ~3 horas | **Dominios:** D1 Identity & Governance

> **Diferenca dos estudos de caso:**
> Este exercicio e **pratico** — voce vai desenhar, planejar e documentar uma estrutura de governanca completa.
> Os estudos de caso (caso1 a caso5) testam **raciocinio** com questoes estilo exame.
> Faca este exercicio **apos** completar os labs e simulados do bloco 1.

---

## Cenario

A **TechNova Solutions** e uma empresa de tecnologia com 100 funcionarios distribuidos em 5 departamentos. A empresa esta adotando o Azure e precisa de uma estrutura de governanca robusta desde o inicio.

### Departamentos

| Departamento | Pessoas | Funcao                      | Necessidade Azure                                |
| ------------ | ------- | --------------------------- | ------------------------------------------------ |
| **Dev**      | 30      | Desenvolvimento de software | Criar/gerenciar recursos em ambiente de dev      |
| **QA**       | 15      | Testes e qualidade          | Criar/gerenciar recursos em ambiente de QA       |
| **Prod**     | 20      | Operacoes de producao       | Gerenciar recursos de producao (sem criar novos) |
| **Finance**  | 20      | Financeiro e contabilidade  | Somente leitura em custos e billing              |
| **HR**       | 15      | Recursos humanos            | Sem acesso ao Azure (apenas Office 365)          |

### Requisitos de Compliance

- Todos os recursos devem ter tags: `Department`, `Environment`, `CostCenter`
- Recursos so podem ser criados em **Brazil South** e **East US**
- VMs nao podem usar tamanhos da serie **M** ou **L** (custo alto)
- Recursos de producao devem ter **Delete Lock**
- Auditores externos precisam de acesso somente leitura a **tudo**
- Cada departamento so deve ver e gerenciar **seus proprios** recursos

---

## Tarefa 1 — Estrutura de Identidade (45 min)

Configure a estrutura de usuarios e grupos no Microsoft Entra ID.

### Entregaveis

1. **Grupos** — Liste todos os grupos que voce criaria:

   | Nome do Grupo | Tipo          | Membership       | Membros | Finalidade |
   | ------------- | ------------- | ---------------- | ------- | ---------- |
   | ?             | Security/M365 | Assigned/Dynamic | ?       | ?          |

   Considere:
   - Grupos para RBAC (acesso Azure)
   - Grupos para licenciamento (Office 365)
   - Algum grupo com dynamic membership? Qual regra?

2. **Hierarquia de Management Groups**
   - Desenhe a hierarquia que separe producao de nao-producao
   - Onde ficariam as subscriptions?
   - Se a empresa crescer e adquirir outra empresa, como a hierarquia acomoda?

3. **Conditional Access** (se tiver licenca P1/P2)
   - Defina pelo menos 2 politicas de Conditional Access:
     - Ex: MFA obrigatorio para acesso ao portal Azure
     - Ex: Bloquear acesso de fora do Brasil

### Criterios de avaliacao

- [ ] Grupos criados para cada departamento
- [ ] Pelo menos 1 grupo com dynamic membership (requer P1)
- [ ] Hierarquia de MG separa prod de non-prod
- [ ] Conditional Access policies definidas (mesmo que conceituais)

---

## Tarefa 2 — RBAC (45 min)

Configure permissoes seguindo o principio de least privilege.

### Entregaveis

1. **Mapeamento de roles** — Para cada departamento/grupo:

   | Grupo     | Role | Escopo | Justificativa |
   | --------- | ---- | ------ | ------------- |
   | Dev       | ?    | ?      | ?             |
   | QA        | ?    | ?      | ?             |
   | Prod      | ?    | ?      | ?             |
   | Finance   | ?    | ?      | ?             |
   | HR        | ?    | ?      | ?             |
   | Auditores | ?    | ?      | ?             |

2. **Custom Role** — Crie a definicao JSON de um custom role para o departamento **Prod** que permita:
   - Gerenciar VMs (start, stop, restart, resize)
   - Gerenciar discos
   - **NAO** permite criar novas VMs
   - **NAO** permite deletar VMs

   ```json
   {
     "Name": "?",
     "Description": "?",
     "Actions": [ "?" ],
     "NotActions": [ "?" ],
     "AssignableScopes": [ "?" ]
   }
   ```

3. **Cenarios de teste** — Para cada cenario, diga se a operacao sera permitida ou negada:

   | Cenario                                 | Permitido? | Por que? |
   | --------------------------------------- | ---------- | -------- |
   | Dev cria VM em subscription de Dev      | ?          | ?        |
   | Dev cria VM em subscription de Prod     | ?          | ?        |
   | Prod deleta VM em producao              | ?          | ?        |
   | Finance ve custo da subscription de Dev | ?          | ?        |
   | Auditor le configuracao de NSG em Prod  | ?          | ?        |
   | HR acessa o portal Azure                | ?          | ?        |

### Criterios de avaliacao

- [ ] Nenhum departamento tem mais permissao do que precisa
- [ ] Custom role definido corretamente em JSON
- [ ] Cenarios de teste respondidos corretamente
- [ ] Finance tem role de billing, nao Contributor

---

## Tarefa 3 — Azure Policy (45 min)

Implemente as regras de compliance via Azure Policy.

### Entregaveis

1. **Inventario de policies** — Liste todas as policies necessarias:

   | #   | Policy                   | Efeito | Escopo | Built-in ou Custom? |
   | --- | ------------------------ | ------ | ------ | ------------------- |
   | 1   | Exigir tag `Department`  | Deny   | ?      | Built-in            |
   | 2   | Exigir tag `Environment` | Deny   | ?      | Built-in            |
   | 3   | Exigir tag `CostCenter`  | Deny   | ?      | Built-in            |
   | 4   | Allowed Locations        | Deny   | ?      | Built-in            |
   | 5   | Allowed VM SKUs          | Deny   | ?      | Built-in            |
   | 6   | ?                        | ?      | ?      | ?                   |

2. **Policy Initiative** — Agrupe as policies relacionadas:
   - Qual nome voce daria a initiative?
   - Quais policies fariam parte?
   - Em qual escopo voce atribuiria?

3. **Remediation** — Para cada cenario:

   | Cenario                                    | O que acontece? | Como remediar? |
   | ------------------------------------------ | --------------- | -------------- |
   | Dev cria VM sem tag `Department`           | ?               | ?              |
   | Dev cria VM em West Europe                 | ?               | ?              |
   | Dev cria VM Standard_M128s                 | ?               | ?              |
   | Recurso existente nao tem tag `CostCenter` | ?               | ?              |

4. **Tag inheritance** — Configure heranca automatica de tags:
   - Qual efeito de policy voce usaria? (Modify, Append, Deny)
   - O que e necessario na policy assignment para que o efeito Modify funcione?
   - Como aplicar retroativamente em recursos que ja existem?

### Criterios de avaliacao

- [ ] Todas as regras de compliance cobertas por policies
- [ ] Initiative criada agrupando policies de tags
- [ ] Efeitos corretos para cada cenario (Deny vs Audit vs Modify)
- [ ] Remediation task mencionada para recursos existentes

---

## Tarefa 4 — Revisao e Documentacao (45 min)

### Entregaveis

1. **Diagrama de governanca** — Consolide tudo em um diagrama:

   ```
   Root MG
   └── TechNova-MG (policies: ?, roles: ?)
       ├── ? (policies: ?, roles: ?)
       │   └── ?-Sub
       └── ? (policies: ?, roles: ?)
           └── ?-Sub
   ```

2. **Matriz de acesso completa:**

   |           | Portal Azure | Criar recursos | Gerenciar VMs | Ver custos | Ver configs | Deletar |
   | --------- | ------------ | -------------- | ------------- | ---------- | ----------- | ------- |
   | Dev       | ?            | ?              | ?             | ?          | ?           | ?       |
   | QA        | ?            | ?              | ?             | ?          | ?           | ?       |
   | Prod      | ?            | ?              | ?             | ?          | ?           | ?       |
   | Finance   | ?            | ?              | ?             | ?          | ?           | ?       |
   | HR        | ?            | ?              | ?             | ?          | ?           | ?       |
   | Auditores | ?            | ?              | ?             | ?          | ?           | ?       |

3. **Checklist de compliance:**

   | Requisito           | Implementado via    | Verificacao                                |
   | ------------------- | ------------------- | ------------------------------------------ |
   | Tags obrigatorias   | Azure Policy (Deny) | Criar recurso sem tag → deve falhar        |
   | Regioes permitidas  | Azure Policy (Deny) | Criar recurso em West Europe → deve falhar |
   | VM SKUs restritos   | Azure Policy (Deny) | Criar VM M-series → deve falhar            |
   | Delete Lock em prod | Resource Lock       | Tentar deletar recurso prod → deve falhar  |
   | Segregacao por dept | RBAC por RG/Sub     | Dev nao ve recursos de Prod                |
   | Auditoria externa   | RBAC Reader         | Auditor ve tudo, nao modifica nada         |

4. **Riscos e gaps** — Liste pelo menos 3 riscos ou gaps na sua implementacao:
   - Ex: "Se um dev for promovido para Prod, os grupos dinamicos nao atualizam automaticamente"
   - Ex: "Conditional Access requer licenca P1 que pode nao estar no orcamento"

### Criterios de avaliacao

- [ ] Diagrama completo com MGs, subscriptions, policies e roles
- [ ] Matriz de acesso preenchida corretamente
- [ ] Todos os requisitos de compliance verificaveis
- [ ] Riscos identificados com mitigacoes propostas

---

## Autoavaliacao

Apos completar, verifique:

| Criterio                                                   | Atendido? |
| ---------------------------------------------------------- | --------- |
| Grupos criados para todos os departamentos                 |           |
| Dynamic membership usado para pelo menos 1 grupo           |           |
| Management Groups separam prod de non-prod                 |           |
| RBAC segue least privilege para todos os departamentos     |           |
| Custom role criado para Prod (gerenciar sem criar/deletar) |           |
| Todas as regras de compliance cobertas por policies        |           |
| Policy Initiative agrupa policies de tags                  |           |
| Tag inheritance com efeito Modify configurado              |           |
| Delete Lock em recursos de producao                        |           |
| Auditores tem acesso somente leitura a tudo                |           |

**Labs relacionados:** `labs/1-iam-gov-net/cenario/bloco1-identity.md`, `labs/1-iam-gov-net/cenario/bloco2-governance.md`, `labs/1-iam-gov-net/cenario/bloco3-iac.md`

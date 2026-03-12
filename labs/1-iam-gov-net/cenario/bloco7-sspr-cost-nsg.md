> Voltar para o [Cenario Contoso](../cenario-contoso.md)

# Bloco 7 - SSPR, Cost Management e NSG Effective Rules

**Origem:** Lab 01 - Manage Microsoft Entra ID Identities (SSPR) + Cost Management + Network Watcher
**Resource Groups utilizados:** `rg-contoso-network` (NSGs do Bloco 4) + `rg-contoso-compute` (VMs do Bloco 5) + `rg-contoso-network` (VMs do Bloco 6)

## Contexto

Com toda a infraestrutura da Contoso Corp operacional (identidade, governanca, rede, compute e load balancing), voce agora complementa a administracao com tres areas criticas para o exame AZ-104: **Self-Service Password Reset (SSPR)** para os usuarios criados no Bloco 1, **Cost Management** para controle de gastos da subscription, e **NSG Effective Security Rules** via Network Watcher para diagnosticar regras de seguranca nas VMs implantadas nos Blocos 5 e 6.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                     Entra ID (Tenant)                              │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  SSPR Configuration                                          │  │
│  │  • Enabled for: Security Group "SSPR-TestGroup"              │  │
│  │  • Methods: Email + Security Questions                       │  │
│  │  • Required methods: 1                                       │  │
│  │  • Registration: Required on next login                      │  │
│  │                                                              │  │
│  │  Users: contoso-user1 (do Bloco 1)                             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Subscription Level                                          │  │
│  │                                                              │  │
│  │  ┌────────────────────┐  ┌─────────────────────────────┐     │  │
│  │  │ Cost Management    │  │ Azure Advisor               │     │  │
│  │  │ • Budget: $50/mes  │  │ • Cost recommendations      │     │  │
│  │  │ • Alert: 80%       │  │ • Security recommendations  │     │  │
│  │  │ • Alert: 100%      │  │ • Reliability               │     │  │
│  │  └────────────────────┘  └─────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Network Watcher                                             │  │
│  │  • Effective Security Rules: NSGs em vm-lb-01 (Bloco 6)        │  │
│  │  • IP Flow Verify: testar trafego permitido/bloqueado        │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 7.1: Configurar SSPR para grupo de teste

O Self-Service Password Reset permite que usuarios resetem suas proprias senhas sem contatar o helpdesk. Voce configura para um grupo de teste usando os usuarios do Bloco 1.

**Criar grupo de teste para SSPR:**

1. Pesquise **Microsoft Entra ID** > **Groups** > **New group**:

   | Setting    | Value                        |
   | ---------- | ---------------------------- |
   | Group type | **Security**                 |
   | Group name | `SSPR-TestGroup`             |
   | Membership | **Assigned**                 |
   | Members    | **contoso-user1** (do Bloco 1) |

2. Clique em **Create**

**Habilitar SSPR:**

3. Navegue para **Microsoft Entra ID** > **Protection** > **Password reset**

4. Em **Properties**:

   | Setting                             | Value            |
   | ----------------------------------- | ---------------- |
   | Self service password reset enabled | **Selected**     |
   | Select group                        | `SSPR-TestGroup` |

5. Clique em **Save**

   > **Conceito:** SSPR pode ser habilitado para **All** (todos os usuarios), **Selected** (grupo especifico) ou **None** (desabilitado). Em producao, o ideal e habilitar para All. Para testes, usar um grupo especifico e mais seguro.

   > **Conexao com Bloco 1:** Voce usa o usuario `contoso-user1` criado no Bloco 1. A identidade e a base — sem usuarios configurados, SSPR nao tem publico-alvo.

---

### Task 7.2: Configurar metodos de autenticacao

1. Em **Password reset** > **Authentication methods**:

   | Setting                    | Value                              |
   | -------------------------- | ---------------------------------- |
   | Number of methods required | `1`                                |
   | Methods available          | **Email** + **Security questions** |

2. Se **Security questions** estiver disponivel, configure:

   | Setting                        | Value |
   | ------------------------------ | ----- |
   | Questions required to register | `3`   |
   | Questions required to reset    | `3`   |

3. Selecione 3 perguntas predefinidas da lista

4. Clique em **Save**

5. Em **Registration**:

   | Setting                                             | Value   |
   | --------------------------------------------------- | ------- |
   | Require users to register when signing in           | **Yes** |
   | Number of days before users are asked to re-confirm | `90`    |

6. Clique em **Save**

7. Em **Notifications**:

   | Setting                              | Value   |
   | ------------------------------------ | ------- |
   | Notify users on password resets      | **Yes** |
   | Notify all admins on password resets | **Yes** |

8. Clique em **Save**

   > **Conceito:** SSPR suporta multiplos metodos: Email, Phone, Microsoft Authenticator, Security Questions e Office phone. O numero de metodos requeridos (1 ou 2) define quantos o usuario precisa fornecer para resetar. Security Questions so podem ser usadas com pelo menos 1 outro metodo.

   > **Dica AZ-104:** Na prova, lembre: SSPR com 2 metodos requeridos e mais seguro. Security Questions NAO podem ser o unico metodo. SSPR requer licenca Azure AD Free (para cloud users) ou P1/P2 (para writeback on-premises).

---

### Task 7.3: Testar fluxo de reset de senha

1. Abra uma janela **InPrivate/Incognito**

2. Acesse `https://aka.ms/ssprsetup`

3. Faca login como **contoso-user1** (credenciais do Bloco 1)

4. Se solicitado, **registre** os metodos de autenticacao:
   - Configure um email alternativo (pode usar qualquer email pessoal)
   - Responda as perguntas de seguranca (se configuradas)

5. Apos registrar, acesse `https://aka.ms/sspr`

6. Insira o username de **contoso-user1**

7. Complete o captcha

8. Selecione o metodo de verificacao (email) e siga o fluxo

9. Defina uma **nova senha**

10. Faca login com a nova senha para confirmar o reset

    > **Conceito:** O fluxo de SSPR: (1) usuario acessa portal de reset, (2) verifica identidade com metodos registrados, (3) define nova senha, (4) Azure AD atualiza a senha. Com writeback habilitado (requer P1), a senha e sincronizada de volta ao AD on-premises.

    > **Conexao com Bloco 1:** O usuario criado no Bloco 1 agora pode resetar sua propria senha sem intervencao do administrador. Isso fecha o ciclo de identidade: criar usuario → atribuir permissoes (Bloco 2) → usuario gerencia propria senha (Bloco 7).

---

### Task 7.4: Criar Budget e alertas no Cost Management

1. Pesquise **Cost Management + Billing** > **Cost Management** > **Budgets**

2. Clique em **+ Add**:

   | Setting         | Value              |
   | --------------- | ------------------ |
   | Scope           | *sua subscription* |
   | Name            | `budget-contoso-lab` |
   | Reset period    | **Monthly**        |
   | Creation date   | *data atual*       |
   | Expiration date | *6 meses a frente* |
   | Budget amount   | `50` (USD)         |

3. Clique em **Next**

4. Configure **alertas**:

   | Alert condition | % of budget | Action Group | Alert recipients |
   | --------------- | ----------- | ------------ | ---------------- |
   | Actual          | `80`        | *nenhum*     | *seu email*      |
   | Actual          | `100`       | *nenhum*     | *seu email*      |
   | Forecasted      | `120`       | *nenhum*     | *seu email*      |

5. Clique em **Create**

6. Navegue para **Cost Management** > **Cost analysis**:
   - Explore a visualizacao **Accumulated costs**
   - Mude para **Daily costs** (bar chart)
   - Filtre por **Resource group** para ver custo por RG
   - Filtre por **Service name** para ver custo por tipo de servico

   > **Conceito:** Budgets enviam notificacoes mas NAO param recursos automaticamente. Para enforcement automatico, use Azure Policy ou Azure Automation com alertas. A opcao "Forecasted" alerta baseada na tendencia de gastos, prevenindo surpresas no fim do mes.

   > **Dica AZ-104:** Na prova: Budgets alertam mas nao bloqueiam. Para limitar gastos, combine Budgets com Policies (ex: limitar VM SKUs) ou Automation runbooks que desligam recursos.

### Task 7.4b: Configurar enforcement automatico com Action Group

Voce conecta um alerta de budget a um Action Group para automatizar acoes quando o limite e atingido.

1. Navegue para **Cost Management** > **Budgets** > clique no budget criado na Task 7.4

2. Clique em **Edit budget**

3. Na secao **Alert conditions**, localize o alerta de **100% Actual**

4. Em **Action group**, clique em **Manage action groups** > **Create action group**:

   | Setting        | Value                                   |
   | -------------- | --------------------------------------- |
   | Resource group | **rg-contoso-identity**                 |
   | Action group name | `ag-budget-alert`                    |
   | Display name   | `BudgetAlert`                           |

5. Na aba **Notifications**:

   | Notification type | Name             | Value          |
   | ----------------- | ---------------- | -------------- |
   | Email/SMS/Push    | `NotifyAdmin`    | *seu email*    |

6. Clique em **Review + create** > **Create**

7. Selecione o action group `ag-budget-alert` para o alerta de 100% > **Save**

   > **Conceito:** Existem diferentes estrategias de enforcement de custos no Azure:
   >
   > | Estrategia               | Mecanismo                                    | Quando usar                              |
   > | ------------------------ | -------------------------------------------- | ---------------------------------------- |
   > | **Azure Policy**         | Restringir SKUs permitidos (ex: B-series)    | Prevenir criacao de recursos caros        |
   > | **Automation Runbook**   | Script que desliga VMs via Action Group       | Reagir a alerta de budget automaticamente |
   > | **Spending Limit**       | Limite de credito (subscriptions dev/test)    | Apenas subscriptions com creditos Azure   |
   > | **Budget + Action Group**| Notificacao + acao automatizada              | Monitoramento proativo de custos          |

   > **Dica AZ-104:** Na prova, diferencie: Budgets **alertam** (nao bloqueiam), Azure Policy **previne** (bloqueia criacao), Automation Runbooks **reagem** (executam acoes). Para um cenario completo de controle de custos, combine os tres: Policy para prevenir, Budget para monitorar, Runbook para reagir.

---

### Task 7.5: Revisar Azure Advisor e criar alerta de recomendacao

1. Pesquise **Advisor** no portal

2. Revise as recomendacoes em cada categoria:
   - **Cost** — identifica recursos ociosos ou superdimensionados
   - **Security** — identifica vulnerabilidades
   - **Reliability** — identifica riscos de disponibilidade
   - **Operational Excellence** — melhores praticas
   - **Performance** — otimizacoes de performance

3. Em **Cost**, verifique se ha recomendacoes como:
   - "Right-size or shutdown underutilized virtual machines"
   - "Delete unattached public IP addresses"
   - "Use Reserved Instances"

4. Selecione qualquer recomendacao e revise os detalhes + impacto estimado

5. Agora crie um **alerta do Advisor**. Navegue para **Advisor** > **Alerts** > **+ New alert**:

   | Setting         | Value                           |
   | --------------- | ------------------------------- |
   | Scope           | *sua subscription*              |
   | Category        | **Cost**                        |
   | Impact          | **High**                        |
   | Alert rule name | `alert-advisor-cost`      |
   | Action Group    | *nenhum (ou crie um com email)* |

6. Clique em **Create alert rule**

   > **Conceito:** Azure Advisor analisa sua configuracao e uso de recursos e fornece recomendacoes personalizadas. Alertas do Advisor notificam quando novas recomendacoes de alto impacto sao identificadas — util para manter o ambiente otimizado continuamente.

   > **Dica AZ-104:** Na prova, Advisor e Cost Management sao frequentemente cobrados juntos. Advisor recomenda; Budgets alertam sobre gastos; Policies restringem. Entenda a diferenca entre esses tres controles.

---

### Task 7.6: Avaliar regras de seguranca efetivas via Network Watcher

O Network Watcher permite visualizar as regras NSG efetivas aplicadas a uma NIC de VM, combinando todas as regras de NSGs associados a subnet e a NIC.

1. Pesquise **Network Watcher** > **Effective security rules** (em Network diagnostic tools)

2. Selecione:

   | Setting           | Value              |
   | ----------------- | ------------------ |
   | Subscription      | *sua subscription* |
   | Resource group    | `rg-contoso-network`      |
   | Virtual machine   | **vm-lb-01**         |
   | Network interface | *selecione a NIC*  |

3. Clique em **View effective security rules**

4. Analise as regras exibidas:
   - Note as **regras do NSG `nsg-snet-lb`** (AllowHTTP, priority 100)
   - Note as **regras padrao** (AllowVNetInBound, AllowAzureLoadBalancerInBound, DenyAllInBound)
   - Identifique a ordem de avaliacao (menor priority = avaliada primeiro)

5. Agora teste com **IP Flow Verify**. Navegue para **Network Watcher** > **IP flow verify**:

   **Teste 1 — HTTP deve ser permitido:**

   | Setting     | Value                  |
   | ----------- | ---------------------- |
   | VM          | **vm-lb-01**             |
   | NIC         | *selecione a NIC*      |
   | Protocol    | **TCP**                |
   | Direction   | **Inbound**            |
   | Local IP    | *IP privado da vm-lb-01* |
   | Local port  | `80`                   |
   | Remote IP   | `10.0.0.1`             |
   | Remote port | `12345`                |

6. Resultado esperado: **Access allowed** — regra `AllowHTTP` (priority 100)

   **Teste 2 — SSH deve ser bloqueado:**

7. Repita com Local port = `22`

8. Resultado esperado: **Access denied** — regra `DenyAllInBound` (priority 65500)

9. Agora compare com uma VM **sem NSG na subnet**. Navegue para **Network Watcher** > **Effective security rules**:

   | Setting         | Value                                       |
   | --------------- | ------------------------------------------- |
   | Virtual machine | **vm-web-01** (Bloco 5, se disponivel) |

10. Note que as regras efetivas sao apenas as **default rules** (sem regras customizadas)

    > **Conceito:** Effective Security Rules mostra a combinacao de TODAS as regras NSG aplicadas a uma NIC (subnet NSG + NIC NSG). IP Flow Verify testa se um pacote especifico seria permitido ou bloqueado, indicando qual regra decide. Essas ferramentas sao essenciais para troubleshooting de conectividade.

    > **Conexao com Bloco 4:** O NSG `nsg-snet-shared` do Bloco 4 esta associado a snet-shared. O NSG `nsg-snet-lb` do Bloco 6 esta associado a snet-lb. Cada subnet tem suas proprias regras efetivas — demonstrando que seguranca e por subnet/NIC.

    > **Dica AZ-104:** Na prova, Network Watcher e cobrado frequentemente: Effective Security Rules (ver regras combinadas), IP Flow Verify (testar pacote), Connection Troubleshoot (testar conectividade fim-a-fim), Next Hop (verificar roteamento).

### Task 7.6b: Testar ordem de avaliacao NSG (subnet vs NIC)

Voce demonstra como o Azure avalia NSGs em camadas: para trafego **inbound**, primeiro o NSG da subnet, depois o NSG da NIC. Ambos precisam permitir.

1. Navegue para **Network security groups** > **Create**:

   | Setting        | Value                                   |
   | -------------- | --------------------------------------- |
   | Name           | `nsg-nic-vm-web-01`                          |
   | Resource group | **rg-contoso-network**                           |
   | Region         | *(mesma regiao das VMs do Bloco 6)*     |

2. Clique em **Create**

3. Navegue para **nsg-nic-vm-web-01** > **Settings** > **Inbound security rules** > **Add**:

   | Setting             | Value              |
   | ------------------- | ------------------ |
   | Source              | **Any**            |
   | Destination         | **Any**            |
   | Service             | **HTTP**           |
   | Action              | **Deny**           |
   | Priority            | `100`              |
   | Name                | `DenyHTTPInbound`  |

4. Clique em **Add**

5. Navegue para **vm-lb-01** > **Networking** > **Network settings** > clique na **NIC** da VM

6. Em **Settings** > **Network security group** > selecione **nsg-nic-vm-web-01** > **Save**

7. Navegue para **Network Watcher** > **IP flow verify**:

   | Setting          | Value                  |
   | ---------------- | ---------------------- |
   | Virtual machine  | **vm-lb-01**             |
   | Direction        | **Inbound**            |
   | Protocol         | **TCP**                |
   | Local port       | `80`                   |
   | Remote IP        | `10.0.0.1`             |
   | Remote port      | `12345`                |

8. **Resultado esperado:** `Access denied` — a regra `DenyHTTPInbound` do NSG da NIC bloqueia

9. Entenda a ordem de avaliacao:

   | Direcao      | Ordem de avaliacao                        | Requisito                      |
   | ------------ | ----------------------------------------- | ------------------------------ |
   | **Inbound**  | Subnet NSG → NIC NSG                      | Ambos devem **permitir**       |
   | **Outbound** | NIC NSG → Subnet NSG                      | Ambos devem **permitir**       |

   Mesmo que o NSG da subnet (`nsg-snet-lb`) permita HTTP, o NSG da NIC (`nsg-nic-vm-web-01`) nega — resultado final: **bloqueado**.

10. **Limpar:** Navegue para a NIC da vm-lb-01 > **Network security group** > selecione **None** > **Save**

11. Delete o NSG `nsg-nic-vm-web-01` (opcional)

    > **Dica AZ-104:** Na prova, a ordem de avaliacao de NSGs e muito cobrada. Regra de ouro: para inbound, o trafego passa primeiro pelo NSG da subnet, depois pelo NSG da NIC. Para outbound, e o inverso. Se QUALQUER um dos NSGs negar, o trafego e bloqueado. Nao e necessario ter NSG em ambos — se nao ha NSG, todo trafego e permitido naquela camada.

---

## Modo Desafio - Bloco 7

- [ ] Criar grupo `SSPR-TestGroup` com `contoso-user1` **(Bloco 1)**
- [ ] Habilitar SSPR para o grupo de teste (Selected)
- [ ] Configurar metodos: Email + Security Questions, 1 metodo requerido
- [ ] Testar reset de senha como contoso-user1 via `https://aka.ms/sspr`
- [ ] Criar Budget mensal ($50) com alertas em 80%, 100% e 120% (forecasted)
- [ ] Criar Action Group `ag-budget-alert` e associar ao alerta de 100% do budget
- [ ] Explorar Cost Analysis por Resource Group e por Service
- [ ] Revisar recomendacoes do Azure Advisor (Cost, Security, Reliability)
- [ ] Criar alerta do Advisor para recomendacoes de Cost com impacto High
- [ ] Visualizar Effective Security Rules da vm-lb-01 **(Bloco 6)**
- [ ] IP Flow Verify: HTTP permitido (porta 80) e SSH bloqueado (porta 22)
- [ ] Comparar regras efetivas entre VM com NSG e sem NSG
- [ ] Criar NSG `nsg-nic-vm-web-01` com regra DenyHTTP, associar a NIC da vm-lb-01, testar com IP Flow Verify
- [ ] Verificar ordem de avaliacao: subnet NSG → NIC NSG (inbound) e NIC NSG → subnet NSG (outbound)

---

## Questoes de Prova - Bloco 7

### Questao 7.1
**Voce habilitou SSPR para um grupo de seguranca. Um usuario membro do grupo reporta que nao consegue resetar a senha. O que voce deve verificar primeiro?**

A) Se o usuario tem licenca Azure AD Premium P2
B) Se o usuario registrou os metodos de autenticacao requeridos
C) Se o usuario e Owner da subscription
D) Se o SSPR esta habilitado para "All"

<details>
<summary>Ver resposta</summary>

**Resposta: B) Se o usuario registrou os metodos de autenticacao requeridos**

Para resetar a senha via SSPR, o usuario precisa ter registrado pelo menos o numero minimo de metodos de autenticacao configurados. Se o usuario nunca registrou (email, telefone, etc.), o SSPR nao funciona. SSPR basico funciona com Azure AD Free para cloud users.

</details>

### Questao 7.2
**Voce criou um Budget de $100/mes com alerta em 80%. O gasto real atinge $85. O que acontece?**

A) O Azure desliga automaticamente os recursos mais caros
B) O Azure envia um email de alerta mas os recursos continuam funcionando
C) O Azure bloqueia novos deployments ate o proximo mes
D) O Azure rebaixa automaticamente os recursos para SKUs menores

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Azure envia um email de alerta mas os recursos continuam funcionando**

Budgets enviam notificacoes (email ou Action Groups) quando o threshold e atingido, mas NAO param ou modificam recursos automaticamente. Para enforcement automatico, voce precisa usar Azure Automation, Logic Apps ou Azure Policy em conjunto com os alertas.

</details>

### Questao 7.3
**Voce quer verificar se trafego TCP na porta 443 de um IP externo e permitido para uma VM. Qual ferramenta do Network Watcher voce usa?**

A) Connection Troubleshoot
B) Effective Security Rules
C) IP Flow Verify
D) Next Hop

<details>
<summary>Ver resposta</summary>

**Resposta: C) IP Flow Verify**

IP Flow Verify testa se um pacote especifico (IP origem, IP destino, porta, protocolo, direcao) seria permitido ou bloqueado pelas regras NSG, e indica qual regra toma a decisao. Effective Security Rules mostra todas as regras mas nao testa um pacote especifico. Connection Troubleshoot verifica conectividade fim-a-fim (nao apenas NSG).

</details>

### Questao 7.4
**Uma VM tem dois NSGs aplicados: um na subnet e outro na NIC. A regra do NSG da subnet permite trafego na porta 80. A regra do NSG da NIC bloqueia trafego na porta 80. O que acontece com trafego inbound na porta 80?**

A) Permitido — a regra da subnet tem precedencia
B) Bloqueado — o trafego precisa ser permitido por AMBOS os NSGs
C) Permitido — a regra Allow sempre vence sobre Deny
D) Depende da priority numerica das regras

<details>
<summary>Ver resposta</summary>

**Resposta: B) Bloqueado — o trafego precisa ser permitido por AMBOS os NSGs**

Para trafego inbound, o Azure avalia primeiro o NSG da subnet, depois o NSG da NIC. O trafego so e permitido se passar por AMBOS. Se qualquer um bloquear, o trafego e negado. Para outbound, a ordem e invertida: NIC primeiro, depois subnet.

</details>

---

> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 3 - Azure Resources & IaC](bloco3-iac.md)

# Bloco 2 - Governance & Compliance

**Origem:** Lab 02a (Subscriptions & RBAC) + Lab 02b (Azure Policy) + **novos exercicios de integracao**
**Resource Groups utilizados:** `rg-contoso-identity`

## Contexto

Com a identidade configurada no Bloco 1, agora voce estabelece governanca: RBAC para os **usuarios e grupos ja criados**, policies que serao **validadas no Bloco 3** durante o deploy de discos, e locks para proteger recursos. Tudo e feito no `rg-contoso-identity`, que tambem sera usado no Bloco 3 (IaC).

## Diagrama

```
┌────────────────────────────────────────────────────────────┐
│                  Root Management Group                     │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         mg-contoso-prod (Management Group)           │  │
│  │                                                      │  │
│  │  RBAC:                                               │  │
│  │  • VM Contributor → IT Lab Administrators (Bloco 1)  │  │
│  │  • Custom Support Request (custom role)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  rg-contoso-identity                                 │  │
│  │  Tag: Cost Center = 000                              │  │
│  │                                                      │  │
│  │  Policies:                                           │  │
│  │  • Deny: Require tag (testada e removida)            │  │
│  │  • Modify: Inherit tag                               │  │
│  │  • Deny: Allowed Locations (East US only)            │  │
│  │                                                      │  │
│  │  Lock: Delete (rg-lock)                              │  │
│  │                                                      │  │
│  │  RBAC:                                               │  │
│  │  • Reader → Guest user (Bloco 1)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  → Policies validadas no Bloco 3 (deploy de discos)        │
│  → RBAC testado nos Blocos 3 e 5                           │
└────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Criar Management Group

Management Groups sao o nivel mais alto de organizacao no Azure, acima das subscriptions. Eles permitem aplicar RBAC e policies em escala — em vez de configurar cada subscription individualmente, voce configura uma vez no MG e tudo abaixo herda.

> **Analogia:** Pense na hierarquia como uma empresa. O Management Group e a diretoria, a subscription e o departamento, o Resource Group e a equipe, e os recursos sao as pessoas. Uma regra da diretoria vale para todos abaixo.

> **Conceito:** A hierarquia do Azure tem 4 niveis: Management Group > Subscription > Resource Group > Resource. RBAC e policies sao **herdados** de cima para baixo. Um role atribuido no MG vale para todas as subscriptions filhas e seus recursos.

1. Acesse o **Azure Portal** e pesquise **Microsoft Entra ID**

2. No blade **Manage**, selecione **Properties**

3. Revise a area **Access management for Azure resources**

   > Esta opcao permite que o Global Administrator do Entra ID gerencie o acesso a **todos** os recursos Azure do tenant. Por padrao esta desabilitada — habilite apenas se precisar de acesso emergencial.

4. Pesquise e selecione **Management groups**

5. Clique em **+ Create**:

   | Setting                       | Value       |
   | ----------------------------- | ----------- |
   | Management group ID           | `mg-contoso-prod` |
   | Management group display name | `mg-contoso-prod` |

   > O **ID** e imutavel depois de criado e usado em scripts/templates. O **display name** pode ser alterado depois. Escolha IDs descritivos porque voce nao podera muda-los.

6. Clique em **Submit** e **Refresh**

7. Selecione **mg-contoso-prod** > clique em **details**

8. Clique em **+ Add subscription** e selecione sua subscription > **Save**

   > **Conceito:** O Root Management Group e o topo da hierarquia. Policies e RBAC aplicados em um MG sao herdados por todas as subscriptions filhas. **Sem mover a subscription para dentro do MG, os roles atribuidos nele nao terao efeito nos recursos.**

   > **Dica AZ-104:** Na prova, questoes sobre "onde aplicar uma policy para afetar multiplas subscriptions" — a resposta e Management Group.

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

Aqui voce conecta a identidade (Bloco 1) com o acesso (Bloco 2). Atribuir um role RBAC e responder a tres perguntas: **quem** (IT Lab Administrators), **pode fazer o que** (gerenciar VMs), **em que escopo** (mg-contoso-prod e tudo abaixo).

Voce atribui o role ao grupo **IT Lab Administrators** (criado no Bloco 1), que inclui `contoso-user1` e o guest user. Isso sera testado no **Bloco 5** quando contoso-user1 gerenciar VMs.

> **Conceito:** RBAC = Role-Based Access Control. No Azure, toda atribuicao de role tem tres componentes: **Security principal** (quem), **Role definition** (permissoes), **Scope** (onde). Sem qualquer um dos tres, o acesso nao funciona.

1. Selecione o management group **mg-contoso-prod**

2. Selecione **Access control (IAM)** > aba **Roles**

3. Navegue pelos built-in roles. Clique em **View** em um role para ver Permissions, JSON e Assignments

   > O Azure tem mais de 100 built-in roles. Os mais comuns na prova: **Owner** (tudo + atribuir roles), **Contributor** (tudo exceto atribuir roles), **Reader** (somente leitura), **User Access Administrator** (apenas gerenciar roles).

4. Clique em **+ Add** > **Add role assignment**

5. Pesquise e selecione **Virtual Machine Contributor**

   > **Conceito:** O role Virtual Machine Contributor permite gerenciar VMs (criar, deletar, ligar, desligar), mas NAO o SO, a VNet ou o Storage Account conectados. Cada role tem um conjunto especifico de **Actions** (o que pode fazer) e **NotActions** (excecoes).

6. Clique em **Next** > na aba **Members**, clique em **Select Members**

7. Pesquise e selecione o grupo **IT Lab Administrators** > **Select**

   > **Boa pratica:** Sempre atribua roles a **grupos**, nunca diretamente a usuarios. Isso facilita gerenciamento — para dar acesso a alguem novo, basta adicionar ao grupo.

8. Clique em **Review + assign** duas vezes

9. Confirme a atribuicao na aba **Role assignments**

   > **Conexao com Bloco 5:** O contoso-user1 (membro do IT Lab Administrators) podera gerenciar VMs em qualquer RG sob este Management Group. Testaremos isso no Bloco 5.

---

### Task 2.3: Criar custom RBAC role

Quando nenhum built-in role atende exatamente as suas necessidades, voce cria um custom role. Neste caso, voce clona o role **Support Request Contributor** e remove uma permissao especifica — demonstrando o principio de least privilege.

> **Conceito:** Custom roles permitem granularidade fina. Voce define exatamente quais **Actions** (permissoes) o role concede e quais **NotActions** sao excluidas. NotActions nao e um "deny" — e uma subtracao do conjunto de Actions.

1. No management group **mg-contoso-prod**, va para **Access control (IAM)**

2. Clique em **+ Add** > **Add custom role**

3. Preencha a aba **Basics**:

   | Setting              | Value                                             |
   | -------------------- | ------------------------------------------------- |
   | Custom role name     | `Custom Support Request`                          |
   | Description          | `A custom contributor role for support requests.` |
   | Baseline permissions | **Clone a role**                                  |
   | Role to clone        | **Support Request Contributor**                   |

   > **Clone a role** e o metodo mais facil: voce parte de um role existente e ajusta. Tambem e possivel comecar do zero ou importar um JSON.

4. Na aba **Permissions**, clique em **+ Exclude permissions**

5. Digite `.Support`, selecione **Microsoft.Support**

6. Marque **Other: Registers Support Resource Provider** > **Add**

   > **Conceito:** A permissao agora aparece em **NotActions**. NotActions remove permissoes do conjunto de Actions. Exemplo: se Actions inclui `Microsoft.Support/*` e NotActions inclui `Microsoft.Support/register/action`, o resultado e: tudo de Support EXCETO registrar o provider.

7. Na aba **Assignable scopes**, verifique que o MG esta listado

   > **Assignable scopes** define ONDE este custom role pode ser atribuido. Se o scope e o MG, ele pode ser atribuido no MG e em qualquer subscription/RG abaixo dele.

8. Revise o JSON: observe **Actions**, **NotActions** e **AssignableScopes**

9. Clique em **Review + Create** > **Create**

   > **Dica AZ-104:** Na prova, saiba que custom roles podem levar ate 5 minutos para propagar. Tambem lembre que o limite e de 5.000 custom roles por tenant.

---

### Task 2.4: Monitorar role assignments via Activity Log

O Activity Log registra todas as operacoes de controle (management plane) no Azure, incluindo atribuicoes de RBAC. E util para auditoria — "quem atribuiu esse role e quando?"

1. No recurso **mg-contoso-prod**, selecione **Activity log**

2. Revise as atividades de role assignments

   > **Dica AZ-104:** O Activity Log retém dados por **90 dias**. Para retencao maior, configure um **Diagnostic Setting** para enviar logs ao Log Analytics ou Storage Account. Na prova, "onde ver operacoes de RBAC?" → Activity Log.

---

### Task 2.5: Criar Resource Group com tags

Resource Groups sao containers logicos que agrupam recursos relacionados. Tags sao metadados (chave:valor) que ajudam na organizacao, cobranca e automacao. Voce cria o Resource Group `rg-contoso-identity` para testes de governanca e para uso no Bloco 3 (IaC). Ele recebe a tag `Cost Center`.

> **Conceito:** Tags NAO sao herdadas automaticamente pelos recursos dentro do RG. Para que isso aconteca, voce precisa de uma Azure Policy (que voce configurara na Task 2.7). Essa e uma pegadinha muito comum na prova.

1. Pesquise e selecione **Resource groups** > **+ Create**:

   | Setting             | Value                 |
   | ------------------- | --------------------- |
   | Subscription        | *sua subscription*    |
   | Resource group name | `rg-contoso-identity` |
   | Location            | **East US**           |

   > **Location do RG** define onde os metadados do RG sao armazenados. Os recursos dentro dele podem estar em qualquer regiao (a menos que uma policy restrinja). Na prova, "a location do RG afeta a location dos recursos?" → NAO, mas e boa pratica manter na mesma regiao.

2. Na aba **Tags**:

   | Name          | Value |
   | ------------- | ----- |
   | `Cost Center` | `000` |

   > Tags sao fundamentais para governanca de custos. Em producao, equipes de financas usam tags como `Cost Center`, `Environment`, `Owner` para alocar custos por departamento, ambiente ou projeto.

3. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** O rg-contoso-identity sera usado para deploy de managed disks. As policies aplicadas aqui serao validadas quando os discos forem criados.

---

### Task 2.6: Aplicar Azure Policy (Deny) - Require tag no rg-contoso-identity

Azure Policy e o mecanismo de governanca que garante que recursos sigam as regras da organizacao. O efeito **Deny** e o mais restritivo — impede a criacao de recursos que nao atendem a condicao. Aqui voce testa: "so crie recursos se tiverem a tag Cost Center = 000".

> **Analogia:** Azure Policy com efeito Deny e como um guarda de seguranca na porta — se voce nao tem o cracha certo (a tag), voce nao entra (o recurso nao e criado).

1. Pesquise e selecione **Policy** > **Authoring** > **Definitions**

   > **Definitions** sao as regras disponiveis (built-in + custom). **Assignments** sao as regras aplicadas a um escopo especifico. Uma definition pode existir sem estar aplicada — como uma lei que existe mas ninguem fiscaliza.

2. Pesquise: `Require a tag and its value on resources`

3. Selecione a policy > **Assign policy**

4. Configure o **Scope**: Subscription + Resource Group **rg-contoso-identity**

   > O scope define onde a policy se aplica. Ao escolher o RG, apenas recursos criados NESTE RG serao avaliados. Recursos em outros RGs nao sao afetados.

5. Configure **Basics**:

   | Setting            | Value                                                 |
   | ------------------ | ----------------------------------------------------- |
   | Assignment name    | `Require Cost Center tag with value 000 on resources` |
   | Policy enforcement | **Enabled**                                           |

   > **Policy enforcement = Enabled** faz a policy agir de verdade (bloquear/modificar). Se Disabled, a policy apenas avalia compliance sem bloquear — util para testar o impacto antes de ativar.

6. Na aba **Parameters**: Tag Name = `Cost Center`, Tag Value = `000`

7. Clique em **Review + Create** > **Create**

   > Aguarde 5-10 minutos para a policy entrar em vigor. Policies nao sao instantaneas — o Azure precisa propagar a atribuicao.

8. **Teste:** Pesquise **Storage Accounts** > **+ Create** no RG **rg-contoso-identity** com qualquer nome

9. Clique em **Review** > **Create** — voce deve receber **Validation failed** (recurso sem tag)

   > **Conceito:** O efeito **Deny** impede criacao de recursos que nao atendem as condicoes da policy. Na prova, "como IMPEDIR criacao de recursos sem tags?" → Policy com efeito Deny.

---

### Task 2.7: Substituir Deny por Modify policy (Inherit tag) no rg-contoso-identity

O efeito Deny e util mas rigido — ele bloqueia e o usuario precisa corrigir manualmente. O efeito **Modify** e mais inteligente: em vez de bloquear, ele **corrige automaticamente** o recurso. Aqui, se um recurso for criado sem a tag Cost Center, a policy adiciona a tag automaticamente.

> **Conceito:** A diferenca entre Deny e Modify e crucial na prova. Deny = bloqueia. Modify = corrige. Audit = apenas registra como non-compliant. Escolha o efeito baseado na intencao: quer impedir? Deny. Quer corrigir? Modify. Quer apenas monitorar? Audit.

1. Va em **Policy** > **Assignments** > localize a atribuicao **Require Cost Center tag...** > **...** > **Delete assignment**

2. Clique em **Assign policy** > Scope: **rg-contoso-identity**

3. Pesquise: `Inherit a tag from the resource group if missing`

4. Configure **Basics**:

   | Setting            | Value                                                                              |
   | ------------------ | ---------------------------------------------------------------------------------- |
   | Assignment name    | `Inherit the Cost Center tag and its value 000 from the resource group if missing` |
   | Policy enforcement | **Enabled**                                                                        |

5. Na aba **Parameters**: Tag Name = `Cost Center`

6. Na aba **Remediation**: Enable **Create a remediation task**

   > **Conceito:** O efeito **Modify** requer uma **Managed Identity** para alterar recursos existentes. A remediation task usa essa identidade para aplicar a correcao em recursos que ja existem e estao non-compliant. Novos recursos sao corrigidos automaticamente no momento da criacao.

   > **Dica AZ-104:** Na prova, "qual efeito de policy requer Managed Identity?" → **Modify** e **DeployIfNotExists**. Ambos precisam de identidade para fazer alteracoes.

7. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** Quando voce criar managed disks no rg-contoso-identity, eles receberao automaticamente a tag `Cost Center: 000`. Voce verificara isso em cada deploy.

---

### Task 2.8: Aplicar Allowed Locations policy no rg-contoso-identity

Esta policy e uma das mais usadas em producao — ela garante que recursos so sejam criados em regioes aprovadas (por compliance, latencia ou custo). Sera testada no **Bloco 3** tentando criar um disco em outra regiao.

> **Conceito:** Existem DUAS policies de location similares: "Allowed locations" (restringe recursos) e "Allowed locations for resource groups" (restringe RGs). Na prova, cuidado para nao confundir — uma afeta recursos, outra afeta RGs.

1. Em **Policy** > **Definitions** > pesquise: `Allowed locations`

2. Selecione a policy (nao confunda com "Allowed locations for resource groups") > **Assign policy**

3. Configure o **Scope**: Subscription + Resource Group **rg-contoso-identity**

4. Configure **Basics**:

   | Setting            | Value                                |
   | ------------------ | ------------------------------------ |
   | Assignment name    | `Restrict resources to East US only` |
   | Policy enforcement | **Enabled**                          |

5. Na aba **Parameters**: Allowed locations = **East US**

6. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** No Bloco 3, voce tentara criar um disco em West US e vera que esta policy bloqueia a criacao.

---

### Task 2.9: Atribuir Reader role ao Guest user no rg-contoso-identity

Voce aplica o principio de least privilege ao guest user: ele so precisa VER recursos, nao modificar. O Reader role concede exatamente isso — acesso somente leitura.

O guest user (convidado no Bloco 1) recebera permissao somente-leitura no rg-contoso-identity, o que sera testado no **Bloco 3**.

> **Conceito:** O escopo da atribuicao importa. Reader no RG permite ver tudo NESTE RG. O mesmo usuario nao vera recursos em outros RGs (a menos que tenha outra atribuicao). RBAC e sempre: quem + o que + onde.

1. Navegue para o resource group **rg-contoso-identity**

2. Selecione **Access control (IAM)** > **+ Add** > **Add role assignment**

3. Pesquise e selecione o role **Reader** > **Next**

4. Na aba **Members**, clique em **Select Members**

5. Pesquise e selecione o **guest user** (convidado no Bloco 1) > **Select**

6. Clique em **Review + assign** duas vezes

7. Confirme na aba **Role assignments** que o guest user tem role **Reader** no rg-contoso-identity

   > **Conexao com Bloco 3:** O guest user podera VER os discos criados no rg-contoso-identity, mas NAO podera criar ou modificar recursos. Testaremos isso no Bloco 3.

---

### Task 2.10: Configurar Resource Lock e testar

Resource Locks sao a "ultima linha de defesa" contra exclusoes acidentais. Mesmo que alguem tenha role Owner, o lock impede a exclusao. Em producao, locks sao essenciais em recursos criticos (databases de producao, VNets compartilhadas, etc.).

> **Analogia:** O lock e como uma trava de seguranca no quadro de luz — mesmo quem tem a chave do predio precisa primeiro remover a trava antes de desligar a energia.

1. Navegue para **rg-contoso-identity** > **Settings** > **Locks**

2. Clique em **Add**:

   | Setting   | Value      |
   | --------- | ---------- |
   | Lock name | `rg-lock`  |
   | Lock type | **Delete** |

   > **Delete vs ReadOnly:** O lock **Delete** permite modificar recursos mas impede exclusao. O lock **ReadOnly** impede QUALQUER modificacao (incluindo criacao de novos recursos no RG). Na prova, saiba a diferenca — ReadOnly e muito mais restritivo do que parece.

3. Clique em **Ok**

4. Tente deletar o resource group: **Overview** > **Delete resource group** > digite `rg-contoso-identity` > **Delete**

5. Voce deve receber uma notificacao **negando a exclusao**

   > **Conceito:** Locks protegem contra exclusoes acidentais. O lock Delete permite modificar mas impede exclusao. Locks **sobrescrevem quaisquer permissoes**, incluindo Owner. Para deletar o RG, primeiro voce precisa remover o lock — e essa acao intencional evita acidentes.

   > **Dica AZ-104:** Na prova, "um Owner nao consegue deletar um RG — qual a causa?" → Resource Lock. Locks sao avaliados ANTES do RBAC.

---

### Task 2.11: Teste de integracao — Verificar acesso do contoso-user1

Este teste fecha o ciclo Identity (Bloco 1) + Governance (Bloco 2). Voce valida que tudo o que configurou funciona junto: o usuario criado no Bloco 1, com os roles atribuidos neste Bloco, tem exatamente as permissoes esperadas — nem mais, nem menos.

1. Abra uma janela **InPrivate/Incognito** no navegador

   > Usar InPrivate evita conflito com sua sessao principal. O Azure usa cookies de autenticacao — sem InPrivate, voce continuaria logado como voce mesmo.

2. Acesse `https://portal.azure.com`

3. Faca login como **contoso-user1@{seu-dominio}.onmicrosoft.com** usando a senha salva no Bloco 1

4. Pesquise **Management groups** — voce deve ver **mg-contoso-prod**

5. Pesquise **Virtual Machines** — voce deve poder ver a pagina (mas nao havera VMs ainda)

6. Pesquise **Resource groups** — voce deve ver os RGs, mas com permissoes limitadas

7. Tente criar um **Storage Account** no rg-contoso-identity — deve **falhar** (VM Contributor nao tem permissao para storage)

   > **Validacao:** contoso-user1 tem VM Contributor (pode gerenciar VMs) mas nao pode criar outros tipos de recursos. Isso demonstra que RBAC e **especifico por servico** — nao e "tudo ou nada". No Bloco 5, testaremos com VMs reais.

8. Feche a janela InPrivate

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `mg-contoso-prod` e **mover sua subscription para dentro dele**
- [ ] Atribuir **VM Contributor** ao grupo `IT Lab Administrators` (Bloco 1) no MG
- [ ] Criar custom role **Custom Support Request** (clone + NotActions)
- [ ] Verificar no Activity Log
- [ ] Criar RG `rg-contoso-identity` com tag `Cost Center: 000`
- [ ] Aplicar Deny policy (Require tag) → testar → remover
- [ ] Aplicar Modify policy (Inherit tag)
- [ ] Aplicar **Allowed Locations** (East US only)
- [ ] Atribuir **Reader** ao guest user
- [ ] Criar Resource Lock (Delete) → testar exclusao
- [ ] **Integracao:** Login como contoso-user1 → verificar acesso limitado

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce atribuiu VM Contributor a um grupo no Management Group. Um membro do grupo tenta criar um Storage Account. O que acontece?**

A) A criacao e permitida porque VM Contributor inclui todas as permissoes de compute
B) A criacao falha porque VM Contributor nao inclui permissoes de Storage
C) A criacao e permitida no nivel de Management Group
D) A criacao depende do Resource Group

<details>
<summary>Ver resposta</summary>

**Resposta: B) A criacao falha porque VM Contributor nao inclui permissoes de Storage**

VM Contributor permite gerenciar VMs (Microsoft.Compute/virtualMachines/*) mas NAO inclui permissoes para Storage, Network ou outros servicos. RBAC no Azure e aditivo — o usuario so pode fazer o que os roles atribuidos permitem explicitamente.

</details>

### Questao 2.2
**Voce aplicou a policy "Allowed locations" com East US em um Resource Group. Um usuario tenta criar um disco em West US via ARM template nesse RG. O que acontece?**

A) O disco e criado em West US normalmente
B) O disco e criado em East US automaticamente
C) O deploy falha com erro de policy violation
D) O disco e criado mas marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: C) O deploy falha com erro de policy violation**

A policy "Allowed locations" usa o efeito **Deny**, que bloqueia ativamente a criacao de recursos em locais nao permitidos. O ARM template falhara durante a validacao.

</details>

### Questao 2.3
**Qual a diferenca entre os efeitos Deny, Audit e Modify no Azure Policy?**

A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente
B) Todos os tres bloqueiam a criacao de recursos
C) Deny e Audit sao identicos, Modify cria recursos novos
D) Audit bloqueia, Deny registra, Modify exclui recursos

<details>
<summary>Ver resposta</summary>

**Resposta: A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente**

- **Deny:** Impede criacao/modificacao de recursos nao-conformes
- **Audit:** Permite a criacao mas registra como non-compliant
- **Modify:** Altera propriedades automaticamente (requer Managed Identity)

</details>

### Questao 2.4
**Um usuario com role Owner tenta excluir um Resource Group que tem um Delete lock. O que acontece?**

A) A exclusao e permitida porque Owner tem todas as permissoes
B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario
C) A exclusao e permitida mas gera um alerta
D) A exclusao e bloqueada apenas para usuarios sem role Owner

<details>
<summary>Ver resposta</summary>

**Resposta: B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario**

Resource Locks sobrescrevem quaisquer permissoes, incluindo Owner. O lock precisa ser removido primeiro.

</details>

### Questao 2.5
**Voce atribuiu Reader role a um guest user em um Resource Group. O que este usuario pode fazer?**

A) Criar e modificar recursos no RG
B) Apenas visualizar recursos, sem poder criar ou modificar
C) Gerenciar apenas VMs no RG
D) Nada — guest users nao podem receber roles

<details>
<summary>Ver resposta</summary>

**Resposta: B) Apenas visualizar recursos, sem poder criar ou modificar**

O role **Reader** permite apenas visualizar recursos existentes. Nao concede permissoes de criacao, modificacao ou exclusao. Guest users podem receber qualquer role RBAC, assim como usuarios internos.

</details>

---

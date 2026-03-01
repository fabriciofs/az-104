# Gabarito — Estudo de Caso 3: Rede VidaSaude Hospitais

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `caso3-hospital-compliance.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Governanca

### Q1.1 — Policy Initiative vs Policies Individuais

**Resposta: B) Initiatives permitem uma unica assignment com compliance tracking unificado, em vez de 5 assignments separadas**

A principal vantagem de uma Policy Initiative e o **gerenciamento centralizado**:

- **Uma unica assignment** para todas as 5 policies, em vez de gerenciar 5 assignments separadas
- **Dashboard de compliance unificado** — voce ve o status de todas as policies relacionadas em um unico painel
- **Facilidade de manutencao** — adicionar ou remover policies da initiative sem criar novas assignments
- **Parametrizacao centralizada** — parametros comuns podem ser definidos uma vez na initiative

**Por que os outros estao errados:**
- **A) Efeitos diferentes na mesma initiative** — Na verdade, initiatives **sim** permitem efeitos diferentes (cada policy dentro da initiative pode ter seu proprio efeito). Mas isso nao e exclusivo de initiatives — policies individuais tambem podem ter efeitos diferentes. A vantagem real e o gerenciamento centralizado, nao os efeitos.
- **C) Avaliacao mais rapida** — Incorreto. O tempo de avaliacao nao muda significativamente entre initiatives e policies individuais.
- **D) MG exclusivo de initiatives** — Incorreto. Tanto policies individuais quanto initiatives podem ser atribuidas em qualquer escopo: Management Group, Subscription ou Resource Group.

**[GOTCHA]** No exame, quando a questao envolve "multiplas regras de compliance relacionadas", a resposta geralmente aponta para Policy Initiative. A chave e o **gerenciamento unificado**, nao capacidades tecnicas exclusivas.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Azure Policy Initiatives

---

### Q1.2 — Management Group Hierarchy Multi-Hospital

**Resposta:**

**1. Hierarquia proposta:**

```
Root Management Group (Tenant)
    └── VidaSaude-MG
        ├── VidaSaude-Prod-Sub (Subscription)
        │   ├── vs-hub-rg
        │   ├── vs-shared-rg
        │   ├── vs-hosp1-rg
        │   ├── vs-hosp2-rg
        │   ├── vs-hosp3-rg
        │   └── vs-hosp4-rg
        └── (futuras subscriptions para novos hospitais)
```

Alternativa com mais granularidade (se cada hospital tiver subscription propria):

```
Root Management Group (Tenant)
    └── VidaSaude-MG (policies de compliance aqui)
        ├── VidaSaude-Shared-MG
        │   └── VidaSaude-Shared-Sub
        └── VidaSaude-Hospitais-MG
            ├── Hosp1-Sub
            ├── Hosp2-Sub
            ├── Hosp3-Sub
            └── Hosp4-Sub (+ futuras)
```

**2. Policy Initiative — atribuir no `VidaSaude-MG`:**

Atribuir no Management Group raiz da VidaSaude garante que:
- Todas as subscriptions existentes herdam automaticamente
- Novas subscriptions adicionadas ao MG tambem herdam
- Policies sao consistentes em todos os hospitais

**3. Role Reader para Auditoria — atribuir no `VidaSaude-MG`:**

Atribuir Reader no Management Group permite que auditores vejam recursos de todos os hospitais com uma unica assignment. Se atribuir por subscription ou RG, seria necessario uma assignment por hospital.

**4. AdminHospital — acesso restrito ao proprio hospital:**

Atribuir o role **Contributor** (ou role customizado) a cada admin no **resource group** do seu hospital:
- Admin Hosp1 → Contributor em `vs-hosp1-rg`
- Admin Hosp2 → Contributor em `vs-hosp2-rg`
- Etc.

Como RBAC nao tem efeito deny (apenas acesso aditivo), cada admin so vera recursos do seu proprio RG.

**[GOTCHA]** Management Groups sao a forma correta de aplicar policies uniformemente em multiplas subscriptions. No exame, se a questao menciona "multiplas entidades que precisam herdar policies", pense em Management Groups.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Management Groups e heranca

---

### Q1.3 — Custom RBAC Role para Auditor

**Resposta:**

**1. Por que Reader nao e suficiente para Activity Logs detalhados:**

O role **Reader** permite ver Activity Logs basicos (quem criou/deletou recursos), mas **nao** inclui permissao para todas as categorias de Activity Log. Para logs detalhados de operacoes (incluindo quem modificou configuracoes, quem acessou cada recurso, tentativas de acesso negadas), e necessario:

- `Microsoft.Insights/eventtypes/*` — para Activity Logs completos
- `Microsoft.Insights/diagnosticSettings/read` — para ver configuracoes de diagnostico

O role Reader inclui `*/read` mas Activity Log detalhado pode requerer permissoes adicionais de Insights.

**2. Actions minimas para o custom role:**

```json
{
  "Name": "VidaSaude Auditor",
  "Description": "Leitura de recursos e logs para auditoria de compliance",
  "Actions": [
    "*/read",
    "Microsoft.Insights/eventtypes/*",
    "Microsoft.Insights/LogDefinitions/read",
    "Microsoft.Insights/diagnosticSettings/read",
    "Microsoft.Insights/ActivityLogAlerts/read"
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "DataActions": [],
  "NotDataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/VidaSaude-MG"
  ]
}
```

Notas:
- `*/read` cobre leitura de todos os recursos (management plane)
- `NotDataActions` com exclusao de blob read impede acesso ao conteudo dos blobs
- `DataActions` vazio significa nenhuma permissao de data plane

**3. Reader e acesso a blobs:**

**Nao**, o role Reader **nao** permite acesso ao conteudo dos blobs. Reader opera no **management plane** — permite ver que o storage account existe, suas propriedades, metricas e configuracoes. Mas ler o **conteudo** dos blobs e uma operacao de **data plane**, que requer roles como:

- `Storage Blob Data Reader` — para ler conteudo
- `Storage Blob Data Contributor` — para ler e gravar conteudo

| Plano | O que ve | Roles |
|-------|----------|-------|
| Management Plane | Recurso existe, propriedades, metricas | Reader, Contributor, Owner |
| Data Plane | Conteudo dentro do recurso (blobs, filas, tabelas) | Storage Blob Data Reader/Contributor |

**[GOTCHA]** Management plane vs data plane e uma das distincoes mais testadas no AZ-104. Reader nunca da acesso ao conteudo de dados. Para acessar dados, sempre e necessario um role de data plane especifico.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Custom RBAC roles

---

## Secao 2 — Networking

### Q2.1 — Private Endpoint DNS Resolution

**Resposta: B) Criar uma Azure Private DNS Zone `privatelink.blob.core.windows.net` com VNet Links para todas as VNets**

Quando um Private Endpoint e criado, o FQDN do storage account precisa resolver para o **IP privado** do endpoint, nao o IP publico. Isso requer:

1. Criar uma **Private DNS Zone** com o nome `privatelink.blob.core.windows.net`
2. Registrar o Private Endpoint na zona (geralmente automatico se a zona for criada junto com o endpoint)
3. Criar **VNet Links** dessa zona para **todas** as VNets que precisam acessar o storage via Private Endpoint

O fluxo de resolucao DNS:
```
VM resolve: vsprontuarios.blob.core.windows.net
    → CNAME: vsprontuarios.privatelink.blob.core.windows.net
        → Private DNS Zone: 10.0.1.10 (IP privado do PE)
```

**Por que os outros estao errados:**
- **A) Registro A manual no DNS on-premises** — Funciona para VMs on-premises, mas nao para VMs no Azure. E incompleto.
- **C) Bloquear acesso publico** — Isso so impede acesso publico, mas nao faz o DNS resolver para o IP privado. Sem a Private DNS Zone, o DNS continuaria resolvendo para o IP publico e as conexoes falhariam.
- **D) DNS apontando para IP direto** — Impratico e fragil. Se o IP do PE mudar, todas as VMs precisariam ser reconfiguradas. Alem disso, aplicacoes que usam FQDN (a maioria) nao funcionariam.

**[GOTCHA]** Private Endpoint sem Private DNS Zone = DNS resolve para IP publico = conexao vai pelo caminho publico (ou falha se o firewall bloquear). A Private DNS Zone e o componente que "fecha o circuito" do Private Endpoint.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Private Endpoints

---

### Q2.2 — Hub-Spoke Network Design e Peering

**Resposta:**

**1. Opcoes de peering para trafego via Azure Firewall:**

**Lado do Hub (HubVNet → Hosp1VNet):**
- **Allow gateway transit:** Habilitar se o Hub tem VPN Gateway que precisa ser compartilhado com spokes
- **Allow forwarded traffic:** Habilitar — permite que o Hub encaminhe trafego de outros spokes

**Lado do Spoke (Hosp1VNet → HubVNet):**
- **Use remote gateway:** Habilitar se quer usar o VPN Gateway do Hub
- **Allow forwarded traffic:** Habilitar — permite receber trafego encaminhado pelo Hub

**2. Trafego spoke-to-spoke direto — o que pode estar errado:**

Se VMs em Hosp2 conseguem acessar VMs em Hosp1 diretamente, as causas possiveis sao:

- Nao ha **UDR (User-Defined Route)** nas subnets dos spokes forcando trafego para o IP do Azure Firewall no Hub
- Sem UDR, o trafego usa a **system route** que roteia via peering diretamente (se ambos os spokes estiverem pareados ao Hub e o peering permitir forwarded traffic)

**3. Forcar trafego spoke-to-spoke pelo Azure Firewall:**

Fernanda deve criar **Route Tables** em cada subnet dos spokes com uma UDR:

| Nome | Address Prefix | Next Hop Type | Next Hop IP |
|------|---------------|---------------|-------------|
| to-spoke-via-fw | 10.0.0.0/8 | Virtual Appliance | 10.0.2.4 (IP do Azure Firewall) |

Essa rota forca todo trafego com destino `10.0.0.0/8` (que inclui todas as VNets) a passar pelo Azure Firewall. O Firewall entao decide se permite ou bloqueia com base nas regras de rede/aplicacao.

Adicionalmente, a configuracao **"propagate gateway routes" = No** na Route Table dos spokes impede que rotas BGP sobrescrevam a UDR.

**[GOTCHA]** Hub-spoke nao roteia trafego pelo Hub automaticamente. Sem UDRs, os spokes usam system routes e o trafego pode ir direto (se o peering permitir). UDRs sao **obrigatorias** para forcar trafego pelo Azure Firewall/NVA.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco5-routing.md` — UDR e NVA

---

### Q2.3 — NSG Rules para Isolamento de Subnets

**Resposta:**

**1. A configuracao atende parcialmente:**

As regras de **inbound** da subnet Data estao corretas:
- Permite SQL (1433) vindo da subnet App ✓
- Bloqueia todo o resto ✓

Porem, falta configurar **outbound** na subnet Data para impedir que ela inicie conexoes para a subnet App (requisito 4).

**2. DenyAllInbound bloqueia respostas de internet?**

**Nao.** O Azure NSG e **stateful**. Isso significa que se uma conexao de **saida** e permitida (a VM na subnet Data inicia uma conexao para a internet para atualizacao), as **respostas** (inbound) dessa mesma conexao sao automaticamente permitidas, independentemente das regras de inbound.

O fluxo:
```
VM (Data subnet) ──── SYN ────► Internet (saida permitida)
VM (Data subnet) ◄── SYN-ACK ── Internet (resposta: permitida automaticamente)
```

A regra `DenyAllInbound` so bloqueia **novas conexoes** iniciadas de fora. Respostas de conexoes que a VM iniciou **passam automaticamente** porque o NSG rastreia o estado da conexao (stateful).

**3. Bloquear Data → App (saida):**

Fernanda deve adicionar uma regra **outbound** no NSG da subnet Data:

| Prioridade | Nome | Direcao | Acao | Porta | Origem | Destino |
|------------|------|---------|------|-------|--------|---------|
| 100 | DenyToAppSubnet | Outbound | Deny | * | 10.1.2.0/24 | 10.1.1.0/24 |
| 4096 | AllowInternetOut | Outbound | Allow | * | * | Internet |

Ou, alternativamente, adicionar essa regra no NSG da subnet App como regra de **inbound**:

| Prioridade | Nome | Direcao | Acao | Porta | Origem | Destino |
|------------|------|---------|------|-------|--------|---------|
| 100 | DenyFromDataSubnet | Inbound | Deny | * | 10.1.2.0/24 | 10.1.1.0/24 |

**[GOTCHA]** NSG e **stateful** — essa e uma informacao testada com frequencia no exame. Respostas de conexoes estabelecidas sao permitidas automaticamente. DenyAllInbound nao bloqueia respostas de trafego que a VM iniciou.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco4-nsg.md` — Regras NSG inbound e outbound

---

## Secao 3 — Armazenamento

### Q3.1 — Immutable Storage (WORM) para Prontuarios

**Resposta: D) Todas as opcoes acima impedem alteracao e delecao igualmente**

Todos os tres mecanismos de immutable storage impedem **alteracao** e **delecao** de blobs:

| Mecanismo | Alteracao | Delecao | Diferenca Principal |
|-----------|-----------|---------|---------------------|
| Time-based Locked | Bloqueada | Bloqueada ate o fim do periodo | Periodo de retencao nao pode ser reduzido |
| Time-based Unlocked | Bloqueada | Bloqueada ate o fim do periodo | Periodo pode ser ajustado ou policy removida |
| Legal Hold | Bloqueada | Bloqueada enquanto hold estiver ativo | Sem periodo definido, removido manualmente |

**Detalhes importantes:**

- **Locked vs Unlocked:** Uma time-based policy comeca como **Unlocked** (pode ser ajustada ou removida). Quando **Locked**, o periodo de retencao **nao pode ser reduzido** (pode ser estendido) e a policy **nao pode ser removida**. Para compliance real, a policy deve ser **Locked**.

- **Legal Hold:** Usado para preservacao de evidencias (investigacoes legais). Nao tem periodo definido — os blobs ficam imutaveis ate o hold ser removido manualmente. Pode coexistir com time-based policies.

- No cenario da questao, o medico nao consegue atualizar o blob porque **nenhuma** das opcoes permite alteracao. Para corrigir erros em prontuarios imutaveis, a pratica e **criar um novo blob** com a correcao (aditamento), mantendo o original intacto.

**[GOTCHA]** Immutable storage = WORM (Write Once, Read Many). Nenhuma das opcoes permite alterar ou deletar blobs existentes durante o periodo de retencao. A diferenca entre elas e como o **periodo** e gerenciado, nao se blobs podem ser alterados.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Immutable storage

---

### Q3.2 — Storage Firewall + Private Endpoint

**Resposta:**

**1. Por que a VM recebe 403:**

O firewall do storage account esta configurado para "Selected networks" com apenas a **HubVNet** adicionada. A VM esta na **Hosp1VNet**, que nao esta na lista de VNets permitidas pelo firewall.

Mesmo que o trafego chegue via Private Endpoint (que esta na HubVNet), o storage account avalia a **origem** do trafego. Se a origem nao esta na lista de redes permitidas, o acesso e negado.

**Importante:** Quando o firewall esta em "Selected networks", o acesso via Private Endpoint **so funciona** se o firewall for configurado corretamente:
- A VNet onde o Private Endpoint esta (HubVNet) ja esta adicionada ✓
- Mas trafego vindo de **outras VNets** (via peering e depois Private Endpoint) pode ser bloqueado se o firewall avaliar a origem como a VNet de origem, nao a VNet do PE

**2. O que Fernanda precisa alterar:**

Fernanda deve escolher uma das opcoes:

- **Opcao A (recomendada):** Mudar o firewall para **"Disabled"** (desabilitar o firewall publico) e confiar **exclusivamente** no Private Endpoint para seguranca. Quando o firewall publico esta desabilitado, todo acesso e feito via Private Endpoint, independente da VNet de origem.

- **Opcao B:** Adicionar todas as VNets dos hospitais na lista de "Selected networks" do firewall. Porem, isso requer Service Endpoints configurados em cada VNet, o que adiciona complexidade.

**3. "All networks" + Private Endpoint:**

**Sim**, o Private Endpoint continua funcionando mesmo com firewall em "All networks". A resolucao DNS via Private DNS Zone direciona o trafego para o IP privado do PE independentemente da configuracao de firewall.

**Impacto na seguranca:** O storage account ficaria acessivel pela internet (IP publico), alem do acesso privado via PE. Qualquer pessoa com as credenciais (SAS token, storage key) poderia acessar os dados pelo caminho publico. Isso **viola o requisito de compliance** da VidaSaude que exige acesso restrito aos prontuarios.

**[GOTCHA]** Private Endpoint e firewall do storage sao mecanismos **independentes**. O PE garante o caminho de rede privado, mas o firewall pode bloquear trafego mesmo via PE se a configuracao de "Selected networks" nao incluir a rede de origem. A configuracao mais segura e: firewall = Disabled + Private Endpoint = unico caminho de acesso.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Storage firewall e Private Endpoints

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Subtopico |
|---------|----------------|-----------|
| Q1.1 | D1 — Manage identities and governance | Policy Initiatives |
| Q1.2 | D1 — Manage identities and governance | Management Groups, RBAC scoping |
| Q1.3 | D1 — Manage identities and governance | Custom RBAC roles, management vs data plane |
| Q2.1 | D4 — Implement and manage virtual networking | Private Endpoints, DNS |
| Q2.2 | D4 — Implement and manage virtual networking | Hub-spoke, UDR, peering |
| Q2.3 | D4 — Implement and manage virtual networking | NSG stateful, subnet isolation |
| Q3.1 | D2 — Implement and manage storage | Immutable storage (WORM) |
| Q3.2 | D2 — Implement and manage storage | Storage firewall + Private Endpoint |

---

## Top Gotchas — Caso 3

| # | Gotcha | Questao |
|---|--------|---------|
| 1 | Policy Initiative = **gerenciamento unificado**, nao capacidades exclusivas | Q1.1 |
| 2 | Management Groups herdam policies para **subscriptions futuras** automaticamente | Q1.2 |
| 3 | Reader (management plane) **nunca** da acesso a dados (data plane) | Q1.3 |
| 4 | Private Endpoint sem **Private DNS Zone** = DNS resolve para IP publico | Q2.1 |
| 5 | Hub-spoke requer **UDRs** para forcar trafego pelo Firewall/NVA | Q2.2 |
| 6 | NSG e **stateful** — respostas de conexoes iniciadas sao permitidas automaticamente | Q2.3 |
| 7 | Immutable storage: **nenhuma** opcao permite alterar blobs existentes | Q3.1 |
| 8 | Storage firewall e Private Endpoint sao **independentes** — ambos devem estar configurados | Q3.2 |

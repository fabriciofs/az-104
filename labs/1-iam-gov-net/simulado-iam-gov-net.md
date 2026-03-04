# Simulado AZ-104 — IAM, Governanca e Networking

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `simulado-iam-gov-net-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta (salvo indicacao contraria)
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: DataFlow Analytics

A **DataFlow Analytics** e uma empresa de medio porte especializada em analytics e processamento de dados para o setor financeiro. Com sede em Sao Paulo, a empresa decidiu migrar sua infraestrutura on-premises para o Azure, escolhendo **Brazil South** como regiao primaria.

Carlos Moura, recem-contratado como **Azure Administrator**, recebeu a missao de montar toda a infraestrutura cloud da empresa do zero. Ele precisa configurar identidade, governanca, automacao, networking e conectividade — tudo em conformidade com as politicas de compliance do setor financeiro.

A DataFlow possui 120 funcionarios internos e trabalha regularmente com auditores externos que precisam de acesso limitado ao ambiente Azure para gerar relatorios de compliance. O dominio corporativo e **dataflow-analytics.com.br** e a infraestrutura interna usa o dominio **internal.dataflow.local** para resolucao DNS privada.

O orcamento e limitado, entao Carlos precisa justificar cada recurso provisionado e manter controle rigoroso sobre custos por departamento.

---

## Personas

| Persona                   | Funcao                | Acesso Necessario                             |
| ------------------------- | --------------------- | --------------------------------------------- |
| Carlos Moura (`df-admin`) | Azure Administrator   | Owner na subscription                         |
| Marina Silva              | Auditora externa (EY) | Somente leitura em RGs especificos            |
| Grupo **AzureOps**        | Time de operacoes     | Gerenciar VMs e redes                         |
| Grupo **DataOps**         | Time de dados         | Helpdesk — resetar senhas e atribuir licencas |

---

## Topologia de Rede Planejada

```
                    ┌──────────────────────────────────────────────────┐
                    │              AZURE — Brazil South                │
                    │                                                  │
                    │  ┌────────────────────────────────────────────┐  │
                    │  │         HubServicesVnet                    │  │
                    │  │         172.16.0.0/16                      │  │
                    │  │                                            │  │
                    │  │  ┌──────────────┐  ┌──────────────────┐    │  │
                    │  │  │  Compute     │  │  SharedSubnet    │    │  │
                    │  │  │ 172.16.0.0/24│  │ 172.16.10.0/24   │    │  │
                    │  │  └──────────────┘  └──────────────────┘    │  │
                    │  │                                            │  │
                    │  │  ┌──────────────┐  ┌──────────────────┐    │  │
                    │  │  │  DMZ         │  │  DataSubnet      │    │  │
                    │  │  │ 172.16.1.0/24│  │ 172.16.20.0/24   │    │  │
                    │  │  │  NVA:        │  └──────────────────┘    │  │
                    │  │  │  172.16.1.7  │                          │  │
                    │  │  └──────────────┘                          │  │
                    │  └───────────────────┬────────────────────────┘  │
                    │                      │                           │
                    │                  Peering                         │
                    │                      │                           │
                    │  ┌───────────────────┴────────────────────────┐  │
                    │  │         AnalyticsVnet                      │  │
                    │  │         172.17.0.0/16                      │  │
                    │  │                                            │  │
                    │  │  ┌──────────────┐  ┌──────────────────┐    │  │
                    │  │  │  Default     │  │  Processing      │    │  │
                    │  │  │ 172.17.0.0/24│  │ 172.17.1.0/24    │    │  │
                    │  │  └──────────────┘  └──────────────────┘    │  │
                    │  └────────────────────────────────────────────┘  │
                    │                                                  │
                    │  DNS Publico: dataflow-analytics.com.br          │
                    │  DNS Privado: internal.dataflow.local            │
                    └──────────────────────────────────────────────────┘
```

---

## Secao 1 — Identidade e Acesso (3 questoes)

### Q1.1 — Licenciamento de Usuario Externo (Multipla Escolha)

Carlos precisa convidar Marina Silva como **guest user** no Microsoft Entra ID para que ela possa acessar recursos da DataFlow. Apos criar o convite, Carlos tenta atribuir uma licenca Microsoft 365 a Marina, mas recebe um erro.

Qual propriedade do usuario **deve** ser configurada antes de atribuir uma licenca?

- **A)** Department
- **B)** Job Title
- **C)** Usage Location
- **D)** Company Name

---

### Q1.2 — Grupos e Licenciamento (Design)

Carlos precisa criar os grupos **AzureOps** e **DataOps** com os seguintes requisitos:

- **AzureOps:** Todos os usuarios cujo campo `Department` seja "Operations" devem ser adicionados automaticamente
- **DataOps:** Membros sao gerenciados manualmente pelo RH

Responda:

1. Que tipo de membership Carlos deve usar para cada grupo?
2. Qual nivel de licenciamento do Microsoft Entra ID e necessario para atender AMBOS os grupos? Justifique.
3. Se o orcamento nao permitir licenca Premium, qual alternativa Carlos teria para o AzureOps?

---

### Q1.3 — Permissoes de Guest User (Cenario)

Marina Silva (guest user / auditora externa) precisa listar todos os usuarios e grupos do Microsoft Entra ID da DataFlow para um relatorio de compliance. Ao acessar o portal, ela consegue ver apenas seu proprio perfil.

Carlos verifica e confirma que Marina tem role **Reader** no resource group `df-audit-rg`. Mesmo assim, ela nao consegue listar usuarios.

1. Por que o role Reader no resource group nao permite que Marina liste usuarios do diretorio?
2. Qual permissao ou role Carlos deveria conceder para resolver isso?
3. Qual risco de seguranca Carlos deve considerar antes de conceder esse acesso?

---

## Secao 2 — Governanca e Compliance (4 questoes)

### Q2.1 — RBAC e Escopo de Permissoes (Troubleshooting)

Carlos atribuiu o role **Virtual Machine Contributor** ao grupo **AzureOps** no escopo do Management Group. Um membro do AzureOps tenta fazer upload de um VHD para um Storage Account no resource group `df-infra-rg` e recebe **Access Denied**.

O que esta errado e como resolver?

---

### Q2.2 — Azure Policy com Modify (Multipla Escolha)

Carlos criou uma Azure Policy com efeito **Modify** para herdar automaticamente a tag `Department` do resource group para todos os recursos criados dentro dele. A policy foi atribuida ao resource group `df-data-rg`, que tem a tag `Department = Engineering`.

Carlos cria um Managed Disk dentro de `df-data-rg`, mas a tag **nao** e herdada automaticamente.

Qual e a causa **mais provavel** do problema?

- **A)** O efeito Modify nao suporta tags
- **B)** A policy assignment nao tem Managed Identity configurada
- **C)** Managed Disks nao suportam tags
- **D)** A policy precisa ser atribuida no nivel da subscription, nao do resource group

---

### Q2.3 — Resource Lock vs Owner (Cenario)

Carlos configurou um **Delete Lock** no resource group `df-prod-rg` para proteger recursos de producao. Um membro do time com role **Owner** no resource group tenta deletar uma VM de teste que nao e mais necessaria e recebe erro.

1. Por que o Owner nao consegue deletar a VM?
2. Qual sequencia de acoes o Owner precisa executar para deletar a VM?
3. Se Carlos quisesse permitir que o Owner modifique recursos mas impedir qualquer tipo de delecao, qual tipo de lock ele deveria ter usado? Esse tipo permite modificar propriedades da VM?

---

### Q2.4 — Audit vs Deny (Multipla Escolha)

Carlos precisa garantir que todos os recursos criados na subscription tenham a tag `Department`. Ele esta decidindo entre dois efeitos de policy:

- **Policy A:** Efeito `Deny` — impede criacao de recursos sem a tag
- **Policy B:** Efeito `Audit` — permite criacao mas marca como non-compliant

Carlos escolhe a **Policy B (Audit)** e a atribui na subscription. Um desenvolvedor cria uma VM sem a tag `Department`.

O que acontece?

- **A)** A VM e criada com sucesso e aparece como **compliant**
- **B)** A VM e criada com sucesso e aparece como **non-compliant**
- **C)** A VM e bloqueada e nao e criada
- **D)** A VM e criada e a tag `Department` e adicionada automaticamente com valor padrao

---

## Secao 3 — Infraestrutura como Codigo (3 questoes)

### Q3.1 — Escopo de Deployment ARM (Multipla Escolha)

Carlos precisa fazer um deployment ARM que realize as seguintes acoes:

1. Criar um novo resource group chamado `df-analytics-rg` em Brazil South
2. Dentro desse RG, provisionar um Storage Account

Ele escreve o template e executa:

```bash
az deployment group create \
  --resource-group df-analytics-rg \
  --template-file main.json
```

O comando falha porque o resource group ainda nao existe. Qual e a abordagem correta?

- **A)** Criar o RG manualmente primeiro, depois executar o deployment no escopo do RG
- **B)** Usar `az deployment sub create` com escopo de subscription e definir o RG como recurso no template
- **C)** Adicionar o parametro `--create-resource-group` ao comando
- **D)** Usar `az deployment mg create` no escopo do Management Group

---

### Q3.2 — ARM vs Bicep (Design)

Carlos precisa automatizar a criacao de toda a infraestrutura de rede da DataFlow (VNets, subnets, NSGs, peerings). Um colega sugere usar ARM Templates JSON, enquanto outro sugere Bicep.

1. Liste **tres** vantagens do Bicep sobre ARM Templates JSON
2. Se Carlos escrever um arquivo `.bicep`, o que acontece "por baixo dos panos" quando ele faz o deployment?
3. Em que cenario Carlos deveria preferir ARM JSON em vez de Bicep?

---

### Q3.3 — Policy vs IaC (Troubleshooting)

Carlos criou um template Bicep para provisionar VMs na regiao **West US** (para disaster recovery). Porem, existe uma Azure Policy com efeito **Deny** que restringe deployments apenas para **Brazil South**.

Carlos argumenta que templates IaC devem ter precedencia sobre policies porque sao revisados e aprovados pelo time.

1. O deployment vai funcionar? Por que?
2. Qual e a relacao hierarquica entre Azure Policy e metodos de deployment (Portal, CLI, ARM, Bicep, Terraform)?
3. Como Carlos pode resolver essa situacao legitimamente se realmente precisa de recursos em West US?

---

## Secao 4 — Redes Virtuais e DNS (5 questoes)

### Q4.1 — IPs Disponiveis em Subnet (Multipla Escolha)

Carlos criou a subnet **SharedSubnet** com endereco `172.16.10.0/24` dentro da HubServicesVnet. Ele precisa saber quantos IPs estao disponiveis para atribuir a recursos.

Quantos IPs **utilizaveis** essa subnet tem?

- **A)** 256
- **B)** 254
- **C)** 251
- **D)** 250

---

### Q4.2 — NSG e Escopo de Aplicacao (Design)

Carlos precisa proteger a **SharedSubnet** (172.16.10.0/24) onde ficam servicos compartilhados. Ele quer:

- Permitir trafego HTTP/HTTPS vindo da internet
- Bloquear todo trafego SSH exceto de um IP de gerenciamento (200.100.50.25)
- Permitir comunicacao interna entre VMs da mesma subnet

Responda:

1. Carlos pode associar um NSG diretamente a uma VNet inteira? Explique.
2. A quais niveis Carlos pode associar o NSG?
3. Se Carlos associar o NSG tanto a subnet quanto a NIC de uma VM, em que ordem as regras sao avaliadas para trafego **de entrada**?

---

### Q4.3 — DNS Privado e VNet Link (Troubleshooting)

Carlos configurou:

- Azure Private DNS Zone: `internal.dataflow.local`
- Registro A: `hubvm.internal.dataflow.local` → `172.16.0.4`
- VNet Link: `internal.dataflow.local` vinculada a **HubServicesVnet**
- Peering ativo entre **HubServicesVnet** e **AnalyticsVnet**

Uma VM na **AnalyticsVnet** tenta resolver `hubvm.internal.dataflow.local` via `nslookup` e recebe **"Non-existent domain"**.

1. Por que a resolucao DNS falha na AnalyticsVnet, mesmo com peering ativo?
2. O que Carlos precisa fazer para corrigir?
3. Qual configuracao adicional Carlos deve habilitar no VNet Link se quiser que VMs registrem automaticamente seus nomes DNS na zona privada?

---

### Q4.4 — Prioridade de Regras NSG (Multipla Escolha)

Carlos configurou o seguinte NSG na **DataSubnet** (172.16.20.0/24):

| Prioridade | Nome           | Direcao | Acao  | Porta | Origem        |
| ---------- | -------------- | ------- | ----- | ----- | ------------- |
| 100        | AllowHTTPS     | Inbound | Allow | 443   | *             |
| 150        | DenyAllInbound | Inbound | Deny  | *     | *             |
| 200        | AllowSSH       | Inbound | Allow | 22    | 200.100.50.25 |

Um administrador tenta conectar via SSH (porta 22) a partir do IP `200.100.50.25`. O que acontece?

- **A)** Conexao SSH permitida — regra AllowSSH (200) e processada
- **B)** Conexao SSH bloqueada — regra DenyAllInbound (150) e avaliada antes da AllowSSH (200)
- **C)** Conexao SSH permitida — regras Allow sempre tem precedencia sobre Deny
- **D)** Conexao SSH bloqueada — a porta 22 nao e permitida por padrao no Azure

---

### Q4.5 — DNS Publico vs Privado (Cenario)

Carlos precisa configurar DNS para dois cenarios:

**Cenario A:** O site publico `www.dataflow-analytics.com.br` precisa ser acessivel de qualquer lugar na internet, apontando para o IP publico `20.195.10.50` de um Application Gateway.

**Cenario B:** O servico interno `api.internal.dataflow.local` deve ser resolvido **apenas** por VMs dentro das VNets da DataFlow, apontando para o IP privado `172.16.10.20`.

1. Que tipo de DNS Zone Carlos deve usar para cada cenario?
2. No Cenario B, se Carlos registrar `api.internal.dataflow.local` em uma Azure Public DNS Zone, funcionaria para as VMs internas? Quais problemas isso causaria?
3. Qual a diferenca fundamental entre Azure Public DNS Zone e Azure Private DNS Zone em termos de resolucao?

---

## Secao 5 — Conectividade e Roteamento (3 questoes)

### Q5.1 — Peering NAO e Transitivo (Multipla Escolha)

Carlos configurou a seguinte topologia de VNet peering:

```
HubServicesVnet ◄──── peering ────► AnalyticsVnet
       │
    peering
       │
       ▼
MonitoringVnet (172.18.0.0/16)
```

- HubServicesVnet ↔ AnalyticsVnet: peering ativo
- HubServicesVnet ↔ MonitoringVnet: peering ativo
- AnalyticsVnet ↔ MonitoringVnet: **nenhum peering**

Uma VM na AnalyticsVnet (172.17.0.4) tenta pingar uma VM na MonitoringVnet (172.18.0.4). Qual e o resultado?

- **A)** Ping funciona — o trafego e roteado via HubServicesVnet automaticamente
- **B)** Ping falha — VNet peering NAO e transitivo; e necessario peering direto entre as duas VNets
- **C)** Ping funciona — desde que o "Allow Forwarded Traffic" esteja habilitado nos peerings existentes
- **D)** Ping falha — peering so funciona dentro da mesma regiao

---

### Q5.2 — UDR com Next Hop Incorreto (Troubleshooting)

Carlos configurou uma Route Table na **ComputeSubnet** (172.16.0.0/24) com a seguinte rota customizada:

| Nome         | Address Prefix | Next Hop Type     | Next Hop IP  |
| ------------ | -------------- | ----------------- | ------------ |
| to-analytics | 172.17.0.0/16  | Virtual Appliance | 172.16.1.100 |

O objetivo e rotear trafego da ComputeSubnet para a AnalyticsVnet passando por um NVA. Porem, o NVA real esta no IP `172.16.1.7` (na DMZ subnet). O IP `172.16.1.100` **nao existe** na rede.

1. O que acontece quando uma VM na ComputeSubnet tenta acessar `172.17.0.4` (AnalyticsVnet)?
2. O Azure vai usar as system routes como fallback nesse caso?
3. Como Carlos deve corrigir a situacao?

---

### Q5.3 — VNet Peering Cross-Resource-Group (Cenario)

A DataFlow tem dois resource groups:

- `df-hub-rg` — contem a **HubServicesVnet**
- `df-analytics-rg` — contem a **AnalyticsVnet**

Carlos (Owner em ambos os RGs) configurou o peering entre as VNets com sucesso. Agora, um membro do **AzureOps** (com role **Virtual Machine Contributor** apenas no `df-hub-rg`) precisa criar o peering entre a HubServicesVnet e uma nova VNet em outro resource group (`df-monitoring-rg`).

1. E possivel criar VNet peering entre VNets que estao em resource groups diferentes? Ha alguma restricao de regiao?
2. Por que o membro do AzureOps vai falhar ao tentar criar o peering? Que permissao esta faltando?
3. Se Carlos quiser que membros do AzureOps possam criar peerings de forma autonoma, qual seria a configuracao **minima** de RBAC necessaria?

---

### Q6.1 — Load Balancer Standard e NSG (Multipla Escolha)

Carlos implantou um **Standard Load Balancer** na DataFlow com duas VMs no backend pool. Os health probes mostram ambas as VMs como healthy, mas usuarios externos reportam que o servico web esta inacessivel pelo IP publico do Load Balancer.

Carlos verifica:
- As VMs estao running e o IIS esta respondendo localmente
- O backend pool esta configurado corretamente
- A regra de load balancing aponta para a porta 80

Qual a causa mais provavel?

A) O Standard Load Balancer requer VMs em Availability Zones, nao Availability Sets
B) Carlos esqueceu de configurar um NSG com regra permitindo trafego HTTP na subnet das VMs
C) Standard Load Balancer nao suporta HTTP, apenas HTTPS
D) As VMs precisam de IPs publicos individuais alem do IP publico do Load Balancer

---

### Q6.2 — Azure Bastion e Requisitos (Cenario)

Carlos precisa implantar **Azure Bastion** para acesso RDP seguro as VMs da HubServicesVnet. Ele cria uma subnet chamada `BastionSubnet` com tamanho /28.

1. O que vai acontecer quando Carlos tentar implantar o Bastion? Por que?
2. Quais sao os requisitos exatos de nome e tamanho da subnet para Azure Bastion?
3. Qual a vantagem de usar Bastion ao inves de abrir porta RDP (3389) via NSG?

---

### Q6.3 — Health Probe e Failover (Troubleshooting)

Carlos nota que o health probe do Load Balancer marca uma VM como **Unhealthy**, mas a VM aparece como **Running** no portal. O problema comecou apos uma atualizacao de software na VM.

1. Explique por que o health probe pode falhar mesmo com a VM running
2. Quais passos Carlos deve seguir para diagnosticar o problema?
3. O que acontece com o trafego destinado a VM unhealthy enquanto o problema nao e resolvido?

---

### Q7.1 — SSPR e Metodos de Autenticacao (Multipla Escolha)

Carlos habilitou SSPR para o grupo **AzureOps** com 2 metodos requeridos. Um membro do grupo, ao tentar resetar a senha, recebe a mensagem: "You cannot reset your password because you have not registered enough authentication methods."

Qual a causa?

A) O usuario nao e membro do grupo AzureOps
B) O usuario nao registrou pelo menos 2 metodos de autenticacao
C) SSPR so funciona com licenca Azure AD Premium P2
D) SSPR nao pode exigir mais de 1 metodo

---

### Q7.2 — Cost Management vs Azure Policy (Design)

A DataFlow atingiu o budget mensal de R$ 5.000 e a CTO quer garantir que isso nao aconteca novamente. Carlos considera duas opcoes:

1. Apenas configurar Budget alerts com action groups
2. Configurar Budget alerts + Azure Policy para restringir SKUs de VMs caras

Responda:
1. O Budget alert sozinho impede novos gastos? Por que?
2. Qual combinacao de controles Carlos deve implementar para prevenir gastos excessivos?
3. Como o Azure Advisor complementa essa estrategia?

---

## Pontuacao

| Secao             | Questoes | Pontos por Questao | Total   |
| ----------------- | -------- | ------------------ | ------- |
| 1 — Identidade    | 3        | 5                  | 15      |
| 2 — Governanca    | 4        | 5                  | 20      |
| 3 — IaC           | 3        | 5                  | 15      |
| 4 — Rede          | 5        | 6                  | 30      |
| 5 — Conectividade | 3        | 5                  | 15      |
| 6 — Load Balancer | 3        | 5                  | 15      |
| 7 — SSPR/Cost     | 2        | 5                  | 10      |
| **Total**         | **23**   | —                  | **120** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                     |
| ----- | ------------ | --------------------------------- |
| 85-95 | Excelente    | Pronto para avançar para Semana 2 |
| 70-84 | Bom          | Revisar questoes erradas nos labs |
| 50-69 | Regular      | Refazer blocos com dificuldade    |
| < 50  | Insuficiente | Refazer lab completo da Semana 1  |

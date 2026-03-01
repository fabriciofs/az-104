# Gabarito — Simulado AZ-104 IAM, Governanca e Networking

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `simulado-iam-gov-net.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Identidade e Acesso

### Q1.1 — Licenciamento de Usuario Externo

**Resposta: C) Usage Location**

A propriedade **Usage Location** e obrigatoria antes de atribuir qualquer licenca a um usuario no Microsoft Entra ID. Isso ocorre porque servicos Microsoft 365 nao estao disponiveis em todos os paises/regioes, e o Azure precisa saber onde o usuario esta localizado para determinar quais servicos podem ser oferecidos.

**Por que os outros estao errados:**
- **A) Department** — Campo informativo para organizacao. Nao e requisito para licenciamento.
- **B) Job Title** — Campo informativo. Nao tem relacao com licencas.
- **D) Company Name** — Campo informativo para guest users. Nao e requisito para licencas.

**[GOTCHA]** No exame, essa propriedade aparece frequentemente. Muitos candidatos assumem que basta criar o usuario e atribuir a licenca diretamente. A Usage Location e o unico campo que bloqueia a atribuicao se nao estiver preenchido.

**Referencia no lab:** Bloco 1 — Tarefa 1 (criar usuario e configurar propriedades)

---

### Q1.2 — Grupos e Licenciamento

**Resposta:**

**1. Tipo de membership:**
- **AzureOps:** Dynamic membership — membros sao adicionados automaticamente com base em regra de query (`user.department -eq "Operations"`)
- **DataOps:** Assigned membership — membros sao adicionados manualmente

**2. Licenciamento necessario: Microsoft Entra ID P1 (ou P2)**

Justificativa: Dynamic membership groups requerem licenca **Microsoft Entra ID P1** ou superior. Grupos assigned funcionam com qualquer tier (Free/P1/P2). Como o requisito do AzureOps exige dynamic membership, o tier minimo e **P1**.

**3. Alternativa sem Premium:**

Se o orcamento nao permitir P1, Carlos teria que:
- Criar o AzureOps como grupo **Assigned** (manual)
- Manter uma rotina manual ou usar um script (PowerShell/Azure CLI) agendado que consulte usuarios com `Department = Operations` e atualize os membros do grupo periodicamente
- Isso perde a automacao nativa, mas funciona sem custo adicional

**[GOTCHA]** O exame testa se voce sabe que Dynamic Groups = P1 obrigatorio. Assigned groups nao requerem Premium. Nao confundir com Azure RBAC (que e gratuito).

**Referencia no lab:** Bloco 1 — Tarefa 3 (criar grupos com dynamic e assigned membership)

---

### Q1.3 — Permissoes de Guest User

**Resposta:**

**1. Por que Reader no RG nao funciona para listar usuarios:**

O role **Reader** no escopo de resource group concede permissao para ler **recursos Azure** (VMs, Storage, etc.) dentro daquele RG. Usuarios e grupos do Microsoft Entra ID **nao sao recursos Azure** — eles pertencem ao **diretorio (tenant)**. Roles RBAC no escopo de subscription/RG nao controlam acesso ao diretorio.

**2. Permissao necessaria:**

Carlos deve atribuir a Marina um **directory role** no Microsoft Entra ID. O role minimo e **Directory Readers**, que permite listar usuarios, grupos e outros objetos do diretorio. Alternativamente, Carlos pode ajustar as configuracoes de guest user no tenant para permitir que guests leiam propriedades do diretorio (External Collaboration Settings).

**3. Risco de seguranca:**

Ao conceder **Directory Readers**, Marina tera visibilidade sobre **todos** os usuarios e grupos do tenant, incluindo:
- Estrutura organizacional da empresa
- Enderecos de email de todos os funcionarios
- Membros de grupos privilegiados (Global Admins, etc.)

Isso pode ser um risco para empresas que trabalham com auditores de diferentes clientes. Carlos deve avaliar se o principio de **least privilege** esta sendo respeitado. Uma alternativa mais restrita seria usar **Administrative Units** para limitar o escopo de visibilidade.

**[GOTCHA]** Guest users tem permissoes de diretorio **extremamente limitadas** por padrao. Eles nao conseguem listar outros usuarios nem grupos. Isso e diferente de Member users, que podem ler o diretorio por padrao. Nao confundir RBAC (recursos Azure) com Directory Roles (objetos do Entra ID).

**Referencia no lab:** Bloco 1 — Tarefa 2 (convidar guest user e testar permissoes)

---

## Secao 2 — Governanca e Compliance

### Q2.1 — RBAC e Escopo de Permissoes

**Resposta:**

O problema e que **Virtual Machine Contributor** so concede permissoes para gerenciar VMs — ele **nao** inclui permissoes sobre Storage Accounts. Fazer upload de VHD requer permissoes de **Storage** (como `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write`).

**O RBAC no Azure e aditivo:** cada role concede apenas as permissoes que ele explicita. Virtual Machine Contributor nao concede nada relacionado a Storage. Roles nao herdam permissoes de outros roles.

**Como resolver:**
- Atribuir um role adicional ao grupo AzureOps, como **Storage Blob Data Contributor**, no escopo do storage account ou do resource group `df-infra-rg`
- Ou criar um **custom role** que combine permissoes de VM e Storage (mais complexo, so recomendado se for padrao recorrente)

**[GOTCHA]** Roles RBAC sao estritamente aditivos — eles so concedem o que explicitam. "Contributor" generico (no escopo do RG) resolveria, mas viola o principio de least privilege. No exame, preste atencao ao nome exato do role: **Virtual Machine** Contributor ≠ Contributor.

**Referencia no lab:** Bloco 2 — Tarefa 1 (atribuir RBAC ao grupo e testar permissoes)

---

### Q2.2 — Azure Policy com Modify

**Resposta: B) A policy assignment nao tem Managed Identity configurada**

O efeito **Modify** precisa de uma **Managed Identity** associada a policy assignment para poder alterar recursos. Sem a Managed Identity, a policy nao tem credenciais para executar a modificacao (adicionar/alterar tags). A policy e criada mas a remediacao nao e executada.

**Por que os outros estao errados:**
- **A) Modify nao suporta tags** — Incorreto. Modify foi projetado exatamente para cenarios de tag inheritance. E um dos usos mais comuns.
- **C) Managed Disks nao suportam tags** — Incorreto. Praticamente todos os recursos Azure suportam tags, incluindo Managed Disks.
- **D) Precisa ser na subscription** — Incorreto. Policy pode ser atribuida em qualquer escopo (Management Group, Subscription, Resource Group). Atribuir no RG e perfeitamente valido.

**Detalhe adicional:** Mesmo com a Managed Identity configurada, o efeito Modify funciona de duas formas:
- **Novos recursos:** A tag e aplicada automaticamente na criacao
- **Recursos existentes:** E necessario criar uma **remediation task** para aplicar a tag retroativamente

**[GOTCHA]** No exame, se a questao menciona Modify + tag nao herdada, verifique se ha Managed Identity na assignment. E o "gotcha" mais comum desse topico. Alem disso, a Managed Identity precisa ter **permissoes suficientes** (ex: Contributor no escopo) para modificar os recursos.

**Referencia no lab:** Bloco 2 — Tarefa 3 (policy Modify para heranca de tags)

---

### Q2.3 — Resource Lock vs Owner

**Resposta:**

**1. Por que o Owner nao consegue deletar:**

Resource Locks **sobrescrevem** permissoes RBAC, incluindo Owner. Um Delete Lock impede a exclusao do recurso independentemente do role do usuario. Mesmo um **Owner** ou **Contributor** no nivel da subscription nao pode deletar um recurso protegido por lock sem antes remover o lock.

**2. Sequencia de acoes:**
1. Navegar ate o resource group `df-prod-rg` > Settings > Locks
2. **Remover** o Delete Lock (ou apenas o lock daquela VM, se aplicado individualmente)
3. **Deletar** a VM
4. **Recriar** o Delete Lock no resource group (se a protecao ainda for desejada para os demais recursos)

**3. Tipo de lock para permitir modificacao mas impedir delecao:**

O lock **Delete** (CanNotDelete) e exatamente o que Carlos ja tem, e ele **sim** permite modificar propriedades da VM (alterar tamanho, adicionar discos, mudar NSG, etc.). O Delete Lock so impede a operacao de **exclusao**.

Se Carlos tivesse usado **ReadOnly** lock, ninguem poderia modificar NEM deletar nenhum recurso — o que seria restritivo demais para o cenario.

**[GOTCHA]** Locks vencem RBAC. Ate um Global Administrator precisa remover o lock antes de deletar. Isso e intencional — locks existem para proteger contra erros acidentais de **qualquer** usuario, independentemente do nivel de acesso.

**Referencia no lab:** Bloco 2 — Tarefa 5 (configurar Delete Lock e testar comportamento)

---

### Q2.4 — Audit vs Deny

**Resposta: B) A VM e criada com sucesso e aparece como non-compliant**

O efeito **Audit** nao bloqueia nenhuma operacao. Ele apenas **registra** que o recurso nao esta em conformidade com a policy. A VM sera criada normalmente, mas no painel de Azure Policy Compliance, ela aparecera como **non-compliant**.

**Por que os outros estao errados:**
- **A) Compliant** — Incorreto. A VM nao tem a tag exigida, entao e non-compliant por definicao.
- **C) Bloqueada** — Incorreto. Esse seria o comportamento do efeito **Deny**, nao Audit.
- **D) Tag adicionada automaticamente** — Incorreto. Esse seria o comportamento do efeito **Modify** (ou **Append** para alguns cenarios). Audit nao modifica recursos.

**Resumo dos efeitos relevantes:**

| Efeito | Bloqueia? | Modifica? | Registra? |
|--------|-----------|-----------|-----------|
| Deny | Sim | Nao | Sim |
| Audit | Nao | Nao | Sim |
| Modify | Nao | Sim | Sim |
| Append | Nao | Sim (add) | Sim |
| AuditIfNotExists | Nao | Nao | Sim |

**[GOTCHA]** No exame, preste atencao a diferenca entre Audit e Deny. Audit e "passivo" — so observa e reporta. Deny e "ativo" — bloqueia a operacao. Se a questao diz "impedir", a resposta e Deny. Se diz "monitorar" ou "detectar", a resposta e Audit.

**Referencia no lab:** Bloco 2 — Tarefa 2 (testar policy Deny vs criar recurso que viola a regra)

---

## Secao 3 — Infraestrutura como Codigo

### Q3.1 — Escopo de Deployment ARM

**Resposta: B) Usar `az deployment sub create` com escopo de subscription e definir o RG como recurso no template**

Para criar um resource group via ARM/Bicep, o deployment precisa ser executado no escopo de **subscription**, nao de resource group. Isso porque o resource group e um recurso que existe no nivel da subscription.

```bash
az deployment sub create \
  --location brazilsouth \
  --template-file main.json
```

No template, o resource group e definido como recurso do tipo `Microsoft.Resources/resourceGroups`, e os demais recursos ficam dentro de um **nested deployment** ou **module** com escopo no RG recem-criado.

**Por que os outros estao errados:**
- **A) Criar RG manualmente** — Funciona na pratica, mas **nao e a abordagem correta para IaC**. O objetivo de IaC e automatizar tudo, incluindo a criacao do RG. A questao pede a abordagem correta.
- **C) `--create-resource-group`** — Esse parametro nao existe na CLI do Azure para `az deployment group create`.
- **D) Management Group scope** — Possivel tecnicamente, mas excessivo e desnecessario. O escopo de subscription e suficiente e mais simples.

**[GOTCHA]** No exame, questoes sobre "criar resource group via template" sempre esperam a resposta "subscription-level deployment". E um padrao que aparece com frequencia. Lembre: `az deployment group` = recursos dentro de um RG existente; `az deployment sub` = recursos no nivel da subscription (incluindo RGs).

**Referencia no lab:** Bloco 3 — Tarefas ARM e Bicep (escopo de deployment)

---

### Q3.2 — ARM vs Bicep

**Resposta:**

**1. Tres vantagens do Bicep sobre ARM JSON:**

1. **Sintaxe mais simples e concisa** — Bicep elimina a verbosidade do JSON (chaves, virgulas, aspas). Um template Bicep tipicamente tem ~50% menos linhas que o equivalente ARM JSON.
2. **Intellisense e validacao nativa** — Com a extensao Bicep do VS Code, ha autocomplete, validacao de tipos e deteccao de erros em tempo real. ARM JSON requer extensoes separadas e a experiencia e inferior.
3. **Modularidade nativa** — Bicep suporta `module` nativamente, facilitando a reutilizacao de codigo. ARM JSON requer nested deployments ou linked templates (mais complexos e propensos a erro).

Outras vantagens validas: gerenciamento automatico de dependencias (Bicep infere `dependsOn`), melhor deteccao de erros em tempo de compilacao, sem necessidade de `concat()` ou `format()` para strings.

**2. O que acontece no deployment:**

Quando Carlos executa `az deployment group create --template-file main.bicep`, o Azure CLI:
1. Invoca o **Bicep compiler** localmente
2. O compiler **transpila** o arquivo `.bicep` para um **ARM Template JSON** equivalente
3. O JSON resultante e enviado ao **Azure Resource Manager** para processamento
4. O ARM processa o template normalmente, sem saber que a origem era Bicep

Ou seja, Bicep e uma **camada de abstracao** sobre ARM JSON. O Azure Resource Manager so entende JSON.

**3. Quando preferir ARM JSON:**

- **Templates gerados automaticamente** — Se a ferramenta/pipeline ja gera ARM JSON (ex: export do portal, ferramentas de terceiros)
- **Environments sem Bicep CLI** — Se o ambiente de deployment nao tem Bicep instalado e nao permite instalar (cenarios corporativos restritos)
- **Templates muito antigos e complexos** — Migrar um template ARM JSON grande e funcional para Bicep pode introduzir riscos sem beneficio real
- **Cenarios que exigem API version pinning rigoroso** — ARM JSON oferece controle mais explicito sobre cada API version (embora Bicep tambem suporte)

**Referencia no lab:** Bloco 3 — Comparacao ARM vs Bicep ao criar VNets

---

### Q3.3 — Policy vs IaC

**Resposta:**

**1. O deployment vai funcionar?**

**Nao.** O deployment sera **bloqueado** pela Azure Policy. Nao importa qual metodo de deployment Carlos use — Portal, CLI, PowerShell, ARM, Bicep ou Terraform — a Azure Policy com efeito **Deny** e avaliada pelo Azure Resource Manager **antes** de qualquer recurso ser criado.

**2. Relacao hierarquica:**

Azure Policy esta acima de todos os metodos de deployment. A hierarquia e:

```
Azure Policy (avaliada pelo ARM)
    │
    ▼ bloqueia se Deny
    │
ARM Resource Manager
    │
    ├── Portal (manual)
    ├── CLI / PowerShell
    ├── ARM Templates JSON
    ├── Bicep (compilado para ARM)
    └── Terraform (usa ARM API)
```

**Todos** os metodos passam pelo Azure Resource Manager, e **todas** as policies sao avaliadas nesse ponto. IaC nao tem nenhum privilegio especial ou bypass sobre policies.

**3. Como resolver legitimamente:**

- **Opcao A:** Modificar a Azure Policy para incluir **West US** na lista de locais permitidos (se o compliance permitir)
- **Opcao B:** Criar uma **exclusao (exemption)** na policy para o resource group especifico de DR, documentando a justificativa
- **Opcao C:** Criar uma policy com escopo mais restrito (ex: aplicar Allowed Locations apenas em RGs de producao, nao nos de DR)
- **Opcao D:** Solicitar ao time de governanca uma revisao da policy para incluir regioes de DR como excecao aprovada

**[GOTCHA]** No exame, e muito comum testarem se o candidato acha que Bicep/Terraform "bypassa" policies. A resposta e sempre **nao**. Azure Policy e enforced no nivel do ARM, e nenhum cliente de deployment esta acima do ARM.

**Referencia no lab:** Bloco 3 — Validacao de Governanca (deploy em regiao bloqueada)

---

## Secao 4 — Redes Virtuais e DNS

### Q4.1 — IPs Disponiveis em Subnet

**Resposta: C) 251**

Uma subnet `/24` tem 256 enderecos IP totais (2^8 = 256). Porem, o Azure **reserva 5 enderecos** em cada subnet:

| IP Reservado | Finalidade |
|-------------|------------|
| 172.16.10.**0** | Endereco de rede |
| 172.16.10.**1** | Gateway padrao do Azure |
| 172.16.10.**2** | DNS do Azure (mapeamento) |
| 172.16.10.**3** | DNS do Azure (mapeamento) |
| 172.16.10.**255** | Broadcast |

Total utilizavel: 256 - 5 = **251**

**Por que os outros estao errados:**
- **A) 256** — Total bruto sem descontar nada. Incorreto em qualquer cenario de rede.
- **B) 254** — Seria o calculo tradicional de redes (desconta rede + broadcast), mas ignora os 3 IPs extras que o Azure reserva.
- **D) 250** — Nao corresponde a nenhum calculo padrao.

**[GOTCHA]** No exame, esse e um dos gotchas mais testados. A diferenca entre redes tradicionais (reserva 2: rede + broadcast) e Azure (reserva 5) e um favorito dos examinadores. Memorize: **Azure reserva 5 IPs por subnet**.

**Referencia no lab:** Bloco 4 — Criacao de subnets e calculo de enderecos

---

### Q4.2 — NSG e Escopo de Aplicacao

**Resposta:**

**1. NSG em VNet inteira:**

**Nao.** Um NSG **nao pode** ser associado diretamente a uma VNet. O NSG e um recurso que filtra trafego em nivel de **subnet** ou **NIC (Network Interface Card)**. Se Carlos quiser proteger toda a VNet, ele precisa associar NSGs a cada subnet individualmente.

**2. Niveis de associacao:**
- **Subnet** — Todas as VMs na subnet sao afetadas pelas regras do NSG
- **NIC (Network Interface Card)** — Apenas a VM especifica e afetada

Carlos pode associar NSGs em ambos os niveis simultaneamente. Cada subnet pode ter no maximo 1 NSG, e cada NIC pode ter no maximo 1 NSG.

**3. Ordem de avaliacao para trafego de ENTRADA:**

```
Internet/Origem
      │
      ▼
┌──────────────┐
│ NSG da Subnet │  ◄── Avaliado PRIMEIRO
└──────┬───────┘
       │ (se Allow)
       ▼
┌──────────────┐
│ NSG da NIC    │  ◄── Avaliado SEGUNDO
└──────┬───────┘
       │ (se Allow)
       ▼
     VM
```

Para trafego de **saida**, a ordem e invertida: NIC primeiro, depois Subnet.

O trafego precisa ser **permitido em ambos** os NSGs para passar. Se qualquer um dos dois bloquear, o trafego e descartado.

**Referencia no lab:** Bloco 4 — Configuracao de NSG e ASG na SharedServicesSubnet

---

### Q4.3 — DNS Privado e VNet Link

**Resposta:**

**1. Por que a resolucao falha:**

VNet peering **nao propaga resolucao DNS**. O fato de HubServicesVnet e AnalyticsVnet estarem conectados via peering significa apenas que o trafego de rede IP pode fluir entre elas. Porem, a zona DNS privada `internal.dataflow.local` so esta **vinculada** (VNet Link) a HubServicesVnet. VMs na AnalyticsVnet nao consultam essa zona porque nao ha VNet Link para ela.

**2. Como corrigir:**

Carlos precisa criar um **segundo VNet Link** na zona DNS privada `internal.dataflow.local`, desta vez vinculando a **AnalyticsVnet**. Assim, VMs na AnalyticsVnet passarao a resolver nomes registrados nessa zona.

```
internal.dataflow.local (Private DNS Zone)
    ├── VNet Link → HubServicesVnet    ✓ (existente)
    └── VNet Link → AnalyticsVnet      ✓ (novo, necessario)
```

**3. Auto-registration:**

Carlos deve habilitar a opcao **Auto Registration** no VNet Link. Com essa configuracao:
- VMs criadas na VNet vinculada registram automaticamente seus nomes (hostname) como registros A na zona DNS privada
- Quando uma VM e deletada, o registro A e removido automaticamente
- Isso elimina a necessidade de criar registros DNS manualmente

**Restricao importante:** Cada VNet pode ter auto-registration habilitado em **no maximo 1 zona DNS privada**. Mas uma zona DNS privada pode ter auto-registration de **ate 1000 VNets**.

**[GOTCHA]** "Peering ativo = DNS funciona" e uma suposicao errada muito comum. Peering = conectividade IP. DNS privado = VNet Links. Sao mecanismos **independentes**. Esse gotcha aparece frequentemente no exame.

**Referencia no lab:** Bloco 4 — Configuracao de DNS privado e VNet Link

---

### Q4.4 — Prioridade de Regras NSG

**Resposta: B) Conexao SSH bloqueada — regra DenyAllInbound (150) e avaliada antes da AllowSSH (200)**

NSG avalia regras por **prioridade numerica**, da **menor para a maior** (menor numero = maior prioridade). O processamento para na **primeira regra que corresponde** ao trafego:

1. **Regra 100 (AllowHTTPS):** Porta 443 — nao corresponde a porta 22 → continua
2. **Regra 150 (DenyAllInbound):** Porta * (todas), Origem * → **corresponde!** → Acao: **Deny** → processamento PARA aqui
3. **Regra 200 (AllowSSH):** Nunca e avaliada porque a regra 150 ja tratou o trafego

**Por que os outros estao errados:**
- **A) Conexao permitida** — A regra AllowSSH (200) nunca e alcancada porque DenyAllInbound (150) tem prioridade mais alta.
- **C) Allow tem precedencia** — Incorreto. NSG nao funciona por tipo de acao (Allow/Deny). Funciona estritamente por **prioridade numerica**.
- **D) Porta 22 nao permitida por padrao** — Embora o Azure nao permita SSH por padrao (a regra implicita DenyAllInbound na prioridade 65500 bloquearia), a questao e sobre a **ordem das regras customizadas**, nao sobre defaults.

**Como Carlos deveria configurar corretamente:**

| Prioridade | Nome | Acao | Porta | Origem |
|------------|------|------|-------|--------|
| 100 | AllowHTTPS | Allow | 443 | * |
| 150 | AllowSSH | Allow | 22 | 200.100.50.25 |
| 200 | DenyAllInbound | Deny | * | * |

A regra mais restritiva (Deny all) deve ter a **maior prioridade numerica** (menor prioridade logica) para ser o "catch-all" final.

**[GOTCHA]** Menor numero = MAIOR prioridade. Isso confunde muita gente. Regra 150 e avaliada ANTES da regra 200. Se houver um Deny com numero menor que um Allow, o trafego e bloqueado e o Allow nunca e avaliado.

**Referencia no lab:** Bloco 4 — Configuracao de regras NSG com prioridades

---

### Q4.5 — DNS Publico vs Privado

**Resposta:**

**1. Tipo de DNS Zone:**
- **Cenario A (www publico):** Azure **Public DNS Zone** — registros acessiveis globalmente via internet
- **Cenario B (api interna):** Azure **Private DNS Zone** — registros acessiveis apenas por VNets vinculadas

**2. Se usasse Public DNS Zone para o Cenario B:**

Tecnicamente, **funcionaria parcialmente** — VMs internas conseguiriam resolver o nome se tivessem acesso a internet para consultar DNS publico. Porem, causaria varios problemas:

- **Exposicao de informacao:** O registro `api.internal.dataflow.local` com IP `172.16.10.20` seria **visivel publicamente** via DNS query. Qualquer pessoa na internet poderia descobrir a estrutura interna da rede da DataFlow.
- **Resolucao inutilizavel externamente:** O IP `172.16.10.20` e privado (RFC 1918). Mesmo sabendo o IP, ninguem fora das VNets conseguiria acessar o servico. Mas a informacao de topologia ficaria exposta.
- **Dependencia de internet:** VMs internas precisariam de acesso a internet para resolver o DNS, mesmo para comunicacao interna. Se a conexao com internet cair, a resolucao interna tambem falha.

**3. Diferenca fundamental:**

| Aspecto | Public DNS Zone | Private DNS Zone |
|---------|-----------------|------------------|
| **Resolucao** | Qualquer lugar na internet | Apenas VNets com VNet Link |
| **Visibilidade** | Publica | Restrita |
| **Name servers** | Azure public NS | Azure private resolver (168.63.129.16) |
| **Registro** | Dominio publico (ex: .com, .com.br) | Qualquer nome (ex: .local, .internal) |
| **Auto-registration** | Nao | Sim (com VNet Link) |

**Referencia no lab:** Bloco 4 — DNS publico (contoso.com) e DNS privado (private.contoso.com)

---

## Secao 5 — Conectividade e Roteamento

### Q5.1 — Peering NAO e Transitivo

**Resposta: B) Ping falha — VNet peering NAO e transitivo; e necessario peering direto entre as duas VNets**

VNet peering conecta **exclusivamente** as duas VNets envolvidas no peering. O trafego NAO flui transitivamente por uma terceira VNet. No cenario:

```
AnalyticsVnet ←→ HubServicesVnet ←→ MonitoringVnet
     ✓ peering direto ✓       ✓ peering direto ✓

AnalyticsVnet ←···→ MonitoringVnet
         ✗ SEM peering direto ✗
```

Mesmo que ambas as VNets estejam conectadas ao Hub, elas **nao** conseguem se comunicar entre si atraves do Hub.

**Por que os outros estao errados:**
- **A) Roteado via Hub** — VNet peering NAO e transitivo. O Hub nao roteia trafego automaticamente entre VNets pareadas.
- **C) Allow Forwarded Traffic** — Essa configuracao permite que trafego **originado de fora da VNet** (ex: via VPN Gateway ou NVA) seja encaminhado pelo peering. Mas ela NAO torna o peering transitivo por si so. Para funcionar, seria necessario um NVA no Hub com UDRs configurados (topologia hub-spoke com NVA), nao apenas a flag.
- **D) Mesma regiao** — Incorreto. VNet peering funciona entre regioes diferentes (**Global VNet Peering**), nao ha restricao de regiao.

**Para resolver (se Carlos precisar de comunicacao AnalyticsVnet ↔ MonitoringVnet):**
- **Opcao A:** Criar peering direto entre AnalyticsVnet e MonitoringVnet
- **Opcao B:** Implantar um **NVA (Network Virtual Appliance)** ou **Azure Firewall** no Hub e configurar UDRs para forcar trafego pelo Hub (topologia hub-spoke verdadeira)
- **Opcao C:** Usar **Azure Virtual WAN** que suporta roteamento transitivo nativamente

**[GOTCHA]** "Peering nao e transitivo" e provavelmente o gotcha MAIS testado em AZ-104 sobre networking. Se A↔B e B↔C, isso NAO significa que A↔C. E a primeira coisa a verificar quando duas VNets nao se comunicam.

**Referencia no lab:** Bloco 5 — Configuracao de peering entre CoreServicesVnet e ManufacturingVnet

---

### Q5.2 — UDR com Next Hop Incorreto

**Resposta:**

**1. O que acontece:**

O trafego e **descartado silenciosamente (dropped)**. Quando a VM na ComputeSubnet envia um pacote para `172.17.0.4`, a route table direciona o trafego para o next hop `172.16.1.100`. Como esse IP **nao existe** (nao ha NIC atribuida a ele), o pacote nao tem para onde ir e e descartado. Nao ha mensagem de erro ICMP retornada — o pacote simplesmente desaparece.

**2. Fallback para system routes:**

**Nao.** Quando uma UDR (User-Defined Route) define uma rota para um prefixo de destino, ela **sobrescreve** a system route para aquele mesmo prefixo. O Azure NAO faz fallback para a rota do sistema se o next hop da UDR falhar. A UDR tem precedencia absoluta.

Hierarquia de rotas no Azure:
```
1. UDR (User-Defined Route)    ← maior precedencia
2. BGP routes
3. System routes               ← menor precedencia
```

Se a UDR aponta para um destino invalido, o trafego e descartado. O Azure nao "tenta a proxima rota".

**3. Como corrigir:**

Carlos deve atualizar a rota na Route Table para usar o IP correto do NVA:

| Nome | Address Prefix | Next Hop Type | Next Hop IP |
|------|---------------|---------------|-------------|
| to-analytics | 172.17.0.0/16 | Virtual Appliance | **172.16.1.7** |

Alem disso, Carlos deve verificar:
- O NVA (172.16.1.7) tem **IP Forwarding habilitado** na NIC do Azure
- O sistema operacional do NVA tambem tem IP forwarding habilitado (ex: `sysctl net.ipv4.ip_forward=1` no Linux)
- O NSG da DMZ subnet permite o trafego necessario

**[GOTCHA]** UDR com next hop invalido = drop silencioso, sem fallback. Diferente de redes tradicionais onde protocolos de roteamento podem convergir para rotas alternativas, o Azure com UDR e estatico e determinístico. Se o next hop nao responde, o pacote e descartado.

**Referencia no lab:** Bloco 5 — Configuracao de Route Table, NVA e custom routes

---

### Q5.3 — VNet Peering Cross-Resource-Group

**Resposta:**

**1. Peering entre RGs diferentes:**

**Sim**, e perfeitamente possivel criar VNet peering entre VNets em resource groups diferentes. Nao ha nenhuma restricao. Inclusive, VNet peering funciona:
- Entre RGs diferentes na mesma subscription ✓
- Entre subscriptions diferentes ✓ (cross-subscription peering)
- Entre regioes diferentes ✓ (Global VNet Peering)
- Entre tenants diferentes ✓ (com autorizacao adequada)

A unica restricao e que os **address spaces das VNets nao podem se sobrepor**.

**2. Por que o AzureOps vai falhar:**

Para criar um VNet peering, o usuario precisa de permissao de **leitura na VNet remota** (a VNet do outro lado do peering). O membro do AzureOps tem **Virtual Machine Contributor** apenas no `df-hub-rg`. Ele nao tem nenhuma permissao no `df-monitoring-rg`.

Criar peering requer a acao `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write` em **ambas** as VNets. O usuario precisa de permissao nos **dois lados** do peering. Especificamente:

- **VNet de origem:** `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write` — para criar o peering local
- **VNet de destino:** `Microsoft.Network/virtualNetworks/peer/action` — para autorizar o peering remoto

Alem disso, **Virtual Machine Contributor** nao inclui permissoes de rede (`Microsoft.Network/*`), entao o usuario tambem falharia mesmo se ambas as VNets estivessem no mesmo RG.

**3. Configuracao minima de RBAC:**

Carlos deve atribuir ao grupo AzureOps:

- **Network Contributor** nos resource groups que contem as VNets que eles precisam parear
  - `df-hub-rg` (HubServicesVnet)
  - `df-monitoring-rg` (nova VNet)

Ou, para granularidade ainda maior, criar um **custom role** com apenas:
- `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write`
- `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read`
- `Microsoft.Network/virtualNetworks/peer/action`
- `Microsoft.Network/virtualNetworks/read`

Atribuir nos RGs necessarios.

**Referencia no lab:** Bloco 5 — Peering entre CoreServicesVnet e ManufacturingVnet

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Peso Estimado no Exame |
|---------|----------------|----------------------|
| Q1.1 | Manage Microsoft Entra users and groups | ~15-20% |
| Q1.2 | Manage Microsoft Entra users and groups | ~15-20% |
| Q1.3 | Manage Microsoft Entra users and groups | ~15-20% |
| Q2.1 | Manage access control (RBAC) | ~15-20% |
| Q2.2 | Manage Azure Policy | ~15-20% |
| Q2.3 | Manage subscriptions and governance | ~15-20% |
| Q2.4 | Manage Azure Policy | ~15-20% |
| Q3.1 | Deploy resources by using ARM templates and Bicep | ~5-10% |
| Q3.2 | Deploy resources by using ARM templates and Bicep | ~5-10% |
| Q3.3 | Manage Azure Policy + IaC | ~5-10% |
| Q4.1 | Configure virtual networks | ~20-25% |
| Q4.2 | Configure NSGs | ~20-25% |
| Q4.3 | Configure Azure DNS | ~20-25% |
| Q4.4 | Configure NSGs | ~20-25% |
| Q4.5 | Configure Azure DNS | ~20-25% |
| Q5.1 | Configure VNet connectivity (peering) | ~20-25% |
| Q5.2 | Configure routing | ~20-25% |
| Q5.3 | Configure VNet connectivity (peering) | ~20-25% |

> **Nota:** Os dominios de rede (VNets, NSG, DNS, Peering, Routing) representam o maior peso no exame AZ-104 (~20-25%), seguidos por Identidade e Governanca (~15-20%). IaC tem peso menor (~5-10%) mas aparece frequentemente combinado com outros dominios.

---

## Top 10 Gotchas — Consolidado

| # | Gotcha | Questao | Por que Pega |
|---|--------|---------|-------------|
| 1 | Azure reserva **5 IPs** por subnet, nao 2 | Q4.1 | Candidatos usam calculo de rede tradicional |
| 2 | VNet peering **NAO e transitivo** | Q5.1 | Assume que A↔B + B↔C = A↔C |
| 3 | **Usage Location** obrigatoria para licenca | Q1.1 | Parece propriedade insignificante |
| 4 | NSG: menor numero = **maior prioridade** | Q4.4 | Confusao entre numero e prioridade logica |
| 5 | Policy **Modify** requer **Managed Identity** | Q2.2 | Esquece que a policy precisa de credenciais |
| 6 | Resource Lock **sobrescreve** Owner/RBAC | Q2.3 | Assume que Owner pode tudo |
| 7 | DNS privado requer **VNet Link**, nao peering | Q4.3 | Assume que peering propaga DNS |
| 8 | IaC **NAO bypassa** Azure Policy | Q3.3 | Assume que Bicep/Terraform tem privilegios |
| 9 | UDR com next hop invalido = **drop silencioso** | Q5.2 | Espera fallback para system routes |
| 10 | RBAC e **aditivo** — VM Contributor ≠ acesso a Storage | Q2.1 | Confunde nomes de roles com escopo real |

---

## Proximos Passos

Apos corrigir o caso de estudo:

1. **Erros em Identidade?** → Refazer Bloco 1 do lab focando em propriedades de usuario e tipos de grupo
2. **Erros em Governanca?** → Refazer Bloco 2 focando em RBAC aditivo, efeitos de policy e locks
3. **Erros em IaC?** → Refazer Bloco 3 focando em escopos de deployment
4. **Erros em Rede?** → Refazer Bloco 4 focando em calculo de IPs, NSG e DNS
5. **Erros em Conectividade?** → Refazer Bloco 5 focando em peering e UDR
6. **Score > 85?** → Avançar para a Semana 2

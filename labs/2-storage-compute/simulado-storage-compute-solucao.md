# Gabarito — Simulado AZ-104 Storage e Compute

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `simulado-storage-compute.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Armazenamento

### Q1.1 — Redundancia de Storage

**Resposta: B) ZRS (Zone-Redundant Storage)**

Zone-Redundant Storage replica dados de forma sincrona em **3 availability zones** dentro da mesma regiao. Cada zona e um datacenter fisicamente separado com energia, refrigeracao e rede independentes. Isso garante que, se um datacenter inteiro falhar, os dados continuam acessiveis nas outras duas zonas.

**Por que os outros estao errados:**
- **A) LRS (Locally-Redundant Storage)** — Replica dados 3 vezes dentro de um **unico datacenter**. Se o datacenter inteiro falhar, os dados ficam indisponiveis. Nao protege contra falha de zona.
- **C) GRS (Geo-Redundant Storage)** — Replica dados para uma **regiao secundaria** a centenas de quilometros. Protege contra falha regional, mas o cenario pede protecao contra falha de datacenter na mesma regiao, nao entre regioes. Alem disso, GRS e mais caro e tem latencia maior na replicacao.
- **D) RA-GRS (Read-Access Geo-Redundant Storage)** — Igual ao GRS mas com leitura na regiao secundaria. Mesmo problema: protecao regional nao era o requisito.

**[GOTCHA]** ZRS protege contra falha de datacenter (zona), GRS protege contra falha de regiao. No exame, leia com atencao se o cenario pede resiliencia **dentro da regiao** (ZRS) ou **entre regioes** (GRS/RA-GRS). Valores de SLA: LRS = 11 noves, ZRS = 12 noves, GRS = 16 noves.

**Referencia no lab:** Bloco 1 — Task 1.1

---

### Q1.2 — SAS Token

**Resposta:**

**1. Tipo de SAS recomendado:**

**Service SAS** no container especifico. Service SAS limita o escopo a um unico servico (Blob, File, Queue ou Table) e pode ser restrito a um container ou blob individual. Isso segue o principio de least privilege — o parceiro so acessa exatamente o que precisa.

**2. Permissoes necessarias:**

**Write** + **Create** permissions no blob container. Write permite sobrescrever blobs existentes, e Create permite criar novos blobs. Nao incluir Read, Delete ou List a menos que sejam explicitamente necessarios.

**3. Diferenca para Account SAS:**

Account SAS da acesso a **TODOS os servicos** (Blob, File, Queue, Table) do storage account inteiro. Se o parceiro receber um Account SAS, ele teria acesso a dados que nao deveria ver — file shares, queues, tables, e todos os containers de blob. E uma violacao do principio de least privilege.

**[GOTCHA]** SAS com permissoes excessivas e risco de seguranca. Sempre usar principio de least privilege. No exame, se a questao menciona "acesso a um container especifico", a resposta e Service SAS (nao Account SAS). Alem disso, SAS tokens nao podem ser revogados individualmente — para invalidar, voce precisa rotacionar a storage account key ou usar uma Stored Access Policy.

**Referencia no lab:** Bloco 1 — Task 1.4

---

### Q1.3 — Lifecycle Management

**Resposta: A) Hot→Cool apos 30 dias, Cool→Archive apos 90 dias, Delete apos 365 dias**

Essa configuracao reflete o padrao de acesso tipico: dados sao acessados frequentemente nos primeiros 30 dias (Hot), esporadicamente entre 30-90 dias (Cool), e raramente apos 90 dias (Archive). A delecao aos 365 dias respeita o periodo de retencao.

**Por que os outros estao errados:**
- **B)** Deleta cedo demais — nao respeita o requisito de retencao de dados. Se a politica exige manter dados por 1 ano, deletar antes viola compliance.
- **C)** Pula o tier Cool — mover direto de Hot para Archive significa que dados que ainda sao acessados esporadicamente (30-90 dias) teriam latencia de horas para reidratacao. Cool tier tem acesso imediato com custo menor que Hot.
- **D)** Comeca em Cool — incorreto porque dados novos sao acessados frequentemente. Comecar em Cool gera custo de acesso maior (Cool cobra por leitura) e early deletion fee se o blob ficar menos de 30 dias no tier.

**[GOTCHA]** Lifecycle management so funciona em **StorageV2 (general-purpose v2)** e **BlobStorage** accounts. StorageV1 nao suporta. Alem disso, Archive tier tem latencia de **horas** para reidratacao (Standard: ate 15h, High Priority: ate 1h). No exame, se o cenario pede "acesso imediato", Archive NAO e opcao.

**Referencia no lab:** Bloco 1 — Task 1.5

---

### Q1.4 — Private Endpoint vs Service Endpoint

**Resposta: B) Private Endpoint cria uma NIC com IP privado na VNet**

Private Endpoint cria um **network interface (NIC)** com um endereco IP privado dentro da sua VNet. O trafego para o storage account flui inteiramente pela rede privada, sem nunca sair para a internet publica. O storage account passa a ser acessivel por um IP privado (ex: 10.0.1.5) em vez do IP publico.

**Por que os outros estao errados:**
- **A) Service Endpoint** — Service Endpoint **NAO** cria um IP privado. Ele apenas otimiza a rota de trafego: em vez de ir pela internet publica, o trafego vai pelo backbone da rede Microsoft (Azure backbone). Porem, o storage account **mantem seu IP publico** — o trafego apenas toma um caminho mais direto.
- **C) Ambos sao iguais** — Completamente diferente. Service Endpoint = rota otimizada com IP publico. Private Endpoint = IP privado na VNet com acesso totalmente privado.
- **D) Nenhum dos dois funciona para Storage** — Incorreto. Storage Account e um dos servicos que mais suporta ambas as opcoes.

**[GOTCHA]** Service Endpoint mantem o IP publico do servico (rota otimizada pelo backbone Microsoft). Private Endpoint cria IP privado (acesso totalmente privado). No exame, se a questao diz "o recurso nao deve ter IP publico acessivel" ou "trafego nao deve sair da rede virtual", a resposta e **Private Endpoint**. Se diz "otimizar roteamento", pode ser Service Endpoint.

**Referencia no lab:** Bloco 1 — Tasks 1.6 e 1.7

---

### Q1.5 — Azure Files com Autenticacao Identity-Based

**Resposta:**

**1. Pre-requisitos para montar Azure File Share via SMB com autenticacao de identidade:**

- A VM deve estar **joined ao mesmo Microsoft Entra ID ou AD DS** (Active Directory Domain Services) que o Storage Account esta configurado para usar
- O Storage Account deve ter **identity-based authentication** habilitado (Entra ID DS, AD DS on-premises, ou Entra ID Kerberos para identidades hibridas)
- A VM e o file share devem estar na mesma rede ou ter conectividade de rede adequada

**2. Protocolo e porta utilizados:**

**SMB (Server Message Block)**, porta **445**. Azure Files suporta SMB 2.1 e SMB 3.0+. Para montagem pela internet, SMB 3.0+ com encriptacao e obrigatorio.

**3. RBAC roles necessarios:**

- **Storage File Data SMB Share Reader** — para acesso somente leitura
- **Storage File Data SMB Share Contributor** — para leitura e escrita
- **Storage File Data SMB Share Elevated Contributor** — para leitura, escrita e modificacao de ACLs NTFS

**[GOTCHA]** Porta 445 e frequentemente **bloqueada por ISPs** e firewalls corporativos. Se o mount falhar de fora do Azure, a primeira coisa a verificar e se a porta 445 esta aberta. Dentro do Azure (VM para Storage na mesma regiao), normalmente funciona sem problemas. Alternativa: usar Azure File Sync ou VPN.

**Referencia no lab:** Bloco 1 — Task 1.3

---

### Q1.6 — Soft Delete vs Blob Versioning

**Resposta: B) Soft delete protege apenas contra delecao. Para proteger contra sobrescrita, precisa de Blob Versioning.**

Soft delete funciona como uma **lixeira**: quando um blob e deletado, ele nao e removido imediatamente — fica em estado "soft deleted" por um periodo configuravel (1-365 dias). Porem, quando um blob e **sobrescrito** (upload de novo conteudo para o mesmo nome), a versao anterior e **perdida** se blob versioning nao estiver habilitado.

Blob Versioning mantem automaticamente **todas as versoes anteriores** de um blob. Cada vez que um blob e modificado ou sobrescrito, a versao anterior e preservada como uma versao imutavel. Voce pode listar, acessar e restaurar qualquer versao anterior.

**Por que os outros estao errados:**
- **A) Soft delete protege contra ambos** — Incorreto. Soft delete so cria um snapshot na delecao, nao na sobrescrita.
- **C) Versioning substitui soft delete** — Incorreto. Sao complementares. Versioning protege contra sobrescrita, soft delete protege contra delecao. Idealmente, ambos devem estar habilitados.
- **D) Nenhum dos dois protege contra sobrescrita** — Incorreto. Blob Versioning protege sim.

**[GOTCHA]** Soft delete e versioning sao **complementares**, nao substitutos. Soft delete = protetor de delecao. Versioning = protetor de sobrescrita. No exame, se o cenario menciona "usuario sobrescreveu acidentalmente", a resposta envolve **Versioning**. Se menciona "usuario deletou acidentalmente", a resposta envolve **Soft Delete**.

**Referencia no lab:** Bloco 1 — Task 1.2

---

## Secao 2 — Virtual Machines

### Q2.1 — Availability e SLA

**Resposta: C) Availability Zones — 99.99% SLA**

Availability Zones distribui VMs em **datacenters fisicamente separados** dentro da mesma regiao, cada um com energia, refrigeracao e rede independentes. Isso oferece o maior SLA para VMs no Azure.

**Por que os outros estao errados:**
- **A) Single VM com Premium SSD** — SLA de **99.9%**. E o SLA mais baixo dos tres, valido apenas quando TODOS os discos sao Premium SSD ou Ultra Disk. Sem Premium SSD, nao ha SLA garantido.
- **B) Availability Set** — SLA de **99.95%**. Distribui VMs entre Fault Domains (racks diferentes) e Update Domains (para manutencao planejada) dentro de um **unico datacenter**. Nao protege contra falha do datacenter inteiro.
- **D) Single VM sem SSD** — Nao tem SLA garantido pela Microsoft.

**[GOTCHA]** SLA valores exatos sao cobrados no exame. Memorizar: **AZ = 99.99%**, **AS = 99.95%**, **Single VM Premium SSD = 99.9%**. Availability Zones > Availability Sets > Single VM. Alem disso, Availability Sets usam Fault Domains (max 3) e Update Domains (max 20, padrao 5).

**Referencia no lab:** Bloco 2 — Task 2.3

---

### Q2.2 — VM Resize Falha

**Resposta:**

**Causa do problema:**

O hardware cluster onde a VM esta hospedada **nao tem capacidade** para o novo tamanho (size) solicitado. Cada cluster Azure tem um conjunto especifico de hardware, e nem todos os tamanhos de VM estao disponiveis em todos os clusters. Se o tamanho desejado nao esta no cluster atual, o resize falha.

**Solucoes (em ordem de preferencia):**

1. **Deallocate a VM e tentar novamente** — Ao fazer deallocate, o Azure libera os recursos no cluster atual. Quando voce iniciar o resize, o Azure pode realocar a VM em um cluster diferente que suporte o novo tamanho.
2. **Mover para outro cluster** — Se o deallocate + resize ainda falhar, pode ser necessario deletar a VM (mantendo os discos) e recria-la com o novo tamanho. Os discos sao preservados.
3. **Escolher um tamanho compativel com o cluster atual** — Usar `az vm list-vm-resize-options` para ver quais tamanhos estao disponiveis no cluster onde a VM esta atualmente.

**[GOTCHA]** **Deallocate** (via Portal/CLI) e diferente de **Stop** (dentro do OS). Deallocate = libera recursos do cluster e **para a cobranca** de compute. Stop (shutdown dentro do OS) = VM continua **alocada no cluster**, continua sendo cobrada, e NAO libera recursos. Alem disso, deallocate faz perder o **IP publico dinamico** (se houver) — use IP estatico se precisar manter o IP.

**Referencia no lab:** Bloco 2 — Task 2.4

---

### Q2.3 — VM Extensions

**Resposta:**

**1. Qual extensao usar para executar script de configuracao no provisionamento:**

**Custom Script Extension (CSE)**. Essa extensao permite executar scripts (PowerShell no Windows, Bash no Linux) durante ou apos o provisionamento da VM. E ideal para automatizar configuracao inicial: instalar software, configurar servicos, baixar arquivos, etc.

**2. Diferenca entre Custom Script Extension e Run Command:**

- **Custom Script Extension** — Executada **durante/apos o provisionamento** como parte da configuracao da VM. E declarativa e registrada como recurso da VM. Ideal para setup inicial automatizado.
- **Run Command** — Executada de forma **ad-hoc (manual)**, sob demanda. Nao faz parte do provisionamento. Ideal para troubleshooting, diagnostico ou tarefas pontuais em VMs ja existentes.

**3. Para VMSS (Virtual Machine Scale Sets):**

Configurar o Custom Script Extension no **model** do VMSS. Quando o CSE faz parte do model, **todas as novas instancias** criadas pelo autoscale recebem automaticamente o script de configuracao. Instancias existentes podem ser atualizadas com `az vmss update-instances` para aplicar o model mais recente.

**[GOTCHA]** Custom Script Extension executa apenas **UMA VEZ** por VM. Se voce precisar re-executar o script (com conteudo diferente), precisa **remover a extensao e reinstalar**. Simplesmente atualizar o script nao re-executa. No exame, se a questao pede "executar script toda vez que a VM iniciar", a resposta NAO e CSE — seria um startup script no OS ou cloud-init.

**Referencia no lab:** Bloco 2 — Task 2.6

---

### Q2.4 — VMSS Autoscale

**Resposta:**

**1. VMSS escalou de 2 para 6 instancias em 10 minutos — e esperado?**

**Sim**, e comportamento correto se as regras de autoscale foram atingidas. Se a metrica (ex: CPU > 70%) se manteve acima do threshold durante o periodo de avaliacao, o autoscale dispara scale-out. Dependendo da configuracao (increment by X instances), multiplas acoes de scale-out podem ocorrer em sequencia rapida.

**2. O que acontece com cool-down period muito curto?**

Cool-down period muito curto causa **"flapping"** — o autoscale escala e desescala repetidamente em ciclos rapidos. O cenario tipico:
1. CPU alta → scale-out (adiciona instancias)
2. Novas instancias reduzem a CPU → scale-in (remove instancias)
3. Menos instancias → CPU alta novamente → scale-out
4. Ciclo se repete indefinidamente

Isso gera **custos desnecessarios** (instancias sendo criadas e destruidas constantemente), **instabilidade** no servico (requests sendo redistribuidas frequentemente), e **logs poluidos** que dificultam troubleshooting.

**[GOTCHA]** Sempre configure cool-down period adequado (padrao recomendado: **5 minutos**). O scale-in deve ter cool-down **maior** que o scale-out, porque remover instancias e mais arriscado que adicionar. Valores tipicos: scale-out cool-down = 5 min, scale-in cool-down = 10 min. No exame, se o cenario descreve "instancias subindo e descendo rapidamente", a causa e cool-down insuficiente.

**Referencia no lab:** Bloco 2 — Task 2.7

---

## Secao 3 — Web Apps (App Service)

### Q3.1 — App Service Tiers e Deployment Slots

**Resposta: C) Standard (S1)**

Deployment slots comecam a partir do tier **Standard (S1)**. Os tiers Free, Shared e Basic **nao suportam** deployment slots.

**Por que os outros estao errados:**
- **A) Free (F1)** — Tier para desenvolvimento/teste. Nao suporta slots, custom domains com SSL, autoscale, nem backups.
- **B) Basic (B1)** — Suporta custom domains e SSL, mas **nao** suporta deployment slots nem autoscale.
- **D) Premium (P1)** — Suporta slots (ate 20), mas nao e o tier **minimo**. Standard ja oferece slots (ate 5).

**Resumo de features por tier:**

| Feature | Free | Shared | Basic | Standard | Premium |
|---------|------|--------|-------|----------|---------|
| Deployment Slots | - | - | - | 5 | 20 |
| Autoscale | - | - | - | Sim | Sim |
| Custom Domain | - | Sim | Sim | Sim | Sim |
| SSL | - | - | Sim | Sim | Sim |
| Backups | - | - | - | Sim | Sim |

**[GOTCHA]** Standard = slots + autoscale + custom domains SSL. Basic = custom domains mas sem slots. Free/Shared = desenvolvimento apenas. No exame, se a questao pede "tier minimo para deployment slots", a resposta e **Standard**. Se pede "tier minimo para custom domain", a resposta e **Shared** (domain only) ou **Basic** (domain + SSL).

**Referencia no lab:** Bloco 3 — Task 3.1

---

### Q3.2 — Slot Swap e Rollback

**Resposta:**

**1. Como fazer rollback apos um slot swap mal-sucedido:**

Fazer **outro swap** — trocar production e staging de volta. Slot swap e uma operacao **simetrica e reversivel**. Se voce fez swap de staging→production e a nova versao tem problemas, basta fazer swap novamente (production→staging) para restaurar o estado anterior. O codigo que estava em production volta para production.

**2. Comportamento das App Settings durante swap:**

- App settings marcadas como **"Deployment slot setting"** — **NAO sao trocadas**. Ficam fixas no slot onde foram configuradas.
- App settings **normais** (sem a marcacao) — **SIM, sao trocadas** junto com o codigo. Elas "viajam" com o deployment.

**3. Outros itens que NAO sao trocados (ficam fixos no slot):**

- Connection strings marcadas como **slot-specific**
- Custom domain **bindings** (o dominio fica vinculado ao slot, nao ao codigo)
- **Scale settings** (numero de instancias, autoscale rules)
- **Publishing endpoints** e credenciais de publicacao
- WebJobs schedulers

**[GOTCHA]** Por padrao, **TODAS** as settings sao trocadas durante swap. Para manter uma setting fixa no slot, voce precisa explicitamente marcar como **"Deployment slot setting"**. No exame, se o cenario diz "connection string de producao aponta para banco de dev apos swap", a causa e que a connection string nao foi marcada como slot-specific.

**Referencia no lab:** Bloco 3 — Tasks 3.3 e 3.4

---

### Q3.3 — App Service Autoscale

**Resposta: C) HTTP Queue Length > 0**

HTTP Queue Length indica que **requests estao sendo enfileiradas** porque o App Service nao consegue processa-las rapido o suficiente. Quando o queue length cresce, significa que a demanda excedeu a capacidade de processamento — esse e o sinal mais direto de que mais instancias sao necessarias.

**Por que os outros estao errados:**
- **A) CPU Percentage > 70%** — Metrica valida mas **generica**. CPU alta pode ser causada por processamento batch, background jobs, ou ineficiencia no codigo — nao necessariamente por demanda de requests HTTP. Pode gerar scale-out desnecessario.
- **B) Memory Percentage > 80%** — Metrica valida mas **generica**. Memoria alta pode ser causada por memory leaks, caching, ou dados em memoria — nao necessariamente correlacionada com demanda de usuarios.
- **D) Disk Queue Length** — Metrica de I/O de disco, mais relevante para VMs com workloads de I/O intensivo. Menos relevante para App Services web-based.

**[GOTCHA]** HTTP Queue Length e uma metrica **especifica do App Service** que mede diretamente a pressao de requests. E diferente de metricas genericas de infraestrutura (CPU, memoria). No exame, quando o cenario e sobre "web app com muitos usuarios simultaneos", priorize metricas HTTP sobre metricas de infra. Alem disso, combine multiplas metricas: scale-out em HTTP Queue Length > 0 OU CPU > 80%.

**Referencia no lab:** Bloco 3 — Task 3.5

---

### Q3.4 — Slot-Specific Settings

**Resposta:**

Marcar as connection strings como **"Deployment slot setting"** na configuracao do App Service. Para fazer isso:

1. Navegar ate o App Service > **Configuration** > **Connection strings**
2. Para cada connection string que deve permanecer fixa no slot, marcar o checkbox **"Deployment slot setting"**
3. Repetir para cada slot (production e staging devem ter suas proprias connection strings apontando para seus respectivos bancos de dados)

Quando uma connection string e marcada como slot-specific:
- No slot de **production**: connection string aponta para o banco de producao
- No slot de **staging**: connection string aponta para o banco de staging/teste
- Apos o **swap**: o codigo se move entre os slots, mas as connection strings **permanecem** em seus respectivos slots

Isso garante que o codigo em staging sempre testa contra o banco de staging, e o codigo em production sempre acessa o banco de producao — independentemente de quantos swaps sejam feitos.

**[GOTCHA]** Settings marcadas como slot-specific ficam **"grudadas" no slot**, nao viajam com o codigo durante swap. Esse conceito e invertido ao que muitos candidatos esperam. No exame, se a questao descreve "apos swap, a app em producao comecou a acessar o banco de teste", a solucao e marcar as connection strings como deployment slot settings.

**Referencia no lab:** Bloco 3 — Task 3.6

---

## Secao 4 — Containers

### Q4.1 — Escolha do Servico de Container

**Resposta:**

**1. ACI (Azure Container Instances) — Jobs batch e tasks efemeras:**

ACI e ideal para workloads de **curta duracao**: processamento batch, tarefas agendadas, build agents, scripts de automacao. Nao requer gerenciamento de infraestrutura. Voce define a imagem, CPU/memoria, executa, e paga apenas pelo tempo de execucao. Sem orquestracao, sem cluster, sem complexidade.

**2. Container Apps — APIs com autoscale e traffic splitting:**

Azure Container Apps e ideal para **APIs e microservicos** que precisam de autoscale baseado em demanda (HTTP requests, KEDA scalers), traffic splitting entre revisoes (canary deployments), e integracoes como Dapr para service-to-service communication. Oferece features de orquestracao sem a complexidade do Kubernetes.

**3. AKS (Azure Kubernetes Service) — Microservicos complexos com orquestracao avancada:**

AKS e ideal quando voce precisa de **controle total** sobre a orquestracao: custom networking (CNI), service mesh (Istio/Linkerd), node pools com diferentes SKUs, GPU workloads, stateful applications com persistent volumes, e configuracoes avancadas de scheduling (affinity, taints, tolerations).

**[GOTCHA]** ACI = serverless simples (sem orquestracao). Container Apps = serverless com features de orquestracao (Dapr, KEDA, revisions). AKS = Kubernetes completo (complexidade maxima, controle maximo). No exame, a chave e identificar a **complexidade do cenario**: se e simples/efemero → ACI; se precisa de autoscale/revisions → Container Apps; se precisa de controle total → AKS.

**Referencia no lab:** Blocos 4 e 5

---

### Q4.2 — Resource Limits do ACI

**Resposta: B) 4 cores por container group**

Azure Container Instances tem limites de recursos por container group. O maximo padrao e **4 vCPUs** e **16 GB RAM** por container group. Um container group pode ter multiplos containers, mas os recursos sao compartilhados entre eles.

**Por que os outros estao errados:**
- **A) 2 cores** — Limite inferior ao real. 2 cores e o limite para algumas regioes especificas ou para containers Windows em certas configuracoes, mas o limite padrao para Linux e 4.
- **C) 8 cores** — Acima do limite padrao. Nao disponivel para ACI padrao (sem GPU).
- **D) 16 cores** — Muito acima do limite. Esse tipo de capacidade requer AKS com node pools de VMs maiores.

**[GOTCHA]** Limites de ACI variam por **regiao** e **OS**. Windows containers tem limites menores que Linux containers. Alem disso, container groups com **GPU** tem limites e SKUs diferentes. No exame, se o cenario pede "mais de 4 cores por container", ACI **nao** e a solucao — use Container Apps ou AKS.

**Referencia no lab:** Bloco 4 — Task 4.2

---

### Q4.3 — Traffic Splitting em Container Apps

**Resposta:**

**1. Criar uma nova revision:**

Fazer deploy de uma nova versao da aplicacao, o que cria uma nova **revision** (ex: v2). A revision anterior (v1) continua existindo e servindo trafego.

**2. Configurar traffic splitting:**

Em **Revision management**, configurar a distribuicao de trafego:
- **80%** para revision v1 (versao estavel)
- **20%** para revision v2 (versao nova em teste)

Isso permite testar a nova versao com uma parcela menor de usuarios antes de migrar todo o trafego.

**3. Validar e migrar gradualmente:**

Monitorar metricas de erro, latencia e performance na v2. Se tudo estiver saudavel, aumentar gradualmente: 50/50, depois 80/20 (invertido), e finalmente 100% para v2. Se houver problemas, reverter todo o trafego para v1 instantaneamente.

**[GOTCHA]** Traffic splitting requer **revision mode "Multiple"**. Se o Container App estiver configurado como **"Single"**, todas as requests vao automaticamente para a revision mais recente — nao ha como dividir trafego. No exame, se o cenario descreve "todo trafego foi para a nova versao automaticamente", a causa e que o revision mode esta em Single, nao Multiple.

**Referencia no lab:** Bloco 5 — Task 5.5

---

### Q4.4 — Volume Mount Falha no ACI

**Resposta:**

A causa mais provavel e **1) Storage Account access key incorreta**. O Azure Container Instances precisa da access key correta para autenticar e montar o Azure File Share. Se a key esta errada, expirada ou foi rotacionada, o mount falha com erro "volume mount failed".

As tres opcoes possiveis (key incorreta, nome do file share errado, file share inexistente) sao todas causas validas, mas **key incorreta e o erro mais comum** na pratica, especialmente apos rotacao de chaves do storage account.

**Checklist de troubleshooting para volume mount no ACI:**

1. **Storage Account name** — Verificar se esta correto (case-sensitive)
2. **Access key** — Verificar se e a key ativa atual (key1 ou key2). Apos rotacao, atualizar o ACI
3. **File share name** — Verificar se o nome esta correto e se o file share existe
4. **Rede** — Se o storage account tem firewall habilitado, verificar se o ACI tem acesso (VNet integration ou IP permitido)
5. **Protocolo** — ACI monta Azure Files via SMB. Verificar se porta 445 esta acessivel

**[GOTCHA]** ACI mount de Azure Files requer: **nome do storage account** + **access key** + **nome do file share** exato. Qualquer erro em qualquer um desses tres campos resulta em "volume mount failed". No exame, a resposta mais segura para "volume mount failed" e verificar as credenciais (access key) primeiro, pois e o item mais frequentemente incorreto, especialmente apos rotacao de chaves.

**Referencia no lab:** Bloco 4 — Task 4.3

---

## Resumo de Performance

| Secao | Questoes | Acertos | Observacoes |
|-------|----------|---------|-------------|
| 1 — Armazenamento | Q1.1 a Q1.6 | __/6 | Redundancia, SAS, lifecycle, endpoints, Files, versioning |
| 2 — Virtual Machines | Q2.1 a Q2.4 | __/4 | Availability, resize, extensions, autoscale |
| 3 — Web Apps | Q3.1 a Q3.4 | __/4 | Tiers, slots, autoscale, slot settings |
| 4 — Containers | Q4.1 a Q4.4 | __/4 | ACI vs Apps vs AKS, limits, traffic, volumes |
| **Total** | **18 questoes** | **__/18** | **Meta: >= 80% (15/18)** |

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Peso Estimado no Exame |
|---------|----------------|----------------------|
| Q1.1 | Implement and manage storage | ~15-20% |
| Q1.2 | Configure access to storage | ~15-20% |
| Q1.3 | Configure Azure Files and Azure Blob Storage | ~15-20% |
| Q1.4 | Configure access to storage (networking) | ~15-20% |
| Q1.5 | Configure Azure Files and Azure Blob Storage | ~15-20% |
| Q1.6 | Configure Azure Files and Azure Blob Storage | ~15-20% |
| Q2.1 | Deploy and manage Azure compute resources | ~20-25% |
| Q2.2 | Deploy and manage Azure compute resources | ~20-25% |
| Q2.3 | Deploy and manage Azure compute resources | ~20-25% |
| Q2.4 | Deploy and manage Azure compute resources | ~20-25% |
| Q3.1 | Create and configure Azure App Service | ~20-25% |
| Q3.2 | Create and configure Azure App Service | ~20-25% |
| Q3.3 | Create and configure Azure App Service | ~20-25% |
| Q3.4 | Create and configure Azure App Service | ~20-25% |
| Q4.1 | Create and configure containers | ~20-25% |
| Q4.2 | Create and configure containers | ~20-25% |
| Q4.3 | Create and configure containers | ~20-25% |
| Q4.4 | Create and configure containers | ~20-25% |

> **Nota:** Os dominios de Compute (VMs, App Service, Containers) representam o maior peso no exame AZ-104 (~20-25%), seguidos por Storage (~15-20%). Questoes frequentemente combinam conceitos de storage com compute (ex: montar Azure Files em VM, persistent storage em containers).

---

## Top 10 Gotchas — Consolidado

| # | Gotcha | Questao | Por que Pega |
|---|--------|---------|-------------|
| 1 | **ZRS** protege contra falha de zona, **GRS** contra falha de regiao | Q1.1 | Confundem ZRS com GRS |
| 2 | **Service SAS** para container especifico, **Account SAS** para tudo | Q1.2 | Nao conhecem os tipos de SAS |
| 3 | Lifecycle management so funciona em **StorageV2** | Q1.3 | Tentam usar em StorageV1 |
| 4 | **Private Endpoint** = IP privado, **Service Endpoint** = rota otimizada com IP publico | Q1.4 | Confundem os dois mecanismos |
| 5 | SLA: **AZ=99.99%**, **AS=99.95%**, **Single Premium=99.9%** | Q2.1 | Nao memorizam valores exatos |
| 6 | **Deallocate** libera recursos e para cobranca; **Stop** (OS) nao libera | Q2.2 | Confundem stop com deallocate |
| 7 | Custom Script Extension executa **UMA VEZ** por VM | Q2.3 | Esperam re-execucao automatica |
| 8 | Deployment slots comecam no tier **Standard** (nao Basic) | Q3.1 | Confundem Basic com Standard |
| 9 | Settings **sem** marcacao de slot-specific **sao trocadas** no swap | Q3.2 | Assumem que settings ficam fixas por padrao |
| 10 | Traffic splitting requer revision mode **Multiple** | Q4.3 | Usam mode Single e perdem controle |

---

## Proximos Passos

Apos corrigir o simulado:

1. **Erros em Armazenamento?** → Refazer Bloco 1 do lab focando em redundancia, SAS tokens e lifecycle
2. **Erros em VMs?** → Refazer Bloco 2 focando em availability, resize e extensions
3. **Erros em Web Apps?** → Refazer Bloco 3 focando em tiers, slots e autoscale
4. **Erros em Containers?** → Refazer Blocos 4 e 5 focando em ACI vs Container Apps vs AKS
5. **Score >= 80%?** → Avancar para o proximo modulo
6. **Score < 80%?** → Revisar os gotchas e refazer as questoes erradas antes de avancar

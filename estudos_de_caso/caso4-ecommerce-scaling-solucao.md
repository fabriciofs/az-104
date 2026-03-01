# Gabarito — Estudo de Caso 4: MegaStore Brasil

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `caso4-ecommerce-scaling.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Computacao

### Q1.1 — VMSS Autoscale Rules

**Resposta:**

**1. Importancia do cooldown (5 minutos):**

O cooldown e um periodo de espera **obrigatorio** entre acoes de scale. Sem ele:

- **Flapping (oscilacao):** O VMSS poderia escalar para fora, a carga caiu momentaneamente, escala para dentro, a carga sobe novamente, e assim por diante — criando um ciclo infinito de scale out/in
- **Instabilidade:** Instancias recem-adicionadas podem nao ter tempo de absorver a carga antes de uma nova avaliacao
- **Custo:** Scale out desnecessario gera cobranc extra por instancias que ficam ativas por menos tempo que o necessario

O cooldown garante que o VMSS espere ate que as novas instancias estejam absorvendo carga antes de reavaliar.

**2. Assimetria scale out vs scale in:**

- **Scale out agressivo (adiciona 2):** Em situacoes de alta carga, e critico adicionar capacidade rapidamente. Adicionar 1 por vez pode nao ser suficiente para absorver a demanda, causando degradacao prolongada.
- **Scale in conservador (remove 1):** Remover instancias deve ser gradual para evitar remover capacidade demais. Se a carga voltar a subir, a recuperacao e mais rapida se menos instancias foram removidas.

Essa assimetria e uma **best practice** de autoscale: escalar rapido para cima, devagar para baixo.

**3. VMSS no limite maximo (20 instancias):**

Opcoes alem de aumentar o limite:
- **Scale up:** Mudar o SKU das instancias para VMs mais potentes (ex: Standard_D4s → Standard_D8s) — mais CPU/RAM por instancia
- **Otimizar a aplicacao:** Caching, connection pooling, queries otimizadas — reduzir carga por requisicao
- **Offload para servicos PaaS:** Mover partes do processamento para servicos gerenciados (Azure Functions, Container Apps) que escalam independentemente
- **CDN:** Se o VMSS serve conteudo estatico, um CDN pode absorver grande parte do trafego
- **Load Balancer com multiplos VMSS:** Distribuir a carga entre mais de um VMSS

**[GOTCHA]** No exame, autoscale sempre testa: cooldown, assimetria de scale out/in, e o que fazer quando o limite maximo e atingido. A resposta para "VMSS no limite" nunca e apenas "aumentar o max" — sempre considere scale up e otimizacao.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco2-vms.md` — VMSS e autoscale

---

### Q1.2 — App Service Deployment Slots Swap

**Resposta: B) O swap troca os virtual IPs dos slots, redirecionando trafego instantaneamente sem downtime**

O processo de swap funciona assim:

1. O Azure **pre-aquece** (warm up) a instancia no slot de destino aplicando as configuracoes do slot de producao
2. Apos o warm-up, o Azure **troca os virtual IPs** entre os slots
3. O trafego que apontava para o IP de production agora vai para a instancia do staging (e vice-versa)
4. **O slot staging continua existindo** com a versao anterior (permite rollback)

**Por que os outros estao errados:**
- **A) Copia de arquivos + downtime** — Incorreto. Nao ha copia de arquivos. O swap troca IPs/rotas, e o warm-up garante zero downtime.
- **C) Deleta o slot staging** — Incorreto. O slot staging permanece com a versao anterior. Isso e o que permite rollback rapido (swap de volta).
- **D) Reinicio manual** — Incorreto. O swap e automatico e nao requer reinicio.

**Detalhes sobre configuracoes no swap:**

Algumas configuracoes acompanham o slot (slot-specific) e outras acompanham o conteudo:

| Acompanha o CONTEUDO (swapped) | Acompanha o SLOT (nao swapped) |
|-------------------------------|-------------------------------|
| Codigo da aplicacao | Connection strings (quando marcadas como slot setting) |
| Versao do framework | Custom domains |
| Configuracoes gerais | SSL certificates |
| Handler mappings | Configuracoes de scale |

**[GOTCHA]** No exame, swap = troca de virtual IPs, zero downtime, staging permanece como rollback. Configuracoes marcadas como "slot settings" (deployment slot settings) NAO sao swapped — ficam com o slot.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco3-webapps.md` — Deployment slots

---

### Q1.3 — ACI vs Container Apps vs AKS

**Resposta:**

**1. Azure Container Instances (ACI):**

**Nao e adequado.** ACI e ideal para containers **simples e isolados**, sem orquestracao. Limitacoes:
- **Nao tem autoscale nativo** baseado em fila — voce teria que implementar logica customizada
- **Nao suporta scale-to-zero** — instancias precisam ser criadas/deletadas manualmente ou via automacao
- Bom para: tarefas one-off, sidecar containers, CI/CD build agents

**2. Azure Container Apps:**

**Sim, e a opcao mais adequada.** Container Apps atende todos os requisitos:
- ✅ **Scale baseado em triggers** — suporta Azure Queue Storage como source de scaling (KEDA)
- ✅ **Scale-to-zero** — quando nao ha mensagens na fila, escala para 0 instancias (custo zero)
- ✅ **Ate 300 replicas** — suporta 50 instancias facilmente
- ✅ **Serverless** — sem gerenciamento de infraestrutura de cluster
- ✅ **Modelo de cobranca** — paga apenas pelo consumo (vCPU-segundo e GB-segundo)

**3. Azure Kubernetes Service (AKS):**

**Funcional, mas excessivo.** AKS atenderia os requisitos, mas:
- ❌ Requer **gerenciamento de cluster** (node pools, upgrades, networking)
- ❌ Custo minimo mesmo sem carga (nodes do cluster continuam rodando)
- ❌ Complexidade desnecessaria para um cenario simples de queue processing
- AKS e ideal quando voce precisa de: service mesh, ingress avancado, multiple workloads complexos, custom operators

**4. Escolha mais adequada: Azure Container Apps**

Container Apps e a escolha ideal para workloads **event-driven** que precisam de scale-to-zero e autoscale baseado em triggers, sem complexidade de gerenciamento de cluster.

**[GOTCHA]** No exame, a escolha de container service depende do cenario: ACI = container simples/one-off; Container Apps = event-driven, scale-to-zero, serverless; AKS = orquestracao complexa, multiplos workloads, full Kubernetes. Container Apps e a "middle ground" que aparece cada vez mais no exame.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco5-container-apps.md` — Container Apps

---

## Secao 2 — Networking

### Q2.1 — Application Gateway vs Load Balancer

**Resposta: B) Azure Application Gateway (WAF v2 SKU)**

O Application Gateway e um load balancer **Layer 7 (HTTP/HTTPS)** que atende todos os requisitos:

| Requisito | Load Balancer | **App Gateway** | Front Door | Traffic Manager |
|-----------|---------------|-----------------|------------|----------------|
| HTTP/HTTPS | Nao (Layer 4) | **Sim (Layer 7)** | Sim | Nao (DNS-based) |
| SSL termination | Nao | **Sim** | Sim | Nao |
| WAF | Nao | **Sim (WAF v2)** | Sim | Nao |
| Path-based routing | Nao | **Sim** | Sim | Nao |
| Regional | Sim | **Sim** | Global | Global |

**Por que os outros estao errados:**
- **A) Azure Load Balancer** — Opera na **Layer 4** (TCP/UDP). Nao entende HTTP, nao faz SSL termination, nao tem WAF, nao faz path-based routing.
- **C) Azure Front Door** — Funcional, mas e um servico **global** (CDN + WAF + Load Balancing). Para um cenario regional (Brazil South), Application Gateway e mais adequado e economico. Front Door e ideal para aplicacoes multi-regiao.
- **D) Azure Traffic Manager** — Opera no nivel **DNS**. Nao faz SSL termination, nao tem WAF, nao faz path-based routing. E usado para roteamento de trafego entre regioes (failover, performance).

**[GOTCHA]** No exame: Layer 4 = Load Balancer; Layer 7 regional = Application Gateway; Layer 7 global = Front Door; DNS-based = Traffic Manager. Se a questao menciona WAF + path-based routing, a resposta e Application Gateway ou Front Door.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco5-routing.md` — Load balancing

---

### Q2.2 — NSG + Application Gateway Subnet

**Resposta:**

**1. Por que o Application Gateway esta Unhealthy:**

A subnet do Application Gateway requer portas adicionais para o Azure gerenciar o servico. O NSG com `DenyAll` na prioridade 200 esta **bloqueando trafego de gerenciamento** essencial do Azure.

**2. Portas adicionais obrigatorias:**

| Porta(s) | Direcao | Finalidade |
|----------|---------|------------|
| **65503-65534** (v1) ou **65200-65535** (v2) | Inbound | **Health probes e gerenciamento** do Azure Infrastructure |
| **80, 443** | Inbound | Trafego de clientes (ja configurado) |
| **8080** (se backend health) | Outbound | Health probes para backends |

A regra NSG correta deve incluir:

| Prioridade | Nome | Direcao | Acao | Porta | Origem | Destino |
|------------|------|---------|------|-------|--------|---------|
| 100 | AllowHTTP | Inbound | Allow | 80 | * | * |
| 110 | AllowHTTPS | Inbound | Allow | 443 | * | * |
| 120 | AllowAzureInfra | Inbound | Allow | 65200-65535 | **GatewayManager** | * |
| 200 | DenyAll | Inbound | Deny | * | * | * |

**3. Source tag para health probes:**

A service tag **`GatewayManager`** deve ser usada como source para permitir trafego de health probes e gerenciamento do Azure para o Application Gateway.

Outra service tag relevante: **`AzureLoadBalancer`** — para health probes do Azure Load Balancer (usado internamente pelo Application Gateway).

**[GOTCHA]** A subnet do Application Gateway **nao pode** ter um NSG que bloqueia as portas de gerenciamento (65200-65535 para v2). Esse e um dos erros mais comuns de deployment. Sem essas portas, o Application Gateway fica Unhealthy e nao funciona.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco4-nsg.md` — NSG com service tags

---

### Q2.3 — VNet Integration para App Service

**Resposta: B) VNet Integration permite que o App Service acesse recursos dentro da VNet (trafego de saida), mas nao da um IP privado ao App Service**

VNet Integration e um recurso de **saida** (outbound) do App Service:

```
Internet ──► App Service (IP publico) ──► VNet Integration ──► VNet (recursos privados)
```

- O App Service pode **acessar** recursos dentro da VNet (SQL Database, VMs, etc.)
- O App Service **nao recebe um IP privado** — ele continua acessivel pela internet via IP publico
- Para dar um IP privado ao App Service (acesso **inbound** privado), e necessario um **Private Endpoint**

**Por que os outros estao errados:**
- **A) VNet acessa App Service via IP privado** — Invertido. VNet Integration e para o App Service acessar a VNet (outbound), nao o contrario. Para acesso inbound privado, use Private Endpoint.
- **C) Substitui Private Endpoints** — Incorreto. VNet Integration (outbound) e Private Endpoint (inbound) sao recursos **complementares**, nao substitutos.
- **D) Disponivel em todos os tiers** — Incorreto. VNet Integration requer tier **Standard** ou superior. Nao esta disponivel em Free, Shared ou Basic.

**Resumo:**

| Direcao | Recurso | O que faz |
|---------|---------|-----------|
| **Outbound** (App → VNet) | VNet Integration | App Service acessa recursos na VNet |
| **Inbound** (VNet → App) | Private Endpoint | App Service recebe IP privado na VNet |

**[GOTCHA]** VNet Integration = saida (App Service acessa a VNet). Private Endpoint = entrada (VNet acessa o App Service). No exame, se a questao fala em "acessar SQL dentro da VNet", a resposta e VNet Integration. Se fala em "acessar App Service sem IP publico", a resposta e Private Endpoint.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco3-webapps.md` — VNet Integration

---

## Secao 3 — Armazenamento

### Q3.1 — Blob Tiers para Imagens de Produto

**Resposta: C) Hot para 70%, Cool para 20%, Cold para 10%**

Analise custo-beneficio:

| Faixa | % | Padrao de Acesso | Tier | Justificativa |
|-------|---|-------------------|------|---------------|
| Produtos ativos | 70% | Acesso constante | **Hot** | Custo de acesso baixo, custo de armazenamento maior |
| Descont. < 6 meses | 20% | Acesso raro | **Cool** | Economia no armazenamento, penalidade de acesso moderada |
| Descont. > 1 ano | 10% | Quase nunca | **Cold** | Economia maxima viavel, acesso eventual possivel |

**Por que os outros estao errados:**
- **A) Hot para 100%** — Desperdicaria dinheiro armazenando 30% dos dados (raramente acessados) no tier mais caro.
- **B) Hot 70% + Cool 20% + Archive 10%** — Archive seria problematico para imagens de produtos descontinuados. Mesmo que quase nunca acessados, quando um cliente busca um produto antigo, a reidratacao do Archive pode levar **ate 15 horas**. Isso e inaceitavel para um e-commerce. **Cold** permite acesso imediato com custo de armazenamento baixo.
- **D) Cool para 100%** — Os 70% de produtos ativos sao acessados constantemente. Cool cobra mais por acesso que Hot. Para dados acessados frequentemente, Hot e mais economico.

**[GOTCHA]** Archive e inadequado para dados que podem ser acessados a qualquer momento (mesmo que raramente). A reidratacao de horas e inaceitavel para cenarios interativos. Cold e o tier correto para "raramente acessado mas precisa estar disponivel".

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Access tiers

---

### Q3.2 — AzCopy para Migracao em Massa

**Resposta:**

**1. Calculo de tempo:**

```
10 TB = 10 × 1024 GB = 10.240 GB = 10.240 × 1024 MB = 10.485.760 MB
100 Mbps = 12,5 MB/s (megabytes por segundo)

Tempo = 10.485.760 MB / 12,5 MB/s = 838.861 segundos
838.861 / 3600 = ~233 horas = ~9,7 dias
```

Com overhead de protocolo e variacao de velocidade, na pratica seria **10-12 dias** de transferencia ininterrupta.

**2. Parametros essenciais do AzCopy:**

```bash
azcopy copy \
  "/caminho/local/imagens" \
  "https://msproductimages.blob.core.windows.net/products?<SAS>" \
  --recursive \
  --put-md5 \
  --log-level=INFO \
  --cap-mbps=90
```

Flags importantes:
- `--recursive` — Copia subpastas recursivamente
- `--put-md5` — Calcula e verifica hash MD5 para garantir integridade
- `--log-level=INFO` — Logs detalhados para acompanhar progresso
- `--cap-mbps=90` — Limita uso de banda para nao saturar a VPN (deixa 10 Mbps para outros servicos)
- `--block-size-mb` — Pode ser ajustado para otimizar transferencia de arquivos grandes
- `--overwrite=ifSourceNewer` — Util para retomar transferencias interrompidas

Para retomar apos interrupcao: AzCopy suporta **journal files** que permitem continuar de onde parou.

**3. Servico offline do Azure:**

**Azure Data Box** — um dispositivo fisico que a Microsoft envia para o datacenter do cliente:

| Variante | Capacidade | Cenario |
|----------|------------|---------|
| Data Box Disk | Ate 35 TB (5 discos SSD de 8 TB) | Transferencias de 10-35 TB |
| Data Box | Ate 80 TB | Transferencias de 40-500 TB |
| Data Box Heavy | Ate 1 PB | Transferencias massivas |

Para 10 TB, o **Data Box Disk** seria adequado:
1. Microsoft envia discos SSD criptografados
2. Thiago copia os dados para os discos no datacenter
3. Envia os discos de volta para a Microsoft
4. Microsoft faz upload para o storage account
5. Discos sao apagados com seguranca (NIST 800-88)

Tempo total: **7-10 dias** (incluindo envio) — similar a VPN, mas sem impacto na bandwidth.

**[GOTCHA]** No exame, quando o volume de dados e grande (> 10 TB) e a bandwidth limitada, Azure Data Box e frequentemente a resposta. O calculo de tempo de transferencia via rede e uma habilidade testada. Lembre: 1 byte = 8 bits, entao 100 Mbps = 12,5 MB/s.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — AzCopy e migracao

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Subtopico |
|---------|----------------|-----------|
| Q1.1 | D3 — Deploy and manage compute resources | VMSS autoscale |
| Q1.2 | D3 — Deploy and manage compute resources | App Service deployment slots |
| Q1.3 | D3 — Deploy and manage compute resources | Container services comparison |
| Q2.1 | D4 — Implement and manage virtual networking | Application Gateway vs Load Balancer |
| Q2.2 | D4 — Implement and manage virtual networking | NSG + Application Gateway |
| Q2.3 | D4 — Implement and manage virtual networking | VNet Integration |
| Q3.1 | D2 — Implement and manage storage | Blob access tiers |
| Q3.2 | D2 — Implement and manage storage | AzCopy, Data Box |

---

## Top Gotchas — Caso 4

| # | Gotcha | Questao |
|---|--------|---------|
| 1 | Autoscale: scale out agressivo + scale in conservador = **best practice** | Q1.1 |
| 2 | Swap = troca de IPs, **zero downtime**, staging vira rollback | Q1.2 |
| 3 | ACI = simples; Container Apps = **event-driven + scale-to-zero**; AKS = complexo | Q1.3 |
| 4 | Layer 4 = Load Balancer; Layer 7 = **Application Gateway** (regional) ou Front Door (global) | Q2.1 |
| 5 | Application Gateway requer portas **65200-65535** abertas + service tag GatewayManager | Q2.2 |
| 6 | VNet Integration = **outbound** (App → VNet); Private Endpoint = **inbound** (VNet → App) | Q2.3 |
| 7 | Archive = reidratacao de horas, **inaceitavel** para acesso interativo | Q3.1 |
| 8 | 100 Mbps = 12,5 MB/s; 10 TB / 12,5 MB/s = **~233 horas** | Q3.2 |

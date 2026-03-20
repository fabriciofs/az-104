# Lab Extra: Load Balancer, DNS Import e Troubleshooting de Rede

> **Objetivo:** Reforcar LB (SKUs, health probes, sessao), DNS import e troubleshooting.
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 40-50 min (teoria + CLI + questoes)

---

## Parte 1 — Load Balancer: Basic vs Standard

### Comparacao de SKUs

| Criterio | Basic | Standard |
|----------|:-----:|:--------:|
| Back-end pool | Availability Set OU VMSS (nao ambos) | Qualquer VM na VNet |
| Back-end cross-VNet | **Nao** | **Nao** (mesma VNet apenas) |
| Health probes | HTTP, TCP | HTTP, HTTPS, TCP |
| SLA | Nenhum | **99,99%** |
| Zonas de disponibilidade | Nao | Sim (zone-redundant) |
| NSG necessario? | Opcional | **Obrigatorio** (back-end pool) |
| Seguro por padrao | Nao (aberto) | **Sim** (fechado — precisa NSG Allow) |
| Preco | Gratuito | Pago |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "LB Standard mas VMs nao recebem trafego"
VERIFICAR:
1. Health probe esta configurada? (porta e caminho corretos?)
2. NSG no back-end permite o trafego? (Standard e FECHADO por padrao)
3. VMs estao na mesma VNet do LB?
4. VMs estao saudaveis no health probe?

PERGUNTA: "Adicionar VMs de outra VNet ao LB"
RESPOSTA: NAO e possivel. LB (Basic e Standard) = mesma VNet apenas.
          Mesmo com peering, NAO funciona.
```

---

## Parte 2 — Health Probes

### Tipos de Health Probe

| Tipo | Porta | Caminho | Uso |
|------|-------|---------|-----|
| TCP | Qualquer | N/A | Verifica se porta esta aberta |
| HTTP | 80 (padrao) | / (padrao) | Verifica resposta HTTP 200 |
| HTTPS | 443 (padrao) | / (padrao) | Verifica resposta HTTPS 200 (Standard only) |

### Parametros do Health Probe

| Parametro | Default | Significado |
|-----------|---------|-------------|
| Interval | 5 seg | Tempo entre probes |
| Unhealthy threshold | 2 | Falhas consecutivas para marcar como unhealthy |
| Port | — | Porta a verificar (deve corresponder ao servico!) |
| Path | / | Caminho HTTP/HTTPS a verificar |

### Task 2.1 — Criar LB com Health Probe

```bash
RG="rg-lab-lb"
LOCATION="eastus"

az group create -n $RG -l $LOCATION

# Criar IP publico
az network public-ip create -g $RG -n pip-lb --sku Standard --zone 1 2 3

# Criar LB Standard
az network lb create -g $RG -n lb-demo \
  --sku Standard \
  --frontend-ip-name fe-ip \
  --public-ip-address pip-lb \
  --backend-pool-name be-pool

# Health probe HTTP na porta 80
az network lb probe create -g $RG --lb-name lb-demo \
  -n probe-http \
  --protocol Http \
  --port 80 \
  --path /health

# Regra de balanceamento
az network lb rule create -g $RG --lb-name lb-demo \
  -n rule-http \
  --frontend-ip fe-ip \
  --backend-pool-name be-pool \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --probe-name probe-http
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "LB esta funcionando mas nenhuma VM recebe trafego"
CAUSA MAIS COMUM: Health probe na porta errada ou servico nao esta rodando
SOLUCAO: Verificar se a porta do probe corresponde ao servico na VM

PERGUNTA: "VMs marcadas como unhealthy no LB"
VERIFICAR:
1. Servico (ex: nginx) esta rodando na porta correta?
2. NSG permite trafego na porta do health probe?
3. Probe path retorna HTTP 200?
```

---

## Parte 3 — Session Persistence (Afinidade de Sessao)

### Modos de Distribuicao

| Modo | Descricao | Baseado em |
|------|-----------|------------|
| **None** (default) | Round-robin | Hash de 5-tupla (IP src, IP dst, porta src, porta dst, protocolo) |
| **Client IP** | Afinidade por IP | Hash de 2-tupla (IP src, IP dst) |
| **Client IP and Protocol** | Afinidade por IP + protocolo | Hash de 3-tupla (IP src, IP dst, protocolo) |

### Task 3.1 — Configurar Session Persistence

```bash
# Alterar regra para Client IP
az network lb rule update -g $RG --lb-name lb-demo \
  -n rule-http \
  --load-distribution SourceIP
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Requisicoes do mesmo usuario devem ir sempre para a mesma VM"
CERTO: Session Persistence = Client IP (SourceIP)

PERGUNTA: "Distribuir trafego igualmente entre todas as VMs"
CERTO: Session Persistence = None (default, 5-tuple hash)

NOMES EQUIVALENTES NA PROVA:
- "Client IP" = "Source IP affinity" = "SourceIP" = "Session persistence"
- "None" = "5-tuple hash" = "Default distribution"
```

---

## Parte 4 — DNS Zone Import

### Migrar zona DNS para Azure

```bash
# UNICA ferramenta que importa zona DNS inteira: Azure CLI
az network dns zone import \
  -g $RG \
  -n techcloud.com \
  --file-name techcloud.com.zone

# Exportar zona
az network dns zone export \
  -g $RG \
  -n techcloud.com \
  --file-name techcloud-export.zone
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Migrar 500 registros DNS para Azure com menor esforco"
ERRADO: Azure PowerShell (nao suporta import de zona)
ERRADO: Portal do Azure (nao suporta import de zona)
ERRADO: Gerenciador de DNS (ferramenta Windows, nao Azure)
CERTO:  Azure CLI — az network dns zone import

SOMENTE o Azure CLI suporta import/export de arquivos de zona DNS!
```

---

## Parte 5 — Troubleshooting de Rede (Network Watcher)

### Ferramentas do Network Watcher

| Ferramenta | O que faz | Quando usar |
|------------|-----------|-------------|
| **IP Flow Verify** | Testa se pacote especifico e permitido/negado | "Por que nao consigo conectar na porta X?" |
| **NSG Flow Logs** | Registra TODO trafego pelo NSG | "Auditar todo trafego de rede" |
| **Connection Monitor** | Monitora conectividade continuamente | "Verificar se conexao entre A e B esta estavel" |
| **Connection Troubleshoot** | Diagnostico pontual de conectividade | "Testar conectividade agora" |
| **Packet Capture** | Captura pacotes de rede | "Analisar trafego em detalhe" |
| **Next Hop** | Mostra proxximo salto de roteamento | "Para onde vai o trafego desta VM?" |
| **Effective Security Rules** | Mostra regras NSG efetivas | "Quais regras se aplicam a esta NIC?" |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Registrar TODAS as tentativas de conexao de/para uma VM"
CERTO: Network Watcher + NSG Flow Logs

PERGUNTA: "Verificar se trafego na porta 80 e permitido ou negado"
CERTO: IP Flow Verify

PERGUNTA: "Capturar pacotes de rede de uma VM"
PREREQUISITO: VM precisa ter a extensao Network Watcher Agent instalada

PERGUNTA: "Monitorar conectividade entre VM e endpoint externo continuamente"
CERTO: Connection Monitor
```

---

## Parte 6 — Cleanup

```bash
az group delete -n $RG --yes --no-wait
```

---

## Questoes de Prova

### Q1
Voce configurou um LB Standard, mas nenhuma VM recebe trafego. As VMs estao rodando nginx na porta 80. O NSG permite trafego na porta 80. O health probe esta configurado na porta 443. Qual e o problema?

- A. O LB precisa ser Basic, nao Standard
- B. O health probe esta na porta errada (443 em vez de 80)
- C. As VMs precisam estar em um Availability Set
- D. O LB precisa de IP privado, nao publico

<details>
<summary>Resposta</summary>

**B.** O health probe verifica a porta 443, mas o nginx roda na porta 80. As VMs sao marcadas como unhealthy porque nao respondem na porta 443.

</details>

### Q2
Voce tem um LB Interno Basico. VMs de uma VNet diferente (com peering configurado) precisam ser adicionadas ao back-end pool. Isso e possivel?

- A. Sim, com peering e suficiente
- B. Sim, mas precisa de VNet Gateway
- C. Nao, LB so suporta VMs da mesma VNet
- D. Sim, mas apenas com LB Standard

<details>
<summary>Resposta</summary>

**C.** LB (Basic e Standard) so suporta VMs da mesma VNet no back-end pool. Peering nao resolve isso.

</details>

### Q3
Usuarios precisam que suas requisicoes sejam sempre direcionadas para a mesma VM. Qual configuracao do LB usar?

- A. Session Persistence = None
- B. Session Persistence = Client IP
- C. Health probe na porta 80
- D. Floating IP habilitado

<details>
<summary>Resposta</summary>

**B.** Client IP (SourceIP) garante que todas as requisicoes do mesmo IP de cliente vao para a mesma VM.

</details>

### Q4
Voce precisa migrar uma zona DNS com 500 registros para o Azure com menor esforco. Qual ferramenta usar?

- A. Azure PowerShell
- B. Azure CLI
- C. Portal do Azure
- D. Gerenciador de DNS

<details>
<summary>Resposta</summary>

**B.** Azure CLI com `az network dns zone import`. E a unica ferramenta que suporta importacao de arquivos de zona DNS para o Azure.

</details>

### Q5
Voce precisa registrar todo o trafego de rede que passa pelos NSGs de uma VM. Qual recurso do Network Watcher usar?

- A. Connection Monitor
- B. IP Flow Verify
- C. Packet Capture
- D. NSG Flow Logs

<details>
<summary>Resposta</summary>

**D.** NSG Flow Logs registram todo trafego IP (origem, destino, porta, protocolo, allow/deny). Connection Monitor monitora conectividade. IP Flow Verify testa pacote especifico.

</details>

### Q6
Qual a diferenca entre LB Basic e Standard quanto ao NSG?

- A. Ambos exigem NSG
- B. Basic exige NSG, Standard nao
- C. Basic nao exige NSG, Standard exige NSG obrigatorio
- D. Nenhum exige NSG

<details>
<summary>Resposta</summary>

**C.** LB Standard e "secure by default" — o trafego e bloqueado por padrao e requer NSG com regra Allow explicita. LB Basic e aberto por padrao (NSG opcional).

</details>

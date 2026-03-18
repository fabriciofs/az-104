# Lab Extra - ASG, NSG e Service Tags na Pratica

**Objetivo:** Praticar Application Security Groups (ASG) em cenarios reais — criar grupos por funcao, testar regras entre camadas (web/db), comparar ASG vs Service Tag, e troubleshoot conectividade.
**Tempo estimado:** 1h
**Custo:** ~$0.50 (3 VMs Linux B1s por ~1h)

> **IMPORTANTE:** Este lab cria recursos do zero. Faca cleanup ao final para evitar custos.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────────┐
│                       rg-lab-asg                                       │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ vnet-asg-lab (10.0.0.0/16)                                       │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────┐  ┌──────────────────────────────┐   │  │
│  │  │ snet-web (10.0.1.0/24)  │  │ snet-db (10.0.2.0/24)       │   │  │
│  │  │                          │  │                              │   │  │
│  │  │ vm-web-01  [asg-web]    │  │ vm-db-01  [asg-db]          │   │  │
│  │  │ vm-web-02  [asg-web]    │  │                              │   │  │
│  │  │                          │  │                              │   │  │
│  │  │ NSG: nsg-snet-web       │  │ NSG: nsg-snet-db            │   │  │
│  │  └──────────────────────────┘  └──────────────────────────────┘   │  │
│  │                                                                    │  │
│  │  ASGs:                                                             │  │
│  │  • asg-web → vm-web-01, vm-web-02                                 │  │
│  │  • asg-db  → vm-db-01                                             │  │
│  │                                                                    │  │
│  │  Regras:                                                           │  │
│  │  • Internet → asg-web: Allow 80/443 (Service Tag "Internet")      │  │
│  │  • asg-web → asg-db: Allow 3306 (MySQL)                          │  │
│  │  • Internet → asg-db: DENY (nenhum acesso direto)                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Parte 1: Setup do ambiente

### Task 1.1: Criar Resource Group, VNet e Subnets

```bash
RG="rg-lab-asg"
LOCATION="eastus"

# Criar RG
az group create --name $RG --location $LOCATION

# Criar VNet com 2 subnets (web e db)
az network vnet create \
  --resource-group $RG \
  --name vnet-asg-lab \
  --address-prefix 10.0.0.0/16 \
  --subnet-name snet-web \
  --subnet-prefix 10.0.1.0/24 \
  --location $LOCATION

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name vnet-asg-lab \
  --name snet-db \
  --address-prefix 10.0.2.0/24

echo "VNet e subnets criadas"
```

### Task 1.2: Criar os ASGs

```bash
# Criar ASG para web servers
az asg create \
  --resource-group $RG \
  --name asg-web \
  --location $LOCATION

# Criar ASG para database servers
az asg create \
  --resource-group $RG \
  --name asg-db \
  --location $LOCATION

echo "ASGs criados: asg-web, asg-db"
```

> **Conceito:** O ASG sozinho nao faz nada — e apenas um "rotulo logico". Voce o associa a NICs de VMs e depois referencia nas regras do NSG. A vantagem: quando adicionar uma nova VM web, basta associar ao asg-web e todas as regras se aplicam automaticamente.

### Task 1.3: Criar 3 VMs Linux (2 web + 1 db)

```bash
# VM Web 01 — associada ao asg-web
az vm create \
  --resource-group $RG \
  --name vm-web-01 \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --vnet-name vnet-asg-lab \
  --subnet snet-web \
  --nsg "" \
  --public-ip-address "" \
  --asg asg-web \
  --admin-username azureuser \
  --generate-ssh-keys \
  --no-wait

# VM Web 02 — associada ao asg-web
az vm create \
  --resource-group $RG \
  --name vm-web-02 \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --vnet-name vnet-asg-lab \
  --subnet snet-web \
  --nsg "" \
  --public-ip-address "" \
  --asg asg-web \
  --admin-username azureuser \
  --generate-ssh-keys \
  --no-wait

# VM DB 01 — associada ao asg-db
az vm create \
  --resource-group $RG \
  --name vm-db-01 \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --vnet-name vnet-asg-lab \
  --subnet snet-db \
  --nsg "" \
  --public-ip-address "" \
  --asg asg-db \
  --admin-username azureuser \
  --generate-ssh-keys

echo "3 VMs criadas com ASGs associados"
```

> **Ponto-chave:** O parametro `--asg asg-web` associa a NIC da VM ao ASG na criacao. Voce tambem pode associar depois via portal (VM > Networking > ASG).

### Task 1.4: Instalar servicos nas VMs

```bash
# Instalar nginx nas VMs web (simula web server)
az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-01 \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y nginx && echo 'Hello from vm-web-01' | sudo tee /var/www/html/index.html"

az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-02 \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y nginx && echo 'Hello from vm-web-02' | sudo tee /var/www/html/index.html"

# Instalar MySQL client na VM db (simula db server escutando na 3306)
az vm run-command invoke \
  --resource-group $RG \
  --name vm-db-01 \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y ncat && sudo ncat -l -k 3306 &"

echo "Servicos instalados: nginx (web), ncat:3306 (db)"
```

### Task 1.5: Verificar IPs privados das VMs

```bash
az vm list-ip-addresses \
  --resource-group $RG \
  --query "[].{VM:virtualMachine.name, PrivateIP:virtualMachine.network.privateIpAddresses[0]}" \
  -o table
```

> **Anote os IPs** — voce vai usa-los para testar conectividade.

---

## Parte 2: NSG com regras baseadas em ASG

> **Contexto de prova:** "Permitir trafego HTTP apenas para web servers" — a resposta usa ASG como destination na regra NSG. "Permitir acesso ao banco apenas dos web servers" — ASG como source.

### Task 2.1: Criar NSG para subnet web

```bash
# Criar NSG
az network nsg create \
  --resource-group $RG \
  --name nsg-snet-web \
  --location $LOCATION

# Regra 1: Permitir HTTP/HTTPS da Internet para asg-web
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-web \
  --name AllowHTTP-Internet-to-Web \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-asgs asg-web \
  --destination-port-ranges 80 443

# Regra 2: Permitir SSH da VNet (para troubleshoot entre VMs)
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-web \
  --name AllowSSH-VNet \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 22

# Associar NSG a subnet web
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name vnet-asg-lab \
  --name snet-web \
  --network-security-group nsg-snet-web

echo "NSG criado e associado a snet-web"
```

> **Lendo a regra AllowHTTP:** "Permite TCP nas portas 80/443 vindo da Internet (Service Tag) com destino a qualquer VM que pertenca ao asg-web." Note que usamos **Service Tag** (Internet) como source e **ASG** (asg-web) como destination — ambos na mesma regra.

### Task 2.2: Criar NSG para subnet db

```bash
# Criar NSG
az network nsg create \
  --resource-group $RG \
  --name nsg-snet-db \
  --location $LOCATION

# Regra 1: Permitir MySQL APENAS de asg-web para asg-db
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-db \
  --name AllowMySQL-Web-to-DB \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-asgs asg-web \
  --destination-asgs asg-db \
  --destination-port-ranges 3306

# Regra 2: BLOQUEAR todo o resto da Internet
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-db \
  --name DenyInternet-Inbound \
  --priority 200 \
  --direction Inbound \
  --access Deny \
  --protocol "*" \
  --source-address-prefixes Internet \
  --destination-port-ranges "*"

# Regra 3: Permitir SSH da VNet (troubleshoot)
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-db \
  --name AllowSSH-VNet \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 22

# Associar NSG a subnet db
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name vnet-asg-lab \
  --name snet-db \
  --network-security-group nsg-snet-db

echo "NSG criado e associado a snet-db"
```

> **Regra chave: AllowMySQL-Web-to-DB** — source = asg-web, destination = asg-db, port = 3306. Isso significa que APENAS VMs no asg-web podem acessar a porta 3306 das VMs no asg-db. Qualquer outra VM (mesmo na mesma VNet) e bloqueada.

### Task 2.3: Verificar regras pelo portal

1. Portal > **nsg-snet-db** > **Inbound security rules**
2. Observe a coluna **Source** — mostra "asg-web" em vez de um IP
3. Compare com **nsg-snet-web** — source mostra "Internet" (Service Tag)

> **Visual:** No portal, ASGs aparecem com o nome do grupo. Service Tags aparecem com o nome do servico (Internet, VirtualNetwork, AzureLoadBalancer). IPs aparecem como CIDR.

---

## Parte 3: Testar conectividade (ASG em acao)

> **Objetivo:** Provar que as regras ASG funcionam — web acessa db, mas acesso direto da internet ao db e bloqueado.

### Task 3.1: Testar web → db (deve funcionar)

```bash
# Da vm-web-01, testar conexao na porta 3306 do vm-db-01
DB_IP=$(az vm list-ip-addresses --resource-group $RG --name vm-db-01 \
  --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-01 \
  --command-id RunShellScript \
  --scripts "nc -zv $DB_IP 3306 -w 5 2>&1 || echo 'CONNECTION FAILED'"
```

> **Resultado esperado:** Connection succeeded — vm-web-01 pertence ao asg-web, que tem permissao na regra AllowMySQL-Web-to-DB.

### Task 3.2: Testar web → web na porta 80 (deve funcionar)

```bash
# Da vm-web-01, acessar vm-web-02 na porta 80
WEB2_IP=$(az vm list-ip-addresses --resource-group $RG --name vm-web-02 \
  --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-01 \
  --command-id RunShellScript \
  --scripts "curl -s http://$WEB2_IP --max-time 5 || echo 'CONNECTION FAILED'"
```

> **Resultado esperado:** "Hello from vm-web-02"

### Task 3.3: Testar db → web na porta 80 (o que acontece?)

```bash
# Da vm-db-01, tentar acessar vm-web-01 na porta 80
WEB1_IP=$(az vm list-ip-addresses --resource-group $RG --name vm-web-01 \
  --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

az vm run-command invoke \
  --resource-group $RG \
  --name vm-db-01 \
  --command-id RunShellScript \
  --scripts "curl -s http://$WEB1_IP --max-time 5 || echo 'CONNECTION FAILED'"
```

> **Resultado esperado:** Funciona! Por que? A regra AllowHTTP no nsg-snet-web permite source=Internet, mas o trafego vem da VNet (nao da Internet). A regra default AllowVnetInBound permite trafego intra-VNet. A regra AllowHTTP com destination=asg-web nao BLOQUEIA quem nao e asg-web — ela so PERMITE para asg-web adicionalmente.

> **PEGADINHA AZ-104:** ASG em uma regra Allow NAO bloqueia trafego de outras origens/destinos. Para bloquear, voce precisa de uma regra Deny explicita. A regra default AllowVnetInBound (prioridade 65000) permite trafego intra-VNet a menos que uma regra de prioridade menor a bloqueie.

### Task 3.4: Bloquear db → web (regra Deny explicita)

```bash
# Adicionar regra: bloquear trafego da snet-db para a porta 80 da snet-web
az network nsg rule create \
  --resource-group $RG \
  --nsg-name nsg-snet-web \
  --name DenyDB-to-Web \
  --priority 200 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --source-asgs asg-db \
  --destination-port-ranges 80 443

echo "Regra Deny criada"
```

```bash
# Testar novamente: db → web (agora deve falhar)
az vm run-command invoke \
  --resource-group $RG \
  --name vm-db-01 \
  --command-id RunShellScript \
  --scripts "curl -s http://$WEB1_IP --max-time 5 || echo 'CONNECTION BLOCKED'"
```

> **Resultado esperado:** CONNECTION BLOCKED — a regra DenyDB-to-Web (prioridade 200) e avaliada antes da AllowVnetInBound (prioridade 65000).

---

## Parte 4: ASG vs Service Tag vs IP Range (comparacao pratica)

> **Contexto de prova (erro no simulado 3):** "Qual usar para permitir trafego do Azure Load Balancer?" → Service Tag. "Qual usar para permitir trafego entre seus web servers e db servers?" → ASG.

### Task 4.1: Listar Service Tags disponiveis

```bash
# Ver alguns Service Tags comuns
az network list-service-tags --location eastus \
  --query "values[?contains(name, 'Internet') || contains(name, 'VirtualNetwork') || contains(name, 'AzureLoadBalancer') || contains(name, 'Storage') || contains(name, 'AzureCloud')].{name:name, prefixes:properties.addressPrefixes[0:3]}" \
  -o table
```

> **Service Tags sao mantidos pela Microsoft** — os IP ranges atualizam automaticamente. Voce NAO precisa atualizar manualmente.

### Task 4.2: Comparar as 3 abordagens numa regra

```bash
# Abordagem 1: ASG (seus recursos agrupados por funcao)
echo "=== ASG ==="
az network nsg rule show --resource-group $RG --nsg-name nsg-snet-db \
  --name AllowMySQL-Web-to-DB \
  --query "{source: sourceApplicationSecurityGroups[0].id, dest: destinationApplicationSecurityGroups[0].id, port: destinationPortRange}" -o table

# Abordagem 2: Service Tag (servicos Azure gerenciados)
echo "=== Service Tag ==="
az network nsg rule show --resource-group $RG --nsg-name nsg-snet-web \
  --name AllowHTTP-Internet-to-Web \
  --query "{source: sourceAddressPrefix, dest_asg: destinationApplicationSecurityGroups[0].id, port: destinationPortRanges}" -o table

# Abordagem 3: IP Range (IPs fixos — evitar quando possivel)
echo "=== Exemplo IP Range (NAO criar, apenas comparar) ==="
echo "Source: 10.0.1.0/24 — funciona mas nao escala e quebra se IPs mudarem"
```

### Resumo visual (DECORE para prova!)

```
┌─────────────────────────────────────────────────────────────────────┐
│               QUANDO USAR CADA UM?                                  │
│                                                                     │
│  ┌─────────────────────┐                                            │
│  │ SERVICE TAG          │ → Servicos Azure gerenciados              │
│  │ (mantido pela MS)    │   Internet, VirtualNetwork,               │
│  │                      │   AzureLoadBalancer, Storage,             │
│  │                      │   AzureCloud, Sql, etc.                   │
│  └─────────────────────┘                                            │
│                                                                     │
│  ┌─────────────────────┐                                            │
│  │ ASG                  │ → SEUS recursos agrupados por funcao      │
│  │ (definido por voce)  │   asg-web, asg-db, asg-api               │
│  │                      │   Escala automaticamente ao adicionar VMs │
│  └─────────────────────┘                                            │
│                                                                     │
│  ┌─────────────────────┐                                            │
│  │ IP RANGE / CIDR      │ → IPs especificos ou ranges fixos        │
│  │ (manual)             │   10.0.1.0/24, 203.0.113.50              │
│  │                      │   Nao escala, quebra se IPs mudam         │
│  └─────────────────────┘                                            │
│                                                                     │
│  REGRA: Use Service Tag para servicos Azure.                        │
│         Use ASG para seus recursos.                                 │
│         Use IP Range apenas como ultimo recurso.                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Parte 5: Troubleshoot — VM nao conecta (falta ASG)

> **Cenario de prova:** "Uma nova VM web foi adicionada mas nao recebe trafego HTTP. As outras VMs web funcionam. O que esta errado?"

### Task 5.1: Criar VM sem ASG (simula erro)

```bash
# Criar vm-web-03 SEM associar ao asg-web
az vm create \
  --resource-group $RG \
  --name vm-web-03 \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --vnet-name vnet-asg-lab \
  --subnet snet-web \
  --nsg "" \
  --public-ip-address "" \
  --admin-username azureuser \
  --generate-ssh-keys

# Instalar nginx
az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-03 \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y nginx && echo 'Hello from vm-web-03' | sudo tee /var/www/html/index.html"

echo "vm-web-03 criada SEM ASG"
```

### Task 5.2: Testar — vm-web-03 consegue acessar o db?

```bash
# vm-web-03 tenta acessar db na porta 3306
az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-03 \
  --command-id RunShellScript \
  --scripts "nc -zv $DB_IP 3306 -w 5 2>&1 || echo 'CONNECTION FAILED'"
```

> **Resultado esperado:** CONNECTION FAILED — vm-web-03 NAO pertence ao asg-web, entao a regra AllowMySQL-Web-to-DB nao se aplica. A regra default AllowVnetInBound permite trafego intra-VNet, mas a regra DenyInternet-Inbound (prioridade 200) no nsg-snet-db pode bloquear dependendo da avaliacao.

> **Aprendizado:** Se uma nova VM nao funciona mas as outras sim, verifique se ela esta no ASG correto!

### Task 5.3: Corrigir — associar vm-web-03 ao asg-web

```bash
# Obter o nome da NIC da vm-web-03
NIC_NAME=$(az vm show --resource-group $RG --name vm-web-03 \
  --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)

# Associar ao asg-web
az network nic update \
  --resource-group $RG \
  --name $NIC_NAME \
  --application-security-groups asg-web

echo "vm-web-03 agora pertence ao asg-web"
```

### Task 5.4: Testar novamente — agora deve funcionar

```bash
az vm run-command invoke \
  --resource-group $RG \
  --name vm-web-03 \
  --command-id RunShellScript \
  --scripts "nc -zv $DB_IP 3306 -w 5 2>&1 || echo 'CONNECTION FAILED'"
```

> **Resultado esperado:** Connection succeeded — agora vm-web-03 pertence ao asg-web e a regra se aplica.

### Task 5.5: Verificar ASGs de uma VM pelo portal

1. Portal > **vm-web-03** > **Networking** > **Application security groups**
2. Deve mostrar **asg-web**
3. Compare com **vm-db-01** — deve mostrar **asg-db**

Ou via CLI:

```bash
# Listar ASGs de todas as VMs
for VM in vm-web-01 vm-web-02 vm-web-03 vm-db-01; do
  NIC=$(az vm show --resource-group $RG --name $VM \
    --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
  ASGS=$(az network nic show --resource-group $RG --name $NIC \
    --query "ipConfigurations[0].applicationSecurityGroups[].id" -o tsv | xargs -I{} basename {})
  echo "$VM → $ASGS"
done
```

---

## Parte 6: NSG Effective Rules (diagnostico)

> **Contexto de prova:** "Como verificar quais regras NSG estao sendo aplicadas a uma VM?" → Effective security rules.

### Task 6.1: Ver regras efetivas de cada VM

```bash
# Regras efetivas da vm-web-01 (pertence ao asg-web)
NIC_WEB=$(az vm show --resource-group $RG --name vm-web-01 \
  --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)

az network nic list-effective-nsg \
  --resource-group $RG \
  --name $NIC_WEB \
  --query "value[0].effectiveSecurityRules[?direction=='Inbound'].{name:name, access:access, priority:priority, srcAddr:sourceAddressPrefix, srcASG:sourceApplicationSecurityGroups, dstPort:destinationPortRange}" \
  -o table
```

```bash
# Regras efetivas da vm-db-01 (pertence ao asg-db)
NIC_DB=$(az vm show --resource-group $RG --name vm-db-01 \
  --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)

az network nic list-effective-nsg \
  --resource-group $RG \
  --name $NIC_DB \
  --query "value[0].effectiveSecurityRules[?direction=='Inbound'].{name:name, access:access, priority:priority, srcAddr:sourceAddressPrefix, dstPort:destinationPortRange}" \
  -o table
```

### Task 6.2: Verificar pelo portal

1. Portal > **vm-web-01** > **Networking** > **Network settings**
2. Clique em **Effective security rules** (ou aba superior)
3. Observe como as regras do NSG da subnet + defaults sao combinadas
4. Compare com **vm-db-01** — regras diferentes por causa do NSG diferente

> **Dica AZ-104:** "Effective security rules" mostra a combinacao de regras do NSG da NIC + NSG da subnet + defaults. Se ambos existem, o trafego precisa ser permitido em AMBOS para passar (AND logico). No nosso lab, so temos NSG na subnet, entao as effective rules sao mais simples.

---

## Cleanup

```bash
az group delete --name rg-lab-asg --yes --no-wait
echo "Resource group sendo deletado em background"
```

---

## Modo Desafio

Faca sem olhar os comandos acima:

- [ ] Criar VNet com 2 subnets (web e db)
- [ ] Criar 2 ASGs (asg-web e asg-db)
- [ ] Criar 3 VMs associando ao ASG correto na criacao
- [ ] Criar NSG para snet-web com regra usando Service Tag (Internet) + ASG (asg-web)
- [ ] Criar NSG para snet-db com regra ASG→ASG (asg-web → asg-db, porta 3306)
- [ ] Testar: web → db funciona, internet → db bloqueado
- [ ] Criar VM SEM ASG e provar que nao acessa o db
- [ ] Associar ASG via `az network nic update` e provar que agora funciona
- [ ] Ver effective security rules via CLI e portal
- [ ] Cleanup

---

## Questoes de Prova - ASG e NSG

### Questao A.1
**Voce tem VMs de web server e database server em subnets diferentes. Precisa permitir que APENAS os web servers acessem o MySQL (porta 3306) nos database servers. Qual abordagem segue o principio de menor privilegio?**

A) Criar regra NSG com source = IP range da subnet web (10.0.1.0/24)
B) Criar regra NSG com source = Service Tag "VirtualNetwork"
C) Criar regra NSG com source = ASG "asg-web" e destination = ASG "asg-db"
D) Criar regra NSG com source = Any

<details>
<summary>Ver resposta</summary>

**Resposta: C) ASG source e destination**

ASG permite granularidade por funcao — apenas VMs no asg-web acessam VMs no asg-db. IP range (A) funciona mas nao escala e inclui qualquer VM na subnet. Service Tag VirtualNetwork (B) permite TODA a VNet. Any (D) e o oposto de menor privilegio.

</details>

### Questao A.2
**Uma nova VM web foi adicionada a subnet web. O nginx esta rodando, as outras VMs web funcionam normalmente, mas essa VM nao recebe trafego HTTP do Load Balancer. O que voce deve verificar PRIMEIRO?**

A) Se o NSG da subnet permite porta 80
B) Se a VM esta associada ao ASG correto
C) Se o health probe do LB esta configurado
D) Se a VM tem IP publico

<details>
<summary>Ver resposta</summary>

**Resposta: B) Se a VM esta associada ao ASG correto**

As outras VMs funcionam, entao o NSG (A) e o health probe (C) estao ok. A diferenca e que a nova VM provavelmente nao foi adicionada ao ASG usado na regra do NSG. Sem o ASG, a regra que permite HTTP nao se aplica a essa VM.

</details>

### Questao A.3
**Voce precisa criar uma regra NSG que permita trafego do Azure Load Balancer para suas VMs. Qual source voce deve usar?**

A) ASG "asg-loadbalancer"
B) Service Tag "AzureLoadBalancer"
C) IP range do Load Balancer
D) Service Tag "Internet"

<details>
<summary>Ver resposta</summary>

**Resposta: B) Service Tag "AzureLoadBalancer"**

Service Tags sao para servicos Azure gerenciados. O Azure Load Balancer tem seu proprio Service Tag. ASG (A) e para SEUS recursos, nao servicos Azure. IP range (C) nao e gerenciado e pode mudar. Internet (D) inclui todo o trafego externo, nao apenas o LB.

**Macete:** Servico Azure → Service Tag. Seus recursos → ASG.

</details>

### Questao A.4
**Qual a diferenca entre ASG e Service Tag?**

A) ASG e definido pela Microsoft; Service Tag e definido pelo usuario
B) ASG agrupa seus recursos por funcao; Service Tag representa ranges de IP de servicos Azure
C) Service Tag pode ser usado em NSG; ASG nao pode
D) ASG e Service Tag sao a mesma coisa com nomes diferentes

<details>
<summary>Ver resposta</summary>

**Resposta: B) ASG agrupa seus recursos; Service Tag representa servicos Azure**

ASG = definido por voce, agrupa VMs por funcao logica (web, db, api). Service Tag = definido pela Microsoft, representa ranges de IP de servicos Azure (Internet, AzureLoadBalancer, Storage). Ambos podem ser usados em regras NSG.

</details>

### Questao A.5
**Voce tem um NSG com as seguintes regras inbound na snet-db:**

| Prioridade | Nome | Source | Dest | Port | Acao |
|---|---|---|---|---|---|
| 100 | AllowMySQL | asg-web | asg-db | 3306 | Allow |
| 200 | DenyAll | Any | Any | * | Deny |
| 65000 | AllowVnetInBound | VirtualNetwork | VirtualNetwork | * | Allow |

**Uma VM na subnet web que NAO pertence ao asg-web tenta acessar a porta 3306 de uma VM no asg-db. O que acontece?**

A) Trafego permitido pela regra AllowMySQL (prioridade 100)
B) Trafego bloqueado pela regra DenyAll (prioridade 200)
C) Trafego permitido pela regra AllowVnetInBound (prioridade 65000)
D) Trafego permitido porque ambas as VMs estao na mesma VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B) Bloqueado pela DenyAll (prioridade 200)**

A avaliacao de regras e por prioridade (menor numero = maior prioridade):
1. **Prioridade 100 (AllowMySQL):** Source = asg-web. A VM NAO pertence ao asg-web → regra nao se aplica, pula.
2. **Prioridade 200 (DenyAll):** Source = Any → VM se encaixa → **DENY**. Avaliacao para aqui.
3. Prioridade 65000 nunca e avaliada.

Se nao existisse a regra DenyAll, o trafego seria permitido pela AllowVnetInBound (prioridade 65000).

</details>

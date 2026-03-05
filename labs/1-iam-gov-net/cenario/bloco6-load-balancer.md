> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 7 - SSPR, Cost Management e NSG Effective Rules](bloco7-sspr-cost-nsg.md)

# Bloco 6 - Load Balancer e Azure Bastion

**Origem:** Lab 06 - Implement Traffic Management (parcial) + Azure Bastion
**Resource Groups utilizados:** `az104-rg4` (VNets do Bloco 4) + `az104-rg6lb` (Load Balancers, VMs, Bastion)

## Contexto

Com as VNets, NSGs e DNS configurados nos Blocos 4-5, a Contoso Corp precisa distribuir trafego entre servidores e garantir acesso seguro as VMs sem expor IPs publicos. Voce cria um Public Load Balancer para balancear trafego HTTP, um Internal Load Balancer para comunicacao entre camadas internas, e implanta o Azure Bastion para acesso administrativo seguro. As VMs deste bloco sao implantadas na CoreServicesVnet do Bloco 4.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                          az104-rg6lb                                 │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  CoreServicesVnet (az104-rg4)                                  │  │
│  │                                                                │  │
│  │  ┌─────────────────────┐   ┌────────────────────────────────┐  │  │
│  │  │ AzureBastionSubnet  │   │ LBSubnet (NOVO)                │  │  │
│  │  │ 10.20.30.0/26       │   │ 10.20.40.0/24                  │  │  │
│  │  │                     │   │                                │  │  │
│  │  │ Azure Bastion ──────│───│─→ Acesso seguro a LB-VM1/VM2   │  │  │
│  │  └─────────────────────┘   │                                │  │  │
│  │                            │  ┌──────────┐  ┌──────────┐    │  │  │
│  │                            │  │ LB-VM1   │  │ LB-VM2   │    │  │  │
│  │  Internet                  │  │ (IIS)    │  │ (IIS)    │    │  │  │
│  │     │                      │  └────┬─────┘  └────┬─────┘    │  │  │
│  │     ▼                      │       │              │         │  │  │
│  │  ┌──────────────────┐      │       └──────┬───────┘         │  │  │
│  │  │ Public LB        │      │              │                 │  │  │
│  │  │ (Standard SKU)   │──────│──── Backend Pool ──────────────│  │  │
│  │  │ Frontend IP (PIP)│      │              │                 │  │  │
│  │  └──────────────────┘      │              │                 │  │  │
│  │                            │       ┌──────┴───────┐         │  │  │
│  │  ┌──────────────────┐      │       │              │         │  │  │
│  │  │ Internal LB      │──────│── Backend Pool (mesmas VMs)    │  │  │
│  │  │ (Standard SKU)   │      │                                │  │  │
│  │  │ Frontend: 10.20. │      │                                │  │  │
│  │  │   40.100         │      │                                │  │  │
│  │  └──────────────────┘      └────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs e Public IP que geram custo. Faca o cleanup assim que terminar.

---

### Task 6.1: Criar subnet e 2 VMs em Availability Set

Voce cria a infraestrutura de backend: uma subnet dedicada, um Availability Set e duas VMs Windows Server com IIS instalado.

**Criar subnet LBSubnet:**

1. Navegue para **CoreServicesVnet** (em az104-rg4) > **Subnets** > **+ Subnet**:

   | Setting          | Value        |
   | ---------------- | ------------ |
   | Name             | `LBSubnet`   |
   | Starting address | `10.20.40.0` |
   | Size             | `/24`        |

2. Clique em **Add**

**Criar Availability Set:**

3. Pesquise **Availability sets** > **+ Create**:

   | Setting        | Value                              |
   | -------------- | ---------------------------------- |
   | Resource group | `az104-rg6lb` (crie se necessario) |
   | Name           | `az104-avset-lb`                   |
   | Region         | **(US) East US**                   |
   | Fault domains  | `2`                                |
   | Update domains | `5`                                |

4. **Review + create** > **Create**

   > **Conceito:** Availability Sets distribuem VMs entre fault domains (racks fisicos diferentes) e update domains (reinicializacoes planejadas escalonadas). O Load Balancer Standard requer que as VMs estejam em um Availability Set, Availability Zone ou VMSS para o backend pool.

**Criar LB-VM1:**

5. Pesquise **Virtual Machines** > **Create** > **Virtual machine**

6. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `az104-rg6lb`                                 |
   | Virtual machine name | `LB-VM1`                                      |
   | Region               | **(US) East US**                              |
   | Availability options | **Availability set**                          |
   | Availability set     | `az104-avset-lb`                              |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

7. **Next: Disks >** (aceite defaults) > **Next: Networking >**

8. Networking:

   | Setting         | Value                               |
   | --------------- | ----------------------------------- |
   | Virtual network | **CoreServicesVnet** (de az104-rg4) |
   | Subnet          | **LBSubnet (10.20.40.0/24)**        |
   | Public IP       | **None**                            |
   | NIC NSG         | **None**                            |

9. **Monitoring** > **Disable** Boot diagnostics

10. **Review + create** > **Create** > **Nao espere** — continue

**Criar LB-VM2:**

11. Repita os passos 5-10 com:

    | Setting              | Value                |
    | -------------------- | -------------------- |
    | Virtual machine name | `LB-VM2`             |
    | Availability set     | `az104-avset-lb`     |
    | Demais settings      | *identicos a LB-VM1* |

12. **Aguarde ambas as VMs serem provisionadas**

**Instalar IIS em ambas as VMs:**

13. Navegue para **LB-VM1** > **Operations** > **Run command** > **RunPowerShellScript**

14. Execute:

    ```powershell
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    Remove-Item 'C:\inetpub\wwwroot\iisstart.htm'
    Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value $('Hello from ' + $env:computername)
    ```

15. Repita na **LB-VM2** com o mesmo script

    > **Conceito:** O script instala IIS e cria uma pagina customizada que exibe o hostname. Isso permite verificar visualmente qual VM esta respondendo ao trafego balanceado.

    > **Conexao com Bloco 5:** Assim como no Bloco 5, as VMs sao implantadas em subnets da CoreServicesVnet (az104-rg4), demonstrando cross-resource-group deployment.

---

### Task 6.2: Criar Public Load Balancer

1. Pesquise **Load balancers** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource group | `az104-rg6lb`    |
   | Name           | `az104-pub-lb`   |
   | Region         | **(US) East US** |
   | SKU            | **Standard**     |
   | Type           | **Public**       |
   | Tier           | **Regional**     |

3. Aba **Frontend IP configuration** > **+ Add a frontend IP configuration**:

   | Setting           | Value                                                     |
   | ----------------- | --------------------------------------------------------- |
   | Name              | `lb-frontend`                                             |
   | IP version        | **IPv4**                                                  |
   | IP type           | **IP address**                                            |
   | Public IP address | **Create new**: `az104-lb-pip` (Standard, Zone-redundant) |

4. Clique em **Add**

5. Aba **Backend pools** > **+ Add a backend pool**:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Name            | `lb-backend-pool`    |
   | Virtual network | **CoreServicesVnet** |

6. Clique em **+ Add** > selecione **LB-VM1** e **LB-VM2** > **Add**

7. Aba **Inbound rules** > **+ Add a load balancing rule**:

   | Setting               | Value             |
   | --------------------- | ----------------- |
   | Name                  | `http-rule`       |
   | IP Version            | **IPv4**          |
   | Frontend IP address   | `lb-frontend`     |
   | Backend pool          | `lb-backend-pool` |
   | Protocol              | **TCP**           |
   | Port                  | `80`              |
   | Backend port          | `80`              |
   | Health probe          | **Create new**    |
   | Health probe name     | `http-probe`      |
   | Health probe protocol | **HTTP**          |
   | Health probe port     | `80`              |
   | Health probe path     | `/`               |
   | Session persistence   | **None**          |

8. Clique em **Add** (regra) > **Review + create** > **Create**

   > **Conceito:** O Load Balancer Standard e zone-aware, suporta apenas backend pools na mesma VNet, e requer NSG explicito para permitir trafego (diferente do Basic que permite por padrao). Health probes verificam periodicamente a saude dos backends — se uma VM falhar no probe, ela e removida da rotacao.

   > **Dica AZ-104:** Standard LB requer Standard SKU Public IP. Standard LB bloqueia trafego por padrao — voce precisa de NSG para permitir. Basic LB esta sendo descontinuado.

---

### Task 6.3: Permitir trafego e testar balanceamento

O Standard Load Balancer bloqueia trafego por padrao. Voce precisa de um NSG para permitir trafego HTTP.

**Criar NSG para LBSubnet:**

1. Pesquise **Network security groups** > **+ Create**:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource group | `az104-rg6lb` |
   | Name           | `nsg-lb`      |
   | Region         | **East US**   |

2. **Review + create** > **Create** > **Go to resource**

3. **Inbound security rules** > **+ Add**:

   | Setting                 | Value       |
   | ----------------------- | ----------- |
   | Source                  | **Any**     |
   | Source port ranges      | `*`         |
   | Destination             | **Any**     |
   | Service                 | **HTTP**    |
   | Destination port ranges | `80`        |
   | Protocol                | **TCP**     |
   | Action                  | **Allow**   |
   | Priority                | `100`       |
   | Name                    | `AllowHTTP` |

4. Clique em **Add**

5. **Settings** > **Subnets** > **+ Associate**:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Virtual network | **CoreServicesVnet** |
   | Subnet          | **LBSubnet**         |

6. Clique em **OK**

**Testar balanceamento:**

7. Navegue para **az104-pub-lb** > **Overview** > copie o **Frontend IP address** (IP publico)

8. Abra o IP no navegador — voce vera "Hello from LB-VM1" ou "Hello from LB-VM2"

9. Faca **hard refresh** (Ctrl+Shift+R) varias vezes — o nome do servidor deve alternar entre LB-VM1 e LB-VM2

   > **Conceito:** Com session persistence = None, o LB distribui requisicoes usando hash de 5-tupla (source IP, source port, dest IP, dest port, protocol). Hard refresh gera source ports diferentes, resultando em distribuicao entre backends.

### Task 6.3b: Testar Session Persistence

Voce altera a configuracao de session persistence e observa o impacto no comportamento do balanceamento.

1. Navegue para **az104-pub-lb** > **Settings** > **Load balancing rules**

2. Clique na regra existente (ex: `az104-lb-rule`)

3. Altere **Session persistence** para **Client IP** > **Save**

4. Acesse o IP publico do LB no navegador e faca refresh varias vezes

5. **Resultado esperado:** O **mesmo servidor** responde todas as vezes (pois o source IP e o mesmo)

6. Volte a regra e altere **Session persistence** para **Client IP and protocol** > **Save**

7. Teste novamente — comportamento similar ao Client IP para o mesmo protocolo

8. Reverta **Session persistence** para **None** > **Save**

9. Consulte a tabela comparativa dos 3 modos:

   | Modo                     | Hash baseado em                             | Uso tipico                              |
   | ------------------------ | ------------------------------------------- | --------------------------------------- |
   | **None** (5-tuple)       | Source IP, Source port, Dest IP, Dest port, Protocol | Distribuicao maxima, apps stateless     |
   | **Client IP** (2-tuple)  | Source IP, Dest IP                           | Apps que precisam de sessao por cliente  |
   | **Client IP and protocol** (3-tuple) | Source IP, Dest IP, Protocol     | Multiplos servicos no mesmo backend     |

   > **Dica AZ-104:** Na prova, session persistence e cobrada em cenarios praticos. "Usuarios reclamam que perdem sessao" → mude para Client IP. "Aplicacao stateless precisa de distribuicao uniforme" → use None. Lembre-se que None usa 5-tupla, nao round-robin puro.

---

### Task 6.4: Testar failover — parar uma VM

1. Navegue para **LB-VM1** > **Overview** > **Stop** > confirme

2. Aguarde 30-60 segundos (health probe interval + timeout)

3. Acesse o IP publico do LB no navegador — agora so deve mostrar "Hello from LB-VM2"

4. Faca refresh varias vezes — confirme que **apenas** LB-VM2 responde

5. Navegue para **az104-pub-lb** > **Insights** (ou **Monitoring** > **Metrics**):
   - Selecione metrica **Health Probe Status**
   - Observe que LB-VM1 mostra status 0 (unhealthy)

6. **Inicie LB-VM1 novamente** (Start) e aguarde o probe retornar a VM ao pool

   > **Conceito:** Quando uma VM falha no health probe, o LB para de enviar trafego para ela automaticamente. Quando a VM volta a responder, o LB a reincorpora ao pool. Isso garante alta disponibilidade sem intervencao manual.

---

### Task 6.5: Criar Internal Load Balancer

O Internal Load Balancer distribui trafego dentro da VNet, sem exposicao a internet. E usado para camadas de aplicacao internas (ex: servidores de aplicacao acessados apenas pelo frontend).

1. Pesquise **Load balancers** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource group | `az104-rg6lb`    |
   | Name           | `az104-int-lb`   |
   | Region         | **(US) East US** |
   | SKU            | **Standard**     |
   | Type           | **Internal**     |
   | Tier           | **Regional**     |

3. Aba **Frontend IP configuration** > **+ Add a frontend IP configuration**:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Name            | `int-lb-frontend`    |
   | Virtual network | **CoreServicesVnet** |
   | Subnet          | **LBSubnet**         |
   | Assignment      | **Static**           |
   | IP address      | `10.20.40.100`       |

4. Clique em **Add**

5. Aba **Backend pools** > **+ Add a backend pool**:

   | Setting         | Value                         |
   | --------------- | ----------------------------- |
   | Name            | `int-lb-backend`              |
   | Virtual network | **CoreServicesVnet**          |
   | VMs             | **LB-VM1** e **LB-VM2** (Add) |

6. Aba **Inbound rules** > **+ Add a load balancing rule**:

   | Setting             | Value                                                    |
   | ------------------- | -------------------------------------------------------- |
   | Name                | `int-http-rule`                                          |
   | Frontend IP address | `int-lb-frontend`                                        |
   | Backend pool        | `int-lb-backend`                                         |
   | Protocol            | **TCP**                                                  |
   | Port                | `80`                                                     |
   | Backend port        | `80`                                                     |
   | Health probe        | **Create new**: `int-http-probe` (HTTP, port 80, path /) |
   | Session persistence | **None**                                                 |

7. **Review + create** > **Create**

8. **Validacao:** A partir de qualquer VM na mesma VNet, voce pode acessar `http://10.20.40.100` e receber resposta das VMs backend

   > **Conceito:** Internal LB usa IP privado como frontend. E ideal para arquiteturas multi-tier onde camadas internas nao devem ser expostas a internet. Public e Internal LBs podem coexistir no mesmo backend pool.

   > **Dica AZ-104:** Na prova, diferencie: Public LB = trafego da internet para VMs; Internal LB = trafego entre tiers internos. Ambos Standard SKU suportam Availability Zones.

---

### Task 6.6: Troubleshoot — Health probe com erro

Voce simula um cenario de troubleshooting onde o health probe falha.

1. Navegue para **LB-VM1** > **Run command** > **RunPowerShellScript**

2. Execute o comando para parar o IIS:

   ```powershell
   Stop-Service -Name W3SVC -Force
   ```

3. Aguarde 30-60 segundos

4. Navegue para **az104-pub-lb** > **Monitoring** > **Metrics**:
   - Selecione metrica **Health Probe Status**
   - Filtre por **Backend IP Address** = IP da LB-VM1
   - Observe o status caindo para 0

5. Navegue para **az104-pub-lb** > **Backend pools** > **lb-backend-pool**:
   - Verifique o **Health Status** de cada VM
   - LB-VM1 deve aparecer como **Unhealthy**

6. **Diagnosticar:** Acesse o portal Network Watcher > **Connection troubleshoot**:

   | Setting          | Value                |
   | ---------------- | -------------------- |
   | Source           | **LB-VM2**           |
   | Destination type | **Specify manually** |
   | URI/IP           | IP privado de LB-VM1 |
   | Destination port | `80`                 |

7. Execute o diagnostico — deve mostrar **Unreachable** na porta 80

**Corrigir:**

8. Na **LB-VM1** > **Run command**:

   ```powershell
   Start-Service -Name W3SVC
   ```

9. Aguarde o health probe detectar a VM como saudavel novamente (~30 segundos)

   > **Conceito:** Health probes sao a base do failover automatico. Se o servico (IIS) para mas a VM continua running, o probe HTTP falha e a VM e removida do pool. Isso e diferente de parar a VM inteira — o probe detecta falhas no nivel da aplicacao.

   > **Dica AZ-104:** Na prova, cenarios de troubleshooting frequentes: (1) Backend unhealthy = verifique health probe + NSG, (2) Sem conectividade = verifique se NSG permite trafego do LB (source = AzureLoadBalancer), (3) Standard LB requer NSG explicito.

---

### Task 6.7: Implantar Azure Bastion

> **Dica de lab:** O deployment do Bastion leva ~15 minutos. Considere criar o Bastion como primeiro passo do bloco para aproveitar o tempo de espera executando outras tasks em paralelo.

O Azure Bastion permite acesso RDP/SSH as VMs diretamente pelo portal Azure, sem expor IPs publicos.

**Criar AzureBastionSubnet:**

1. Navegue para **CoreServicesVnet** (em az104-rg4) > **Subnets** > **+ Subnet**:

   | Setting          | Value                |
   | ---------------- | -------------------- |
   | Name             | `AzureBastionSubnet` |
   | Starting address | `10.20.30.0`         |
   | Size             | `/26`                |

   > **Conceito:** O nome da subnet DEVE ser exatamente `AzureBastionSubnet` — e um requisito do Azure. O tamanho minimo e /26 (64 IPs). O Bastion e implantado nesta subnet e injeta conectividade RDP/SSH via browser.

2. Clique em **Add**

**Criar Azure Bastion:**

3. Pesquise **Bastions** > **+ Create**:

   | Setting         | Value                                   |
   | --------------- | --------------------------------------- |
   | Resource group  | `az104-rg6lb`                           |
   | Name            | `az104-bastion`                         |
   | Region          | **(US) East US**                        |
   | Tier            | **Basic**                               |
   | Virtual network | **CoreServicesVnet**                    |
   | Subnet          | `AzureBastionSubnet` (auto-selecionado) |
   | Public IP       | **Create new**: `az104-bastion-pip`     |

4. **Review + create** > **Create**

   > **Nota:** O deployment do Bastion pode levar 5-10 minutos.

5. Apos o deploy, navegue para **LB-VM1** > **Overview** > clique em **Connect** > **Connect via Bastion**

6. Insira as credenciais:

   | Setting  | Value         |
   | -------- | ------------- |
   | Username | `localadmin`  |
   | Password | *senha da VM* |

7. Clique em **Connect** — uma sessao RDP abre no navegador

8. Verifique que voce esta conectado a LB-VM1 (hostname visivel no desktop)

9. Feche a sessao Bastion

   > **Conceito:** Azure Bastion elimina a necessidade de IP publico nas VMs e de regras NSG para RDP/SSH. A conexao e feita via TLS pelo portal Azure, com o trafego passando pela AzureBastionSubnet. Isso reduz a superficie de ataque significativamente.

   > **Dica AZ-104:** Na prova: Bastion requer subnet /26+ chamada `AzureBastionSubnet`, SKU Basic suporta RDP/SSH via portal, SKU Standard adiciona features como native client support e IP-based connection.

---

## Modo Desafio - Bloco 6

- [ ] Criar subnet `LBSubnet` (10.20.40.0/24) na CoreServicesVnet **(Bloco 4)**
- [ ] Criar Availability Set `az104-avset-lb` (2 FD, 5 UD)
- [ ] Criar 2 VMs (LB-VM1, LB-VM2) no Availability Set, sem IP publico
- [ ] Instalar IIS em ambas as VMs via Run Command
- [ ] Criar Public Load Balancer Standard com frontend IP, backend pool, health probe HTTP e regra
- [ ] Criar NSG `nsg-lb` com regra AllowHTTP e associar a LBSubnet
- [ ] Testar balanceamento (hard refresh no IP publico)
- [ ] Testar Session Persistence: Client IP (mesmo servidor) → Client IP and protocol → reverter para None
- [ ] Testar failover: parar VM1 → apenas VM2 responde → reiniciar VM1
- [ ] Criar Internal Load Balancer com frontend IP estatico (10.20.40.100)
- [ ] Troubleshoot: parar IIS → diagnosticar unhealthy → reiniciar IIS
- [ ] Criar `AzureBastionSubnet` (/26) e implantar Azure Bastion Basic
- [ ] Conectar a VM via Bastion (sem IP publico)

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce criou um Standard Load Balancer e adicionou VMs ao backend pool. O health probe mostra todas as VMs como healthy, mas os clientes nao conseguem acessar o servico. Qual a causa mais provavel?**

A) O Load Balancer Standard requer Availability Zones
B) Falta um NSG com regra permitindo trafego na porta do servico
C) O health probe esta configurado incorretamente
D) As VMs precisam de IP publico individual

<details>
<summary>Ver resposta</summary>

**Resposta: B) Falta um NSG com regra permitindo trafego na porta do servico**

O Standard Load Balancer bloqueia todo o trafego por padrao (diferente do Basic). Voce precisa de um NSG associado a subnet ou NIC com regra explicita permitindo o trafego na porta configurada na regra do LB.

</details>

### Questao 6.2
**Qual a diferenca entre Public Load Balancer e Internal Load Balancer?**

A) Public LB usa Basic SKU; Internal LB usa Standard SKU
B) Public LB distribui trafego da internet; Internal LB distribui trafego dentro da VNet
C) Internal LB nao suporta health probes
D) Public LB suporta apenas TCP; Internal LB suporta TCP e UDP

<details>
<summary>Ver resposta</summary>

**Resposta: B) Public LB distribui trafego da internet; Internal LB distribui trafego dentro da VNet**

Public LB tem frontend com IP publico e distribui trafego externo. Internal LB tem frontend com IP privado e distribui trafego entre camadas internas. Ambos suportam Standard SKU, health probes e TCP/UDP.

</details>

### Questao 6.3
**Voce precisa implantar Azure Bastion para acesso seguro as VMs. Qual requisito de subnet e obrigatorio?**

A) Uma subnet chamada `BastionSubnet` com tamanho minimo /28
B) Uma subnet chamada `AzureBastionSubnet` com tamanho minimo /26
C) Qualquer subnet com tamanho /24 ou maior
D) Uma subnet chamada `AzureBastionSubnet` com tamanho minimo /24

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma subnet chamada `AzureBastionSubnet` com tamanho minimo /26**

O Azure Bastion requer uma subnet com nome exato `AzureBastionSubnet` e tamanho minimo /26 (64 IPs). O nome e obrigatorio — o Azure nao aceita outro nome para a subnet do Bastion.

</details>

### Questao 6.4
**Uma VM no backend pool do Load Balancer esta com health probe status "Unhealthy". A VM esta running e acessivel via RDP. O que pode estar causando o problema?**

A) A VM nao tem IP publico
B) O servico monitorado pelo health probe (ex: IIS) nao esta respondendo na porta configurada
C) A VM esta em um Availability Set diferente
D) O Load Balancer precisa ser reiniciado

<details>
<summary>Ver resposta</summary>

**Resposta: B) O servico monitorado pelo health probe (ex: IIS) nao esta respondendo na porta configurada**

Health probes verificam a saude no nivel da aplicacao, nao da VM. Se a VM esta running mas o servico (IIS, nginx, etc.) esta parado ou nao responde na porta/path configurados, o probe falha e a VM e marcada como unhealthy.

</details>

### Questao 6.5
**Voce tem um Standard Load Balancer com 3 VMs no backend pool. Uma VM e marcada como unhealthy pelo health probe. O que acontece com o trafego destinado a essa VM?**

A) O trafego e enfileirado ate a VM voltar a ficar healthy
B) O trafego e redirecionado automaticamente para as VMs healthy restantes
C) O Load Balancer para de funcionar completamente
D) O trafego e descartado e o cliente recebe erro 503

<details>
<summary>Ver resposta</summary>

**Resposta: B) O trafego e redirecionado automaticamente para as VMs healthy restantes**

Quando uma VM falha no health probe, o Load Balancer para de enviar novas conexoes para ela e distribui o trafego entre as VMs restantes que estao healthy. Quando a VM volta a responder ao probe, ela e reincorporada ao pool automaticamente.

</details>

---

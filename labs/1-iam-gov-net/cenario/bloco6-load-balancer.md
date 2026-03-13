> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 7 - SSPR, Cost Management e NSG Effective Rules](bloco7-sspr-cost-nsg.md)

# Bloco 6 - Load Balancer e Azure Bastion

**Origem:** Lab 06 - Implement Traffic Management (parcial) + Azure Bastion
**Resource Groups utilizados:** `rg-contoso-network` (VNets do Bloco 4) + `rg-contoso-network` (Load Balancers, VMs, Bastion)

## Contexto

Com as VNets, NSGs e DNS configurados nos Blocos 4-5, a Contoso Corp precisa distribuir trafego entre servidores e garantir acesso seguro as VMs sem expor IPs publicos. Voce cria um Public Load Balancer para balancear trafego HTTP, um Internal Load Balancer para comunicacao entre camadas internas, e implanta o Azure Bastion para acesso administrativo seguro. As VMs deste bloco sao implantadas na vnet-contoso-hub do Bloco 4.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                          rg-contoso-network                          │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  vnet-contoso-hub (rg-contoso-network)                         │  │
│  │                                                                │  │
│  │  ┌─────────────────────┐   ┌────────────────────────────────┐  │  │
│  │  │ AzureBastionSubnet  │   │ snet-lb (NOVO)                 │  │  │
│  │  │ 10.20.30.0/26       │   │ 10.20.40.0/24                  │  │  │
│  │  │                     │   │                                │  │  │
│  │  │ Azure Bastion ──────│───│─→ Acesso seguro a vm-lb-01/VM2 │  │  │
│  │  └─────────────────────┘   │                                │  │  │
│  │                            │  ┌──────────┐  ┌──────────┐    │  │  │
│  │                            │  │ vm-lb-01 │  │ vm-lb-02 │    │  │  │
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

> **Nota:** Este bloco cria VMs, Load Balancers, Public IPs e Azure Bastion que geram custo. Faca o cleanup assim que terminar.

---

### Task 6.1: Criar subnet e 2 VMs em Availability Set

**O que estamos construindo:** A infraestrutura completa de backend para balanceamento de carga: uma subnet dedicada, um Availability Set (para resiliencia fisica) e duas VMs com IIS (web server). As duas VMs servirao como backend pool do Load Balancer.

**Por que duas VMs?** Um Load Balancer com apenas uma VM nao tem utilidade — o objetivo e distribuir trafego entre multiplas instancias para alta disponibilidade. Se uma VM falhar, a outra continua respondendo.

**Criar subnet snet-lb:**

1. Navegue para **vnet-contoso-hub** (em rg-contoso-network) > **Subnets** > **+ Subnet**:

   | Setting          | Value        |
   | ---------------- | ------------ |
   | Name             | `snet-lb`    |
   | Starting address | `10.20.40.0` |
   | Size             | `/24`        |

2. Clique em **Add**

**Criar Availability Set:**

3. Pesquise **Availability sets** > **+ Create**:

   | Setting        | Value                                     |
   | -------------- | ----------------------------------------- |
   | Resource group | `rg-contoso-network` (crie se necessario) |
   | Name           | `avail-contoso-lb`                        |
   | Region         | **(US) East US**                          |
   | Fault domains  | `2`                                       |
   | Update domains | `5`                                       |

4. **Review + create** > **Create**

   > **Conceito:** Availability Sets distribuem VMs entre fault domains (racks fisicos diferentes) e update domains (reinicializacoes planejadas escalonadas). No Standard Load Balancer, o requisito principal do backend pool e estar na mesma VNet; usar Availability Set/Zone melhora resiliencia, mas nao e requisito obrigatorio para participar do pool.

   > **Fault Domains vs Update Domains:**
   > - **Fault Domain (FD = 2):** As VMs ficam em racks fisicos diferentes. Se um rack falhar (problema eletrico, rede), apenas metade das VMs e afetada.
   > - **Update Domain (UD = 5):** Durante manutencoes planejadas do Azure, apenas 1/5 das VMs reinicia por vez, garantindo que as outras continuem operando.
   >
   > **Dica AZ-104:** Update Domains determinam quantas VMs podem reiniciar simultaneamente. Com UD=5 e 10 VMs, no maximo 2 VMs reiniciam ao mesmo tempo. A formula e: `VMs por UD = Total VMs / Update Domains`.

**Criar vm-lb-01:**

5. Pesquise **Virtual Machines** > **Create** > **Virtual machine**

6. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `rg-contoso-network`                          |
   | Virtual machine name | `vm-lb-01`                                    |
   | Region               | **(US) East US**                              |
   | Availability options | **Availability set**                          |
   | Availability set     | `avail-contoso-lb`                            |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

7. **Next: Disks >** (aceite defaults) > **Next: Networking >**

8. Networking:

   | Setting         | Value                                        |
   | --------------- | -------------------------------------------- |
   | Virtual network | **vnet-contoso-hub** (de rg-contoso-network) |
   | Subnet          | **snet-lb (10.20.40.0/24)**                  |
   | Public IP       | **None**                                     |
   | NIC NSG         | **None**                                     |

   > **Por que Public IP = None?** As VMs ficarao atras do Load Balancer — o acesso sera pelo IP do LB, nao por IPs individuais. Em producao, VMs de backend nunca devem ter IP publico proprio (acesso administrativo sera feito via Bastion na Task 6.7).

   > **Por que NIC NSG = None?** Vamos criar um NSG na subnet inteira (Task 6.3), o que e mais eficiente do que configurar NSG em cada NIC individualmente.

9. **Monitoring** > **Disable** Boot diagnostics

10. **Review + create** > **Create** > **Nao espere** — continue

**Criar vm-lb-02:**

11. Repita os passos 5-10 com:

    | Setting              | Value                  |
    | -------------------- | ---------------------- |
    | Virtual machine name | `vm-lb-02`             |
    | Availability set     | `avail-contoso-lb`     |
    | Demais settings      | *identicos a vm-lb-01* |

12. **Aguarde ambas as VMs serem provisionadas**

**Instalar IIS em ambas as VMs:**

13. Navegue para **vm-lb-01** > **Operations** > **Run command** > **RunPowerShellScript**

14. Execute:

    ```powershell
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    Remove-Item 'C:\inetpub\wwwroot\iisstart.htm'
    Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value $('Hello from ' + $env:computername)
    ```

15. Repita na **vm-lb-02** com o mesmo script

    > **Conceito:** O script instala IIS e cria uma pagina customizada que exibe o hostname. Isso permite verificar visualmente qual VM esta respondendo ao trafego balanceado.

    > **Conexao com Bloco 5:** Assim como no Bloco 5, as VMs sao implantadas em subnets da vnet-contoso-hub (rg-contoso-network), demonstrando cross-resource-group deployment.

---

### Task 6.2: Criar Public Load Balancer

**O que e um Load Balancer?** E um servico que distribui trafego de rede entre multiplas VMs. O cliente envia a requisicao para o IP do Load Balancer, e ele decide para qual VM encaminhar. Se uma VM falhar, o LB para de enviar trafego para ela automaticamente.

**Analogia:** Pense num recepcionista de hospital que distribui pacientes entre os medicos disponiveis. Se um medico sai de ferias (VM unhealthy), o recepcionista para de encaminhar pacientes para ele.

> **Conceito:** O Load Balancer Standard (que usaremos) tem algumas diferencas criticas em relacao ao Basic: (1) bloqueia trafego por padrao — exige NSG explicito, (2) suporta Availability Zones, (3) requer Standard SKU Public IP. O Basic LB entrou em retirement e nao e mais recomendado.

1. Pesquise **Load balancers** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value                |
   | -------------- | -------------------- |
   | Resource group | `rg-contoso-network` |
   | Name           | `lbe-contoso-web`    |
   | Region         | **(US) East US**     |
   | SKU            | **Standard**         |
   | Type           | **Public**           |
   | Tier           | **Regional**         |

3. Aba **Frontend IP configuration** > **+ Add a frontend IP configuration**:

   | Setting           | Value                                                            |
   | ----------------- | ---------------------------------------------------------------- |
   | Name              | `fe-lbe-web`                                                     |
   | IP version        | **IPv4**                                                         |
   | IP type           | **IP address**                                                   |
   | Public IP address | **Create new**: `pip-lbe-contoso-web` (Standard, Zone-redundant) |

   > **Frontend IP** e o "endereco de entrada" do Load Balancer — e esse IP que os clientes acessam. Zone-redundant significa que o IP sobrevive a falha de uma zona de disponibilidade.

4. Clique em **Add**

5. Aba **Backend pools** > **+ Add a backend pool**:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Name            | `bp-lbe-web`         |
   | Virtual network | **vnet-contoso-hub** |

6. Clique em **+ Add** > selecione **vm-lb-01** e **vm-lb-02** > **Add**

7. Aba **Inbound rules** > **+ Add a load balancing rule**:

   | Setting               | Value          |
   | --------------------- | -------------- |
   | Name                  | `http-rule`    |
   | IP Version            | **IPv4**       |
   | Frontend IP address   | `fe-lbe-web`   |
   | Backend pool          | `bp-lbe-web`   |
   | Protocol              | **TCP**        |
   | Port                  | `80`           |
   | Backend port          | `80`           |
   | Health probe          | **Create new** |
   | Health probe name     | `http-probe`   |
   | Health probe protocol | **HTTP**       |
   | Health probe port     | `80`           |
   | Health probe path     | `/`            |
   | Session persistence   | **None**       |

   > **Campos importantes explicados:**
   > - **Port vs Backend port:** Port e a porta que o cliente acessa (frontend). Backend port e a porta onde a VM escuta. Podem ser diferentes (ex: frontend 443, backend 8080).
   > - **Health probe path = `/`:** O LB faz um HTTP GET em `/` periodicamente. Se receber resposta 200, a VM esta saudavel.
   > - **Session persistence = None:** Cada requisicao pode ir para qualquer VM. Vamos testar outros modos na Task 6.3b.

8. Clique em **Add** (regra) > **Review + create** > **Create**

   > **Conceito:** O Load Balancer Standard e zone-aware, suporta apenas backend pools na mesma VNet, e requer NSG explicito para permitir trafego (diferente do Basic que permite por padrao). Health probes verificam periodicamente a saude dos backends — se uma VM falhar no probe, ela e removida da rotacao.

   > **Dica AZ-104:** Standard LB requer Standard SKU Public IP. Standard LB bloqueia trafego por padrao — voce precisa de NSG para permitir. Basic LB entrou em retirement em 30/09/2025.

---

### Task 6.3: Permitir trafego e testar balanceamento

**Por que esse passo e necessario?** O Standard Load Balancer opera com modelo "deny by default" — ele NAO permite trafego a menos que exista um NSG com regra explicita. Isso e diferente do antigo Basic LB, que permitia tudo. Sem esse NSG, mesmo com o LB configurado corretamente, nenhuma requisicao HTTP chegaria as VMs.

> **Conceito:** Essa e uma das pegadinhas mais comuns no AZ-104. Se o cenario descreve um Standard LB com VMs saudaveis mas sem conectividade, a causa mais provavel e falta de NSG.

**Criar NSG para snet-lb:**

1. Pesquise **Network security groups** > **+ Create**:

   | Setting        | Value                |
   | -------------- | -------------------- |
   | Resource group | `rg-contoso-network` |
   | Name           | `nsg-snet-lb`        |
   | Region         | **East US**          |

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
   | Virtual network | **vnet-contoso-hub** |
   | Subnet          | **snet-lb**          |

6. Clique em **OK**

**Testar balanceamento:**

7. Navegue para **lbe-contoso-web** > **Overview** > copie o **Frontend IP address** (IP publico)

8. Abra o IP no navegador — voce vera "Hello from vm-lb-01" ou "Hello from vm-lb-02"

9. Faca **hard refresh** (Ctrl+Shift+R) varias vezes — o nome do servidor deve alternar entre vm-lb-01 e vm-lb-02

   > **Conceito:** Com session persistence = None, o LB distribui requisicoes usando hash de 5-tupla (source IP, source port, dest IP, dest port, protocol). Hard refresh gera source ports diferentes, resultando em distribuicao entre backends.

### Task 6.3b: Testar Session Persistence

Voce altera a configuracao de session persistence e observa o impacto no comportamento do balanceamento.

1. Navegue para **lbe-contoso-web** > **Settings** > **Load balancing rules**

2. Clique na regra existente (ex: `rule-lbe-http`)

3. Altere **Session persistence** para **Client IP** > **Save**

4. Acesse o IP publico do LB no navegador e faca refresh varias vezes

5. **Resultado esperado:** O **mesmo servidor** responde todas as vezes (pois o source IP e o mesmo)

6. Volte a regra e altere **Session persistence** para **Client IP and protocol** > **Save**

7. Teste novamente — comportamento similar ao Client IP para o mesmo protocolo

8. Reverta **Session persistence** para **None** > **Save**

9. Consulte a tabela comparativa dos 3 modos:

   | Modo                                 | Hash baseado em                                      | Uso tipico                              |
   | ------------------------------------ | ---------------------------------------------------- | --------------------------------------- |
   | **None** (5-tuple)                   | Source IP, Source port, Dest IP, Dest port, Protocol | Distribuicao maxima, apps stateless     |
   | **Client IP** (2-tuple)              | Source IP, Dest IP                                   | Apps que precisam de sessao por cliente |
   | **Client IP and protocol** (3-tuple) | Source IP, Dest IP, Protocol                         | Multiplos servicos no mesmo backend     |

   > **Dica AZ-104:** Na prova, session persistence e cobrada em cenarios praticos. "Usuarios reclamam que perdem sessao" → mude para Client IP. "Aplicacao stateless precisa de distribuicao uniforme" → use None. Lembre-se que None usa 5-tupla, nao round-robin puro.

---

### Task 6.4: Testar failover — parar uma VM

**O que estamos testando:** O comportamento de failover automatico do Load Balancer. Quando uma VM para de responder ao health probe, o LB remove ela da rotacao automaticamente — sem intervencao manual. Quando a VM volta, ela e reincorporada.

1. Navegue para **vm-lb-01** > **Overview** > **Stop** > confirme

2. Aguarde 30-60 segundos (health probe interval + timeout)

3. Acesse o IP publico do LB no navegador — agora so deve mostrar "Hello from vm-lb-02"

4. Faca refresh varias vezes — confirme que **apenas** vm-lb-02 responde

5. Navegue para **lbe-contoso-web** > **Insights** (ou **Monitoring** > **Metrics**):
   - Selecione metrica **Health Probe Status**
   - Observe que vm-lb-01 mostra status 0 (unhealthy)

6. **Inicie vm-lb-01 novamente** (Start) e aguarde o probe retornar a VM ao pool

   > **Conceito:** Quando uma VM falha no health probe, o LB para de enviar trafego para ela automaticamente. Quando a VM volta a responder, o LB a reincorpora ao pool. Isso garante alta disponibilidade sem intervencao manual.

---

### Task 6.5: Criar Internal Load Balancer

**O que e e por que existe?** O Internal Load Balancer distribui trafego dentro da VNet, sem exposicao a internet. E usado em arquiteturas multi-tier: o Public LB recebe trafego da internet e distribui para web servers, que por sua vez enviam requisicoes para app servers atras de um Internal LB.

**Analogia:** Se o Public LB e a portaria do predio (recebe visitantes de fora), o Internal LB e o sistema de distribuicao de tarefas entre funcionarios dentro do predio — so funciona internamente.

> **Conceito:** A diferenca fundamental: Public LB tem frontend com IP publico; Internal LB tem frontend com IP privado. Ambos podem usar o mesmo backend pool — as mesmas VMs podem receber trafego de ambos os LBs simultaneamente.

1. Pesquise **Load balancers** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value                |
   | -------------- | -------------------- |
   | Resource group | `rg-contoso-network` |
   | Name           | `lbi-contoso-apps`   |
   | Region         | **(US) East US**     |
   | SKU            | **Standard**         |
   | Type           | **Internal**         |
   | Tier           | **Regional**         |

3. Aba **Frontend IP configuration** > **+ Add a frontend IP configuration**:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Name            | `fe-lbi-apps`        |
   | Virtual network | **vnet-contoso-hub** |
   | Subnet          | **snet-lb**          |
   | Assignment      | **Static**           |
   | IP address      | `10.20.40.100`       |

   > **Por que IP estatico?** Outros servicos (web servers, configuracoes de DNS) precisam apontar para esse IP. Se fosse dinamico, o IP poderia mudar e quebrar as referencias. Em producao, IPs de LBs internos sao quase sempre estaticos.

4. Clique em **Add**

5. Aba **Backend pools** > **+ Add a backend pool**:

   | Setting         | Value                             |
   | --------------- | --------------------------------- |
   | Name            | `bp-lbi-apps`                     |
   | Virtual network | **vnet-contoso-hub**              |
   | VMs             | **vm-lb-01** e **vm-lb-02** (Add) |

6. Aba **Inbound rules** > **+ Add a load balancing rule**:

   | Setting             | Value                                                    |
   | ------------------- | -------------------------------------------------------- |
   | Name                | `int-http-rule`                                          |
   | Frontend IP address | `fe-lbi-apps`                                            |
   | Backend pool        | `bp-lbi-apps`                                            |
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

**O que estamos simulando:** Um cenario real onde o servico (IIS) para de funcionar mas a VM continua ligada. Isso demonstra que health probes verificam a **aplicacao**, nao a VM. Uma VM "Running" com servico parado e marcada como "Unhealthy" pelo probe.

**Por que isso e importante para a prova:** O AZ-104 adora cenarios de troubleshooting com LB. A sequencia de diagnostico e: (1) verificar health probe status, (2) verificar NSG, (3) verificar se o servico esta rodando na porta correta.

1. Navegue para **vm-lb-01** > **Run command** > **RunPowerShellScript**

2. Execute o comando para parar o IIS:

   ```powershell
   Stop-Service -Name W3SVC -Force
   ```

3. Aguarde 30-60 segundos

4. Navegue para **lbe-contoso-web** > **Monitoring** > **Metrics**:
   - Selecione metrica **Health Probe Status**
   - Filtre por **Backend IP Address** = IP da vm-lb-01
   - Observe o status caindo para 0

5. Navegue para **lbe-contoso-web** > **Backend pools** > **bp-lbe-web**:
   - Verifique o **Health Status** de cada VM
   - vm-lb-01 deve aparecer como **Unhealthy**

6. **Diagnosticar:** Acesse o portal Network Watcher > **Connection troubleshoot**:

   | Setting          | Value                  |
   | ---------------- | ---------------------- |
   | Source           | **vm-lb-02**           |
   | Destination type | **Specify manually**   |
   | URI/IP           | IP privado de vm-lb-01 |
   | Destination port | `80`                   |

7. Execute o diagnostico — deve mostrar **Unreachable** na porta 80

**Corrigir:**

8. Na **vm-lb-01** > **Run command**:

   ```powershell
   Start-Service -Name W3SVC
   ```

9. Aguarde o health probe detectar a VM como saudavel novamente (~30 segundos)

   > **Conceito:** Health probes sao a base do failover automatico. Se o servico (IIS) para mas a VM continua running, o probe HTTP falha e a VM e removida do pool. Isso e diferente de parar a VM inteira — o probe detecta falhas no nivel da aplicacao.

   > **Dica AZ-104:** Na prova, cenarios de troubleshooting frequentes: (1) Backend unhealthy = verifique health probe + NSG, (2) Sem conectividade = verifique se NSG permite trafego do LB (source = AzureLoadBalancer), (3) Standard LB requer NSG explicito.

---

### Task 6.7: Implantar Azure Bastion

**O que e Azure Bastion?** E um servico PaaS que permite acesso RDP/SSH as VMs diretamente pelo navegador (portal Azure), sem precisar de IP publico nas VMs e sem precisar de cliente RDP local. O trafego entre voce e a VM passa por TLS dentro do datacenter do Azure.

**Por que usar Bastion em vez de IP publico + RDP?** Seguranca. Uma VM com IP publico e porta RDP (3389) aberta e alvo constante de ataques de forca bruta. Com Bastion, a VM nao tem IP publico e a porta 3389 nao e exposta na internet.

> **Dica de lab:** O deployment do Bastion leva ~15 minutos. Considere criar o Bastion como primeiro passo do bloco para aproveitar o tempo de espera executando outras tasks em paralelo.

**Criar AzureBastionSubnet:**

1. Navegue para **vnet-contoso-hub** (em rg-contoso-network) > **Subnets** > **+ Subnet**:

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
   | Resource group  | `rg-contoso-network`                    |
   | Name            | `bas-contoso-hub`                       |
   | Region          | **(US) East US**                        |
   | Tier            | **Basic**                               |
   | Virtual network | **vnet-contoso-hub**                    |
   | Subnet          | `AzureBastionSubnet` (auto-selecionado) |
   | Public IP       | **Create new**: `bas-contoso-hub-pip`   |

4. **Review + create** > **Create**

   > **Nota:** O deployment do Bastion pode levar 5-10 minutos.

5. Apos o deploy, navegue para **vm-lb-01** > **Overview** > clique em **Connect** > **Connect via Bastion**

6. Insira as credenciais:

   | Setting  | Value         |
   | -------- | ------------- |
   | Username | `localadmin`  |
   | Password | *senha da VM* |

7. Clique em **Connect** — uma sessao RDP abre no navegador

8. Verifique que voce esta conectado a vm-lb-01 (hostname visivel no desktop)

9. Feche a sessao Bastion

   > **Conceito:** Azure Bastion elimina a necessidade de IP publico nas VMs e de regras NSG para RDP/SSH. A conexao e feita via TLS pelo portal Azure, com o trafego passando pela AzureBastionSubnet. Isso reduz a superficie de ataque significativamente.

   > **Dica AZ-104:** Na prova: Bastion requer subnet /26+ chamada `AzureBastionSubnet`, SKU Basic suporta RDP/SSH via portal, SKU Standard adiciona features como native client support e IP-based connection.

---

## Modo Desafio - Bloco 6

- [ ] Criar subnet `snet-lb` (10.20.40.0/24) na vnet-contoso-hub **(Bloco 4)**
- [ ] Criar Availability Set `avail-contoso-lb` (2 FD, 5 UD)
- [ ] Criar 2 VMs (vm-lb-01, vm-lb-02) no Availability Set, sem IP publico
- [ ] Instalar IIS em ambas as VMs via Run Command
- [ ] Criar Public Load Balancer Standard com frontend IP, backend pool, health probe HTTP e regra
- [ ] Criar NSG `nsg-snet-lb` com regra AllowHTTP e associar a snet-lb
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

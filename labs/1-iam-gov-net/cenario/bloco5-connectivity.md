> Voltar para o [Cenario Contoso](../cenario-contoso.md)

# Bloco 5 - Intersite Connectivity

**Origem:** Lab 05 - Implement Intersite Connectivity + **integracoes com Blocos 1-4**
**Resource Groups utilizados:** `az104-rg5` (VMs e route tables) + `az104-rg4` (VNets do Bloco 4)

## Contexto

Este e o bloco final onde tudo se conecta. As VMs sao implantadas nas **VNets criadas no Bloco 4** (cross-resource-group), o DNS privado do Bloco 4 resolve nomes reais das VMs, e o RBAC configurado nos Blocos 1-2 e testado de ponta a ponta.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                az104-rg4 (VNets do Bloco 4)                         │
│                                                                     │
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  CoreServicesVnet            │  │  ManufacturingVnet          │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16               │  │
│  │                              │  │                             │  │
│  │  SharedServicesSubnet        │  │  SensorSubnet1 (Bloco 4)    │  │
│  │  10.20.10.0/24 (← NSG)       │  │  SensorSubnet2 (Bloco 4)    │  │
│  │  DatabaseSubnet              │  │                             │  │
│  │  10.20.20.0/24               │  │  Manufacturing (NOVO)       │  │
│  │                              │  │  10.30.0.0/24               │  │
│  │  Core (NOVO) ←──────────── peering ──────────→ ManufacturingVM│  │
│  │  10.20.0.0/24                │  │  (az104-rg5)                │  │
│  │  CoreServicesVM              │  └─────────────────────────────┘  │
│  │  (az104-rg5)                 │                                   │
│  │                              │                                   │
│  │  perimeter (NOVO)            │  ┌────────────────────────────┐   │
│  │  10.20.1.0/24                │  │ DNS: private.contoso.com   │   │
│  │  (NVA: 10.20.1.7)            │  │ + corevm → IP real da VM   │   │
│  └──────────────────────────────┘  │ + Link: CoreServicesVnet   │   │
│                                    └────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ az104-rg5                    │                                   │
│  │ (VMs + Route Table)          │                                   │
│  │                              │                                   │
│  │ • CoreServicesVM             │                                   │
│  │ • ManufacturingVM            │                                   │
│  │ • rt-CoreServices            │                                   │
│  └──────────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 5.1: Adicionar subnets para VMs nas VNets existentes

Antes de criar as VMs, adicione subnets dedicadas nas VNets do Bloco 4.

**Core subnet na CoreServicesVnet:**

1. Pesquise e selecione **Virtual Networks** > **CoreServicesVnet** (em az104-rg4)

2. **Subnets** > **+ Subnet**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `Core`      |
   | Starting address | `10.20.0.0` |
   | Size             | `/24`       |

3. Clique em **Add**

**Manufacturing subnet na ManufacturingVnet:**

4. Navegue para **ManufacturingVnet** (em az104-rg4)

5. **Subnets** > **+ Subnet**:

   | Setting          | Value           |
   | ---------------- | --------------- |
   | Name             | `Manufacturing` |
   | Starting address | `10.30.0.0`     |
   | Size             | `/24`           |

6. Clique em **Add**

   > **Conexao com Bloco 4:** Voce esta evoluindo as VNets criadas no Bloco 4, adicionando subnets para compute. Isso demonstra que VNets sao estruturas vivas que crescem conforme a necessidade.

---

### Task 5.2: Criar CoreServicesVM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. Pesquise **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `az104-rg5` (crie se necessario)              |
   | Virtual machine name | `CoreServicesVM`                              |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** (aceite defaults) > **Next: Networking >**

4. Para Virtual network, selecione **CoreServicesVnet** (de az104-rg4)

   > **Nota:** VMs podem referenciar VNets de outros Resource Groups. O dropdown mostra todas as VNets acessiveis na subscription.

5. Para Subnet, selecione **Core (10.20.0.0/24)**

6. Aba **Monitoring** > **Disable** Boot diagnostics

7. **Review + create** > **Create**

8. **Nao precisa esperar** — continue para a proxima task

---

### Task 5.3: Criar ManufacturingVM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `az104-rg5`                                   |
   | Virtual machine name | `ManufacturingVM`                             |
   | Region               | **(US) East US**                              |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** > **Next: Networking >**

4. Virtual network: **ManufacturingVnet** (de az104-rg4)

5. Subnet: **Manufacturing (10.30.0.0/24)**

6. **Monitoring** > **Disable** Boot diagnostics

7. **Review + create** > **Create**

8. **Aguarde ambas as VMs serem provisionadas** antes de continuar

---

### Task 5.4: Network Watcher — Connection Troubleshoot

1. Pesquise **Network Watcher** > **Connection troubleshoot**

2. Preencha:

   | Setting              | Value                        |
   | -------------------- | ---------------------------- |
   | Source type          | **Virtual machine**          |
   | Virtual machine      | **CoreServicesVM**           |
   | Destination type     | **Select a virtual machine** |
   | Virtual machine      | **ManufacturingVM**          |
   | Preferred IP Version | **Both**                     |
   | Protocol             | **TCP**                      |
   | Destination port     | `3389`                       |

3. **Run diagnostic tests**

4. **Resultado esperado:** Connectivity test = **Unreachable**

   > **Conceito:** VNets diferentes NAO se comunicam por padrao, mesmo estando no mesmo RG ou sendo gerenciadas pela mesma subscription.

---

### Task 5.5: Configurar VNet Peering bidirecional

Peering entre as VNets **do Bloco 4** para habilitar comunicacao.

1. Navegue para **CoreServicesVnet** (em az104-rg4)

2. **Settings** > **Peerings** > **+ Add**:

   | Setting                                          | Value                                   |
   | ------------------------------------------------ | --------------------------------------- |
   | **This virtual network**                         |                                         |
   | Peering link name                                | `CoreServicesVnet-to-ManufacturingVnet` |
   | Allow access to 'ManufacturingVnet'              | **selected**                            |
   | Allow forwarded traffic from 'ManufacturingVnet' | **selected**                            |
   | **Remote virtual network**                       |                                         |
   | Peering link name                                | `ManufacturingVnet-to-CoreServicesVnet` |
   | Virtual network                                  | **ManufacturingVnet (az104-rg4)**       |
   | Allow access to 'CoreServicesVnet'               | **selected**                            |
   | Allow forwarded traffic from 'CoreServicesVnet'  | **selected**                            |

3. Clique em **Add**

4. **Refresh** ate Peering status = **Connected** em ambas as VNets

   > **Conceito:** VNet Peering e **NAO transitivo**. Se A↔B e B↔C, A nao se comunica com C automaticamente.

---

### Task 5.6: Testar conexao via Run Command

1. Navegue para **CoreServicesVM** > **Overview** > anote o **Private IP address**

2. Navegue para **ManufacturingVM** > **Operations** > **Run command** > **RunPowerShellScript**

3. Execute:

   ```powershell
   Test-NetConnection <CoreServicesVM-private-IP> -port 3389
   ```

4. **Resultado esperado:** `TcpTestSucceeded: True`

   > O peering funciona! As VMs se comunicam pela rede backbone da Microsoft.

### Task 5.6b: Testar nao-transitividade do peering

Voce valida que o peering NAO e transitivo — se VNet A conecta a VNet B, e VNet B conecta a VNet C, A nao alcanca C automaticamente.

1. Navegue para **ManufacturingVM** > **Operations** > **Run command** > **RunPowerShellScript**

2. Tente conectar a um IP que estaria em uma terceira VNet hipotetica (fora do range de ambas as VNets):

   ```powershell
   Test-NetConnection 10.40.0.4 -port 3389
   ```

3. **Resultado esperado:** `TcpTestSucceeded: False` — o pacote nao tem rota para essa rede

4. Isso demonstra que peering e **ponto a ponto**: cada par de VNets precisa de seu proprio peering

   > **Conceito:** O VNet peering NAO e transitivo. Se voce tem VNet A ↔ VNet B e VNet B ↔ VNet C, a VNet A NAO consegue se comunicar com VNet C automaticamente. Para resolver isso, use topologia **hub-spoke**: uma VNet central (hub) conecta a todas as outras (spokes), e o hub roteia trafego entre spokes usando NVA ou Azure Firewall com "Allow Gateway Transit" e "Use Remote Gateways".

   > **Dica AZ-104:** Na prova, questoes sobre transitividade de peering sao frequentes. Lembre-se: (1) peering nao e transitivo, (2) hub-spoke resolve com NVA/Firewall no hub, (3) "Allow Gateway Transit" permite compartilhar VPN gateway entre VNets peered, (4) cada peering e configurado independentemente nos dois lados.

---

### Task 5.7: Teste de integracao — DNS privado com IP real da VM

Voce atualiza a zona DNS privada do **Bloco 4** com o IP real da CoreServicesVM e testa a resolucao.

1. Navegue para a zona **private.contoso.com** (em az104-rg4)

2. Primeiro, adicione um **Virtual network link** para CoreServicesVnet:

   | Setting         | Value               |
   | --------------- | ------------------- |
   | Link name       | `coreservices-link` |
   | Virtual network | `CoreServicesVnet`  |

3. Clique em **Create** e aguarde

4. Em **Recordsets**, adicione um novo registro com o IP **real** da CoreServicesVM:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Name       | `corevm`                       |
   | Type       | **A**                          |
   | TTL        | `1`                            |
   | IP address | *IP privado da CoreServicesVM* |

5. Clique em **Add**

6. Agora teste a resolucao a partir da **ManufacturingVM**. Va para **ManufacturingVM** > **Run command** > **RunPowerShellScript**:

   ```powershell
   Resolve-DnsName corevm.private.contoso.com
   ```

7. **Resultado esperado:** O comando retorna o IP privado da CoreServicesVM

   > **Conexao com Bloco 4:** A zona DNS privada criada no Bloco 4 agora resolve nomes reais de VMs do Bloco 5. A ManufacturingVnet (linkada no Bloco 4) e a CoreServicesVnet (linkada agora) podem resolver nomes nesta zona.

---

### Task 5.8: Criar subnet perimeter, Route Table e custom route

**Criar subnet perimeter:**

1. Navegue para **CoreServicesVnet** (em az104-rg4) > **Subnets** > **+ Subnet**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `perimeter` |
   | Starting address | `10.20.1.0` |
   | Size             | `/24`       |

2. Clique em **Add**

**Criar Route Table:**

3. Pesquise **Route tables** > **+ Create**:

   | Setting                  | Value              |
   | ------------------------ | ------------------ |
   | Subscription             | *sua subscription* |
   | Resource group           | `az104-rg5`        |
   | Region                   | **East US**        |
   | Name                     | `rt-CoreServices`  |
   | Propagate gateway routes | **No**             |

4. **Review + create** > **Create**

**Criar custom route:**

5. Navegue para **rt-CoreServices** > **Settings** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `PerimetertoCore`     |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.20.0.0/16`        |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.20.1.7`           |

6. Clique em **Add**

**Associar route table a subnet:**

7. **Subnets** > **+ Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg4)** |
   | Subnet          | **Core**                         |

8. Clique em **OK**

   > **Conceito:** UDRs sobrescrevem rotas do sistema. O next hop "Virtual appliance" direciona trafego para um NVA (firewall, proxy). Se o NVA nao existir no IP configurado, o trafego e **descartado**.

---

### Task 5.9: Teste de integracao — Verificar isolamento NSG por subnet

Este teste confirma que o NSG do Bloco 4 afeta apenas a subnet associada.

1. Lembre-se: o NSG **myNSGSecure** esta associado a **SharedServicesSubnet** (Bloco 4)

2. A CoreServicesVM esta na subnet **Core** (sem NSG associado)

3. A ManufacturingVM esta na subnet **Manufacturing** (sem NSG associado)

4. Verifique: navegue para **myNSGSecure** (az104-rg4) > **Subnets**

5. Confirme que apenas **SharedServicesSubnet** esta listada

   > **Validacao:** As VMs NAO sao afetadas pelo NSG porque estao em subnets diferentes. NSGs sao associados a **subnets ou NICs**, nao a VNets inteiras. Se voce quisesse proteger as VMs, precisaria associar o NSG (ou outro) as subnets Core e Manufacturing tambem.

---

### Task 5.10: Teste de integracao final — RBAC de ponta a ponta

Teste final que valida todo o RBAC configurado desde o Bloco 1.

1. Abra uma janela **InPrivate/Incognito**

2. Faca login como **az104-user1** (senha salva no Bloco 1)

3. Navegue para **Virtual Machines**

4. Voce deve ver **CoreServicesVM** e **ManufacturingVM**

5. Selecione **CoreServicesVM** > tente **Stop** (desligar) a VM — deve **funcionar** (VM Contributor permite)

6. Tente deletar o resource group **az104-rg2** — deve **falhar** por dois motivos:
   - az104-user1 nao tem Contributor/Owner no RG
   - O resource lock (Delete) do Bloco 2 impede a exclusao

7. Navegue para **Storage Accounts** > tente criar um — deve **falhar** (VM Contributor nao inclui permissoes de Storage)

   > **Validacao completa:**
   > - **Bloco 1:** Identidade criada ✓
   > - **Bloco 2:** RBAC (VM Contributor) funciona + Lock protege ✓
   > - **Bloco 5:** az104-user1 gerencia VMs mas nao outros recursos ✓

8. **Se parou a VM no passo 5**, inicie-a novamente antes de fechar

9. Feche a janela InPrivate

---

## Modo Desafio - Bloco 5

- [ ] Adicionar subnet `Core` (10.20.0.0/24) na CoreServicesVnet **(Bloco 4)**
- [ ] Adicionar subnet `Manufacturing` (10.30.0.0/24) na ManufacturingVnet **(Bloco 4)**
- [ ] Criar `CoreServicesVM` em az104-rg5, na subnet Core da **VNet do Bloco 4**
- [ ] Criar `ManufacturingVM` em az104-rg5, na subnet Manufacturing da **VNet do Bloco 4**
- [ ] Network Watcher → Unreachable
- [ ] Configurar VNet Peering bidirecional entre VNets **do Bloco 4**
- [ ] Test-NetConnection → Success
- [ ] Testar nao-transitividade: Test-NetConnection para IP fora das VNets (10.40.0.4) → False
- [ ] **Integracao:** Adicionar link DNS + registro A com IP real → Resolve-DnsName da ManufacturingVM
- [ ] Criar subnet `perimeter` + Route Table + custom route (NVA 10.20.1.7)
- [ ] **Integracao:** Verificar NSG isolado por subnet
- [ ] **Integracao final:** Login como az104-user1 → gerenciar VM ✓, criar Storage ✗

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Uma VM no az104-rg5 usa uma VNet do az104-rg4. E possivel?**

A) Nao, VMs e VNets devem estar no mesmo Resource Group
B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription
C) Sim, mas apenas via ARM template
D) Nao, a VNet precisa ser movida para o mesmo RG

<details>
<summary>Ver resposta</summary>

**Resposta: B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription**

No Azure, VMs e VNets nao precisam estar no mesmo RG. Voce pode organizar recursos em RGs diferentes conforme a funcao (networking, compute, etc.) e referencia-los entre si.

</details>

### Questao 5.2
**VNet A tem peering com VNet B. VNet B tem peering com VNet C. VNet A se comunica com VNet C?**

A) Sim, peering e transitivo
B) Nao, peering NAO e transitivo — precisa de peering direto A↔C
C) Sim, se forwarded traffic estiver habilitado
D) Nao, precisa de VPN Gateway

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, peering NAO e transitivo**

Peering nao e transitivo. Para A↔C, crie peering direto ou use hub-spoke com NVA/VPN Gateway.

</details>

### Questao 5.3
**Voce criou uma UDR com next hop "Virtual appliance" IP 10.20.1.7, mas nao ha NVA nesse IP. O que acontece com o trafego?**

A) Roteado normalmente, ignorando a regra
B) Descartado (dropped)
C) Azure cria um NVA automaticamente
D) Redirecionado para o gateway padrao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Descartado (dropped)**

UDRs sobrescrevem rotas do sistema. Se o next hop nao for alcancavel, o trafego e descartado sem fallback.

</details>

### Questao 5.4
**Voce configurou VNet Peering entre CoreServicesVnet e ManufacturingVnet. Voce quer que o trafego da ManufacturingVM passe por um NVA na CoreServicesVnet antes de alcançar a CoreServicesVM. O que voce precisa configurar alem do peering?**

A) Apenas um NSG na subnet de destino
B) Uma User-Defined Route (UDR) na subnet da ManufacturingVM com next hop apontando para o NVA
C) Habilitar IP forwarding no NVA e nada mais
D) Criar um VPN Gateway entre as VNets

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma User-Defined Route (UDR) na subnet da ManufacturingVM com next hop apontando para o NVA**

Para forcar trafego atraves de um NVA, voce precisa criar uma UDR na subnet de origem com o next hop tipo "Virtual appliance" apontando para o IP do NVA. Alem disso, o NVA precisa ter **IP forwarding** habilitado na NIC. Apenas o peering nao e suficiente — ele habilita conectividade direta, mas nao roteia trafego atraves de intermediarios.

</details>

### Questao 5.5
**Voce criou uma Private DNS Zone `private.contoso.com` e vinculou (Virtual Network Link) apenas a VNet A. Uma VM na VNet B (que tem peering com VNet A) tenta resolver `sensorvm.private.contoso.com`. O que acontece?**

A) A resolucao funciona porque o peering compartilha DNS automaticamente
B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada
C) A resolucao funciona se o peering tiver "Allow forwarded traffic" habilitado
D) A resolucao funciona apenas se a VM usar um DNS forwarder na VNet A

<details>
<summary>Ver resposta</summary>

**Resposta: B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada**

Private DNS Zones resolvem nomes **apenas** para VNets que possuem um Virtual Network Link configurado. O VNet Peering nao propaga resolucao DNS automaticamente. Para que VMs na VNet B resolvam nomes da zona privada, voce precisa criar um Virtual Network Link adicional para a VNet B, ou configurar um DNS forwarder customizado.

</details>

---

> Voltar para o [Cenario Contoso](../cenario-contoso.md)

# Bloco 5 - Intersite Connectivity

**Origem:** Lab 05 - Implement Intersite Connectivity + **integracoes com Blocos 1-4**
**Resource Groups utilizados:** `rg-contoso-compute` (VMs e route tables) + `rg-contoso-network` (VNets do Bloco 4)

## Contexto

Este e o bloco final onde tudo se conecta. As VMs sao implantadas nas **VNets criadas no Bloco 4** (cross-resource-group), o DNS privado do Bloco 4 resolve nomes reais das VMs, e o RBAC configurado nos Blocos 1-2 e testado de ponta a ponta.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                rg-contoso-network (VNets do Bloco 4)                         │
│                                                                     │
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  vnet-contoso-hub-brazilsouth            │  │  vnet-contoso-spoke-brazilsouth          │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16               │  │
│  │                              │  │                             │  │
│  │  snet-shared        │  │  SensorSubnet1 (Bloco 4)    │  │
│  │  10.20.10.0/24 (← NSG)       │  │  SensorSubnet2 (Bloco 4)    │  │
│  │  snet-data              │  │                             │  │
│  │  10.20.20.0/24               │  │  snet-workloads (NOVO)      │  │
│  │                              │  │  10.30.0.0/24               │  │
│  │  snet-apps (NOVO) ←──────── peering ──────────→ vm-app-01│  │
│  │  10.20.0.0/24                │  │  (rg-contoso-compute)                │  │
│  │  vm-web-01              │  └─────────────────────────────┘  │
│  │  (rg-contoso-compute)                 │                                   │
│  │                              │                                   │
│  │  perimeter (NOVO)            │  ┌────────────────────────────┐   │
│  │  10.20.1.0/24                │  │ DNS: contoso.internal   │   │
│  │  (NVA: 10.20.1.7)            │  │ + corevm → IP real da VM   │   │
│  └──────────────────────────────┘  │ + Link: vnet-contoso-hub-brazilsouth   │   │
│                                    └────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ rg-contoso-compute                    │                                   │
│  │ (VMs + Route Table)          │                                   │
│  │                              │                                   │
│  │ • vm-web-01             │                                   │
│  │ • vm-app-01            │                                   │
│  │ • rt-contoso-spoke            │                                   │
│  └──────────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 5.1: Adicionar subnets para VMs nas VNets existentes

Antes de criar as VMs, adicione subnets dedicadas nas VNets do Bloco 4.

**snet-apps subnet na vnet-contoso-hub-brazilsouth:**

1. Pesquise e selecione **Virtual Networks** > **vnet-contoso-hub-brazilsouth** (em rg-contoso-network)

2. **Subnets** > **+ Subnet**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `snet-apps` |
   | Starting address | `10.20.0.0` |
   | Size             | `/24`       |

3. Clique em **Add**

**snet-workloads subnet na vnet-contoso-spoke-brazilsouth:**

4. Navegue para **vnet-contoso-spoke-brazilsouth** (em rg-contoso-network)

5. **Subnets** > **+ Subnet**:

   | Setting          | Value           |
   | ---------------- | --------------- |
   | Name             | `snet-workloads` |
   | Starting address | `10.30.0.0`     |
   | Size             | `/24`           |

6. Clique em **Add**

   > **Conexao com Bloco 4:** Voce esta evoluindo as VNets criadas no Bloco 4, adicionando subnets para compute. Isso demonstra que VNets sao estruturas vivas que crescem conforme a necessidade.

---

### Task 5.2: Criar vm-web-01

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. Pesquise **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `rg-contoso-compute` (crie se necessario)              |
   | Virtual machine name | `vm-web-01`                              |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** (aceite defaults) > **Next: Networking >**

4. Para Virtual network, selecione **vnet-contoso-hub-brazilsouth** (de rg-contoso-network)

   > **Nota:** VMs podem referenciar VNets de outros Resource Groups. O dropdown mostra todas as VNets acessiveis na subscription.

5. Para Subnet, selecione **snet-apps (10.20.0.0/24)**

6. Aba **Monitoring** > **Disable** Boot diagnostics

7. **Review + create** > **Create**

8. **Nao precisa esperar** — continue para a proxima task

---

### Task 5.3: Criar vm-app-01

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `rg-contoso-compute`                                   |
   | Virtual machine name | `vm-app-01`                             |
   | Region               | **(US) East US**                              |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** > **Next: Networking >**

4. Virtual network: **vnet-contoso-spoke-brazilsouth** (de rg-contoso-network)

5. Subnet: **snet-workloads (10.30.0.0/24)**

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
   | Virtual machine      | **vm-web-01**           |
   | Destination type     | **Select a virtual machine** |
   | Virtual machine      | **vm-app-01**          |
   | Preferred IP Version | **Both**                     |
   | Protocol             | **TCP**                      |
   | Destination port     | `3389`                       |

3. **Run diagnostic tests**

4. **Resultado esperado:** Connectivity test = **Unreachable**

   > **Conceito:** VNets diferentes NAO se comunicam por padrao, mesmo estando no mesmo RG ou sendo gerenciadas pela mesma subscription.

---

### Task 5.5: Configurar VNet Peering bidirecional

Peering entre as VNets **do Bloco 4** para habilitar comunicacao.

1. Navegue para **vnet-contoso-hub-brazilsouth** (em rg-contoso-network)

2. **Settings** > **Peerings** > **+ Add**:

   | Setting                                          | Value                                   |
   | ------------------------------------------------ | --------------------------------------- |
   | **This virtual network**                         |                                         |
   | Peering link name                                | `vnet-contoso-hub-brazilsouth-to-vnet-contoso-spoke-brazilsouth` |
   | Allow access to 'vnet-contoso-spoke-brazilsouth'              | **selected**                            |
   | Allow forwarded traffic from 'vnet-contoso-spoke-brazilsouth' | **selected**                            |
   | **Remote virtual network**                       |                                         |
   | Peering link name                                | `vnet-contoso-spoke-brazilsouth-to-vnet-contoso-hub-brazilsouth` |
   | Virtual network                                  | **vnet-contoso-spoke-brazilsouth (rg-contoso-network)**       |
   | Allow access to 'vnet-contoso-hub-brazilsouth'               | **selected**                            |
   | Allow forwarded traffic from 'vnet-contoso-hub-brazilsouth'  | **selected**                            |

3. Clique em **Add**

4. **Refresh** ate Peering status = **Connected** em ambas as VNets

   > **Conceito:** VNet Peering e **NAO transitivo**. Se A↔B e B↔C, A nao se comunica com C automaticamente.

---

### Task 5.6: Testar conexao via Run Command

1. Navegue para **vm-web-01** > **Overview** > anote o **Private IP address**

2. Navegue para **vm-app-01** > **Operations** > **Run command** > **RunPowerShellScript**

3. Execute:

   ```powershell
   Test-NetConnection <vm-web-01-private-IP> -port 3389
   ```

4. **Resultado esperado:** `TcpTestSucceeded: True`

   > O peering funciona! As VMs se comunicam pela rede backbone da Microsoft.

### Task 5.6b: Testar nao-transitividade do peering

Voce valida que o peering NAO e transitivo — se VNet A conecta a VNet B, e VNet B conecta a VNet C, A nao alcanca C automaticamente.

1. Navegue para **vm-app-01** > **Operations** > **Run command** > **RunPowerShellScript**

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

Voce atualiza a zona DNS privada do **Bloco 4** com o IP real da vm-web-01 e testa a resolucao.

1. Navegue para a zona **contoso.internal** (em rg-contoso-network)

2. Primeiro, adicione um **Virtual network link** para vnet-contoso-hub-brazilsouth:

   | Setting         | Value               |
   | --------------- | ------------------- |
   | Link name       | `coreservices-link` |
   | Virtual network | `vnet-contoso-hub-brazilsouth`  |

3. Clique em **Create** e aguarde

4. Em **Recordsets**, adicione um novo registro com o IP **real** da vm-web-01:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Name       | `corevm`                       |
   | Type       | **A**                          |
   | TTL        | `1`                            |
   | IP address | *IP privado da vm-web-01* |

5. Clique em **Add**

6. Agora teste a resolucao a partir da **vm-app-01**. Va para **vm-app-01** > **Run command** > **RunPowerShellScript**:

   ```powershell
   Resolve-DnsName corevm.contoso.internal
   ```

7. **Resultado esperado:** O comando retorna o IP privado da vm-web-01

   > **Conexao com Bloco 4:** A zona DNS privada criada no Bloco 4 agora resolve nomes reais de VMs do Bloco 5. A vnet-contoso-spoke-brazilsouth (linkada no Bloco 4) e a vnet-contoso-hub-brazilsouth (linkada agora) podem resolver nomes nesta zona.

---

### Task 5.8: Criar subnet perimeter, Route Table e custom route

**Criar subnet perimeter:**

1. Navegue para **vnet-contoso-hub-brazilsouth** (em rg-contoso-network) > **Subnets** > **+ Subnet**:

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
   | Resource group           | `rg-contoso-compute`        |
   | Region                   | **East US**        |
   | Name                     | `rt-contoso-spoke`  |
   | Propagate gateway routes | **No**             |

4. **Review + create** > **Create**

**Criar custom route:**

5. Navegue para **rt-contoso-spoke** > **Settings** > **Routes** > **+ Add**:

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
   | Virtual network | **vnet-contoso-hub-brazilsouth (rg-contoso-network)** |
   | Subnet          | **snet-apps**                    |

8. Clique em **OK**

   > **Conceito:** UDRs sobrescrevem rotas do sistema. O next hop "Virtual appliance" direciona trafego para um NVA (firewall, proxy). Se o NVA nao existir no IP configurado, o trafego e **descartado**.

---

### Task 5.9: Teste de integracao — Verificar isolamento NSG por subnet

Este teste confirma que o NSG do Bloco 4 afeta apenas a subnet associada.

1. Lembre-se: o NSG **nsg-snet-shared** esta associado a **snet-shared** (Bloco 4)

2. A vm-web-01 esta na subnet **snet-apps** (sem NSG associado)

3. A vm-app-01 esta na subnet **snet-workloads** (sem NSG associado)

4. Verifique: navegue para **nsg-snet-shared** (rg-contoso-network) > **Subnets**

5. Confirme que apenas **snet-shared** esta listada

   > **Validacao:** As VMs NAO sao afetadas pelo NSG porque estao em subnets diferentes. NSGs sao associados a **subnets ou NICs**, nao a VNets inteiras. Se voce quisesse proteger as VMs, precisaria associar o NSG (ou outro) as subnets snet-apps e snet-workloads tambem.

---

### Task 5.10: Teste de integracao final — RBAC de ponta a ponta

Teste final que valida todo o RBAC configurado desde o Bloco 1.

1. Abra uma janela **InPrivate/Incognito**

2. Faca login como **contoso-user1** (senha salva no Bloco 1)

3. Navegue para **Virtual Machines**

4. Voce deve ver **vm-web-01** e **vm-app-01**

5. Selecione **vm-web-01** > tente **Stop** (desligar) a VM — deve **funcionar** (VM Contributor permite)

6. Tente deletar o resource group **rg-contoso-identity** — deve **falhar** por dois motivos:
   - contoso-user1 nao tem Contributor/Owner no RG
   - O resource lock (Delete) do Bloco 2 impede a exclusao

7. Navegue para **Storage Accounts** > tente criar um — deve **falhar** (VM Contributor nao inclui permissoes de Storage)

   > **Validacao completa:**
   > - **Bloco 1:** Identidade criada ✓
   > - **Bloco 2:** RBAC (VM Contributor) funciona + Lock protege ✓
   > - **Bloco 5:** contoso-user1 gerencia VMs mas nao outros recursos ✓

8. **Se parou a VM no passo 5**, inicie-a novamente antes de fechar

9. Feche a janela InPrivate

---

### Task 5.11: Criar GatewaySubnet e VPN Gateway

> **Cobranca:** VPN Gateway gera custo significativo (~$0.04/h para VpnGw1). Faca cleanup assim que terminar. O provisionamento leva **30-45 minutos**.

**Criar GatewaySubnet:**

1. Navegue para **vnet-contoso-hub-brazilsouth** (em rg-contoso-network) > **Subnets** > **+ Subnet**:

   | Setting          | Value            |
   | ---------------- | ---------------- |
   | Name             | `GatewaySubnet`  |
   | Starting address | `10.20.2.0`      |
   | Size             | `/27`            |

2. Clique em **Add**

   > **Conceito:** O nome **GatewaySubnet** e obrigatorio (exato). O Azure so permite criar VPN/ExpressRoute Gateways nesta subnet. Recomendacao minima: **/27** (32 IPs). Nunca associe NSG a GatewaySubnet.

**Criar Public IP para o Gateway:**

3. Pesquise **Public IP addresses** > **+ Create**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Name           | `pip-vpngw-core`   |
   | SKU            | **Standard**       |
   | Assignment     | **Static**         |
   | Resource group | `rg-contoso-compute`        |
   | Region         | **East US**        |

4. **Review + create** > **Create**

**Criar VPN Gateway:**

5. Pesquise **Virtual network gateways** > **+ Create**:

   | Setting          | Value                            |
   | ---------------- | -------------------------------- |
   | Name             | `vgw-contoso-hub`             |
   | Region           | **East US**                      |
   | Gateway type     | **VPN**                          |
   | SKU              | **VpnGw1**                       |
   | Generation       | **Generation1**                  |
   | Virtual network  | **vnet-contoso-hub-brazilsouth (rg-contoso-network)** |
   | Public IP        | `pip-vpngw-core`                 |
   | Enable active-active | **Disabled**                 |

6. **Review + create** > **Create**

7. **Aguarde o provisionamento** (~30-45 min). Continue lendo sobre os conceitos enquanto espera.

   > **Conceito:** O SKU **VpnGw1** suporta ate 30 tuneis S2S e 250 conexoes P2S. Active-Passive e o padrao — se a instancia ativa falha, a passiva assume. Active-Active requer 2 Public IPs e oferece maior disponibilidade.

---

### Task 5.12: Configurar Point-to-Site (P2S) VPN

> Esta task configura P2S usando autenticacao por certificado Azure, o metodo mais cobrado no AZ-104.

**Gerar certificado raiz autoassinado (no seu computador local):**

1. Abra **PowerShell como Administrador** no seu computador e execute:

   ```powershell
   # Criar certificado raiz
   $rootCert = New-SelfSignedCertificate -Type Custom `
     -KeySpec Signature `
     -Subject "CN=P2SRootCert" `
     -KeyExportPolicy Exportable `
     -HashAlgorithm sha256 `
     -KeyLength 2048 `
     -CertStoreLocation "Cert:\CurrentUser\My" `
     -KeyUsageProperty Sign `
     -KeyUsage CertSign

   # Criar certificado cliente
   New-SelfSignedCertificate -Type Custom `
     -DependsOn $rootCert `
     -Subject "CN=P2SChildCert" `
     -KeySpec Signature `
     -KeyExportPolicy Exportable `
     -HashAlgorithm sha256 `
     -KeyLength 2048 `
     -CertStoreLocation "Cert:\CurrentUser\My" `
     -Signer $rootCert
   ```

2. Exporte o **certificado raiz** em Base64:

   ```powershell
   $rootCertData = [Convert]::ToBase64String($rootCert.RawData)
   $rootCertData | Set-Clipboard
   ```

   > O valor copiado sera colado no portal na proxima etapa.

**Configurar P2S no VPN Gateway:**

3. Navegue para **vgw-contoso-hub** > **Settings** > **Point-to-site configuration**

4. Clique em **Configure now**:

   | Setting            | Value                                   |
   | ------------------ | --------------------------------------- |
   | Address pool       | `172.16.0.0/24`                         |
   | Tunnel type        | **IKEv2 and SSTP (SSL)**                |
   | Authentication type| **Azure certificate**                   |
   | Root certificate name | `P2SRootCert`                        |
   | Public certificate data | *cole o Base64 copiado no passo 2* |

5. Clique em **Save** (aguarde alguns minutos)

6. Clique em **Download VPN client** e salve o arquivo .zip

7. Extraia o .zip e execute o instalador adequado (WindowsAmd64/VpnClientSetupAmd64.exe)

   > **Conceito:** P2S usa o address pool (172.16.0.0/24) para atribuir IPs aos clientes. Cada cliente recebe um IP deste range ao conectar. **SSTP** funciona atraves de firewalls (porta 443), **IKEv2** e mais rapido mas pode ser bloqueado.

---

### Task 5.13: Testar conexao P2S e verificar rotas

1. No seu computador, va para **Settings** > **Network & Internet** > **VPN**

2. Conecte a VPN **vnet-contoso-hub-brazilsouth** (aparece automaticamente apos instalar o cliente)

3. Apos conectar, abra **PowerShell** e verifique as rotas:

   ```powershell
   Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.20.*" }
   ```

4. **Resultado esperado:** Voce vera rotas para `10.20.0.0/16` (vnet-contoso-hub-brazilsouth)

5. **Note:** Voce **NAO** vera rotas para `10.30.0.0/16` (vnet-contoso-spoke-brazilsouth), mesmo com peering ativo

   > **Conceito:** O cliente VPN P2S recebe as rotas no momento do download/instalacao. O peering entre vnet-contoso-hub-brazilsouth e vnet-contoso-spoke-brazilsouth ja existe (Task 5.5), mas as rotas da vnet-contoso-spoke-brazilsouth nao estao no cliente.

---

### Task 5.14: Habilitar Gateway Transit e reinstalar cliente P2S

Esta task demonstra a pegadinha classica do AZ-104: **cliente P2S precisa ser reinstalado apos mudancas na topologia**.

**Habilitar Gateway Transit no peering:**

1. Navegue para **vnet-contoso-hub-brazilsouth** > **Peerings** > selecione `vnet-contoso-hub-brazilsouth-to-vnet-contoso-spoke-brazilsouth`

2. Marque **Allow gateway transit** > **Save**

3. Navegue para **vnet-contoso-spoke-brazilsouth** > **Peerings** > selecione `vnet-contoso-spoke-brazilsouth-to-vnet-contoso-hub-brazilsouth`

4. Marque **Use remote gateway** > **Save**

   > **Conceito:** "Allow Gateway Transit" no hub permite que spokes usem seu VPN Gateway. "Use Remote Gateways" no spoke diz para usar o gateway do peer em vez de precisar de um proprio.

**Verificar que o cliente P2S NAO tem as novas rotas:**

5. No seu computador (ainda conectado via VPN), verifique:

   ```powershell
   Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.30.*" }
   ```

6. **Resultado esperado:** Nenhuma rota para 10.30.0.0/16 — o cliente **nao sabe** que Gateway Transit foi habilitado

**Reinstalar cliente P2S:**

7. Desconecte a VPN

8. No portal, va para **vgw-contoso-hub** > **Point-to-site configuration** > **Download VPN client** novamente

9. Extraia e **reinstale** o cliente VPN

10. Conecte novamente e verifique:

    ```powershell
    Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.30.*" }
    ```

11. **Resultado esperado:** Agora voce vera rotas para `10.30.0.0/16` — vnet-contoso-spoke-brazilsouth acessivel via P2S!

    > **PEGADINHA AZ-104:** Sempre que a topologia de rede muda (novo peering, gateway transit, novas subnets), o cliente VPN P2S precisa ser **baixado e reinstalado** para obter as rotas atualizadas. As rotas NAO se atualizam automaticamente no cliente.

---

### Task 5.15: Cleanup dos recursos VPN

> **Importante:** VPN Gateway gera custo continuo. Faca cleanup ao terminar.

1. Navegue para **Virtual network gateways** > **vgw-contoso-hub** > **Delete** (demora ~15 min)

2. Aguarde a exclusao completar

3. Delete o Public IP **pip-vpngw-core**

4. (Opcional) Remova a **GatewaySubnet** da vnet-contoso-hub-brazilsouth

5. Reverta o peering: remova "Allow Gateway Transit" e "Use Remote Gateways" das configuracoes de peering

   > **Nota:** Delete o VPN Gateway **antes** de deletar o Public IP e a GatewaySubnet, pois existem dependencias.

---

## Modo Desafio - Bloco 5

- [ ] Adicionar subnet `snet-apps` (10.20.0.0/24) na vnet-contoso-hub-brazilsouth **(Bloco 4)**
- [ ] Adicionar subnet `snet-workloads` (10.30.0.0/24) na vnet-contoso-spoke-brazilsouth **(Bloco 4)**
- [ ] Criar `vm-web-01` em rg-contoso-compute, na subnet snet-apps da **VNet do Bloco 4**
- [ ] Criar `vm-app-01` em rg-contoso-compute, na subnet snet-workloads da **VNet do Bloco 4**
- [ ] Network Watcher → Unreachable
- [ ] Configurar VNet Peering bidirecional entre VNets **do Bloco 4**
- [ ] Test-NetConnection → Success
- [ ] Testar nao-transitividade: Test-NetConnection para IP fora das VNets (10.40.0.4) → False
- [ ] **Integracao:** Adicionar link DNS + registro A com IP real → Resolve-DnsName da vm-app-01
- [ ] Criar subnet `perimeter` + Route Table + custom route (NVA 10.20.1.7)
- [ ] **Integracao:** Verificar NSG isolado por subnet
- [ ] **Integracao final:** Login como contoso-user1 → gerenciar VM ✓, criar Storage ✗
- [ ] Criar `GatewaySubnet` (/27) na vnet-contoso-hub-brazilsouth + Public IP + VPN Gateway (VpnGw1)
- [ ] Gerar certificados (raiz + cliente) e configurar P2S com Azure certificate
- [ ] Conectar via P2S e verificar rotas (so vnet-contoso-hub-brazilsouth)
- [ ] Habilitar Gateway Transit + Use Remote Gateways no peering
- [ ] Verificar que cliente P2S **NAO** tem rotas da vnet-contoso-spoke-brazilsouth
- [ ] Reinstalar cliente P2S → agora tem rotas para vnet-contoso-spoke-brazilsouth ✓
- [ ] **Cleanup:** Deletar VPN Gateway + Public IP

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Uma VM no rg-contoso-compute usa uma VNet do rg-contoso-network. E possivel?**

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
**Voce configurou VNet Peering entre vnet-contoso-hub-brazilsouth e vnet-contoso-spoke-brazilsouth. Voce quer que o trafego da vm-app-01 passe por um NVA na vnet-contoso-hub-brazilsouth antes de alcançar a vm-web-01. O que voce precisa configurar alem do peering?**

A) Apenas um NSG na subnet de destino
B) Uma User-Defined Route (UDR) na subnet da vm-app-01 com next hop apontando para o NVA
C) Habilitar IP forwarding no NVA e nada mais
D) Criar um VPN Gateway entre as VNets

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma User-Defined Route (UDR) na subnet da vm-app-01 com next hop apontando para o NVA**

Para forcar trafego atraves de um NVA, voce precisa criar uma UDR na subnet de origem com o next hop tipo "Virtual appliance" apontando para o IP do NVA. Alem disso, o NVA precisa ter **IP forwarding** habilitado na NIC. Apenas o peering nao e suficiente — ele habilita conectividade direta, mas nao roteia trafego atraves de intermediarios.

</details>

### Questao 5.5
**Voce criou uma Private DNS Zone `contoso.internal` e vinculou (Virtual Network Link) apenas a VNet A. Uma VM na VNet B (que tem peering com VNet A) tenta resolver `sensorvm.contoso.internal`. O que acontece?**

A) A resolucao funciona porque o peering compartilha DNS automaticamente
B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada
C) A resolucao funciona se o peering tiver "Allow forwarded traffic" habilitado
D) A resolucao funciona apenas se a VM usar um DNS forwarder na VNet A

<details>
<summary>Ver resposta</summary>

**Resposta: B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada**

Private DNS Zones resolvem nomes **apenas** para VNets que possuem um Virtual Network Link configurado. O VNet Peering nao propaga resolucao DNS automaticamente. Para que VMs na VNet B resolvam nomes da zona privada, voce precisa criar um Virtual Network Link adicional para a VNet B, ou configurar um DNS forwarder customizado.

</details>

### Questao 5.6
**Voce tem VNet1 com VPN Gateway e um cliente P2S conectado no Device1. Voce configura peering entre VNet1 e VNet2 com Gateway Transit habilitado. O Device1 consegue acessar VNet2 imediatamente?**

A) Sim, Gateway Transit propaga rotas automaticamente para clientes P2S conectados
B) Nao, e preciso baixar e reinstalar o cliente VPN P2S no Device1
C) Sim, basta desconectar e reconectar a VPN no Device1
D) Nao, e preciso gerar um novo certificado de cliente

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, e preciso baixar e reinstalar o cliente VPN P2S no Device1**

O cliente VPN P2S recebe a tabela de rotas no momento do download/instalacao. Mudancas na topologia (novo peering, gateway transit, novas subnets) **nao** sao propagadas automaticamente para clientes ja instalados. E necessario baixar novamente o pacote do cliente VPN no portal e reinstalar para que as novas rotas sejam incluidas. Simplesmente reconectar nao resolve — o cliente precisa ser reinstalado.

</details>

### Questao 5.7
**Voce precisa criar um VPN Gateway na vnet-contoso-hub-brazilsouth. Qual subnet e obrigatoria e qual o tamanho minimo recomendado?**

A) VPNSubnet, /28
B) GatewaySubnet, /29
C) GatewaySubnet, /27
D) VirtualGatewaySubnet, /27

<details>
<summary>Ver resposta</summary>

**Resposta: C) GatewaySubnet, /27**

O nome **GatewaySubnet** e obrigatorio — o Azure nao aceita outro nome para hospedar VPN/ExpressRoute Gateways. O tamanho minimo funcional e /29, mas a Microsoft recomenda **/27** para acomodar futuras configuracoes (coexistencia VPN + ExpressRoute). Nunca associe NSGs a GatewaySubnet.

</details>

---

> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 3 - Azure Web Apps](bloco3-webapps.md)

# Bloco 2 - Virtual Machines

**Origem:** Lab 08 - Manage Virtual Machines
**Resource Groups utilizados:** `rg-contoso-compute`

## Contexto

Com o armazenamento configurado no Bloco 1, voce agora implanta cargas de trabalho de computacao. As VMs serao criadas nas VNets da Semana 1 (vnet-contoso-hub-brazilsouth e vnet-contoso-spoke-brazilsouth), usando o storage do Bloco 1 para dados. Voce tambem criara um VMSS com auto-scaling para cenarios de alta disponibilidade. Os data disks demonstram integracao com o storage, e a montagem do file share valida a conectividade end-to-end.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          rg-contoso-compute                                │
│                                                                   │
│  ┌────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  vm-web-01              │  │  vm-api-01             │  │
│  │  (Windows Server 2022)     │  │  (Ubuntu 22.04 LTS)         │  │
│  │                            │  │                             │  │
│  │  VNet: vnet-contoso-hub-brazilsouth    │  │  VNet: vnet-contoso-spoke-brazilsouth    │  │
│  │  Subnet: snet-apps (Semana 1)   │  │  Subnet: snet-apps      │  │
│  │  Size: Standard_D2s_v3     │  │  Size: Standard_D2s_v3      │  │
│  │                            │  │                             │  │
│  │  Data Disk: 32 GiB         │  │  Custom Script Ext.         │  │
│  │  File Share: Z: drive      │  │  (instala Nginx)            │  │
│  │  (← Bloco 1)               │  │                             │  │
│  └────────────────────────────┘  └─────────────────────────────┘  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  vmss-contoso-web                                                 │  │
│  │  (VM Scale Set - Ubuntu 22.04)                              │  │
│  │                                                             │  │
│  │  VNet: vnet-contoso-hub-brazilsouth (Semana 1)                          │  │
│  │  Subnet: snet-shared                               │  │
│  │  Instances: min 1, max 3 (CPU > 75% scale out)              │  │
│  │  → Usa rede ja protegida por NSG (Semana 1)                 │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  → VMs usam VNets da Semana 1 (cross-resource-group)              │
│  → File Share do Bloco 1 montado na Windows VM                    │
│  → Data Disk demonstra gerenciamento de storage para VMs          │
└───────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 2.1: Criar Windows VM na vnet-contoso-hub-brazilsouth

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

A VM Windows sera implantada na vnet-contoso-hub-brazilsouth criada na Semana 1, demonstrando cross-resource-group deployment.

1. Pesquise e selecione **Virtual Machines** > **Create** > **Azure Virtual Machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `rg-contoso-compute` (ja existe do Modulo 1)              |
   | Virtual machine name | `vm-web-01`                                |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2022 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa (salve!)*                     |
   | Public inbound ports | **Allow selected ports**                      |
   | Select inbound ports | **RDP (3389)**                                |

3. Aba **Disks**: mantenha defaults (OS disk: Premium SSD)

4. Aba **Networking**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Virtual network      | **vnet-contoso-hub-brazilsouth** (de rg-contoso-network, Semana 1) |
   | Subnet               | **snet-apps** (10.20.0.0/24)                       |
   | Public IP            | **(new) vm-web-01-ip**                     |
   | NIC NSG              | **Basic**                                     |
   | Public inbound ports | **Allow selected ports**                      |
   | Select inbound ports | **RDP (3389)**                                |

   > **Nota:** Se a VNet da Semana 1 nao existir, crie uma VNet `ComputeVnet` (10.40.0.0/16) com subnet `ComputeSubnet` (10.40.0.0/24) no rg-contoso-compute.

   > **Conexao com Semana 1:** A VM esta sendo implantada na mesma VNet usada para networking (cross-RG). Isso demonstra que VMs e VNets nao precisam estar no mesmo Resource Group.

5. Aba **Management**: mantenha defaults

6. Aba **Monitoring**: **Disable** Boot diagnostics

7. Clique em **Review + create** > **Create**

8. Aguarde o deployment concluir > **Go to resource**

9. No blade **Overview**, anote:
   - **Private IP address** (ex: 10.20.0.4)
   - **Public IP address**
   - **Status**: Running

---

### Task 2.2: Adicionar Data Disk e montar File Share (Storage do Bloco 1)

Voce adiciona um data disk gerenciado e monta o file share do Bloco 1 como unidade de rede.

**Adicionar Data Disk:**

1. Na VM **vm-web-01**, navegue para **Settings** > **Disks**

2. Clique em **+ Create and attach a new disk**:

   | Setting      | Value                |
   | ------------ | -------------------- |
   | LUN          | `0`                  |
   | Disk name    | `disk-vm-web-01-data` |
   | Storage type | **Premium SSD**      |
   | Size (GiB)   | `32`                 |
   | Encryption   | Default              |

3. Clique em **Apply**

4. Conecte-se a VM via **RDP**:
   - Clique em **Connect** > **Connect** (native RDP)
   - Baixe o arquivo RDP e conecte com as credenciais `localadmin`

5. Dentro da VM, abra **Server Manager** > **File and Storage Services** > **Disks**

6. Localize o disco de 32 GiB (offline). Clique com botao direito > **Bring Online** > **Yes**

7. Clique com botao direito > **Initialize** (GPT)

8. Clique com botao direito no espaco nao alocado > **New Simple Volume**:
   - Drive letter: `F`
   - File system: NTFS
   - Volume label: `Data`

9. Confirme que o drive `F:` aparece no File Explorer

**Montar File Share do Bloco 1:**

10. Dentro da VM, abra **PowerShell** como Administrator

11. Execute o script de conexao do File Share copiado na Task 1.4 do Bloco 1:

    > **Nota:** O script usa `net use` ou `New-PSDrive` para mapear o share como drive Z:. Ele autentica com a storage account key.

    ```powershell
    # Exemplo de script (use o script gerado no portal):
    $connectTestResult = Test-NetConnection -ComputerName stcontosoprod01.file.core.windows.net -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        cmd.exe /C "cmdkey /add:`"stcontosoprod01.file.core.windows.net`" /user:`"localhost\stcontosoprod01`" /pass:`"<storage-account-key>`""
        New-PSDrive -Name Z -PSProvider FileSystem -Root "\\stcontosoprod01.file.core.windows.net\contoso-files" -Persist
    }
    ```

12. Verifique que o drive **Z:** aparece no File Explorer com o conteudo do file share

13. Crie um arquivo de teste no drive Z: `echo "Hello from VM" > Z:\vm-test.txt`

14. Volte ao **Azure Portal** > Storage Account > **File shares** > **contoso-files** — confirme que `vm-test.txt` aparece

    > **Conexao com Bloco 1:** O file share criado no Bloco 1 esta montado na VM. Isso demonstra integracao entre compute e storage. O mesmo share sera montado como volume no Bloco 4 (ACI).

15. Desconecte do RDP

---

### Task 2.3: Criar Linux VM na vnet-contoso-spoke-brazilsouth com Custom Script Extension

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. Pesquise **Virtual Machines** > **Create** > **Azure Virtual Machine**

2. Aba **Basics**:

   | Setting              | Value                                  |
   | -------------------- | -------------------------------------- |
   | Resource group       | `rg-contoso-compute`                            |
   | Virtual machine name | `vm-api-01`                       |
   | Region               | **(US) East US**                       |
   | Security type        | **Standard**                           |
   | Image                | **Ubuntu Server 22.04 LTS - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                    |
   | Authentication type  | **Password**                           |
   | Username             | `localadmin`                           |
   | Password             | *senha complexa*                       |
   | Public inbound ports | **Allow selected ports**               |
   | Select inbound ports | **HTTP (80)**, **SSH (22)**            |

3. Aba **Networking**:

   | Setting         | Value                                          |
   | --------------- | ---------------------------------------------- |
   | Virtual network | **vnet-contoso-spoke-brazilsouth** (de rg-contoso-network, Semana 1) |
   | Subnet          | **snet-apps** (10.30.0.0/24)               |
   | Public IP       | **(new) vm-api-01-ip**                    |

   > **Conexao com Semana 1:** A Linux VM fica na vnet-contoso-spoke-brazilsouth. Se o peering da Semana 1 ainda existir, ela pode se comunicar com a Windows VM na vnet-contoso-hub-brazilsouth.

4. Aba **Monitoring**: **Disable** Boot diagnostics

5. Clique em **Review + create** > **Create**

6. Apos o deploy, navegue para **vm-api-01** > **Operations** > **Run command** > **RunShellScript**

7. Execute o Custom Script para instalar Nginx:

   ```bash
   sudo apt-get update
   sudo apt-get install -y nginx
   echo "<h1>Hello from vm-api-01 (vnet-contoso-spoke-brazilsouth)</h1>" | sudo tee /var/www/html/index.html
   ```

8. Clique em **Run** e aguarde a saida

9. Copie o **Public IP** da VM e acesse via navegador — voce deve ver a pagina do Nginx

   > **Conceito:** Custom Script Extension permite executar scripts pos-provisioning automaticamente. Util para configuracao, instalacao de software e deployment.

---

### Task 2.3b: Criar Linux VM com Cloud-init (Custom Data)

> **Conceito para prova:** Cloud-init e o metodo nativo do Linux para configuracao automatica no **primeiro boot**. Diferente do Custom Script Extension (pos-provisioning) e do Run Command (ad-hoc), o cloud-init executa durante o provisioning inicial da VM.

1. Crie um arquivo local `cloud-init.yaml`:

   ```yaml
   #cloud-config
   package_upgrade: true
   packages:
     - nginx
   write_files:
     - path: /var/www/html/index.html
       content: |
         <h1>Hello from cloud-init VM (vnet-contoso-spoke-brazilsouth)</h1>
         <p>Configurado automaticamente no primeiro boot</p>
   runcmd:
     - systemctl enable nginx
     - systemctl start nginx
   ```

2. Crie a VM via CLI usando `--custom-data`:

   ```bash
   az vm create \
     --resource-group rg-contoso-compute \
     --name vm-api-01 \
     --image Ubuntu2204 \
     --size Standard_B1s \
     --admin-username localadmin \
     --admin-password '<senha-complexa>' \
     --vnet-name vnet-contoso-spoke-brazilsouth \
     --subnet snet-apps \
     --custom-data cloud-init.yaml \
     --public-ip-sku Standard \
     --nsg-rule SSH
   ```

3. Aguarde o deploy (~2-3 min). O cloud-init executa automaticamente no boot

4. Abra a porta 80:

   ```bash
   az vm open-port --resource-group rg-contoso-compute --name vm-api-01 --port 80
   ```

5. Acesse o IP publico no navegador — Nginx ja deve estar rodando com a pagina customizada

6. Verifique o log do cloud-init via Run Command:

   ```bash
   az vm run-command invoke \
     --resource-group rg-contoso-compute \
     --name vm-api-01 \
     --command-id RunShellScript \
     --scripts "cat /var/log/cloud-init-output.log | tail -20"
   ```

   > **Comparacao para prova:**
   > | Metodo | Quando executa | Caso de uso |
   > |--------|----------------|-------------|
   > | **Cloud-init** (Custom Data) | 1º boot apenas | Config inicial, pacotes, users |
   > | **Custom Script Extension** | Pos-deploy (sob demanda) | Deploy de software, config |
   > | **Run Command** | Ad-hoc | Troubleshooting, diagnostico |

7. Limpe o recurso (se nao for mais usar):

   ```bash
   az vm delete --resource-group rg-contoso-compute --name vm-api-01 --yes
   ```

---

### Task 2.4: Comparar tamanhos de VM e Resize

1. Navegue para **vm-web-01** > **Availability + scale** > **Size**

2. Explore os tamanhos disponiveis. Observe as familias:
   - **D-series**: proposito geral (balanceado CPU/memoria)
   - **E-series**: otimizado para memoria
   - **F-series**: otimizado para CPU
   - **B-series**: burstable (economico para workloads variaveis)

3. Selecione **Standard_DS1_v2** (menor custo) > **Resize**

   > **Nota:** O resize pode reiniciar a VM. Alguns tamanhos requerem deallocate primeiro.

4. Aguarde a operacao. A VM sera reiniciada.

5. Confirme o novo tamanho no **Overview**

6. **Opcional:** Faca resize de volta para **Standard_D2s_v3**

   > **Dica AZ-104:** Na prova, questoes sobre familias de VM sao comuns. Memorize: B=burstable, D=general purpose, E=memory optimized, F=compute optimized, N=GPU.

---

### Task 2.5: Criar VM Scale Set (VMSS)

> **Cobranca:** Cada instancia do VMSS gera cobranca. Escale para 0 ao pausar o lab.

O VMSS sera implantado na snet-shared da vnet-contoso-hub-brazilsouth (Semana 1), que ja tem o NSG `nsg-snet-shared` associado.

1. Pesquise **Virtual machine scale sets** > **+ Create**

2. Aba **Basics**:

   | Setting             | Value                                  |
   | ------------------- | -------------------------------------- |
   | Resource group      | `rg-contoso-compute`                            |
   | VMSS name           | `vmss-contoso-web`                           |
   | Region              | **(US) East US**                       |
   | Availability zone   | **None**                               |
   | Orchestration mode  | **Uniform**                            |
   | Security type       | **Standard**                           |
   | Image               | **Ubuntu Server 22.04 LTS - x64 Gen2** |
   | Size                | **Standard_B1s** (economico)           |
   | Authentication type | **Password**                           |
   | Username            | `localadmin`                           |
   | Password            | *senha complexa*                       |

3. Aba **Networking**:

   | Setting         | Value                                         |
   | --------------- | --------------------------------------------- |
   | Virtual network | **vnet-contoso-hub-brazilsouth** (de rg-contoso-network, Semana 1) |
   | Subnet          | **snet-shared** (10.20.10.0/24)      |
   | Load balancer   | **None** (para simplificar)                   |

   > **Conexao com Semana 1:** O VMSS esta na snet-shared, que tem o NSG `nsg-snet-shared` associado (Semana 1, Bloco 4). Isso significa que as regras de inbound/outbound do NSG se aplicam a todas as instancias do VMSS automaticamente.

4. Aba **Scaling**:

   | Setting                | Value      |
   | ---------------------- | ---------- |
   | Initial instance count | `1`        |
   | Scaling policy         | **Custom** |
   | Minimum instances      | `1`        |
   | Maximum instances      | `3`        |

5. Configure a regra de scale-out:
   - Metric: **Percentage CPU**
   - Operator: **Greater than**
   - Threshold: `75`
   - Duration: `10` minutes
   - Increase count by: `1`

6. Configure a regra de scale-in:
   - Metric: **Percentage CPU**
   - Operator: **Less than**
   - Threshold: `25`
   - Duration: `10` minutes
   - Decrease count by: `1`

7. Aba **Management**: mantenha defaults

8. Clique em **Review + create** > **Create**

9. Apos o deploy, navegue para **vmss-contoso-web** > **Instances** > confirme que 1 instancia esta Running

   > **Conceito:** VMSS permite criar e gerenciar um grupo de VMs identicas com auto-scaling. As instancias compartilham configuracao, imagem e regras de scaling.

---

### Task 2.6: Gerenciar VMSS — Upgrade Policy e instancias

1. No **vmss-contoso-web**, navegue para **Settings** > **Scaling**

2. Revise as regras de auto-scale configuradas

3. Navegue para **Upgrade policy** e note a politica configurada (Manual ou Automatic)

   > **Conceito:** Upgrade policies controlam como atualizacoes sao aplicadas as instancias. **Manual** requer acao explicita; **Automatic** atualiza instancias automaticamente; **Rolling** atualiza em lotes.

4. Navegue para **Instances** > selecione a instancia > explore:
   - **Status**: Running
   - **Latest model**: sim/nao (indica se esta atualizada)
   - **Protection**: opcoes de protecao contra scale-in

5. **Opcional:** Force scale-out manual:
   - Em **Scaling**, altere temporariamente o **minimum** para `2`
   - Aguarde a criacao da segunda instancia
   - Reverta o minimum para `1`

---

### Task 2.7: Configurar VM Backup e testar Run Command

1. Navegue para **vm-web-01** > **Operations** > **Backup**

2. Revise as opcoes:

   | Setting                 | Value                               |
   | ----------------------- | ----------------------------------- |
   | Recovery Services vault | *crie ou selecione um existente*    |
   | Backup policy           | **DefaultPolicy** (diario, 30 dias) |

   > **Nota:** Nao e necessario habilitar o backup de fato (gera custo). Apenas revise as opcoes.

3. Agora teste **Run Command** na Windows VM:
   - Navegue para **vm-web-01** > **Operations** > **Run command** > **RunPowerShellScript**

4. Execute:

   ```powershell
   Get-Disk | Format-Table Number, PartitionStyle, OperationalStatus, Size
   Get-Volume | Format-Table DriveLetter, FileSystemLabel, SizeRemaining, Size
   ```

5. Revise a saida — voce deve ver o disco C: (OS), F: (Data) e Z: (File Share, se ainda montado)

6. Teste Run Command na Linux VM:
   - Navegue para **vm-api-01** > **Operations** > **Run command** > **RunShellScript**

   ```bash
   df -h
   systemctl status nginx
   curl localhost
   ```

7. Confirme que Nginx esta ativo e respondendo

   > **Conceito:** Run Command e util para troubleshooting sem necessidade de RDP/SSH. Os comandos executam via VM Agent.

---

### Task 2.8: Availability Zones vs Availability Sets vs Scale Sets

> Esta task esclarece a confusao mais comum do AZ-104: quando usar Zone, Set ou Scale Set. Voce vai criar recursos e ver as restricoes na pratica.

**Criar VM em Availability Zone 1:**

1. Pesquise **Virtual Machines** > **Create** > **Virtual machine**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `rg-contoso-compute`                                   |
   | Virtual machine name | `az104-vm-zone1`                               |
   | Region               | **(US) East US**                              |
   | Availability options | **Availability zone**                         |
   | Availability zone    | **Zone 1**                                    |
   | Security type        | **Standard**                                  |
   | Image                | **Ubuntu Server 22.04 LTS - x64 Gen2**        |
   | Size                 | **Standard_B1s**                              |
   | Authentication type  | **Password**                                  |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |

2. **Networking**: selecione **vnet-contoso-hub-brazilsouth** > subnet **snet-apps**

3. **Monitoring** > **Disable** Boot diagnostics

4. **Review + create** > **Create**

**Criar VM em Availability Zone 2:**

5. Repita os passos acima com:

   | Setting              | Value              |
   | -------------------- | ------------------ |
   | Virtual machine name | `az104-vm-zone2`   |
   | Availability zone    | **Zone 2**         |

6. **Review + create** > **Create**

**Verificar zonas atribuidas:**

7. Apos o deploy, navegue para **az104-vm-zone1** > **Overview** > verifique **Availability zone: 1**

8. Navegue para **az104-vm-zone2** > **Overview** > verifique **Availability zone: 2**

   > **Conceito:** Availability Zones sao **datacenters fisicamente separados** dentro da mesma regiao. Se o datacenter da Zone 1 falhar, a VM na Zone 2 continua operando. SLA: **99.99%**.

**Criar Availability Set e entender a diferenca:**

9. Pesquise **Availability Sets** > **+ Create**:

   | Setting            | Value                |
   | ------------------ | -------------------- |
   | Resource group     | `rg-contoso-compute`          |
   | Name               | `az104-avset`        |
   | Region             | **East US**          |
   | Fault domains      | `2`                  |
   | Update domains     | `5`                  |

10. **Review + create** > **Create**

**Tentar colocar VM de Zone em Availability Set:**

11. Inicie a criacao de uma nova VM:
    - Availability options: **Availability set**
    - Availability set: **az104-avset**

12. Note que **Availability zone** desaparece das opcoes — sao **mutuamente exclusivos**

13. Cancele a criacao

   > **REGRA AZ-104:** Uma VM pode estar em Availability **Zone** OU Availability **Set**, **nunca ambos**. Zone protege contra falha de datacenter. Set protege contra falha de rack/hardware dentro do mesmo datacenter.

**Comparar com Scale Set (ja criado na Task 2.5):**

14. Navegue para **vmss-contoso-web** (criado anteriormente) > **Overview**

15. Note: VMSS e para **escalabilidade automatica** (auto-scale), nao para alta disponibilidade por si so

16. Um VMSS **pode** usar Availability Zones (distribui instancias entre zonas), mas o proposito principal e **escalar**, nao proteger contra falhas

   > **RESUMO PARA A PROVA:**

   | Pergunta na prova | Resposta |
   | --- | --- |
   | "Proteger contra falha de **datacenter**" | **Availability Zone** |
   | "Proteger contra falha de **rack/hardware**" | **Availability Set** |
   | "**Escalar** automaticamente com demanda" | **VM Scale Set** |
   | "Proteger contra falha de **regiao** inteira" | **Region Pairs** + Site Recovery |

---

### Task 2.9: Cleanup das VMs de zona

> **Importante:** VMs geram custo. Delete as VMs de teste apos a pratica.

1. Delete **az104-vm-zone1** e **az104-vm-zone2** (e seus discos e NICs associados)
2. Delete o Availability Set **az104-avset**

---

## Modo Desafio - Bloco 2

- [ ] Criar `vm-web-01` (Windows) na subnet snet-apps da **vnet-contoso-hub-brazilsouth (Semana 1)**
- [ ] Adicionar Data Disk 32 GiB → inicializar como drive F: dentro da VM
- [ ] **Integracao Bloco 1:** Montar File Share `contoso-files` como drive Z: na VM
- [ ] Criar arquivo de teste no share via VM → confirmar no portal
- [ ] Criar `vm-api-01` (Ubuntu) na subnet snet-apps da **vnet-contoso-spoke-brazilsouth (Semana 1)**
- [ ] Instalar Nginx via Custom Script Extension / Run Command
- [ ] Comparar tamanhos de VM e executar resize
- [ ] Criar VMSS `vmss-contoso-web` na **snet-shared (Semana 1)** com auto-scale (CPU 75%/25%)
- [ ] **Integracao Semana 1:** Verificar que NSG da snet-shared se aplica ao VMSS
- [ ] Gerenciar instancias do VMSS (status, latest model)
- [ ] Testar Run Command em ambas as VMs
- [ ] Criar VMs em **Availability Zone 1** e **Zone 2** — verificar zonas no Overview
- [ ] Criar **Availability Set** (fault domain 2, update domain 5)
- [ ] Verificar que Zone e Set sao **mutuamente exclusivos** (um exclui o outro)
- [ ] Comparar VMSS (escala) vs Zone (HA datacenter) vs Set (HA rack)
- [ ] Cleanup: deletar VMs de zona + Availability Set

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce precisa anexar um data disk a uma VM em execucao. E necessario reiniciar a VM?**

A) Sim, sempre e necessario reiniciar
B) Nao, hot-attach e suportado para data disks em VMs com suporte
C) Apenas se o disco for Premium SSD
D) Apenas se a VM estiver em um Availability Set

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, hot-attach e suportado para data disks em VMs com suporte**

Data disks podem ser anexados/desanexados de VMs em execucao (hot-attach/hot-detach) em tamanhos de VM que suportam este recurso. O OS disk requer stop/deallocate.

</details>

### Questao 2.2
**Voce configurou uma regra de auto-scale no VMSS: scale-out quando CPU > 75% por 10 minutos. O CPU fica em 80% por 8 minutos e depois cai para 60%. O VMSS faz scale-out?**

A) Sim, porque o CPU ultrapassou 75%
B) Nao, porque o threshold nao foi mantido pelo periodo completo de 10 minutos
C) Sim, mas apenas apos 15 minutos de cooldown
D) Depende do numero atual de instancias

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, porque o threshold nao foi mantido pelo periodo completo de 10 minutos**

A regra de auto-scale requer que a metrica exceda o threshold pelo **periodo completo** (duration). Se o CPU cair antes dos 10 minutos, a condicao nao e atendida e o scale-out nao e disparado.

</details>

### Questao 2.3
**Voce precisa executar um script de troubleshooting em uma VM Azure mas nao tem acesso RDP/SSH. Qual recurso voce deve usar?**

A) Azure Bastion
B) Run Command
C) Custom Script Extension
D) Serial Console

<details>
<summary>Ver resposta</summary>

**Resposta: B) Run Command**

Run Command permite executar scripts diretamente na VM via Azure Portal, CLI ou PowerShell, sem necessidade de conectividade RDP/SSH. E executado pelo VM Agent. Custom Script Extension e para cenarios de deployment/configuracao automatizada, nao troubleshooting ad-hoc.

</details>

### Questao 2.4
**Qual familia de VM Azure e mais adequada para cargas de trabalho com uso intensivo de memoria, como bancos de dados em memoria?**

A) B-series (Burstable)
B) D-series (General Purpose)
C) E-series (Memory Optimized)
D) F-series (Compute Optimized)

<details>
<summary>Ver resposta</summary>

**Resposta: C) E-series (Memory Optimized)**

E-series e otimizada para cargas de trabalho com alto consumo de memoria (bancos de dados, caches, analytics in-memory). D-series e general purpose, F-series e compute optimized, B-series e para workloads variaveis.

</details>

### Questao 2.5
**Sua empresa planeja hospedar um aplicativo em 4 VMs Azure. Voce precisa garantir que pelo menos 2 VMs estejam disponiveis se um unico datacenter Azure falhar. Qual opcao voce deve selecionar?**

A) Um conjunto de disponibilidade (Availability Set)
B) Uma zona de disponibilidade (Availability Zone)
C) Conjuntos de dimensionamento (VM Scale Set)
D) Grupo de posicionamento de proximidade

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma zona de disponibilidade (Availability Zone)**

Availability Zone protege contra falha de **datacenter inteiro** — cada zona e um datacenter fisicamente separado. Availability Set protege contra falha de rack/hardware dentro do **mesmo** datacenter. Scale Set e para escalabilidade automatica, nao HA. Grupo de proximidade otimiza latencia, nao disponibilidade.

</details>

### Questao 2.6
**Voce planeja implantar uma VM Azure Spot. Quais dois fatores podem causar a remocao da VM?**

A) Uso medio de CPU da instancia
B) Necessidades de capacidade do Azure
C) Preco atual da instancia Spot
D) Hora do dia

<details>
<summary>Ver resposta</summary>

**Resposta: B + C) Necessidades de capacidade do Azure + Preco atual da instancia Spot**

Spot VMs sao removidas quando: (1) o Azure precisa da capacidade de volta para workloads pagos, ou (2) o preco da instancia Spot excede o maximo que voce definiu. CPU, memoria e hora do dia NAO sao fatores de eviction. Spot VMs sao indicadas para dev/test e batch, sem SLA.

</details>

### Questao 2.7
**Uma VM esta em Availability Zone 1. Voce quer adiciona-la a um Availability Set existente. E possivel?**

A) Sim, basta associar nas configuracoes da VM
B) Nao, Availability Zone e Availability Set sao mutuamente exclusivos
C) Sim, mas apenas se o Availability Set estiver na mesma zona
D) Sim, mas requer redesploy da VM

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, Availability Zone e Availability Set sao mutuamente exclusivos**

Uma VM pode estar em Availability Zone OU Availability Set, nunca em ambos. Essa opcao e definida no momento da criacao e nao pode ser alterada depois. Para mudar, e necessario recriar a VM.

</details>

---


# Laboratórios Práticos - AZ-104: Microsoft Azure Administrator

> **Fonte:** [Microsoft Learning - AZ-104 Labs](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/)
>
> **Repositório GitHub:** [MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator](https://github.com/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator)
>
> **Download dos Arquivos:** [Baixar Arquivos do Lab](https://github.com/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator/archive/master.zip)

---

## Visão Geral

Este documento contém a descrição completa dos laboratórios práticos oficiais da Microsoft para a certificação AZ-104: Microsoft Azure Administrator. Os labs cobrem todos os domínios do exame e fornecem experiência hands-on essencial para a preparação.

---

## Resumo dos Laboratórios

| Lab                                                             | Módulo                                |
| --------------------------------------------------------------- | ------------------------------------- |
| [Lab 01](#lab-01-manage-microsoft-entra-id-identities)          | Administer Identity                   |
| [Lab 02a](#lab-02a-manage-subscriptions-and-rbac)               | Administer Governance and Compliance  |
| [Lab 02b](#lab-02b-manage-governance-via-azure-policy)          | Administer Governance and Compliance  |
| [Lab 03](#lab-03-manage-azure-resources-by-using-arm-templates) | Administer Azure Resources            |
| [Lab 04](#lab-04-implement-virtual-networking)                  | Implement Virtual Networking          |
| [Lab 05](#lab-05-implement-intersite-connectivity)              | Administer Intersite Connectivity     |
| [Lab 06](#lab-06-implement-network-traffic-management)          | Administer Network Traffic Management |
| [Lab 07](#lab-07-manage-azure-storage)                          | Administer Azure Storage              |
| [Lab 08](#lab-08-manage-virtual-machines)                       | Administer Virtual Machines           |
| [Lab 09a](#lab-09a-implement-web-apps)                          | Administer PaaS Compute Options       |
| [Lab 09b](#lab-09b-implement-azure-container-instances)         | Administer PaaS Compute Options       |
| [Lab 09c](#lab-09c-implement-azure-container-apps)              | Administer PaaS Compute Options       |
| [Lab 10](#lab-10-implement-data-protection)                     | Administer Data Protection            |
| [Lab 11](#lab-11-implement-monitoring)                          | Administer Monitoring                 |

---

## Lab 01: Manage Microsoft Entra ID Identities

### Informações Gerais

- **Módulo:** Administer Identity
- **Região Padrão:** East US

### Cenário

Sua organização está construindo um novo ambiente de lab para testes de pré-produção de apps e serviços. Alguns engenheiros estão sendo contratados para gerenciar o ambiente, incluindo VMs. Para permitir autenticação via Microsoft Entra ID, você precisa provisionar usuários e grupos. Para minimizar overhead administrativo, a associação a grupos deve ser atualizada automaticamente com base em cargos.

### Habilidades Desenvolvidas

1. Criar e configurar contas de usuário
2. Criar grupos e adicionar membros

### Tarefas do Lab

#### Task 1: Create and configure user accounts

- Fazer login no Azure Portal
- Acessar Microsoft Entra ID
- Explorar o conceito de **Tenant** (instância específica do Entra ID)
- Criar novo usuário com as seguintes propriedades:
  - User principal name: `az104-user1`
  - Display name: `az104-user1`
  - Job title: `IT Lab Administrator`
  - Department: `IT`
  - Usage location: `United States`
- Convidar usuário externo (guest user)

#### Task 2: Create groups and add members

- Criar grupo de segurança:
  - Group type: `Security`
  - Group name: `IT Lab Administrators`
  - Membership type: `Assigned`
- Configurar owner e members do grupo
- Explorar configurações de **Expiration** e **Naming policy**

### Key Takeaways

- Um **tenant** representa sua organização e gerencia instâncias do Microsoft Cloud Services
- Microsoft Entra ID tem contas de usuário e convidados com diferentes níveis de acesso
- **Groups** combinam usuários ou dispositivos relacionados (Security ou Microsoft 365)
- Membership pode ser **estática** ou **dinâmica**

### Recursos de Aprendizado

- [Understand Microsoft Entra ID](https://learn.microsoft.com/training/modules/understand-azure-active-directory/)
- [Create Azure users and groups in Microsoft Entra ID](https://learn.microsoft.com//training/modules/create-users-and-groups-in-azure-active-directory/)
- [Allow users to reset their password with Microsoft Entra self-service password reset](https://learn.microsoft.com/training/modules/allow-users-reset-their-password/)

---

## Lab 02a: Manage Subscriptions and RBAC

### Informações Gerais

- **Módulo:** Administer Governance and Compliance
- **Região Padrão:** East US

### Cenário

Para simplificar o gerenciamento de recursos Azure em sua organização, você precisa implementar:

- Um management group que inclua todas as assinaturas Azure
- Permissões para submeter requests de suporte para todas as assinaturas no management group

### Habilidades Desenvolvidas

1. Implementar management groups
2. Revisar e atribuir funções Azure built-in
3. Criar funções RBAC customizadas
4. Monitorar atribuições de função com Activity Log

### Tarefas do Lab

#### Task 1: Implement Management Groups

- Acessar Microsoft Entra ID > Properties
- Revisar **Access management for Azure resources**
- Criar management group:
  - Management group ID: `az104-mg1`
  - Display name: `az104-mg1`
- Entender o **root management group** e hierarquia

#### Task 2: Review and assign a built-in Azure role

- Acessar Access control (IAM)
- Explorar roles built-in: **Owner**, **Contributor**, **Reader**
- Atribuir role **Virtual Machine Contributor** a um grupo
- Best practice: sempre atribuir roles a grupos, não indivíduos

#### Task 3: Create a custom RBAC role

- Clonar role **Support Request Contributor**
- Criar role customizada: `Custom Support Request`
- Configurar **NotActions** para remover permissões
- Definir **Assignable scopes**
- Revisar JSON com Actions, NotActions e AssignableScopes

#### Task 4: Monitor role assignments with the Activity Log

- Usar Activity Log para monitorar atribuições de roles

### Key Takeaways

- **Management groups** organizam logicamente as assinaturas
- O **root management group** inclui todos os management groups e assinaturas
- Azure tem muitas **built-in roles** para controle de acesso
- Você pode criar **custom roles** ou personalizar roles existentes
- Roles são definidas em JSON com **Actions**, **NotActions** e **AssignableScopes**
- **Activity Log** monitora atribuições de roles

### Recursos de Aprendizado

- [Secure your Azure resources with Azure role-based access control (Azure RBAC)](https://learn.microsoft.com/training/modules/secure-azure-resources-with-rbac/)

---

## Lab 02b: Manage Governance via Azure Policy

### Informações Gerais

- **Módulo:** Administer Governance and Compliance

### Cenário

Implementar Azure Policy para garantir conformidade e governança em recursos Azure.

### Habilidades Desenvolvidas

- Criar e atribuir Azure Policies
- Configurar iniciativas de policy
- Verificar compliance

---

## Lab 03: Manage Azure Resources by Using ARM Templates

### Informações Gerais

- **Módulo:** Administer Azure Resources

### Cenário

Aprender a automatizar implantação de recursos usando Azure Resource Manager Templates e Bicep.

### Habilidades Desenvolvidas

- Interpretar templates ARM e arquivos Bicep
- Modificar templates existentes
- Implantar recursos usando templates
- Exportar implantações como templates

---

## Lab 04: Implement Virtual Networking

### Informações Gerais

- **Módulo:** Implement Virtual Networking
- **Região Padrão:** East US

### Cenário

Sua organização global planeja implementar redes virtuais para acomodar recursos existentes e crescimento futuro:

- **CoreServicesVnet**: maior número de recursos, necessita grande espaço de endereços
- **ManufacturingVnet**: sistemas para operações de fabricação com muitos dispositivos IoT

### Habilidades Desenvolvidas

1. Criar virtual network com subnets usando o portal
2. Criar virtual network e subnets usando template
3. Criar e configurar comunicação entre ASG e NSG
4. Configurar zonas DNS públicas e privadas

### Tarefas do Lab

#### Task 1: Create a virtual network with subnets using the portal

- Criar **CoreServicesVnet**:
  - Resource Group: `az104-rg4`
  - IPv4 address space: `10.20.0.0/16`
  - SharedServicesSubnet: `10.20.10.0/24`
  - DatabaseSubnet: `10.20.20.0/24`
- Exportar template para uso posterior

#### Task 2: Create a virtual network and subnets using a template

- Modificar template exportado para criar **ManufacturingVnet**:
  - IPv4: `10.30.0.0/16`
  - SensorSubnet1: `10.30.20.0/24`
  - SensorSubnet2: `10.30.21.0/24`
- Implantar usando **Deploy a custom template**

#### Task 3: Create and configure communication between ASG and NSG

- Criar **Application Security Group** (asg-web)
- Criar **Network Security Group** (myNSGSecure)
- Associar NSG à subnet SharedServicesSubnet
- Criar regra inbound para permitir tráfego do ASG (portas 80, 443)
- Criar regra outbound para negar acesso à Internet

#### Task 4: Configure public and private Azure DNS zones

**DNS Zone Pública:**

- Criar zona: `contoso.com`
- Adicionar record A: `www` -> IP
- Testar com `nslookup`

**DNS Zone Privada:**

- Criar zona: `private.contoso.com`
- Criar virtual network link para ManufacturingVnet
- Adicionar record para VMs internas

### Key Takeaways

- **Virtual network** é a representação da sua rede na nuvem
- Evitar overlapping de IP address ranges entre redes
- **Subnet** é um range de IPs dentro da virtual network
- **NSG** contém regras de segurança que permitem ou negam tráfego de rede
- **ASG** protege grupos de servidores com função comum
- **Azure DNS** fornece hospedagem de domínios e resolução de nomes

### Recursos de Aprendizado

- [Introduction to Azure Virtual Networks](https://learn.microsoft.com/training/modules/introduction-to-azure-virtual-networks/)
- [Design an IP addressing scheme](https://learn.microsoft.com/training/modules/design-ip-addressing-for-azure/)
- [Secure and isolate access to Azure resources by using network security groups and service endpoints](https://learn.microsoft.com/training/modules/secure-and-isolate-with-nsg-and-service-endpoints/)
- [Host your domain on Azure DNS](https://learn.microsoft.com/training/modules/host-domain-azure-dns/)

---

## Lab 05: Implement Intersite Connectivity

### Informações Gerais

- **Módulo:** Administer Intersite Connectivity

### Habilidades Desenvolvidas

- Configurar VNet Peering
- Implementar conectividade entre sites

---

## Lab 06: Implement Network Traffic Management

### Informações Gerais

- **Módulo:** Administer Network Traffic Management

### Habilidades Desenvolvidas

- Configurar Azure Load Balancer
- Configurar Application Gateway
- Gerenciar tráfego de rede

---

## Lab 07: Manage Azure Storage

### Informações Gerais

- **Módulo:** Administer Azure Storage
- **Região Padrão:** East US

### Cenário

Sua organização armazena dados em data stores on-premises, com a maioria dos arquivos não sendo acessados frequentemente. Você deseja:

- Minimizar custos colocando arquivos em storage tiers de menor preço
- Explorar mecanismos de proteção: network access, authentication, authorization e replication
- Determinar se Azure Files é adequado para hospedar file shares on-premises

### Habilidades Desenvolvidas

1. Criar e configurar uma storage account
2. Criar e configurar blob storage seguro
3. Criar e configurar Azure File storage

### Tarefas do Lab

#### Task 1: Create and configure a storage account

- Criar storage account com:
  - Performance: **Standard**
  - Redundancy: **Geo-redundant storage (GRS)**
  - Public network access: **Disabled** (depois configurar selected networks)
- Configurar **Lifecycle management**:
  - Regra "Movetocool": mover blobs para cool storage após 30 dias

#### Task 2: Create and configure secure blob storage

- Criar container `data` com acesso **Private**
- Configurar **Immutable blob storage** com retenção de 180 dias
- Upload de arquivo com:
  - Blob type: **Block blob**
  - Access tier: **Hot**
- Testar acesso anônimo (deve falhar: ResourceNotFound)
- Gerar **SAS token** com permissão de leitura
- Testar acesso com SAS URL (deve funcionar)

#### Task 3: Create and configure Azure File storage

- Criar file share `share1` com tier **Transaction optimized**
- Usar **Storage Browser** para explorar e fazer upload
- Criar virtual network e service endpoint para Microsoft.Storage
- Restringir acesso ao storage account apenas da VNet
- Testar acesso (deve falhar fora da VNet)

### Key Takeaways

- **Azure Storage account** contém todos os objetos: blobs, files, queues, tables
- Modelos de redundância: **LRS**, **ZRS**, **GRS**
- **Blob storage** armazena grandes quantidades de dados não estruturados
- **File storage** fornece armazenamento compartilhado estruturado
- **Immutable storage** fornece WORM (Write Once, Read Many)

### Recursos de Aprendizado

- [Create an Azure Storage account](https://learn.microsoft.com/training/modules/create-azure-storage-account/)
- [Manage the Azure Blob storage lifecycle](https://learn.microsoft.com/training/modules/manage-azure-blob-storage-lifecycle)

---

## Lab 08: Manage Virtual Machines

### Informações Gerais

- **Módulo:** Administer Virtual Machines
- **Região Padrão:** East US

### Cenário

Sua organização quer explorar implantação e configuração de VMs Azure:

- Implementar VM com scaling manual
- Implementar Virtual Machine Scale Set com autoscaling

### Habilidades Desenvolvidas

1. Implantar VMs resilientes a zonas usando o portal
2. Gerenciar scaling de compute e storage para VMs
3. Criar e configurar Azure Virtual Machine Scale Sets
4. Escalar Azure Virtual Machine Scale Sets
5. Criar VM usando Azure PowerShell (opcional)
6. Criar VM usando CLI (opcional)

### Tarefas do Lab

#### Task 1: Deploy zone-resilient Azure virtual machines

- Criar 2 VMs em zonas de disponibilidade diferentes (Zone 1 e Zone 2)
- Configurações:
  - Names: `az104-vm1`, `az104-vm2`
  - Image: Windows Server 2025 Datacenter
  - Size: Standard D2s v3
  - OS disk type: Premium SSD
  - Boot diagnostics: Disable
- Alcançar SLA de 99.99% com VMs em zonas diferentes

#### Task 2: Manage compute and storage scaling

- **Vertical Scaling** (resize):
  - Alterar tamanho para `D2ds_v4`
- **Storage scaling**:
  - Criar data disk: `vm1-disk1`, Standard HDD, 32 GiB
  - Detach disk
  - Alterar tipo para Standard SSD
  - Reattach disk

#### Task 3: Create and configure Azure Virtual Machine Scale Sets

- Criar VMSS:
  - Name: `vmss1`
  - Availability zones: 1, 2, 3
  - Orchestration mode: Uniform
  - Image: Windows Server 2025 Datacenter
- Configurar networking:
  - VNet: `vmss-vnet` (10.82.0.0/20)
  - Subnet: `subnet0` (10.82.0.0/24)
  - NSG: `vmss1-nsg` com regra HTTP (porta 80)
  - Load Balancer: `vmss-lb`

#### Task 4: Scale Azure Virtual Machine Scale Sets

- Configurar **Custom autoscale**:

**Scale Out Rule:**

- Metric: Percentage CPU
- Threshold: > 70% por 10 min
- Operation: Increase percent by 50%
- Cooldown: 5 min

**Scale In Rule:**

- Threshold: < 30% por 10 min
- Operation: Decrease percentage by 50%

**Instance Limits:**

- Minimum: 2
- Maximum: 10
- Default: 2

#### Task 5: Create VM using Azure PowerShell (Opcional)

```powershell
New-AzVm `
  -ResourceGroupName 'az104-rg8' `
  -Name 'myPSVM' `
  -Location 'East US' `
  -Image 'Win2019Datacenter' `
  -Zone '1' `
  -Size 'Standard_D2s_v3' `
  -Credential (Get-Credential)

Get-AzVM -ResourceGroupName 'az104-rg8' -Status

Stop-AzVM -ResourceGroupName 'az104-rg8' -Name 'myPSVM'
```

#### Task 6: Create VM using CLI (Opcional)

```bash
az vm create --name myCLIVM --resource-group az104-rg8 --image Ubuntu2204 --admin-username localadmin --generate-ssh-keys

az vm show --name myCLIVM --resource-group az104-rg8 --show-details --output table

az vm deallocate --resource-group az104-rg8 --name myCLIVM
```

### Key Takeaways

- **Azure VMs** são recursos de computação sob demanda e escaláveis
- VMs suportam **vertical** (resize) e **horizontal** (scale out) scaling
- Configuração inclui: OS, size, storage e networking settings
- **VMSS** permite criar e gerenciar grupo de VMs com load balancing
- VMs em VMSS são criadas da mesma imagem e configuração
- VMSS pode escalar automaticamente baseado em demanda ou schedule

### Recursos de Aprendizado

- [Create a Windows virtual machine in Azure](https://learn.microsoft.com/training/modules/create-windows-virtual-machine-in-azure/)
- [Build a scalable application with Virtual Machine Scale Sets](https://learn.microsoft.com/training/modules/build-app-with-scale-sets/)
- [Connect to virtual machines through the Azure portal by using Azure Bastion](https://learn.microsoft.com/en-us/training/modules/connect-vm-with-azure-bastion/)

---

## Lab 09a: Implement Web Apps

### Informações Gerais

- **Módulo:** Administer PaaS Compute Options

### Habilidades Desenvolvidas

- Criar e configurar Azure App Service
- Implantar Web Apps

---

## Lab 09b: Implement Azure Container Instances

### Informações Gerais

- **Módulo:** Administer PaaS Compute Options

### Habilidades Desenvolvidas

- Criar e configurar Azure Container Instances
- Implantar containers

---

## Lab 09c: Implement Azure Container Apps

### Informações Gerais

- **Módulo:** Administer PaaS Compute Options

### Habilidades Desenvolvidas

- Criar e configurar Azure Container Apps
- Gerenciar scaling de containers

---

## Lab 10: Implement Data Protection

### Informações Gerais

- **Módulo:** Administer Data Protection

### Habilidades Desenvolvidas

- Configurar Azure Backup
- Criar Recovery Services vault
- Configurar políticas de backup
- Implementar Azure Site Recovery

---

## Lab 11: Implement Monitoring

### Informações Gerais

- **Módulo:** Administer Monitoring

### Habilidades Desenvolvidas

- Configurar Azure Monitor
- Criar alertas e action groups
- Analisar logs e métricas
- Usar Log Analytics

---

## Demonstrations (Para Instrutores)

| Módulo                            | Demonstration                                                                                                                                                                                         |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| All                               | [Demonstration Instructions](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/00%20-%20readme.html)                                                          |
| Administer Identity               | [Demo 01: Administer Identity](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/01%20-%20Administer%20Identity.html)                                         |
| Administer Governance             | [Demo 02: Administer Governance and Compliance](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/02%20-%20Administer%20Governance%20and%20Compliance.html)   |
| Administer Azure Resources        | [Demo 03: Administer Azure Resources](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/03%20-%20Administer%20Azure%20Resources.html)                         |
| Administer Virtual Networking     | [Demo 04: Administer Virtual Networking](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/04%20-%20Administer%20VIrtual%20Networking.html)                   |
| Administer Intersite Connectivity | [Demo 05: Administer Intersite Connectivity](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/05%20-%20Administer%20Intersite%20Connectivity.html)           |
| Administer Network Traffic        | [Demo 06: Administer Network Traffic Management](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/06%20-%20Administer%20Network%20Traffic%20Management.html) |
| Administer Azure Storage          | [Demo 07: Administer Azure Storage](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/07%20-%20Administer%20Azure%20Storage.html)                             |
| Administer Azure VMs              | [Demo 08: Administer Azure Virtual Machines](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/08%20-%20Administer%20Azure%20Virtual%20Machines.html)         |
| Administer PaaS Compute           | [Demo 09: Administer PaaS Compute Options](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/09%20-%20Administer%20PaaS%20Compute%20Options.html)             |
| Administer Data Protection        | [Demo 10: Administer Data Protection](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/10%20-%20Administer%20Data%20Protection.html)                         |
| Administer Monitoring             | [Demo 11: Administer Monitoring](https://microsoftlearning.github.io/AZ-104-MicrosoftAzureAdministrator/Instructions/Demos/11%20-%20Administer%20Monitoring.html)                                     |

---

## Requisitos e Pré-requisitos

### Requisitos

- Assinatura Azure ativa
- Navegador moderno (Edge, Chrome, Firefox)
- Acesso ao Azure Portal

### Pré-requisitos de Conhecimento

- Familiaridade com sistemas operacionais
- Conceitos básicos de rede
- Experiência com virtualização
- Conhecimento básico de PowerShell ou CLI

### Custos

A maioria dos labs pode ser executada com os créditos gratuitos do Azure. Sempre lembre de:

- Excluir recursos após completar o lab
- Usar o menor tamanho de VM possível
- Desalocar VMs quando não estiver usando

---

## Dicas para os Labs

1. **Sempre verifique a região**: Use a região especificada (geralmente East US)
2. **Nomes únicos**: Storage accounts e alguns recursos requerem nomes globalmente únicos
3. **Cleanup**: Delete resource groups após completar cada lab
4. **Screenshots**: Tire screenshots importantes para revisão
5. **Copilot**: Use o Copilot para ajudar com comandos PowerShell/CLI


---

## Mapeamento Labs x Domínios do Exame

| Domínio do Exame                                      | Labs Relacionados                         |
| ----------------------------------------------------- | ----------------------------------------- |
| Gerenciar identidades e governança (20-25%)           | Lab 01, Lab 02a, Lab 02b                  |
| Implementar e gerenciar armazenamento (15-20%)        | Lab 07                                    |
| Implantar e gerenciar recursos de computação (20-25%) | Lab 03, Lab 08, Lab 09a, Lab 09b, Lab 09c |
| Implementar e gerenciar redes virtuais (15-20%)       | Lab 04, Lab 05, Lab 06                    |
| Monitorar e manter recursos do Azure (10-15%)         | Lab 10, Lab 11                            |

---

**Boa sorte nos laboratórios e no exame!**

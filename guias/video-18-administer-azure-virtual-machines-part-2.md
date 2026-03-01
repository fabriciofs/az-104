# Video 18: Administer Azure Virtual Machines (Part 2) AZ-104

## Informacoes Gerais

| Propriedade             | Valor                                             |
| ----------------------- | ------------------------------------------------- |
| **Titulo**              | Administer Azure Virtual Machines (Part 2) AZ-104 |
| **Canal**               | Microsoft Learn                                   |
| **Inscritos no Canal**  | 88,7 mil                                          |
| **Visualizacoes**       | 2.600+                                            |
| **Data de Publicacao**  | 4 de junho de 2025                                |
| **Posicao na Playlist** | Episodio 18 de 22                                 |
| **Idioma**              | Ingles                                            |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=oaaMcbHsamk                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Continue exploring the essentials of managing Azure virtual machines in Part 2 of this module. You'll build on core concepts such as configuring availability, determining sizing, and connecting using various protocols. This session further equips you to effectively plan, create, and manage Azure VMs.

### O que voce aprendera

- Configuracao de disponibilidade de VMs
- Determinacao de dimensionamento (sizing) de VMs
- Conexao usando diversos protocolos
- Planejamento efetivo de VMs
- Criacao e gerenciamento de Azure VMs

---

## Topicos Abordados

### 1. Disponibilidade de Maquinas Virtuais

| Conceito               | Descricao                                              |
| ---------------------- | ------------------------------------------------------ |
| **Availability Sets**  | Grupos logicos de VMs para alta disponibilidade        |
| **Availability Zones** | Datacenters fisicamente separados dentro de uma regiao |
| **Fault Domains**      | Racks separados de hardware                            |
| **Update Domains**     | Grupos de VMs que podem ser reiniciadas juntas         |

### 2. Dimensionamento de VMs (VM Sizing)

| Serie        | Uso Recomendado                               |
| ------------ | --------------------------------------------- |
| **B-series** | Workloads com uso variavel de CPU (burstable) |
| **D-series** | Proposito geral, balanceado                   |
| **E-series** | Otimizado para memoria                        |
| **F-series** | Otimizado para computacao                     |
| **N-series** | GPU para IA/ML e graficos                     |

### 3. Metodos de Conexao

| Protocolo          | Sistema Operacional | Porta Padrao       |
| ------------------ | ------------------- | ------------------ |
| **RDP**            | Windows             | 3389               |
| **SSH**            | Linux               | 22                 |
| **Bastion**        | Ambos               | Via Portal (HTTPS) |
| **Serial Console** | Ambos               | Via Portal         |

### 4. Configuracoes Avancadas

- **Custom Script Extension** - Executar scripts pos-provisionamento
- **Desired State Configuration (DSC)** - Manter configuracao consistente
- **Run Command** - Executar scripts sem RDP/SSH
- **Azure Automation** - Automatizar tarefas de gerenciamento

---

## Conceitos-Chave para o Exame

1. **Availability Sets vs Zones**

   - Sets: Protecao contra falhas de hardware no mesmo datacenter
   - Zones: Protecao contra falhas de datacenter inteiro

2. **SLA de Disponibilidade**

   - Single VM com Premium SSD: 99.9%
   - Availability Set: 99.95%
   - Availability Zones: 99.99%

3. **Redimensionamento de VMs**

   - Pode causar reinicializacao
   - Nem todos os tamanhos estao disponiveis em todas as regioes
   - Deallocate pode ser necessario para algumas mudancas

4. **Azure Bastion**
   - Conexao segura sem IP publico na VM
   - Usa TLS sobre porta 443
   - Protege contra port scanning

---

## Peso no Exame AZ-104

| Dominio                                               | Peso   |
| ----------------------------------------------------- | ------ |
| Implantar e gerenciar recursos de computacao do Azure | 20-25% |

Este modulo sobre Maquinas Virtuais Azure e fundamental para o exame, cobrindo uma parte significativa das questoes praticas.

---

## Recursos Complementares

| Recurso                    | Link                                                                  |
| -------------------------- | --------------------------------------------------------------------- |
| **Documentacao Azure VMs** | https://learn.microsoft.com/en-us/azure/virtual-machines/             |
| **VM Sizes**               | https://learn.microsoft.com/en-us/azure/virtual-machines/sizes        |
| **Availability Options**   | https://learn.microsoft.com/en-us/azure/virtual-machines/availability |

---

## Video Anterior

**Video 17:** Administer Azure Virtual Machines (Part 1)

- Introducao as VMs Azure
- Criacao de VMs
- Discos gerenciados
- Imagens e templates

## Proximo Video

**Video 19:** Administrar opcoes de computacao PaaS (Parte 1)

- Azure App Service
- App Service Plans
- Deployment slots
- Configuracao de aplicacoes web

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

# Video 19: Administrar Opcoes de Computacao PaaS (Parte 1) AZ-104

## Informacoes Gerais

| Propriedade             | Valor                                                  |
| ----------------------- | ------------------------------------------------------ |
| **Titulo**              | Administrar opcoes de computacao PaaS (Parte 1) AZ-104 |
| **Canal**               | Microsoft Learn                                        |
| **Inscritos no Canal**  | 88,7 mil                                               |
| **Visualizacoes**       | 3.100+                                                 |
| **Data de Publicacao**  | 4 de junho de 2025                                     |
| **Posicao na Playlist** | Episodio 19 de 22                                      |
| **Idioma**              | Ingles (com dublagem automatica disponivel)            |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=5clKdnQCb-0                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Este video e a primeira parte do modulo sobre opcoes de computacao PaaS (Platform as a Service) no Azure. O conteudo aborda como configurar e gerenciar servicos de computacao gerenciados, focando principalmente no Azure App Service e App Service Plans.

### O que voce aprendera

- Conceitos fundamentais de PaaS vs IaaS
- Azure App Service e seus recursos
- Configuracao de App Service Plans
- Deployment slots para implantacoes seguras
- Configuracao de aplicacoes web

---

## Topicos Abordados

### 1. Introducao ao PaaS no Azure

| Conceito           | Descricao                                                           |
| ------------------ | ------------------------------------------------------------------- |
| **PaaS**           | Plataforma gerenciada onde voce so gerencia a aplicacao             |
| **IaaS**           | Infraestrutura onde voce gerencia SO, runtime, etc.                 |
| **SaaS**           | Software pronto para uso                                            |
| **Vantagens PaaS** | Menos gerenciamento, escalabilidade automatica, patches automaticos |

### 2. Azure App Service

| Recurso           | Descricao                                   |
| ----------------- | ------------------------------------------- |
| **Web Apps**      | Hospedagem de aplicacoes web                |
| **API Apps**      | Hospedagem de APIs REST                     |
| **Mobile Apps**   | Backend para apps moveis                    |
| **Function Apps** | Funcoes serverless (abordado separadamente) |

### 3. App Service Plans

| Tier                 | Caracteristicas                                |
| -------------------- | ---------------------------------------------- |
| **Free (F1)**        | Desenvolvimento/teste, recursos limitados      |
| **Shared (D1)**      | Desenvolvimento, CPU compartilhada             |
| **Basic (B1-B3)**    | Apps de baixo trafego, sem auto-scale          |
| **Standard (S1-S3)** | Producao, auto-scale, slots, backups           |
| **Premium (P1-P3)**  | Alta performance, mais slots, VNet integration |
| **Isolated (I1-I3)** | App Service Environment, isolamento completo   |

### 4. Deployment Slots

| Aspecto             | Detalhe                                   |
| ------------------- | ----------------------------------------- |
| **Definicao**       | Ambientes separados para staging/producao |
| **Swap**            | Troca instantanea entre slots             |
| **Warm-up**         | Pre-aquecimento antes do swap             |
| **Rollback**        | Reverter swap se necessario               |
| **Disponibilidade** | Standard tier ou superior                 |

### 5. Configuracao de Aplicacoes

- **Application Settings** - Variaveis de ambiente
- **Connection Strings** - Strings de conexao com banco
- **General Settings** - Stack, versao, platform
- **Path Mappings** - Handler mappings, virtual paths
- **Custom Domains** - Dominios personalizados
- **TLS/SSL** - Certificados e bindings

---

## Conceitos-Chave para o Exame

1. **App Service Plan vs App Service**

   - Plan: Define recursos de computacao (CPU, memoria)
   - App Service: Aplicacao em si que roda no Plan
   - Multiplos App Services podem compartilhar um Plan

2. **Scaling**

   - Scale Up: Mudar para tier superior
   - Scale Out: Adicionar mais instancias
   - Auto-scale: Disponivel em Standard+

3. **Deployment Slots**

   - Producao sempre tem slot padrao
   - Slots adicionais requerem Standard+
   - Swap nao causa downtime

4. **Always On**
   - Mantem a aplicacao sempre carregada
   - Evita cold start
   - Requer Basic tier ou superior

---

## Peso no Exame AZ-104

| Dominio                                               | Peso   |
| ----------------------------------------------------- | ------ |
| Implantar e gerenciar recursos de computacao do Azure | 20-25% |

O App Service e um topico frequente no exame, especialmente questoes sobre tiers, scaling e deployment slots.

---

## Recursos Complementares

| Recurso                      | Link                                                                       |
| ---------------------------- | -------------------------------------------------------------------------- |
| **Documentacao App Service** | https://learn.microsoft.com/en-us/azure/app-service/                       |
| **App Service Plans**        | https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans |
| **Deployment Slots**         | https://learn.microsoft.com/en-us/azure/app-service/deploy-staging-slots   |

---

## Video Anterior

**Video 18:** Administer Azure Virtual Machines (Part 2)

- Configuracao de disponibilidade de VMs
- Dimensionamento de VMs
- Metodos de conexao
- Configuracoes avancadas

## Proximo Video

**Video 20:** Administer PaaS Compute Options (Part 2)

- Azure Container Instances (ACI)
- Azure Kubernetes Service (AKS)
- Azure Functions
- Opcoes avancadas de containers

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

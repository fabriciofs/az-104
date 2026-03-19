# App Service e Containers

## App Service

- Connection strings com prefixo no ambiente: `CUSTOMCONNSTR_`, `SQLCONNSTR_`, `SQLAZURECONNSTR_`
- Slot settings marcados como "deployment slot setting" **NAO** sao swapped
- Backup requer **Standard+**, limite de 10 GB
- VNet Integration = **outbound** (App Service acessa VNet)
- Private Endpoint = **inbound** (VNet acessa App Service)
- Subnet dedicada /28 minimo para VNet Integration

## Custom Domain e TLS

- **CNAME** = subdominio (www.contoso.com); **A record** = apex domain (contoso.com)
- TXT record `asuid` = verificacao de propriedade
- Free/Shared tier **nao** suporta custom domains
- App Service Managed Certificate = gratis, automatico, **so subdomains**
- Apex domain ou wildcard → certificado do Key Vault ou upload .pfx
- SNI SSL (padrao) vs IP-based SSL (requer IP dedicado)
- HTTPS Only forca redirect **301** de HTTP para HTTPS

## App Service - Logs de Diagnostico

**Niveis de severidade (do mais grave ao menos):**
1. Error
2. **Warning** (inclui Warning + Error + Critical)
3. Information
4. **Verbose** (inclui TUDO — mais detalhado)

- "Armazenar avisos e niveis superiores" → nivel **Warning** (NAO Verbose)
- Verbose inclui TUDO (excess de logs); Warning filtra apenas Warning+Error+Critical
- **Blob** = logs persistentes (mais de 1 semana); **FileSystem** = temporario (ate 12h)

## ACR (Azure Container Registry)

| SKU      | Storage | Features extras                    |
| -------- | ------- | ---------------------------------- |
| Basic    | 10 GiB  | -                                  |
| Standard | 100 GiB | Webhooks                           |
| Premium  | 500 GiB | Geo-replication, Private Link, CMK |

## Containers: ACI vs AKS vs Container Apps

| Servico        | Quando usar                                            |
| -------------- | ------------------------------------------------------ |
| ACI            | Containers simples, sem orquestracao                   |
| Container Apps | Serverless com auto-scale, revisions, HTTPS automatico |
| AKS            | Controle total do Kubernetes                           |

## ACI (Azure Container Instances)

- Armazenamento persistente: **Azure Files** (file share montado como volume)
- ACI **NAO** suporta montar Blob, Queue ou Table como volume persistente
- "Container + armazenamento persistente" → **Azure Files** (NUNCA Blob Storage)
- Suporta Linux e Windows containers
- Pode rodar em VNet (deploy privado)

## AKS (Azure Kubernetes Service)

**Seguranca do API Server:**

| Opcao                     | O que faz                                                        |
| ------------------------- | ---------------------------------------------------------------- |
| **IP ranges autorizados** | Mantém endpoint público, restringe quem acessa                   |
| **Cluster privado**       | API server acessível **apenas** pela VNet (sem endpoint público) |

- "Limitar acesso ao API server" → **IP ranges** + **cluster privado** (NAO tags)
- Tags sao metadados de organizacao, nao controlam acesso de rede

## Container Apps

**Tipos de container:**

| Tipo                   | Funcao                                                         |
| ---------------------- | -------------------------------------------------------------- |
| **App**                | Container principal do aplicativo                              |
| **Sidecar (auxiliar)** | Container auxiliar que roda junto (ex: coletor de logs, proxy) |
| **Init**               | Roda antes do app iniciar, depois encerra                      |

- "Container que atualiza cache usado pelo app principal" → **Sidecar** (aplicativo auxiliar)
- "Container privilegiado" NAO e um tipo valido em Container Apps

**Triggers de escalonamento:**

| Trigger          | Quando usar                                                         |
| ---------------- | ------------------------------------------------------------------- |
| HTTP             | Escalar com base em requisicoes HTTP                                |
| CPU/Memoria      | Escalar com base em uso de recursos                                 |
| **Event-driven** | Escalar com base em **eventos externos** (Service Bus, Kafka, etc.) |
| Custom           | Metricas personalizadas                                             |

- "Escalar com base em mensagens do Service Bus" → **Event-driven** (controlado por evento)
- HTTP trigger **NAO** funciona para filas/Service Bus

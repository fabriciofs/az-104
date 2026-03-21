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

### Autenticação no ACR

| Método            | Descrição                                     | Quando usar                          | Recomendado? |
| ----------------- | --------------------------------------------- | ------------------------------------ | ------------ |
| **Admin User**    | Usuário único com 2 senhas; habilitar manualmente | Dev/teste, ACI com `--registry-username` | NAO (prod)   |
| **Service Principal** | App ID + senha; suporta RBAC granular      | CI/CD, pipelines headless            | SIM          |
| **Managed Identity**  | Sem credenciais no código                  | AKS (`--attach-acr`), Container Apps | SIM (melhor) |
| **az acr login**  | Token temporário via CLI                      | Desenvolvimento local                | SIM (dev)    |

**Admin User — Por que existe:**
- Por padrão, ACR só aceita autenticação via Azure AD (sem usuário/senha)
- Serviços que precisam de `--registry-username` e `--registry-password` (ex: ACI) requerem Admin User habilitado
- Habilitar: `az acr update --name meuACR --admin-enabled true`
- Obter credenciais: `az acr credential show --name meuACR`
- **NAO usar em produção** — é conta compartilhada, sem RBAC granular

**Comandos essenciais:**
```bash
# Habilitar admin
az acr update --name meuACR --admin-enabled true

# Push via cloud (sem Docker local) *** RESPOSTA DA PROVA ***
az acr build --registry meuACR --image myapp:v1 .

# Push local (requer Docker)
docker tag myapp:latest meuACR.azurecr.io/myapp:latest
docker push meuACR.azurecr.io/myapp:latest

# Importar de outro registry
az acr import --name meuACR --source docker.io/library/nginx:latest --image nginx:latest
```

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

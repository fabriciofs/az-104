> Voltar para o [Cenario Contoso](../cenario-contoso.md)

# Bloco 7 - ACR e App Service Avancado

**Origem:** Lab 09b - Implement Azure Container Instances (ACR) + Lab 09a - App Service (topicos avancados)
**Resource Groups utilizados:** `rg-contoso-compute` (App Service do Bloco 3) + `rg-contoso-compute` (Container Registry, ACI)

## Contexto

A Contoso Corp precisa de um registro privado de containers para armazenar e distribuir imagens de forma segura (Azure Container Registry), e configuracoes avancadas de App Service cobradas no exame AZ-104: mapeamento de dominio DNS customizado, certificados TLS/SSL, backup de Web Apps e integracao com VNet. Este bloco complementa o Bloco 3 (Web Apps basico) e o Bloco 4 (ACI basico) com funcionalidades avancadas.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     rg-contoso-compute                                         │
│                                                                          │
│  ┌──────────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ Azure Container Registry     │  │ ACI: ci-contoso-acr               │  │
│  │ acrcontosoprod<uniqueid>           │  │                                  │  │
│  │ SKU: Basic                   │  │ Image: acrcontosoprod*.azurecr.io/     │  │
│  │                              │  │   sample-app:v1                  │  │
│  │ Images:                      │  │                                  │  │
│  │ • sample-app:v1              │  │ ← Pull from ACR (admin creds)    │  │
│  │   (built via az acr build)   │  │                                  │  │
│  └──────────────────────────────┘  └──────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │ rg-contoso-compute (App Service do Bloco 3)                               │    │
│  │                                                                  │    │
│  │  App Service: app-contoso-web                                     │    │
│  │  ├─ Custom DNS: walkthrough (CNAME + verificacao)                │    │
│  │  ├─ TLS/SSL: walkthrough (certificado)                           │    │
│  │  ├─ Backup: para Storage Account (stcontosoprod01)                 │    │
│  │  └─ VNet Integration: vnet-contoso-hub-brazilsouth (Semana 1)                │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### Task 7.1: Criar Azure Container Registry (ACR)

1. Pesquise **Container registries** > **+ Create**:

   | Setting        | Value                                    |
   | -------------- | ---------------------------------------- |
   | Resource group | `rg-contoso-compute` (crie se necessario)      |
   | Registry name  | `acrcontosoprod<uniqueid>` (globalmente unico) |
   | Region         | **(US) East US**                         |
   | SKU            | **Basic**                                |

2. **Review + create** > **Create** > **Go to resource**

3. No **Overview**, note:
   - **Login server**: `acrcontosoprod<uniqueid>.azurecr.io`
   - **SKU**: Basic (suporta ate 10 GiB de storage)

4. Navegue para **Settings** > **Access keys**:
   - Habilite **Admin user** (para simplificar o lab)
   - Anote o **Username** e **password**

   > **Conceito:** ACR e um registro privado de containers compativel com Docker. SKUs: Basic (desenvolvimento), Standard (producao), Premium (geo-replicacao, private link, content trust). Admin user e para testes — em producao, use Managed Identity ou service principal.

   > **Dica AZ-104:** Na prova: ACR Basic vs Standard vs Premium. Basic = 10 GiB; Standard = 100 GiB + webhooks; Premium = 500 GiB + geo-replication + private link + customer-managed keys.

---

### Task 7.2: Build e push de imagem via az acr build

O `az acr build` permite construir imagens diretamente no ACR, sem precisar de Docker instalado localmente.

1. Abra o **Cloud Shell** (Bash)

2. Crie um Dockerfile simples:

   ```bash
   mkdir ~/acr-lab && cd ~/acr-lab

   cat > Dockerfile << 'EOF'
   FROM mcr.microsoft.com/hello-world
   EOF
   ```

3. Execute o build no ACR:

   ```bash
   az acr build \
     --registry acrcontosoprod<uniqueid> \
     --image sample-app:v1 \
     --file Dockerfile .
   ```

4. Aguarde o build completar (1-2 minutos)

5. Liste as imagens no ACR:

   ```bash
   az acr repository list --name acrcontosoprod<uniqueid> -o table
   ```

6. Veja os tags da imagem:

   ```bash
   az acr repository show-tags --name acrcontosoprod<uniqueid> --repository sample-app -o table
   ```

7. No portal, navegue para o ACR > **Repositories** > **sample-app** > confirme que `v1` esta listado

   > **Conceito:** `az acr build` executa o build no cloud (ACR Tasks), eliminando a necessidade de Docker local. O contexto (Dockerfile + arquivos) e enviado ao ACR que executa o build e armazena a imagem. Ideal para CI/CD e ambientes sem Docker.

---

### Task 7.3: Deploy ACI a partir de imagem privada do ACR

1. Pesquise **Container instances** > **+ Create**:

   | Setting        | Value                        |
   | -------------- | ---------------------------- |
   | Resource group | `rg-contoso-compute`               |
   | Container name | `ci-contoso-acr`              |
   | Region         | **(US) East US**             |
   | Image source   | **Azure Container Registry** |
   | Registry       | `acrcontosoprod<uniqueid>`         |
   | Image          | `sample-app`                 |
   | Image tag      | `v1`                         |
   | OS type        | **Linux**                    |
   | Size           | **1 vcpu, 1.5 GiB memory**   |

2. Aba **Networking**:

   | Setting | Value      |
   | ------- | ---------- |
   | Type    | **Public** |

3. **Review + create** > **Create**

4. Apos o deploy, navegue para o container instance > **Overview**:
   - Verifique **Status** = Running
   - Navegue para **Containers** > **Logs** para ver a saida

   > **Conceito:** ACI pode puxar imagens de registros privados (ACR, Docker Hub privado) usando credenciais de admin, service principal ou managed identity. Em producao, prefira managed identity para eliminar credenciais hardcoded.

   > **Conexao com Bloco 4:** No Bloco 4 voce criou ACI com imagens publicas do Docker Hub. Agora voce usa uma imagem privada do ACR — o fluxo recomendado para aplicacoes corporativas.

---

### Task 7.4: Mapear dominio DNS customizado para App Service (walkthrough)

> **Nota:** Esta task documenta o processo completo de mapeamento DNS. Em ambiente de lab sem dominio comprado, voce seguira os passos no portal ate o ponto de verificacao, entendendo cada etapa.

1. Navegue para o App Service **app-contoso-web** (do Bloco 3, em rg-contoso-compute)

2. **Settings** > **Custom domains** > **+ Add custom domain**

3. O processo requer:

   **Passo 1 — Registrar CNAME no provedor DNS:**

   | Record Type | Host        | Points to                          |
   | ----------- | ----------- | ---------------------------------- |
   | CNAME       | `www`       | `app-contoso-web.azurewebsites.net` |
   | TXT         | `asuid.www` | *Domain verification ID do portal* |

   **Passo 2 — Verificacao no portal:**
   - O Azure verifica que o CNAME e o TXT record existem no DNS
   - Apos verificacao, o dominio customizado e vinculado ao App Service

   **Passo 3 — Configurar no portal:**

   | Setting              | Value                |
   | -------------------- | -------------------- |
   | Domain               | `www.seudominio.com` |
   | Hostname record type | **CNAME**            |

4. No portal, observe as **opcoes disponiveis** mesmo sem dominio real:
   - Note o **Custom Domain Verification ID** (valor unico do App Service)
   - Note que o App Service ja tem o dominio padrao `*.azurewebsites.net`
   - Revise a documentacao inline sobre como configurar A records (para apex/root domain)

   > **Conceito:** Dominios customizados requerem verificacao via CNAME ou TXT record. Para o apex domain (contoso.com sem www), use A record + TXT verification. O Azure valida a propriedade do dominio antes de vincular. App Service Free/Shared NAO suportam dominios customizados — requer Basic ou superior.

   > **Dica AZ-104:** Na prova: CNAME = subdominio (www.contoso.com); A record = apex domain (contoso.com). O TXT record `asuid` e usado para verificacao de propriedade. Free/Shared tier nao suporta custom domains.

---

### Task 7.5: Configurar certificado TLS/SSL para App Service (walkthrough)

> **Nota:** Como na task anterior, esta e uma walkthrough documentando o processo sem dominio real.

1. No App Service, navegue para **Settings** > **Certificates**

2. Explore as opcoes de certificado:

   | Opcao                           | Descricao                                  | Custo  |
   | ------------------------------- | ------------------------------------------ | ------ |
   | App Service Managed Certificate | Certificado gratuito gerenciado pelo Azure | Free   |
   | Import from Key Vault           | Certificado armazenado no Key Vault        | Varies |
   | Upload certificate (.pfx)       | Certificado proprio                        | Varies |

3. Note que **App Service Managed Certificate**:
   - E gratuito e renovado automaticamente
   - Requer custom domain ja configurado
   - NAO suporta apex domains ou wildcard
   - Requer Standard tier ou superior

4. Em **TLS/SSL settings** (ou **Settings** > **Configuration** > **General settings**):

   | Setting             | Value                                |
   | ------------------- | ------------------------------------ |
   | HTTPS Only          | **On** (redireciona HTTP para HTTPS) |
   | Minimum TLS version | **1.2**                              |

5. Clique em **Save**

6. Abra o navegador e acesse `http://app-contoso-web.azurewebsites.net` (HTTP, sem S)

7. Observe o redirecionamento automatico para HTTPS (a URL muda no navegador)

8. **Validacao:** O HTTPS Only forca um redirect 301 de HTTP para HTTPS. Qualquer requisicao HTTP e automaticamente redirecionada

   > **Conceito:** HTTPS Only forca redirecionamento de todas as requisicoes HTTP para HTTPS (301 redirect). TLS 1.2 e o minimo recomendado — versoes anteriores (1.0, 1.1) tem vulnerabilidades conhecidas. App Service Managed Certificate simplifica TLS para subdomains sem custo adicional.

   > **Dica AZ-104:** Na prova: App Service Managed Certificate = gratis, automatico, so subdomains. Para apex domain ou wildcard, use certificado importado do Key Vault ou upload .pfx. Binding types: SNI SSL (padrao) vs IP-based SSL (requer IP dedicado).

---

### Task 7.6: Configurar backup do App Service para Storage Account

1. No App Service, navegue para **Settings** > **Backups**

   > **Nota:** Backup requer App Service Plan **Standard** ou superior.

2. Clique em **Configure**:

   | Setting        | Value                                         |
   | -------------- | --------------------------------------------- |
   | Backup storage | **Storage Account**: stcontosoprod01 (Bloco 1) |
   | Container      | Selecione ou crie `webapp-backups`            |

3. Configure o **schedule**:

   | Setting                  | Value             |
   | ------------------------ | ----------------- |
   | Scheduled backup         | **On**            |
   | Backup every             | `1` **Days**      |
   | Start from               | *data/hora atual* |
   | Retention (days)         | `30`              |
   | Keep at least one backup | **Yes**           |

4. Marque **Include database**: Nao (sem banco neste lab)

5. Clique em **Save**

6. Clique em **Backup Now** para executar um backup imediato

7. Aguarde o backup completar > verifique o status na lista de backups

8. Navegue para **stcontosoprod01** > **Containers** > `webapp-backups` e confirme que o arquivo de backup (.zip) esta la

   > **Conceito:** App Service Backup cria um snapshot completo da aplicacao (codigo, configuracao, conteudo). Os backups sao armazenados em uma Storage Account como arquivos .zip. O limite e 10 GB por app. Para bancos de dados, o backup inclui connection strings configuradas.

   > **Conexao com Bloco 1:** O backup e armazenado na Storage Account criada no Bloco 1, demonstrando integracao entre servicos. As regras de SAS e networking do Bloco 1 se aplicam ao acesso dos backups.

   > **Dica AZ-104:** Na prova: Backup requer Standard+. Limite de 10 GB. O backup inclui app settings, connection strings e conteudo. Para restore, voce pode restaurar para o mesmo app ou para um novo.

---

### Task 7.7: Configurar VNet Integration no App Service

VNet Integration permite que o App Service acesse recursos privados na VNet (outbound traffic).

1. No App Service, navegue para **Settings** > **Networking**

2. Em **Outbound traffic**, clique em **VNet integration** > **+ Add VNet**:

   | Setting         | Value                                         |
   | --------------- | --------------------------------------------- |
   | Virtual network | **vnet-contoso-hub-brazilsouth** (do rg-contoso-network, Semana 1) |
   | Subnet          | Selecione ou crie uma subnet dedicada         |

   > **Nota:** Se nenhuma subnet livre estiver disponivel, crie uma nova: `WebAppSubnet` (10.20.50.0/24) na vnet-contoso-hub-brazilsouth.

3. Clique em **OK**

4. **Validacao:** Apos a integracao, o App Service pode acessar:
   - Recursos com Private Endpoints na VNet (ex: Storage Account do Bloco 1)
   - VMs em subnets da mesma VNet
   - Recursos em VNets peered (se peering estiver configurado)

5. Verifique a configuracao: volte para **Networking** > confirme que VNet integration mostra a VNet e subnet configuradas

   > **Conceito:** VNet Integration (regional) permite que o App Service envie trafego outbound pela VNet. Isso nao expoe o App Service na VNet (para inbound, use Private Endpoints). A subnet delegada ao App Service nao pode ter outros recursos. Requer Standard ou Premium plan.

   > **Conexao com Semana 1:** O App Service agora pode acessar o Storage Account via Private Endpoint (configurado no Bloco 1 da Semana 2) pela vnet-contoso-hub-brazilsouth, garantindo que o trafego nunca saia da rede Microsoft.

   > **Dica AZ-104:** Na prova: VNet Integration = outbound (App Service acessa VNet). Private Endpoint = inbound (VNet acessa App Service). Requer subnet dedicada (/28 minimo). Funciona com peering e ExpressRoute.

---

## Modo Desafio - Bloco 7

- [ ] Criar ACR `acrcontosoprod<id>` (Basic) com admin user habilitado
- [ ] Criar Dockerfile e executar `az acr build` para gerar imagem `sample-app:v1`
- [ ] Criar ACI puxando imagem privada do ACR
- [ ] Explorar configuracao de Custom Domain no App Service **(Bloco 3)** — CNAME + TXT verification
- [ ] Configurar HTTPS Only + TLS 1.2 no App Service
- [ ] Testar redirecionamento HTTP → HTTPS no navegador (validar 301 redirect)
- [ ] Explorar opcoes de certificado: Managed, Key Vault, Upload
- [ ] Configurar backup do App Service para storage account **(Bloco 1)** com schedule diario
- [ ] Executar backup manual e verificar .zip no container
- [ ] Configurar VNet Integration no App Service com vnet-contoso-hub-brazilsouth **(Semana 1)**

---

## Questoes de Prova - Bloco 7

### Questao 7.1
**Voce precisa construir uma imagem de container sem instalar Docker localmente. Qual servico do Azure permite isso?**

A) Azure Container Instances
B) Azure Container Registry Tasks (az acr build)
C) Azure Kubernetes Service
D) Azure App Service

<details>
<summary>Ver resposta</summary>

**Resposta: B) Azure Container Registry Tasks (az acr build)**

ACR Tasks permite executar builds de imagens diretamente no cloud. O comando `az acr build` envia o Dockerfile e contexto para o ACR, que executa o build e armazena a imagem resultante. Nao requer Docker ou outro container runtime instalado localmente.

</details>

### Questao 7.2
**Voce quer mapear o dominio `api.contoso.com` para um App Service. Qual tipo de registro DNS voce deve criar?**

A) A record apontando para o IP do App Service
B) CNAME record apontando para `*.azurewebsites.net`
C) MX record apontando para o App Service
D) SRV record com a porta 443

<details>
<summary>Ver resposta</summary>

**Resposta: B) CNAME record apontando para `*.azurewebsites.net`**

Para subdomains (www, api, etc.), use CNAME apontando para o FQDN do App Service (`app-name.azurewebsites.net`). Para o apex/root domain (contoso.com sem subdomain), use A record com o IP do App Service + TXT record para verificacao.

</details>

### Questao 7.3
**Qual SKU do Azure Container Registry suporta geo-replicacao e Private Link?**

A) Basic
B) Standard
C) Premium
D) Todas as SKUs

<details>
<summary>Ver resposta</summary>

**Resposta: C) Premium**

Apenas a SKU Premium do ACR suporta geo-replicacao, Private Link, content trust e customer-managed keys. Basic e Standard nao oferecem esses recursos enterprise. Premium tambem tem maior capacidade de storage (500 GiB).

</details>

### Questao 7.4
**Voce configurou VNet Integration em um App Service. O que essa configuracao permite?**

A) Usuarios na VNet podem acessar o App Service via IP privado
B) O App Service pode enviar trafego outbound pela VNet para acessar recursos privados
C) O App Service e implantado diretamente na VNet
D) O App Service recebe um IP publico da VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B) O App Service pode enviar trafego outbound pela VNet para acessar recursos privados**

VNet Integration (regional) permite que o App Service envie trafego outbound pela VNet, acessando recursos como Private Endpoints, VMs e servicos em VNets peered. Para permitir acesso inbound via IP privado, use App Service Private Endpoints. VNet Integration nao move o App Service para a VNet.

</details>

### Questao 7.5
**Voce precisa fazer backup automatico de um App Service diariamente. Quais sao os requisitos?**

A) Free tier + Blob storage
B) Standard tier ou superior + Storage Account com container
C) Qualquer tier + Azure Backup vault
D) Premium tier + Azure Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) Standard tier ou superior + Storage Account com container**

App Service Backup requer plano Standard ou superior e uma Storage Account com um container blob para armazenar os backups (.zip). O limite e 10 GB por app. O backup inclui codigo, configuracao e opcionalmente banco de dados.

</details>

---

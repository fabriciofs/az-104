> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 4 - Azure Container Instances](bloco4-aci.md)

# Bloco 3 - Azure Web Apps

**Origem:** Lab 09a - Implement Web Apps
**Resource Groups utilizados:** `az104-rg8`

## Contexto

Com armazenamento (Bloco 1) e computacao (Bloco 2) configurados, voce agora implanta aplicacoes web usando Azure App Service. As Web Apps se conectam ao storage do Bloco 1 via connection strings para acessar blobs e file shares. Voce tambem configura deployment slots para estrategias de deploy blue/green, demonstrando como a Contoso Corp pode fazer deploys sem downtime.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg8                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  App Service Plan: az104-appplan                              │  │
│  │  SKU: Standard S1                                             │  │
│  │  OS: Linux                                                    │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────┐     │  │
│  │  │  Web App: az104-webapp-<uniqueid>                     │     │  │
│  │  │                                                       │     │  │
│  │  │  Runtime: PHP 8.2                                     │     │  │
│  │  │  Deployment: GitHub/External Git                      │     │  │
│  │  │                                                       │     │  │
│  │  │  App Settings:                                        │     │  │
│  │  │  • STORAGE_CONNECTION (← Bloco 1 Storage Account)     │     │  │
│  │  │                                                       │     │  │
│  │  │  Deployment Slots:                                    │     │  │
│  │  │  • Production (default)                               │     │  │
│  │  │  • staging (swap target)                              │     │  │
│  │  │                                                       │     │  │
│  │  │  Scaling:                                             │     │  │
│  │  │  • Scale out: min 1, max 3 (CPU > 60%)               │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Connection String referencia Storage Account do Bloco 1         │
│  → Deployment Slots permitem deploy blue/green sem downtime        │
└───────────────────────────────────────────────────────────────────┘
```

---

### Task 3.1: Criar App Service Plan e Web App

> **Cobranca:** O App Service Plan gera cobranca enquanto existir, mesmo com a app parada.

1. Pesquise e selecione **App Services** > **+ Create** > **Web App**

2. Aba **Basics**:

   | Setting              | Value                                       |
   | -------------------- | ------------------------------------------- |
   | Subscription         | *sua subscription*                          |
   | Resource group       | `az104-rg8` (crie se necessario)            |
   | Name                 | `az104-webapp-<uniqueid>` (globalmente unico) |
   | Publish              | **Code**                                    |
   | Runtime stack        | **PHP 8.2**                                 |
   | Operating System     | **Linux**                                   |
   | Region               | **East US**                                 |
   | App Service Plan     | *Create new*: `az104-appplan`               |
   | Pricing plan         | **Standard S1**                             |

   > **Nota:** Standard S1 ou superior e necessario para deployment slots. Free/Basic nao suportam slots.

3. Aba **Deployment**: mantenha defaults (nenhum deployment continuo)

4. Aba **Networking**: mantenha defaults

5. Aba **Monitoring**: **Disable** Application Insights (para simplificar)

6. Clique em **Review + create** > **Create** > **Go to resource**

7. No blade **Overview**, copie a **Default domain** URL (ex: `az104-webapp-<uniqueid>.azurewebsites.net`)

8. Acesse a URL no navegador — voce deve ver a pagina padrao do App Service

   > **Conceito:** Um App Service Plan define os recursos de compute (CPU, memoria, features) disponiveis para as Web Apps hospedadas nele. Multiplas Web Apps podem compartilhar o mesmo plan.

---

### Task 3.2: Configurar Connection String do Storage (Bloco 1)

Voce conecta a Web App ao Storage Account do Bloco 1 para que a aplicacao possa acessar blobs e dados.

1. Na Web App, navegue para **Settings** > **Environment variables**

2. Na aba **App settings**, clique em **+ Add**:

   | Setting | Value                                                                     |
   | ------- | ------------------------------------------------------------------------- |
   | Name    | `STORAGE_ACCOUNT_NAME`                                                    |
   | Value   | `contosostore<uniqueid>` (nome do storage account do Bloco 1)            |

3. Clique em **Apply**

4. Na aba **Connection strings**, clique em **+ Add**:

   | Setting | Value                                                        |
   | ------- | ------------------------------------------------------------ |
   | Name    | `AzureStorageConnection`                                     |
   | Value   | *cole a connection string da Storage Account (Bloco 1)*      |
   | Type    | **Custom**                                                   |

   > **Para obter a connection string:** Va ate a Storage Account (Bloco 1) > **Security + networking** > **Access keys** > copie a **Connection string** de key1.

5. Clique em **Apply** > **Apply** (confirme as alteracoes)

   > **Conexao com Bloco 1:** A Web App agora tem referencia direta ao Storage Account. Em um cenario real, a aplicacao usaria esta connection string para acessar blobs, queues ou tables.

6. **Validacao:** Na Web App, navegue para **Advanced tools** > **Go** (Kudu)

7. No Kudu, va para **Environment** e procure `STORAGE_ACCOUNT_NAME` e `CUSTOMCONNSTR_AzureStorageConnection` — ambos devem estar listados

   > **Dica AZ-104:** Na prova, connection strings definidas como App Settings aparecem com prefixo no ambiente: `CUSTOMCONNSTR_`, `SQLCONNSTR_`, `SQLAZURECONNSTR_`, etc.

---

### Task 3.3: Deploy de aplicacao e Deployment Slots

1. Na Web App, navegue para **Deployment** > **Deployment Center**

2. Configure o source:

   | Setting    | Value            |
   | ---------- | ---------------- |
   | Source     | **External Git** |
   | Repository | `https://github.com/Azure-Samples/php-docs-hello-world` |
   | Branch     | `master`         |

3. Clique em **Save**

4. Aguarde o deployment. Navegue para **Deployment Center** > aba **Logs** para acompanhar

5. Acesse a URL da Web App — voce deve ver "Hello World!" (ou conteudo similar do sample app)

**Criar Deployment Slot:**

6. Navegue para **Deployment** > **Deployment slots**

7. Clique em **+ Add Slot**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `staging`   |
   | Clone settings from | **Do not clone settings** |

8. Clique em **Add**

9. Selecione o slot **staging** (abre como uma Web App separada)

10. No slot staging, configure um deployment diferente (ou use o mesmo repo):
    - Navegue para **Deployment Center** do slot staging
    - Mantenha o mesmo source ou altere o branch para demonstrar a diferenca

11. Acesse a URL do slot staging: `az104-webapp-<uniqueid>-staging.azurewebsites.net`

   > **Conceito:** Slots permitem testar alteracoes em um ambiente identico ao producao antes de promover (swap). Cada slot tem sua propria URL, configuracoes e deployment.

---

### Task 3.4: Swap de Deployment Slots

1. Navegue de volta para a Web App principal (nao o slot) > **Deployment** > **Deployment slots**

2. Clique em **Swap**:

   | Setting     | Value              |
   | ----------- | ------------------ |
   | Source      | **staging**        |
   | Target      | **Production**     |

3. Revise as **Config changes** (mostra quais settings vao mudar)

4. Clique em **Swap**

5. Aguarde a operacao concluir

6. Acesse a URL de producao — o conteudo agora e o que estava no staging

   > **Conceito:** Swap e uma operacao instantanea (switch de DNS/routing). Nao ha downtime. Se algo der errado, faca swap novamente para reverter.

   > **Dica AZ-104:** Slot settings marcados como "deployment slot setting" NAO sao swapped — ficam fixos no slot. Isso e util para connection strings de staging vs production.

---

### Task 3.5: Configurar Auto-scaling

1. Na Web App, navegue para **Settings** > **Scale out (App Service plan)**

2. Selecione **Rules Based** (se disponivel) ou configure:

   | Setting               | Value                        |
   | --------------------- | ---------------------------- |
   | Minimum instances     | `1`                          |
   | Maximum instances     | `3`                          |
   | Rules                 | *custom rule abaixo*         |

3. **+ Add a rule** (scale-out):

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Metric source      | **Current resource**     |
   | Metric name        | **CPU Percentage**       |
   | Operator           | **Greater than**         |
   | Metric threshold   | `60`                     |
   | Duration           | `5` minutes              |
   | Operation          | **Increase count by**    |
   | Instance count     | `1`                      |
   | Cool down          | `5` minutes              |

4. **+ Add a rule** (scale-in):

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Metric source      | **Current resource**     |
   | Metric name        | **CPU Percentage**       |
   | Operator           | **Less than**            |
   | Metric threshold   | `30`                     |
   | Duration           | `5` minutes              |
   | Operation          | **Decrease count by**    |
   | Instance count     | `1`                      |
   | Cool down          | `5` minutes              |

5. Clique em **Save**

   > **Conceito:** Auto-scale no App Service opera no nivel do **App Service Plan**, nao da Web App individual. Todas as apps no mesmo plan sao escaladas juntas.

---

### Task 3.6: Explorar App Service Features (Networking, Logs)

1. Navegue para **Settings** > **Networking** na Web App

2. Explore as opcoes:
   - **Inbound Traffic**: Access restrictions, Private endpoints
   - **Outbound Traffic**: VNet integration, Hybrid connections

   > **Conceito:** VNet Integration permite que a Web App acesse recursos em uma VNet (como o storage com Private Endpoint do Bloco 1).

3. Navegue para **Monitoring** > **App Service logs**

4. Configure:

   | Setting                  | Value            |
   | ------------------------ | ---------------- |
   | Application Logging (Filesystem) | **On** |
   | Level                    | **Information**  |
   | Web server logging       | **File System**  |
   | Quota (MB)               | `35`             |
   | Retention Period (Days)  | `3`              |

5. Clique em **Save**

6. Navegue para **Log stream** e observe os logs em tempo real enquanto acessa a URL da Web App em outra aba

   > **Conceito:** Logs do App Service podem ser enviados para File System, Blob Storage ou Application Insights. Log stream mostra logs em tempo real via browser.

---

## Modo Desafio - Bloco 3

- [ ] Criar App Service Plan `az104-appplan` (Standard S1, Linux) no az104-rg8
- [ ] Criar Web App com runtime PHP 8.2
- [ ] **Integracao Bloco 1:** Configurar App Setting com nome do Storage Account e Connection String
- [ ] Validar variaveis de ambiente via Kudu
- [ ] Deploy de app sample via External Git
- [ ] Criar slot `staging` e fazer deploy
- [ ] Executar **Swap** staging → production
- [ ] Configurar auto-scaling (CPU > 60% scale-out, < 30% scale-in)
- [ ] Explorar Networking (VNet Integration, Access restrictions)
- [ ] Habilitar App Service Logs e testar Log stream

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa de deployment slots para sua Web App. Qual tier minimo do App Service Plan e necessario?**

A) Free F1
B) Basic B1
C) Standard S1
D) Premium P1

<details>
<summary>Ver resposta</summary>

**Resposta: C) Standard S1**

Deployment slots estao disponiveis a partir do tier **Standard S1**. Free e Basic nao suportam slots. Standard permite ate 5 slots, Premium ate 20.

</details>

### Questao 3.2
**Voce fez um swap do slot staging para production. Uma connection string marcada como "deployment slot setting" no slot staging vai para production?**

A) Sim, todas as settings sao swapped
B) Nao, "deployment slot settings" permanecem no slot original
C) Apenas connection strings sao swapped
D) Depende do tipo da connection string

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, "deployment slot settings" permanecem no slot original**

Settings marcadas como "deployment slot setting" sao **sticky** — permanecem no slot e NAO sao swapped. Isso permite ter connection strings diferentes para staging e production (ex: banco de dados diferente).

</details>

### Questao 3.3
**Voce configurou auto-scaling baseado em CPU no App Service Plan. Quando o scale-out acontece, quais apps sao escaladas?**

A) Apenas a Web App que disparou a regra
B) Todas as Web Apps no mesmo App Service Plan
C) Apenas Web Apps com a mesma connection string
D) Depende da configuracao individual de cada app

<details>
<summary>Ver resposta</summary>

**Resposta: B) Todas as Web Apps no mesmo App Service Plan**

Auto-scaling opera no nivel do **App Service Plan**, nao da Web App individual. Quando o plan escala, TODAS as apps hospedadas nele recebem mais instancias. Por isso e importante planejar quais apps compartilham o mesmo plan.

</details>

---


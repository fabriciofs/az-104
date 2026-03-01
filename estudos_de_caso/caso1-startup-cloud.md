# Estudo de Caso 1 — ByteWave Tecnologia

**Dificuldade:** Facil | **Dominios:** D1 Identity & Governance + D2 Storage | **Questoes:** 6

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `caso1-startup-cloud-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: ByteWave Tecnologia

A **ByteWave Tecnologia** e uma startup de 25 funcionarios com sede em **Florianopolis**, especializada em desenvolvimento de aplicativos moveis para o setor de turismo. A empresa esta em fase de crescimento rapido e decidiu adotar o Azure como plataforma cloud.

**Renata Oliveira**, co-fundadora e unica pessoa com experiencia em cloud, foi designada como **Azure Administrator**. Ela precisa estruturar o ambiente Azure do zero, garantindo que a equipe tenha acesso adequado e que os dados dos clientes estejam armazenados de forma segura e economica.

A ByteWave trabalha frequentemente com **freelancers externos** para projetos especificos e tambem com uma empresa de **auditoria contabil** que precisa acessar relatorios financeiros armazenados no Azure.

### Equipe

| Persona                      | Funcao                              | Acesso Necessario                         |
| ---------------------------- | ----------------------------------- | ----------------------------------------- |
| Renata Oliveira (`bw-admin`) | Azure Administrator / Co-fundadora  | Owner na subscription                     |
| Pedro Santos                 | Freelancer de design (externo)      | Acesso temporario a arquivos de design    |
| Ana Costa                    | Auditora contabil (empresa externa) | Somente leitura em relatorios financeiros |
| Grupo **Devs**               | Time de desenvolvimento (8 pessoas) | Contributor em RGs de desenvolvimento     |
| Grupo **Marketing**          | Time de marketing (5 pessoas)       | Acesso a blobs publicos de marketing      |

### Infraestrutura

```
                    ┌───────────────────────────────────────────┐
                    │          AZURE — Brazil South             │
                    │                                           │
                    │  Subscription: ByteWave-Prod              │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  RG: bw-dev-rg                      │  │
                    │  │  - Storage Account (codigo-fonte)   │  │
                    │  │  - App Service (dev environment)    │  │
                    │  └─────────────────────────────────────┘  │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  RG: bw-marketing-rg                │  │
                    │  │  - Storage Account (assets publicos)│  │
                    │  │  - CDN Profile                      │  │
                    │  └─────────────────────────────────────┘  │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  RG: bw-finance-rg                  │  │
                    │  │  - Storage Account (relatorios)     │  │
                    │  └─────────────────────────────────────┘  │
                    │                                           │
                    │  Tags obrigatorias: Project, CostCenter   │
                    └───────────────────────────────────────────┘
```

### Requisitos de Storage

| Storage Account | Container       | Finalidade                   | Acesso                    |
| --------------- | --------------- | ---------------------------- | ------------------------- |
| `bwdevstorage`  | `source-code`   | Backups de codigo            | Privado — apenas Devs     |
| `bwmarketing`   | `public-assets` | Imagens, videos de marketing | Publico — CDN             |
| `bwfinance`     | `reports`       | Relatorios financeiros       | Privado — apenas auditora |

---

## Secao 1 — Identidade e Governanca (3 questoes)

### Q1.1 — Guest User vs Member User (Multipla Escolha)

Renata precisa dar acesso ao ambiente Azure para Pedro Santos (freelancer) e Ana Costa (auditora). Ambos sao de empresas externas e nao fazem parte da organizacao da ByteWave.

Renata decide convidar ambos como **guest users** no Microsoft Entra ID. Apos enviar os convites, ela tenta atribuir o role **Reader** a Ana Costa no resource group `bw-finance-rg`. Ana aceita o convite e faz login, mas ao acessar o portal do Azure, ela nao consegue ver nenhum recurso.

Qual e a causa **mais provavel**?

- **A)** Guest users nao podem receber atribuicoes RBAC
- **B)** Ana precisa ser convertida de Guest para Member antes de usar RBAC
- **C)** Ana precisa acessar o portal usando o URL com o tenant ID da ByteWave (portal.azure.com/bytewavetenantid)
- **D)** O role Reader so funciona no escopo de subscription, nao de resource group

---

### Q1.2 — RBAC Scoping para Acesso Minimo (Design)

Renata precisa configurar permissoes seguindo o principio de **least privilege**:

1. O grupo **Devs** precisa criar e gerenciar todos os recursos dentro de `bw-dev-rg`, mas nao pode acessar outros resource groups
2. O grupo **Marketing** precisa apenas fazer upload e gerenciar blobs no container `public-assets` do storage account `bwmarketing`
3. Ana Costa (auditora) precisa ler os blobs no container `reports` do storage account `bwfinance`, sem poder modificar nada

Responda:

1. Qual role e escopo voce atribuiria ao grupo **Devs**?
2. Qual role e escopo voce atribuiria ao grupo **Marketing**? Ha um role mais especifico que **Contributor**?
3. Qual role e escopo voce atribuiria a **Ana Costa**? Qual a diferenca entre usar **Reader** no RG vs um role de storage mais especifico?

---

### Q1.3 — Azure Policy para Tags Obrigatorias (Multipla Escolha)

Renata quer garantir que todos os recursos criados na subscription tenham as tags `Project` e `CostCenter`. Ela cria uma Azure Policy com efeito **Deny** que exige a tag `Project` e atribui na subscription.

Um desenvolvedor tenta criar um Storage Account sem a tag `Project` e recebe erro. Em seguida, ele cria o Storage Account com a tag `Project = "MobileApp"`, mas sem a tag `CostCenter`. O recurso e criado com sucesso.

Por que o recurso foi criado sem a tag `CostCenter`?

- **A)** O efeito Deny nao consegue verificar mais de uma tag por vez
- **B)** Renata so criou uma policy para a tag `Project`; precisa de uma segunda policy (ou initiative) para `CostCenter`
- **C)** Tags sao opcionais por natureza e nao podem ser obrigatorias via policy
- **D)** A policy Deny so funciona para tags herdadas, nao para tags em novos recursos

---

## Secao 2 — Armazenamento (3 questoes)

### Q2.1 — Redundancia de Storage Account (Multipla Escolha)

Renata precisa escolher o nivel de redundancia para cada storage account. O orcamento e limitado, mas a seguranca dos dados varia por caso:

- `bwdevstorage`: Backups de codigo — ja existem copias no GitHub, perda toleravel
- `bwfinance`: Relatorios financeiros — criticos, precisam sobreviver a desastre regional
- `bwmarketing`: Assets publicos — facilmente recriados, perda toleravel

Qual combinacao de redundancia e a **mais adequada e economica**?

- **A)** LRS para todos — mais barato e suficiente para uma startup
- **B)** `bwdevstorage`: LRS, `bwfinance`: GRS, `bwmarketing`: LRS
- **C)** GRS para todos — maximo de seguranca
- **D)** `bwdevstorage`: ZRS, `bwfinance`: ZRS, `bwmarketing`: LRS

---

### Q2.2 — Blob Access Tiers e Lifecycle Management (Design)

O storage account `bwfinance` acumula relatorios mensais. Renata observou o seguinte padrao de acesso:

- Relatorios do **mes atual**: acessados diariamente pela auditora
- Relatorios dos **ultimos 3 meses**: acessados eventualmente
- Relatorios com **mais de 6 meses**: acessados apenas em auditorias anuais
- Relatorios com **mais de 5 anos**: obrigacao legal de manter, nunca acessados

Responda:

1. Qual access tier voce usaria para cada faixa de tempo?
2. Como Renata pode automatizar a transicao entre tiers sem intervencao manual?
3. Qual o impacto financeiro de acessar um blob que esta no tier **Archive**? Ha alguma limitacao operacional?

---

### Q2.3 — SAS Token vs Stored Access Policy (Multipla Escolha)

Renata precisa dar acesso temporario (30 dias) a Pedro Santos (freelancer) ao container `source-code` do storage account `bwdevstorage`. Ela gera um **SAS token** com validade de 30 dias e envia a Pedro.

Apos 15 dias, Pedro termina o projeto e Renata quer revogar o acesso imediatamente. Ela descobre que **nao e possivel revogar um SAS token individual** diretamente.

Qual abordagem Renata deveria ter usado desde o inicio para permitir revogacao?

- **A)** Usar um **Stored Access Policy** no container e associar o SAS token a essa policy
- **B)** Usar um **Service Endpoint** para controlar o acesso por IP
- **C)** Usar uma **Managed Identity** associada ao usuario externo
- **D)** Gerar um SAS token com duracao de 1 dia e renovar manualmente a cada dia

---

## Pontuacao

| Secao                       | Questoes | Pontos por Questao | Total  |
| --------------------------- | -------- | ------------------ | ------ |
| 1 — Identidade e Governanca | 3        | 5                  | 15     |
| 2 — Armazenamento           | 3        | 5                  | 15     |
| **Total**                   | **6**    | —                  | **30** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                                  |
| ----- | ------------ | ---------------------------------------------- |
| 26-30 | Excelente    | Avance para o Caso 2                           |
| 20-25 | Bom          | Revisar questoes erradas nos labs              |
| 12-19 | Regular      | Refazer blocos com dificuldade                 |
| < 12  | Insuficiente | Revisar labs 1-iam-gov-net e 2-storage-compute |

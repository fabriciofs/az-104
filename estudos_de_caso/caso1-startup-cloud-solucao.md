# Gabarito — Estudo de Caso 1: ByteWave Tecnologia

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `caso1-startup-cloud.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Identidade e Governanca

### Q1.1 — Guest User vs Member User

**Resposta: C) Ana precisa acessar o portal usando o URL com o tenant ID da ByteWave**

Quando um guest user e convidado para um tenant, ele precisa acessar o portal Azure **especificando o tenant** da organizacao que o convidou. Por padrao, ao fazer login no portal.azure.com, o guest user acessa o **proprio tenant de origem** (ou o diretorio padrao), onde ele nao vera os recursos da ByteWave.

A URL correta e: `portal.azure.com/<tenantId>` ou o guest user pode alternar o diretorio manualmente no portal (Settings > Directories + subscriptions).

**Por que os outros estao errados:**
- **A) Guest users nao podem receber RBAC** — Incorreto. Guest users podem receber qualquer role RBAC normalmente, incluindo Owner, Contributor e Reader.
- **B) Converter de Guest para Member** — Desnecessario. Guest users funcionam perfeitamente com RBAC. A conversao so e necessaria se a organizacao quiser dar permissoes de diretorio equivalentes a um membro interno.
- **D) Reader so funciona na subscription** — Incorreto. O role Reader funciona em qualquer escopo: Management Group, Subscription, Resource Group ou recurso individual.

**[GOTCHA]** Guest users frequentemente nao veem recursos porque estao olhando para o **tenant errado**. Esse e o primeiro item a verificar quando um guest user reclama que "nao ve nada". Nao confundir com falta de permissao RBAC.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco1-identity.md` — Tarefa de convidar guest user

---

### Q1.2 — RBAC Scoping para Acesso Minimo

**Resposta:**

**1. Grupo Devs:**
- **Role:** Contributor
- **Escopo:** Resource Group `bw-dev-rg`

O Contributor permite criar e gerenciar todos os recursos dentro do RG, mas nao permite gerenciar permissoes (RBAC) nem atribuir roles a outros usuarios. E o role ideal para times de desenvolvimento.

**2. Grupo Marketing:**
- **Role:** Storage Blob Data Contributor
- **Escopo:** Storage Account `bwmarketing` (ou idealmente, no container `public-assets`)

O **Storage Blob Data Contributor** e mais especifico que Contributor generico. Ele permite ler, gravar e deletar blobs, sem acesso a outros tipos de recurso no RG. Usar Contributor no RG daria acesso ao CDN Profile e outros recursos — violando least privilege.

**Diferenca importante:**
- **Contributor** (no RG) = acesso ao management plane de todos os recursos
- **Storage Blob Data Contributor** = acesso ao data plane de blobs apenas

**3. Ana Costa (auditora):**
- **Role:** Storage Blob Data Reader
- **Escopo:** Storage Account `bwfinance` (ou container `reports`)

**Diferenca entre Reader no RG vs Storage Blob Data Reader:**
- **Reader no RG:** Permite ver que o storage account **existe** e suas propriedades (management plane), mas **nao permite ler o conteudo** dos blobs (data plane). Ana veria o recurso no portal mas nao conseguiria abrir os relatorios.
- **Storage Blob Data Reader:** Permite **ler o conteudo** dos blobs (data plane). E o que Ana realmente precisa.

**[GOTCHA]** A diferenca entre management plane e data plane e crucial no exame. O role **Reader** da acesso ao management plane (ver recursos, propriedades, metricas). Para acessar **dados dentro** de storage accounts, e necessario um role de **data plane** como Storage Blob Data Reader/Contributor.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Configuracao de RBAC por escopo

---

### Q1.3 — Azure Policy para Tags Obrigatorias

**Resposta: B) Renata so criou uma policy para a tag `Project`; precisa de uma segunda policy (ou initiative) para `CostCenter`**

Cada Azure Policy avalia **uma condicao especifica**. A policy que Renata criou verifica apenas a existencia da tag `Project`. Para exigir `CostCenter`, ela precisa criar uma **segunda policy** com a mesma logica para a tag `CostCenter`.

**Melhor pratica:** Usar uma **Policy Initiative** (tambem chamada de Policy Set) que agrupe ambas as policies:
- Policy 1: Require tag `Project` (efeito Deny)
- Policy 2: Require tag `CostCenter` (efeito Deny)
- Initiative: `ByteWave-Required-Tags` contendo as duas policies

A Initiative facilita o gerenciamento — atribuir uma unica Initiative em vez de multiplas policies individuais.

**Por que os outros estao errados:**
- **A) Deny nao verifica mais de uma tag** — Incorreto. O efeito Deny funciona perfeitamente para tags, mas cada policy avalia uma condicao. Nao e uma limitacao do efeito.
- **C) Tags nao podem ser obrigatorias** — Incorreto. Azure Policy pode exigir tags com efeito Deny.
- **D) Deny so funciona para tags herdadas** — Incorreto. Deny funciona para qualquer condicao avaliada no momento da criacao do recurso.

**[GOTCHA]** No exame, questoes sobre "exigir multiplas tags" testam se voce sabe que cada policy trata uma condicao. Para multiplas condicoes, use multiplas policies (idealmente agrupadas em uma Initiative).

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Tarefa de Azure Policy

---

## Secao 2 — Armazenamento

### Q2.1 — Redundancia de Storage Account

**Resposta: B) `bwdevstorage`: LRS, `bwfinance`: GRS, `bwmarketing`: LRS**

A analise custo-beneficio:

| Storage Account | Criticidade | Redundancia | Justificativa |
|-----------------|-------------|-------------|---------------|
| `bwdevstorage` | Baixa (backup existe no GitHub) | **LRS** | 3 copias no mesmo datacenter, mais barato. Perda toleravel. |
| `bwfinance` | Alta (relatorios financeiros criticos) | **GRS** | 6 copias: 3 local + 3 na regiao pareada. Sobrevive a desastre regional. |
| `bwmarketing` | Baixa (facilmente recriavel) | **LRS** | 3 copias locais, mais barato. Assets podem ser recriados. |

**Por que os outros estao errados:**
- **A) LRS para todos** — Inadequado para `bwfinance`. Relatorios financeiros criticos precisam de redundancia geografica.
- **C) GRS para todos** — Desperdicio de orcamento. Dados de baixa criticidade (dev e marketing) nao justificam o custo extra de GRS.
- **D) ZRS para dev e finance** — ZRS protege contra falha de datacenter na mesma regiao, mas nao contra desastre regional. Para dados criticos, GRS e mais adequado. Alem disso, ZRS e mais caro que LRS sem beneficio para dados de baixa criticidade.

**Resumo dos niveis de redundancia:**

| Tipo | Copias | Protecao | Custo Relativo |
|------|--------|----------|----------------|
| LRS | 3 (mesmo datacenter) | Falha de disco/rack | $ |
| ZRS | 3 (datacenters diferentes na mesma regiao) | Falha de datacenter | $$ |
| GRS | 6 (3 local + 3 regiao pareada) | Falha regional | $$$ |
| GZRS | 6 (3 em zonas + 3 regiao pareada) | Falha regional + datacenter | $$$$ |

**[GOTCHA]** No exame, sempre analise a criticidade dos dados antes de escolher a redundancia. A pergunta frequentemente testa se voce aplica o principio de custo-beneficio em vez de sempre escolher a opcao mais cara.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Configuracao de redundancia

---

### Q2.2 — Blob Access Tiers e Lifecycle Management

**Resposta:**

**1. Access tier por faixa de tempo:**

| Faixa | Access Tier | Justificativa |
|-------|-------------|---------------|
| Mes atual (acesso diario) | **Hot** | Custo de armazenamento maior, mas acesso gratuito/barato |
| Ultimos 3 meses (acesso eventual) | **Cool** | Custo de armazenamento menor, custo de acesso moderado |
| Mais de 6 meses (acesso raro) | **Cold** | Custo de armazenamento ainda menor, custo de acesso alto |
| Mais de 5 anos (nunca acessado) | **Archive** | Custo de armazenamento minimo, custo de reidratacao alto |

**2. Automatizar a transicao:**

Renata deve configurar uma **Lifecycle Management Policy** no storage account `bwfinance`. Exemplo de regras:

```json
{
  "rules": [
    {
      "name": "move-to-cool",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 30 }
          }
        }
      }
    },
    {
      "name": "move-to-cold",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCold": { "daysAfterModificationGreaterThan": 180 }
          }
        }
      }
    },
    {
      "name": "move-to-archive",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToArchive": { "daysAfterModificationGreaterThan": 1825 }
          }
        }
      }
    }
  ]
}
```

**3. Impacto de acessar blob no Archive:**

- **Custo:** A reidratacao (rehydrate) do Archive tem custo significativo por GB. E a operacao de acesso mais cara de todos os tiers.
- **Limitacao operacional:** Blobs no tier Archive **nao podem ser lidos diretamente**. E necessario primeiro **reidratar** o blob para Hot ou Cool. A reidratacao pode levar:
  - **Standard priority:** Ate **15 horas**
  - **High priority:** Ate **1 hora** (custo adicional)
- Enquanto a reidratacao nao terminar, o blob esta **inacessivel**.

**[GOTCHA]** Archive nao e um tier de "acesso lento" — e um tier de acesso **offline**. Voce nao pode ler blobs no Archive sem reidratacao. No exame, se a questao diz "precisa acessar imediatamente", Archive nao e opcao viavel.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Lifecycle management

---

### Q2.3 — SAS Token vs Stored Access Policy

**Resposta: A) Usar um Stored Access Policy no container e associar o SAS token a essa policy**

Um **Stored Access Policy** (SAP) e uma policy definida no nivel do container que controla parametros do SAS token (permissoes, data de inicio, data de expiracao). Quando um SAS token e gerado **associado a uma Stored Access Policy**, ele herda os parametros da policy.

**Vantagem principal:** Para revogar o acesso, basta **deletar ou modificar a Stored Access Policy**. Todos os SAS tokens associados a essa policy serao imediatamente invalidados.

**Como funciona:**
1. Criar Stored Access Policy no container `source-code` com permissoes de leitura e 30 dias de validade
2. Gerar SAS token referenciando essa policy
3. Enviar SAS token a Pedro
4. Quando quiser revogar: deletar a Stored Access Policy → token invalidado imediatamente

**Por que os outros estao errados:**
- **B) Service Endpoint** — Controla acesso por VNet/subnet, nao por usuario. Nao resolve o problema de revogacao de acesso individual.
- **C) Managed Identity** — Managed Identities sao para recursos Azure (VMs, App Services), nao para usuarios externos.
- **D) SAS token de 1 dia** — Funciona tecnicamente, mas e extremamente impratico. Requer renovacao diaria e envio manual do novo token.

**Alternativa para revogar SAS token sem Stored Access Policy:**
A unica forma de revogar um SAS token nao associado a uma policy e **regenerar a storage account key** usada para assinalo. Porem, isso invalida **TODOS** os SAS tokens gerados com aquela key — afetando outros usuarios.

**[GOTCHA]** No exame, quando a questao fala em "revogar acesso SAS", a resposta quase sempre envolve Stored Access Policy. E a unica forma granular de revogar um SAS token individual sem afetar outros tokens.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — SAS tokens e Stored Access Policies

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Subtopico |
|---------|----------------|-----------|
| Q1.1 | D1 — Manage identities and governance | Guest user access |
| Q1.2 | D1 — Manage identities and governance | RBAC scoping, least privilege |
| Q1.3 | D1 — Manage identities and governance | Azure Policy, Initiatives |
| Q2.1 | D2 — Implement and manage storage | Storage redundancy |
| Q2.2 | D2 — Implement and manage storage | Blob access tiers, lifecycle management |
| Q2.3 | D2 — Implement and manage storage | SAS tokens, Stored Access Policies |

---

## Top Gotchas — Caso 1

| # | Gotcha | Questao |
|---|--------|---------|
| 1 | Guest user precisa acessar o **tenant correto** no portal | Q1.1 |
| 2 | **Reader** (management plane) ≠ **Blob Data Reader** (data plane) | Q1.2 |
| 3 | Cada policy avalia **uma condicao**; multiplas tags = multiplas policies ou initiative | Q1.3 |
| 4 | Redundancia deve ser proporcional a **criticidade** dos dados | Q2.1 |
| 5 | Archive = acesso **offline**, reidratacao pode levar ate 15h | Q2.2 |
| 6 | SAS token so pode ser revogado individualmente via **Stored Access Policy** | Q2.3 |

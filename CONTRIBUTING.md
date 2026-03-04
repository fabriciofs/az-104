# Guia de Contribuicao

Obrigado por querer contribuir com este repositorio de estudos para a certificacao **AZ-104 (Microsoft Azure Administrator)**! Este guia explica a estrutura do projeto e as convencoes a seguir.

---

## Estrutura do Repositorio

```
az-104/
├── guias/                          # Resumos de videos do curso
│   └── video-NN-titulo-slug.md
├── labs/                           # Labs praticos (portal + IaC)
│   └── N-topico-slug/
│       ├── README.md               # Indice do lab
│       ├── cenario-contoso.md      # Mapa de dependencias entre blocos
│       ├── cenario/                # Blocos do lab (passo a passo portal)
│       │   └── blocoN-topico.md
│       ├── IaC/                    # Versoes em codigo dos blocos
│       │   ├── arm.md
│       │   ├── bicep.md
│       │   └── powershell.md
│       ├── simulado-*.md           # Questoes estilo prova
│       └── simulado-*-solucao.md   # Gabarito comentado
├── estudos_de_caso/                # Casos e exercicios praticos
│   ├── casoN-empresa-slug.md
│   ├── casoN-empresa-slug-solucao.md
│   └── praticoN-topico-slug.md
└── dicas-prova.md                  # Dicas rapidas para revisao
```

---

## Convencoes de Nomenclatura

| Tipo              | Padrao                                | Exemplo                                          |
| ----------------- | ------------------------------------- | ------------------------------------------------ |
| Guia de video     | `video-NN-titulo-slug.md`             | `video-03-entenda-microsoft-entra-id-parte-1.md` |
| Pasta de lab      | `N-topico-slug/`                      | `2-storage-compute/`                             |
| Bloco de lab      | `blocoN-topico.md`                    | `bloco4-networking.md`                           |
| IaC               | `arm.md`, `bicep.md`, `powershell.md` | (sempre esses tres nomes)                        |
| Simulado          | `simulado-{lab-slug}.md`              | `simulado-iam-gov-net.md`                        |
| Gabarito simulado | `simulado-{lab-slug}-solucao.md`      | `simulado-iam-gov-net-solucao.md`                |
| Estudo de caso    | `casoN-empresa-slug.md`               | `caso3-hospital-compliance.md`                   |
| Gabarito caso     | `casoN-empresa-slug-solucao.md`       | `caso3-hospital-compliance-solucao.md`           |
| Exercicio pratico | `praticoN-topico-slug.md`             | `pratico1-migracao-datacenter.md`                |

**Regras gerais:**
- Slugs em minusculo, separados por hifen
- Numeros sequenciais (NN com zero a esquerda nos guias, N simples nos labs/casos)
- Sem acentos nos nomes de arquivo

---

## Como Contribuir

### 1. Guias de Video (`guias/video-NN-*.md`)

Cada arquivo resume um video do curso. Estrutura obrigatoria:

```markdown
# Video NN: Titulo AZ-104

## Informacoes Gerais
| Campo  | Valor |
| ------ | ----- |
| Titulo | ...   |
| Canal  | ...   |

## Links Importantes
| Recurso          | Link |
| ---------------- | ---- |
| Video no YouTube | ...  |

## Descricao do Conteudo
Paragrafo narrativo.

### O que voce aprendera
- Topico 1
- Topico 2

## Topicos Abordados
### 1. Nome do Topico
(Tabelas e/ou listas)

## Conceitos-Chave para o Exame
1. Conceito

## Peso no Exame AZ-104
| Dominio | Peso |
| ------- | ---- |

## Recursos Complementares
| Recurso | Link |

## Proximo Video
**Video NN+1:** Titulo
- Topicos do proximo video

---
_Fonte: Microsoft Learn - Canal oficial no YouTube_
```

### 2. Labs Portal (`labs/*/cenario/blocoN-*.md`)

Cada bloco e um passo a passo de atividades no portal Azure. Estrutura obrigatoria:

```markdown
> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco N+1 - Titulo](blocoN+1-slug.md)

# Bloco N - Titulo

**Origem:** Lab XX - Nome oficial do lab Microsoft Learn
**Resource Groups utilizados:** `az104-rgN`

## Contexto
Paragrafo narrativo conectando ao cenario geral e a outros blocos.

## Diagrama
```
(Diagrama ASCII dos recursos Azure, VNets, IPs, setas entre blocos)
```

### Task N.M: Titulo da Tarefa
1. Passo a passo no portal
2. ...

| Setting | Value |
| ------- | ----- |
| ...     | ...   |

> **Conceito:** Explicacao de conceito Azure.

> **Dica AZ-104:** Dica relevante para a prova.

> **Conexao com Bloco X:** Como esta tarefa se relaciona com outro bloco.

## Modo Desafio - Bloco N
- [ ] Tarefa resumida 1
- [ ] Tarefa resumida 2

## Questoes de Prova - Bloco N
### Questao N.M
**Texto da questao**

A) Opcao
B) Opcao
C) Opcao
D) Opcao

<details>
<summary>Ver resposta</summary>

**Resposta: X) Opcao**

Explicacao.

</details>
```

**Elementos especiais nos blocos:**
- `> **Cobranca:**` — Alerta de recurso que gera custo
- `> **Conceito:**` — Explicacao de conceito Azure
- `> **Dica AZ-104:**` — Dica para a prova
- `> **Conexao com Bloco N:**` — Referencia cruzada entre blocos

### 3. Labs IaC (`labs/*/IaC/`)

Cada lab tem tres arquivos IaC que reproduzem os mesmos recursos dos blocos portal, mas em codigo:

- **`arm.md`** — ARM Templates (JSON) + Azure CLI
- **`bicep.md`** — Bicep + Azure CLI
- **`powershell.md`** — PowerShell (modulos Az e Microsoft Graph)

Estrutura obrigatoria:

```markdown
# Lab AZ-104 - Semana N: Tudo via {ARM Templates|Bicep|PowerShell}

> **Pre-requisitos:**
> - Subscription Azure com Owner/Contributor
> - Azure Cloud Shell
> - (extensoes/modulos necessarios)
>
> **Objetivo:** Reproduzir o lab completo (~N recursos) usando {metodo}.

## Pre-requisitos: Cloud Shell e Conceitos {ARM|Bicep|PowerShell}

> **Ambiente:** (descricao do Cloud Shell)

### Conceitos Basicos de {ARM|Bicep|PowerShell}
(Bloco de codigo anotado)

## Variaveis Globais  ← (somente PowerShell)

# === BLOCO 1: TITULO ===
(Codigo reproduzindo cada recurso do bloco portal correspondente)
```

- Marque valores que o usuario deve alterar com `# ← ALTERE`
- Separe blocos com comentarios `# === BLOCO N: TITULO ===`

### 4. Simulados (`simulado-*.md` + `simulado-*-solucao.md`)

Simulados vivem dentro da pasta do lab correspondente. Sempre em par: questoes + gabarito.

**Arquivo de questoes:**

```markdown
# Simulado AZ-104 — Titulo do Dominio

> **Regras:** (instrucoes de uso)

## Cenario: Nome da Empresa
Paragrafo descrevendo empresa ficticia brasileira.

## Personas
| Persona | Funcao | Acesso Necessario |

## Secao N — Dominio (X questoes)

### QN.M — Topico (Tipo da Questao)
Texto da questao.

- **A)** Opcao
- **B)** Opcao
- **C)** Opcao
- **D)** Opcao

## Pontuacao
| Secao | Questoes | Pontos | Total |

### Classificacao
| Faixa | Nivel | Acao Sugerida |
```

**Arquivo de gabarito (`-solucao.md`):**

```markdown
# Gabarito — Simulado AZ-104 Titulo

> **Como usar este gabarito:** (instrucoes)

## Secao N — Dominio

### QN.M — Topico
**Resposta: X) Opcao**

Explicacao.

**Por que os outros estao errados:**
- A) ...
- B) ...

**[GOTCHA]** Armadilha comum na prova.

**Referencia no lab:** Bloco N — Tarefa M
```

### 5. Estudos de Caso (`estudos_de_caso/`)

Mesma logica dos simulados, mas com cenarios mais longos e multidisciplinares.

**Caso (`casoN-*.md`):** Inclui cenario detalhado com equipe, infraestrutura (diagrama ASCII) e questoes por secao.

**Gabarito (`casoN-*-solucao.md`):** Mesmo formato do gabarito de simulado.

**Pratico (`praticoN-*.md`):** Exercicios hands-on com tarefas cronometradas, entregaveis e criterios de avaliacao em checklist.

### 6. Dicas de Prova (`dicas-prova.md`)

Arquivo unico na raiz com dicas rapidas organizadas por dominio. Para adicionar dicas:
- Identifique a secao correta pelo dominio
- Mantenha dicas curtas e objetivas
- Inclua referencia ao bloco do lab quando aplicavel

---

## Regras de Commit

- Escreva em **portugues**
- Use **verbo no imperativo** (Adiciona, Corrige, Remove, Reestrutura)
- Mensagem em **linha unica**, sem ponto final
- Descreva o **escopo** da mudanca (qual arquivo ou feature)
- **Nunca** mencione IA, assistente ou ferramentas automatizadas

**Exemplos:**
```
Adiciona bloco8-dns ao lab de networking
Corrige diagrama ASCII no bloco4-networking
Adiciona 10 questoes de storage ao simulado da semana 2
Reestrutura secao de monitoramento no dicas-prova
```

---

## Como Abrir Issues

Use issues para:
- Reportar erros em comandos, configuracoes ou respostas de questoes
- Sugerir novos blocos, labs ou simulados
- Pedir esclarecimentos sobre conceitos

Inclua na issue:
- **Arquivo afetado** (caminho completo)
- **Descricao do problema** ou sugestao
- **Referencia** ao lab Microsoft Learn original, se aplicavel

---

## Como Abrir Pull Requests

1. Crie um branch a partir de `main`
2. Siga as convencoes de nomenclatura e estrutura descritas acima
3. Verifique que links internos (entre blocos, para cenario-contoso, etc.) estao corretos
4. Descreva no PR:
   - O que foi adicionado ou alterado
   - Quais arquivos foram afetados
   - Se novos recursos Azure sao introduzidos, indique se geram cobranca

---

## Checklist antes de Enviar

- [ ] Nomes de arquivos seguem as convencoes
- [ ] Estrutura interna do arquivo segue o template do tipo correspondente
- [ ] Links de navegacao entre blocos estao corretos (`Voltar para...`, `Proximo:...`)
- [ ] Diagramas ASCII estao dentro de blocos de codigo
- [ ] Questoes tem `<details>` para esconder respostas
- [ ] Alertas de cobranca marcados com `> **Cobranca:**`
- [ ] Commit em portugues, verbo imperativo, sem mencao a IA

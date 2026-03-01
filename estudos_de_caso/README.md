# Estudos de Caso — AZ-104

Estudos de caso no estilo do exame AZ-104, com cenarios realistas que cruzam **multiplos dominios** do exame. Cada caso simula uma empresa brasileira com necessidades reais de infraestrutura Azure.

> **Diferenca dos simulados:** enquanto os simulados focam em 1-2 dominios por vez, os estudos de caso integram multiplos dominios em um unico cenario, simulando a complexidade do exame real.

---

## Indice

| # | Estudo de Caso | Empresa | Dificuldade | Dominios | Questoes |
|---|----------------|---------|-------------|----------|----------|
| 1 | [ByteWave Tecnologia](caso1-startup-cloud.md) | Startup — Florianopolis | Facil | D1 Identity + D2 Storage | 6 |
| 2 | [Instituto Saber Digital](caso2-escola-monitoramento.md) | Escola — Belo Horizonte | Facil | D3 Compute + D5 Monitoring | 6 |
| 3 | [Rede VidaSaude Hospitais](caso3-hospital-compliance.md) | Hospital — Brasilia | Medio | D1 Governance + D4 Networking + D2 Storage | 8 |
| 4 | [MegaStore Brasil](caso4-ecommerce-scaling.md) | E-commerce — Porto Alegre | Medio | D3 Compute + D4 Networking + D2 Storage | 8 |
| 5 | [Banco Horizonte Digital](caso5-banco-migracao.md) | Banco — Sao Paulo | Dificil | Todos os 5 dominios | 10 |

**Total: 38 questoes**

---

## Exercicios Praticos

Exercicios hands-on para planejar e documentar arquiteturas completas no portal Azure.

| # | Exercicio | Duracao | Dominios |
|---|-----------|---------|----------|
| P1 | [Migracao de Datacenter](pratico1-migracao-datacenter.md) | ~3h | D2 Storage + D3 Compute + D4 Networking + D5 Monitoring |
| P2 | [Governanca Corporativa](pratico2-governanca-corporativa.md) | ~3h | D1 Identity & Governance |

> **Diferenca:** Os estudos de caso (1-5) testam **raciocinio** com questoes estilo exame.
> Os exercicios praticos (P1-P2) treinam **execucao** — voce desenha, planeja e documenta.

---

## Legenda de Dificuldade

| Nivel | Descricao |
|-------|-----------|
| Facil | 2 dominios, questoes diretas, cenarios simples |
| Medio | 3 dominios, questoes com integracao entre servicos, cenarios corporativos |
| Dificil | 5 dominios, questoes complexas com troubleshooting avancado, cenario enterprise |

## Tipos de Questao

| Tipo | Descricao |
|------|-----------|
| Multipla Escolha | Uma unica resposta correta entre 4 opcoes |
| Design | Questao aberta que avalia raciocinio e decisoes de arquitetura |
| Troubleshooting | Identificar e resolver um problema em cenario com erro |
| Cenario | Analisar situacao complexa e propor solucao completa |

---

## Cobertura por Dominio

| Dominio | Caso 1 | Caso 2 | Caso 3 | Caso 4 | Caso 5 | Total | % |
|---------|--------|--------|--------|--------|--------|-------|---|
| D1 Identity & Governance | 3 | - | 3 | - | 2 | 8 | 21% |
| D2 Storage | 3 | - | 2 | 2 | 2 | 9 | 24% |
| D3 Compute | - | 3 | - | 3 | 2 | 8 | 21% |
| D4 Networking | - | - | 3 | 3 | 2 | 8 | 21% |
| D5 Monitoring | - | 3 | - | - | 2 | 5 | 13% |

---

## Ordem de Estudo Sugerida

1. **Caso 1** (Facil) — Estabelece base de Identity e Storage
2. **Caso 2** (Facil) — Complementa com Compute e Monitoring
3. **Caso 3** (Medio) — Integra Governance, Networking e Storage
4. **Caso 4** (Medio) — Integra Compute, Networking e Storage
5. **Caso 5** (Dificil) — Revisao completa de todos os dominios
6. **Pratico 1** — Migracao de datacenter (apos labs blocos 2 e 3)
7. **Pratico 2** — Governanca corporativa (apos labs bloco 1)

---

## Como Usar

1. Leia o cenario completo antes de responder qualquer questao
2. Responda **todas** as questoes sem consultar documentacao
3. Anote as questoes que teve duvida — elas indicam gaps de estudo
4. Confira o gabarito (`*-solucao.md`) questao por questao
5. Preste atencao especial nos itens marcados com **[GOTCHA]**
6. Para cada erro, volte ao lab correspondente e refaca o exercicio relacionado

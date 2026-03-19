# Backup e Recuperacao

## MARS vs MABS vs VM Backup

| Agente        | O que protege                                                | Onde instala                  |
| ------------- | ------------------------------------------------------------ | ----------------------------- |
| **MARS**      | **Arquivos e pastas**                                        | Direto no servidor (Windows)  |
| **MABS**      | Workloads completos (SQL, SharePoint, Exchange, VMs Hyper-V) | Servidor dedicado             |
| **VM Backup** | VM inteira (todos os discos)                                 | Sem agente (plataforma Azure) |

- "Backup de **arquivos e pastas**" → **agente MARS** (NAO MABS)
- "Backup de SQL Server ou SharePoint" → **MABS**
- "Backup de VM inteira" → **Azure Backup** (sem agente)
- MARS requer **Recovery Services Vault** + registrar o servidor no vault

## Recovery Services Vault vs Backup Vault

| Workload                |  RSV  | Backup Vault |
| ----------------------- | :---: | :----------: |
| VM backup               |  Sim  |     Nao      |
| Disk backup (snapshots) |  Nao  |     Sim      |
| File Share backup       |  Sim  |     Nao      |
| Blob backup             |  Nao  |     Sim      |
| Site Recovery           |  Sim  |     Nao      |

- Disk backup via Backup Vault = **snapshots incrementais** (menor custo)
- VM backup via RSV = ponto de restauracao **completo**

## Backup Policy

- Limites de retencao: daily (9999 dias), weekly (5163 semanas), monthly (1188 meses), yearly (99 anos)
- Diferenciar: backup on-demand vs scheduled, full vs incremental, snapshot vs vault tier

## Deletar Recovery Services Vault (sequencia obrigatoria)

1. **Interromper backup** de todos os itens (Stop backup + Delete data)
2. **Desabilitar soft delete** (habilitado por padrao, retencao 14 dias)
3. **Purgar itens em soft-deleted state** (Undelete → Delete permanente)
4. **Deletar vault** (so funciona quando completamente vazio)

- NAO precisa deletar as VMs (so parar o backup)
- NAO precisa criar novo vault
- **Lock IMPEDE** exclusao — e distrator quando perguntam "como deletar"
- Soft delete vem **habilitado por padrao** em todos os vaults novos
- Itens soft-deleted: podem ser restaurados via **Undelete** dentro de 14 dias
- **Immutability (WORM)** no vault impede exclusao por qualquer usuario (compliance)

## Cross Region Restore (CRR)

- CRR so funciona com **GRS** (Geo-Redundant Storage)
- Replicacao do vault **NAO pode ser alterada** apos o primeiro backup
- CRR tem RPO de ate **36 horas** (tempo de replicacao geo)
- Para RPO menor, use **Site Recovery**

## Site Recovery (DR)

- Sincronizacao inicial pode levar horas (depende do tamanho dos discos)
- RPO comeca a ser medido **apos a sincronizacao completar**
- Recovery point **retention** ≠ RPO: retention = quanto tempo pontos sao mantidos; RPO = frequencia de criacao
- App-consistent snapshots sao menos frequentes e tem maior impacto no IO

## Tipos de Failover

| Tipo               |     Data Loss      | Quando usar                             |
| ------------------ | :----------------: | --------------------------------------- |
| Test Failover      |       Nenhum       | Validacao (VM isolada, sem impacto)     |
| Planned Failover   |        Zero        | Migracao planejada (VM desligada antes) |
| Unplanned Failover | Possivel (ate RPO) | Desastre (ultimo recovery point)        |

- Apos failover real: **Commit** para confirmar ou **Change recovery point** para usar outro ponto

**Ciclo completo de failover/failback:**

```
Failover → Commit → Re-protect → Failback
```

| Status | Significado | Proximo passo |
| --- | --- | --- |
| Failover completed | VM na secundaria, nao confirmado | Commit ou Cancel |
| **Failover committed** | Confirmado, recovery points antigos removidos | **Re-protect** |
| Re-protecting | Replicacao inversa em andamento | Aguardar |
| Protected | Replicacao ativa | Pronto para failback |

- "Status antes de re-proteger" → **Failover committed** (NAO "concluir failover", NAO "mecanismo de failover confirmado")
- Re-protect so fica disponivel **apos commit**
- Re-protect inverte a replicacao: secundaria → primaria

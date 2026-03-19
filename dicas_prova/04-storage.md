# Storage

## SAS Token - Tipos e Revogacao

**Tipos de SAS:**

| Tipo | O que faz | Quando usar |
| --- | --- | --- |
| **SAS ad hoc** | Token com inicio/expiracao direto nele | Acesso temporario unico (ex: 30 dias a terceiro) |
| **Stored Access Policy** | Politica reutilizavel que gera multiplos SAS | Gerenciar/revogar varios tokens centralmente |
| **SAS de servico** | Acesso a 1 servico (blob, file, queue, table) | Escopo limitado a 1 servico |
| **SAS de conta** | Acesso a nivel da conta inteira | Escopo amplo (viola privilegio minimo) |

- "Acesso temporario unico a terceiro por X dias" → **SAS ad hoc** (simples, tempo no token)
- "Gerenciar/revogar multiplos tokens" → **Stored Access Policy**
- SAS de conta = amplo demais, evitar quando privilegio minimo for mencionado

**Revogacao:**

- Como revogar SAS: (1) Deletar stored access policy, (2) Regenerar storage key, (3) Alterar expiry
- "SAS comprometido, revogacao mais rapida" → **deletar Stored Access Policy**
- SAS ad hoc **NAO pode ser revogado** individualmente (so regenerando a key, que invalida TODOS os SAS)
- "Blob deletado acidentalmente, como recuperar?" → **Soft Delete** (se habilitado)

## Lifecycle Management vs Immutability

- Lifecycle = **automacao de custo** (mover entre tiers)
- Immutability = **compliance e retencao legal** (impedir alteracao/delecao)
- Para regras baseadas em **ultimo acesso** (lastAccessTime), habilitar **access tracking** (controle de acesso)
- Access tracking ≠ versioning. **Versioning** rastreia alteracoes, **access tracking** rastreia leitura
- Sem access tracking, lifecycle so pode usar **lastModifiedTime**

## Azure Files - Large File Shares

- File Shares padrao: ate **5 TiB**
- Para ate **100 TiB**: habilitar **EnableLargeFileShare** na conta de storage
- Cmdlets necessarios:
  1. `Set-AzStorageAccount -EnableLargeFileShare` (habilita suporte)
  2. `Update-AzRmStorageShare -QuotaGiB 102400` (atualiza a cota)
- **NAO precisa** alterar o tipo de redundancia (RA-RAGRS) para aumentar file share
- **NAO precisa** criar novo file share, pode atualizar o existente

## Tipos de Conta e Data Lake Gen2

| Tipo de conta           | Suporta Data Lake Gen2? | Observacao                            |
| ----------------------- | :---------------------: | ------------------------------------- |
| **Standard GPv2**       |           Sim           | Mais comum, suporta todos os servicos |
| **Premium Block Blobs** |           Sim           | Alta performance para blobs           |
| Premium File Shares     |           Nao           | Apenas Azure Files                    |
| Premium Page Blobs      |         **Nao**         | Apenas page blobs (VHDs)              |

- Data Lake Gen2 = **namespace hierarquico** habilitado na conta
- **ACLs POSIX** requerem **namespace hierarquico** (nao SFTP, nao camada de acesso)
- SFTP e um protocolo de acesso, nao habilita ACLs POSIX
- Namespace hierarquico e habilitado **na criacao** (nao pode ser adicionado depois em contas existentes - com excecoes recentes)

## Object Replication - Pre-requisitos (ERRO PERSISTENTE S1+S2+S3+S4!)

Para configurar Object Replication entre storage1 (origem) → storage2 (destino):

1. **Versionamento habilitado em AMBAS** as contas (origem E destino)
2. **Change feed habilitado na ORIGEM** (storage1)
3. Contas devem ser **GPv2 ou Premium Block Blobs**

**Mnemonico — sao exatamente 3 pre-requisitos:**
```
V V C  (e so isso!)
│ │ └── Change feed → ORIGEM (storage1)
│ └──── Versioning  → DESTINO (storage2)
└────── Versioning  → ORIGEM (storage1)
```

**DISTRATORES frequentes (NAO sao pre-requisitos):**
- ~~Restauracao pontual~~ — depende de versioning, mas NAO e pre-requisito da replicacao
- ~~Change feed no destino~~ — so na origem
- ~~Namespace hierarquico~~ — nao tem relacao
- ~~Soft delete~~ — nao tem relacao

- Se vir **"restauracao"** como opcao em Object Replication → **DESCARTE**
- Change feed so e necessario na **origem**, nao no destino
- "Versionamento desabilitado" → **habilitar versionamento** (nao change feed, nao namespace)

## Redundancia - Leitura na regiao secundaria

| Tipo        |   Multi-regiao   |     Leitura secundaria     |
| ----------- | :--------------: | :------------------------: |
| LRS         |       Nao        |            Nao             |
| ZRS         | Nao (multi-zona) |            Nao             |
| GRS         |       Sim        |   **Nao** (so failover)    |
| **RA-GRS**  |       Sim        | **Sim** (leitura continua) |
| GZRS        |       Sim        |          **Nao**           |
| **RA-GZRS** |       Sim        |          **Sim**           |

- "Ler dados da regiao secundaria" → precisa do prefixo **RA-** (Read Access)

## Replicacao e Transferencia

- **GRS/GZRS** = replicacao sincrona gerenciada (redundancia)
- **Object Replication** = replicacao assincrona configuravel (flexibilidade, qualquer regiao)
- **AzCopy copy** = copia arquivos (uso com `--recursive` para diretorios inteiros)
- **AzCopy sync** = sincroniza (similar, mas compara timestamps)
- **Get-ChildItem -Recurse | Set-AzStorageBlobContent** = alternativa PowerShell para upload em massa
- **Set-AzStorageBlobContent** sozinho = upload de **um unico arquivo** (nao recursivo)
- Storage Explorer usa AzCopy internamente

## Criptografia

- **SSE** = padrao, automatico, no storage layer (sempre ativo)
- **ADE** = no OS (BitLocker/DM-Crypt), requer Key Vault
- SSE e ADE sao complementares
- **CMK** requer Key Vault com **purge protection** habilitado

## Azure Files - Autenticacao

- 3 metodos: (1) Storage account key (padrao), (2) Entra ID Domain Services, (3) On-premises AD DS
- RBAC controla acesso no nivel do **share**; ACLs NTFS controlam acesso **granular**

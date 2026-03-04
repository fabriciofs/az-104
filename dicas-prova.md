# Dicas para Prova AZ-104

Anotacoes rapidas e pegadinhas para revisar antes do exame.

---

## Azure Bastion

- Precisa de subnet especifica chamada **AzureBastionSubnet** (nome exato, obrigatorio)
- Logicamente fica vinculado a uma rede virtual
- Demora em media 15 min para ser criado

### SKUs do Bastion (4 camadas)

Doc: https://learn.microsoft.com/pt-br/azure/bastion/bastion-sku-comparison

| Feature                             | Developer           | Basic         | Standard   | Premium       |
| ----------------------------------- | ------------------- | ------------- | ---------- | ------------- |
| Gratuito                            | Sim                 | Nao           | Nao        | Nao           |
| Requer AzureBastionSubnet /26       | Nao                 | Sim           | Sim        | Sim           |
| Requer IP publico                   | Nao                 | Sim           | Sim        | Nao (privado) |
| Host dedicado                       | Nao (compartilhado) | Sim           | Sim        | Sim           |
| VNet peering                        | Nao                 | Sim           | Sim        | Sim           |
| Conexoes simultaneas                | Nao (1 VM por vez)  | Sim           | Sim        | Sim           |
| RDP + SSH (Windows/Linux)           | Sim                 | Sim           | Sim        | Sim           |
| Linux via RDP / Windows via SSH     | Nao                 | Nao           | Sim        | Sim           |
| Cliente nativo (CLI)                | Nao                 | Nao           | Sim        | Sim           |
| Porta customizada                   | Nao                 | Nao           | Sim        | Sim           |
| IP-Connect                          | Nao                 | Nao           | Sim        | Sim           |
| Link compartilhavel                 | Nao                 | Nao           | Sim        | Sim           |
| Upload/download arquivos            | Nao                 | Nao           | Sim        | Sim           |
| Gravacao de sessao                  | Nao                 | Nao           | Nao        | Sim           |
| Deploy somente privado (sem IP pub) | Nao                 | Nao           | Nao        | Sim           |
| Scale units                         | Nao                 | Nao (2 fixas) | Sim (2-50) | Sim (2-50)    |

### Capacidade por instancia
- RDP: 20 sessoes simultaneas por instancia
- SSH: 40 sessoes simultaneas por instancia
- Basic (2 inst fixas): max 40 RDP ou 80 SSH
- Standard/Premium (ate 50 inst): max 1000 RDP ou 2000 SSH

### Regras de upgrade
- Pode subir SKU: Developer -> Basic -> Standard -> Premium
- NAO pode fazer downgrade (precisa excluir e recriar)
- Upgrade leva ~10 min
- Developer -> Basic/Standard/Premium exige criar AzureBastionSubnet + IP publico

### Pegadinhas de prova
- Developer: apenas dev/teste, 1 VM por vez, nao suporta peering, NAO precisa de subnet dedicada
- Basic: producao simples, sem features avancadas
- Standard: quando precisa de cliente nativo, file transfer, link compartilhavel, escala
- Premium: quando precisa de gravacao de sessao ou deploy 100% privado
- "Qual SKU permite conexao via cliente SSH nativo?" -> Standard ou Premium
- "Precisa gravar sessoes para auditoria" -> Premium
- "Fez upgrade de Basic para Standard, quer voltar" -> NAO pode, precisa excluir e recriar

---

## Virtual Machines

- (adicionar dicas conforme estudo avanca)

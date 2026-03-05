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

### Cloud-init / Custom Data vs Custom Script Extension

| Aspecto | Cloud-init (Custom Data) | Custom Script Extension | Run Command |
|---------|--------------------------|------------------------|-------------|
| SO | Linux apenas | Windows e Linux | Windows e Linux |
| Quando executa | Primeiro boot (provisioning) | Pos-provisioning (sob demanda) | Ad-hoc (troubleshooting) |
| Re-executa no reboot | Nao | Nao (1x por deployment) | Nao |
| Atualizar apos criacao | Nao (Custom Data e imutavel) | Sim (nova extension) | Sim |
| Formato | YAML (cloud-config) | Script (bash/ps1) | Script inline |
| Uso tipico | Config inicial, pacotes, users | Deploy de software, config | Diagnostico, fix rapido |

### Pegadinhas de prova
- "Instalar pacotes automaticamente no 1º boot de VM Linux" -> **cloud-init (Custom Data)**
- "Executar script em VM ja criada" -> **Custom Script Extension**
- "Troubleshooting rapido sem RDP/SSH" -> **Run Command**
- Custom Data e passado em **base64** no ARM/Bicep (`properties.osProfile.customData`)
- Cloud-init NAO funciona em Windows
- User Data (diferente de Custom Data): pode ser atualizado apos criacao, acessivel via IMDS

### CLI de referencia
```bash
# Cloud-init na criacao
az vm create --custom-data cloud-init.yaml ...

# Custom Script Extension pos-criacao
az vm extension set --name CustomScript --publisher Microsoft.Azure.Extensions ...

# Run Command ad-hoc
az vm run-command invoke --command-id RunShellScript --scripts "apt update" ...
```

---

## Service Endpoint Policies

- Service Endpoints habilitados numa subnet permitem acesso a **todos** os recursos do tipo PaaS (ex: todas as Storage Accounts do Azure)
- **Service Endpoint Policies** restringem esse acesso para **recursos especificos** (ex: apenas `contosostorage01`)
- A policy e aplicada na **subnet** (nao no recurso PaaS)
- Servicos suportados: **Microsoft.Storage** (GA) e Azure SQL Database (preview)
- Sem policy, dados podem ser exfiltrados para Storage Accounts de outros tenants via Service Endpoint

### Diferenca entre mecanismos de restricao

| Mecanismo | O que filtra | Direcao |
|-----------|-------------|---------|
| NSG | IP, porta, protocolo | Entrada/saida na subnet |
| Firewall do Storage | Subnet/IP de **origem** | Quem acessa o storage |
| Service Endpoint Policy | Recurso PaaS de **destino** | Para onde a subnet pode enviar trafego |
| Private Endpoint | Elimina acesso publico (IP privado) | Acesso totalmente privado |

### Pegadinhas de prova
- "Subnet com Service Endpoint para Storage esta acessando Storage Accounts nao autorizadas" -> **Service Endpoint Policy**
- "Restringir Service Endpoint para aceitar apenas uma Storage Account especifica" -> **Service Endpoint Policy**
- NAO confunda com firewall do storage (filtra origem) — a policy filtra **destino**
- Service Endpoint Policy so funciona com Service Endpoints habilitados (nao com Private Endpoints)

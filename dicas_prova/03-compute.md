# Virtual Machines e Compute

## Familias de VM

- **B** = burstable, **D** = general purpose, **E** = memory optimized
- **F** = compute optimized, **N** = GPU

## Disponibilidade de VMs

| Protecao contra                     | Solucao                                           | SLA               |
| ----------------------------------- | ------------------------------------------------- | ----------------- |
| Falha de **hardware** (rack/switch) | **Availability Set** (fault/update domains)       | 99.95%            |
| Falha de **datacenter** inteiro     | **Availability Zone** (zonas 1, 2, 3)             | 99.99%            |
| Escala automatica                   | **VM Scale Set** (auto-scale, nao e HA por si so) | depende da config |

- "Datacenter falhar" → **Availability Zone** (NAO Scale Set, NAO Availability Set)
- Availability Set protege contra falha de **rack**, nao de datacenter
- Scale Set = escalabilidade, nao e sinonimo de alta disponibilidade

## Availability Set - Update Domains vs Fault Domains (calculo)

**Formula rapida:** `ceil(total VMs / total domains)` = max VMs fora ao mesmo tempo

**Regra chave para a prova:**
- **Manutencao planejada** → conta **Update Domains (UD)**
- **Falha de hardware** → conta **Fault Domains (FD)**

**Update Domains (UD)** = grupos de VMs reiniciadas juntas em manutencao
- Azure reinicia **1 UD por vez** durante manutencao planejada

**Exemplo visual: 18 VMs, 2 FDs, 10 UDs**

Distribuicao nos UDs (manutencao planejada):
```
UD0: VM1, VM11   (2 VMs)    UD5: VM6, VM16   (2 VMs)
UD1: VM2, VM12   (2 VMs)    UD6: VM7, VM17   (2 VMs)
UD2: VM3, VM13   (2 VMs)    UD7: VM8, VM18   (2 VMs)
UD3: VM4, VM14   (2 VMs)    UD8: VM9         (1 VM)
UD4: VM5, VM15   (2 VMs)    UD9: VM10        (1 VM)
```
→ 18/10 = 1.8 → ceil = **2 VMs max indisponiveis**

Distribuicao nos FDs (falha de hardware):
```
FD0: VM1-VM9    (9 VMs)
FD1: VM10-VM18  (9 VMs)
```
→ 18/2 = **9 VMs max indisponiveis**

- Se a pergunta fala **manutencao** → resposta e **ceil(VMs/UDs)**
- Se a pergunta fala **falha de hardware/rack** → resposta e **ceil(VMs/FDs)**
- NAO confundir: 2 (UD) vs 9 (FD) sao respostas completamente diferentes para o mesmo cenario

## Spot VMs

- Custo reduzido, mas Azure pode **remover a qualquer momento**
- 2 fatores de remocao: (1) **capacidade do Azure** (precisa para outros workloads), (2) **preco excede maximo definido**
- NAO depende de: CPU da instancia, hora do dia, uso de memoria
- Boas para: dev/test, batch processing, workloads sem SLA
- Politica de remocao: **Stop/Deallocate** (padrao) ou **Delete**

## Reimplantar vs Mover

- **Reimplantar (Redeploy)** = move VM para outro host fisico (resolve problemas de hardware/manutencao)
- Azure desliga a VM, move para novo host, e reinicia
- IPs dinamicos podem mudar; IPs estaticos sao mantidos

## Cloud-init / Custom Data vs Custom Script Extension

| Aspecto                | Cloud-init (Custom Data) | Custom Script Extension | Run Command     |
| ---------------------- | ------------------------ | ----------------------- | --------------- |
| SO                     | Linux apenas             | Windows e Linux         | Windows e Linux |
| Quando executa         | Primeiro boot            | Pos-provisioning        | Ad-hoc          |
| Atualizar apos criacao | Nao (imutavel)           | Sim                     | Sim             |
| Uso tipico             | Config inicial, pacotes  | Deploy software         | Troubleshooting |

### Pegadinhas
- "Instalar pacotes no 1o boot de VM Linux" → **cloud-init**
- "Executar script em VM ja criada" → **Custom Script Extension**
- "Troubleshooting rapido sem RDP/SSH" → **Run Command**
- Custom Data em **base64** no ARM/Bicep
- Cloud-init **NAO** funciona em Windows

## ARM Templates (IaC)

- `New-AzResourceGroupDeployment` = deploy ARM template em **Resource Group** (mais comum)
- `New-AzSubscriptionDeployment` = deploy no nivel de **Subscription**
- `New-AzManagementGroupDeployment` = deploy no nivel de **Management Group**
- `New-AzVM` = cria VM diretamente (sem template)
- Para passar **array como parametro inline**: usar `--parameters` no comando de deploy
- NAO usar arquivo separado para arrays inline — usar diretamente no `--parameters`
- Folha **Implantacoes** no RG mostra nome, status, **data/hora** de cada deploy ARM
- Folha Diagnostico = metricas; Folha Policy = politicas

**Parametros de referencia ao template:**

| Template esta onde | CLI | PowerShell |
| --- | --- | --- |
| Disco local | `--template-file` | `-TemplateFile` |
| URL (blob, GitHub) | `--template-uri` | `-TemplateUri` |
| Template Spec no Azure | `--template-spec` | `-TemplateSpecId` |
| `-Tag` | **NAO existe** para deploy (distrator!) | |

- "Template em blob storage" → **-TemplateUri** (NAO -TemplateFile)
- "Template local" → **-TemplateFile**
- "Template Spec salvo no Azure" → **-TemplateSpecId**

**Exportar template de recurso existente:**

| Cmdlet | O que faz |
| --- | --- |
| `Save-AzDeploymentTemplate` | Salva o template de um **deployment passado** |
| `Export-AzResourceGroup` | Exporta o **estado atual** dos recursos do RG |
| RG/Recurso > **Export template** > Deploy | Exporta e faz deploy pelo portal |

- 3 formas de usar VM como modelo: (1) `Save-AzDeploymentTemplate` + deploy, (2) Portal Export + download + deploy, (3) VM > Export template > Deploy direto
- `Get-AzVM` **NAO** exporta templates (apenas lista VMs)
- `Save-AzDeploymentScriptLog` salva **logs**, nao templates

## Extensoes de VM - Quando usar cada uma

| Extensao | Funcao | Coleta logs/metricas? |
| --- | --- | --- |
| **Azure Monitor Agent (AMA)** | Coletar dados (metricas guest, logs custom) → Log Analytics | **Sim** |
| **Custom Script Extension** | Executar scripts pos-deploy (instalar software, config) | Nao |
| **DSC (Desired State Config)** | Gerenciar configuracao como codigo (estado desejado) | Nao |
| **VMAccess** | Reset de senha/SSH, reparar acesso ao Linux | Nao |
| **NetworkWatcherExtension** | Habilitar Packet Capture na VM | Nao |

- "Coletar dados para Log Analytics" → **AMA**
- "Coletar logs customizados (JSON, texto) → Log Analytics" → **AMA + DCR** (NAO Custom Script Extension)
- "Instalar software apos criar VM" → **Custom Script Extension**
- "Manter configuracao consistente" → **DSC**
- "Reset de senha SSH no Linux" → **VMAccess**
- "Capturar pacotes de rede" → **NetworkWatcherExtension** (pre-requisito do Packet Capture)

## Mover Recursos

| Cenario                  | Metodo                         | Downtime |
| ------------------------ | ------------------------------ | -------- |
| Entre RGs (mesma regiao) | `az resource move`             | Nenhum   |
| Entre subscriptions      | `az resource move`             | Nenhum   |
| Entre regioes            | ASR / Resource Mover / Recriar | Variavel |

- `az resource move` **NAO** suporta move entre regioes para VMs
- Resources com **locks** nao podem ser movidos
- **Azure Resource Mover** orquestra dependencias para moves cross-region

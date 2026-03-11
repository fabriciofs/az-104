> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 4 - Virtual Networking](bloco4-networking.md)

# Bloco 3 - Azure Resources & IaC

**Origem:** Lab 03b - Manage Azure Resources by Using ARM Templates + **testes de integracao com governanca**
**Resource Groups utilizados:** `rg-contoso-identity` (preparado no Bloco 2 com policies)

## Contexto

Voce vai provisionar recursos usando diferentes metodos de IaC. O diferencial desta versao: todos os discos sao criados no **rg-contoso-identity** que ja tem policies ativas do Bloco 2 (Modify tag + Allowed Locations). A cada deploy, voce **valida que a governanca funciona**: tags herdadas e restricao de regiao.

## Diagrama

```
┌───────────────────────────────────────────────────────────┐
│                    rg-contoso-identity                              │
│               Tag: Cost Center = 000                      │
│          Policy: Modify (inherit tag) ← Bloco 2           │
│          Policy: Allowed Locations (East US) ← Bloco 2    │
│          RBAC: Reader → Guest user ← Bloco 2              │
│                                                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │disk-iac-    │ │disk-iac-    │ │disk-iac-    │ │disk-iac-    │ │
│  │test-01      │ │test-02      │ │test-03      │ │test-04      │ │
│  │(Portal)     │ │(ARM Portal) │ │(ARM + PS)   │ │(ARM + CLI)  │ │
│  │Tag: ✓       │ │Tag: ✓       │ │Tag: ✓       │ │Tag: ✓       │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│                                                                   │
│  ┌─────────────┐ ┌──────────────────────────────────────┐         │
│  │disk-iac-    │ │ Testes de integracao:                │         │
│  │test-05      │ │ • Tags herdadas em cada disco ✓      │         │
│  │(Bicep +     │ │ • Deploy West US → bloqueado ✓       │         │
│  │ CLI)        │ │ • Guest user → somente leitura ✓     │         │
│  │Tag: ✓       │ └──────────────────────────────────────┘         │
│  └─────────────┘                                                  │
│                                                           │
│  → Cloud Shell configurado aqui → reusado nos Blocos 4/5  │
│  → ARM/Bicep skills → usadas no Bloco 4                   │
└───────────────────────────────────────────────────────────┘
```

---

### Task 3.1: Criar managed disk e exportar ARM template

1. Pesquise e selecione **Disks** > **Create**:

   | Setting           | Value                                     |
   | ----------------- | ----------------------------------------- |
   | Subscription      | *sua subscription*                        |
   | Resource Group    | `rg-contoso-identity`                               |
   | Disk name         | `disk-iac-test-01`                             |
   | Region            | **East US**                               |
   | Availability zone | **No infrastructure redundancy required** |
   | Source type       | **None**                                  |
   | Performance       | **Standard HDD** (altere o tamanho)       |
   | Size              | **32 GiB**                                |

2. Clique em **Review + Create** > **Create**

3. Selecione **Go to resource**

4. **Validacao de governanca:** No blade **Tags**, verifique que a tag **Cost Center = 000** foi automaticamente atribuida pela policy Modify do Bloco 2.

   > **Conexao com Bloco 2:** A policy "Inherit tag from resource group if missing" esta funcionando! O disco herdou a tag do rg-contoso-identity sem voce precisar configura-la manualmente.

5. No blade **Automation**, selecione **Export template**

6. Revise as abas **Template** e **Parameters**

7. Clique em **Download** em cada aba para salvar os arquivos JSON

---

### Task 3.2: Editar template e fazer deploy de disk-iac-test-02 via portal

1. Pesquise **Deploy a custom template** > **Build your own template in the editor**

2. **Load file** > carregue **template.json**

3. No editor, altere:
   - `disks_disk_iac_test_01_name` → `disk_name` (dois locais)
   - `disk-iac-test-01` → `disk-iac-test-02` (um local)

4. Clique em **Save**

5. **Edit parameters** > **Load file** > carregue **parameters.json**

6. Altere `disks_disk_iac_test_01_name` → `disk_name`

7. Clique em **Save**

8. Complete o deployment:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource Group | `rg-contoso-identity`   |
   | Region         | **East US**   |
   | Disk_name      | `disk-iac-test-02` |

9. Clique em **Review + Create** > **Create**

10. Selecione **Go to resource**

11. **Validacao de governanca:** Verifique no blade **Tags** que `Cost Center = 000` foi herdada automaticamente.

---

### Task 3.3: Configurar Cloud Shell e deploy de disk-iac-test-03 via PowerShell

1. Clique no icone do **Cloud Shell** no canto superior direito

2. Selecione **PowerShell**

3. Na tela Getting started, selecione **Mount storage account** > selecione sua subscription > **Apply**

4. Selecione **I want to create a storage account** > **Next**:

   | Setting         | Value                                                      |
   | --------------- | ---------------------------------------------------------- |
   | Resource Group  | **rg-contoso-identity**                                              |
   | Region          | *sua regiao*                                               |
   | Storage account | *nome unico globalmente (3-24 chars, lowercase + numeros)* |
   | File share      | `fs-cloudshell`                                            |

5. Clique em **Create**

   > **Conexao com Blocos 4/5:** O Cloud Shell configurado aqui sera reutilizado para nslookup (Bloco 4) e outros comandos (Bloco 5). Nao sera necessario reconfigurar.

6. Selecione **Settings** > **Go to classic version**

7. **Upload** os arquivos template.json e parameters.json

8. No **Editor**, altere o nome do disco para `disk-iac-test-03`. Salve com **Ctrl+S**

9. Execute o deploy:

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName rg-contoso-identity -TemplateFile template.json -TemplateParameterFile parameters.json
    ```

10. Verifique que o ProvisioningState e **Succeeded**

11. **Validacao de governanca:** Verifique a tag:

    ```powershell
    Get-AzDisk -ResourceGroupName rg-contoso-identity -DiskName disk-iac-test-03 | Select-Object Name, Tags
    ```

    A tag `Cost Center: 000` deve aparecer.

---

### Task 3.4: Deploy via CLI (Bash) de disk-iac-test-04

1. No Cloud Shell, selecione **Bash** e **confirme**

2. Verifique os arquivos: `ls`

3. No **Editor**, altere o nome do disco para `disk-iac-test-04`. Salve com **Ctrl+S**

4. Execute o deploy:

   ```sh
   az deployment group create --resource-group rg-contoso-identity --template-file template.json --parameters parameters.json
   ```

5. Verifique o ProvisioningState: **Succeeded**

6. **Validacao de governanca:**

   ```sh
   az disk show --resource-group rg-contoso-identity --name disk-iac-test-04 --query tags
   ```

   Resultado esperado: `{"Cost Center": "000"}`

---

### Task 3.5: Deploy via Bicep de disk-iac-test-05

1. Continue no **Cloud Shell** (Bash)

2. **Upload** o arquivo `azuredeploydisk.bicep`:

   **Conteudo do arquivo `azuredeploydisk.bicep`:**

   ```bicep
   @description('Name of the managed disk to be copied')
   param managedDiskName string = 'diskname'

   @description('Disk size in GiB')
   @minValue(4)
   @maxValue(65536)
   param diskSizeinGiB int = 8

   @description('Disk IOPS value')
   @minValue(100)
   @maxValue(160000)
   param diskIopsReadWrite int = 100

   @description('Disk throughput value in MBps')
   @minValue(1)
   @maxValue(2000)
   param diskMbpsReadWrite int = 10

   @description('Location for all resources.')
   param location string = resourceGroup().location

   resource managedDisk 'Microsoft.Compute/disks@2023-10-02' = {
     name: managedDiskName
     location: location
     sku: {
       name: 'UltraSSD_LRS'
     }
     properties: {
       creationData: {
         createOption: 'Empty'
       }
       diskSizeGB: diskSizeinGiB
       diskIOPSReadWrite: diskIopsReadWrite
       diskMBpsReadWrite: diskMbpsReadWrite
     }
   }
   ```

3. No **Editor**, faca as alteracoes:
   - Linha 2: `managedDiskName` default → `disk-iac-test-05`
   - Linha 27 (dentro do bloco `sku`): name → `StandardSSD_LRS`
   - Linha 7: `diskSizeinGiB` default → `32`

4. Salve com **Ctrl+S**

5. Execute o deploy:

   ```sh
   az deployment group create --resource-group rg-contoso-identity --template-file azuredeploydisk.bicep
   ```

6. **Validacao de governanca:**

   ```sh
   az disk show --resource-group rg-contoso-identity --name disk-iac-test-05 --query tags
   ```

7. Liste todos os 5 discos:

   ```sh
   az disk list --resource-group rg-contoso-identity --output table
   ```

---

### Task 3.6: Teste de integracao — Allowed Locations policy

Voce testa a policy do Bloco 2 que restringe recursos ao East US.

1. No Cloud Shell (Bash), tente criar um disco em **West US**:

   ```sh
   az deployment group create --resource-group rg-contoso-identity \
     --template-file azuredeploydisk.bicep \
     --parameters managedDiskName=az104-disk-test location=westus
   ```

2. **Resultado esperado:** O deploy **falha** com erro de policy violation:

   ```
   "Resource 'az104-disk-test' was disallowed by policy."
   ```

   > **Conexao com Bloco 2:** A policy "Allowed locations" aplicada no Bloco 2 esta funcionando! Recursos so podem ser criados em East US neste resource group.

3. Confirme que o disco de teste NAO foi criado:

   ```sh
   az disk list --resource-group rg-contoso-identity --output table
   ```

   Devem aparecer apenas os 5 discos originais.

---

### Task 3.7: Teste de integracao — Guest user com Reader role (Opcional)

Este teste valida o RBAC configurado no Bloco 2 (Reader para o guest user).

> **Pre-requisito:** O guest user deve ter aceito o convite do Bloco 1.

1. Abra uma janela **InPrivate/Incognito**

2. Acesse `https://portal.azure.com`

3. Faca login com as credenciais do **guest user** (seu email pessoal)

4. Pesquise e selecione **Resource groups** > **rg-contoso-identity**

5. Voce deve conseguir **ver** os discos criados

6. Tente criar um novo disco (**Disks** > **Create**) — deve **falhar** com erro de permissao

   > **Conexao com Blocos 1 e 2:** O guest user (convidado no Bloco 1) recebeu Reader (atribuido no Bloco 2) e pode ver mas nao criar recursos. Isso demonstra RBAC em acao.

7. Feche a janela InPrivate

---

## Modo Desafio - Bloco 3

- [ ] Criar `disk-iac-test-01` via Portal em rg-contoso-identity → **verificar tag herdada**
- [ ] Deploy `disk-iac-test-02` via ARM Portal → **verificar tag herdada**
- [ ] Configurar Cloud Shell (PowerShell) → deploy `disk-iac-test-03` → **verificar tag**
- [ ] Trocar para Bash → deploy `disk-iac-test-04` → **verificar tag**
- [ ] Deploy `disk-iac-test-05` via Bicep → **verificar tag**
- [ ] **Integracao:** Tentar deploy em West US → bloqueado por policy
- [ ] **Integracao (opcional):** Login como guest → Reader somente leitura

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce aplicou uma policy Modify "Inherit tag from resource group" no rg-contoso-identity. Voce cria um managed disk via ARM template sem tags. O que acontece com as tags do disco?**

A) O disco e criado sem tags
B) O disco herda a tag Cost Center = 000 do resource group automaticamente
C) O deploy falha porque o disco nao tem a tag
D) O disco e criado e marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: B) O disco herda a tag Cost Center = 000 do resource group automaticamente**

O efeito **Modify** altera as propriedades do recurso durante a criacao. A policy "Inherit tag from resource group if missing" copia a tag do RG para o recurso se ele nao a possuir. Diferente do Deny (que bloquearia) ou Audit (que apenas registraria).

</details>

### Questao 3.2
**Qual comando PowerShell faz deploy de um ARM template em um Resource Group?**

A) `Set-AzResourceGroup`
B) `New-AzResourceGroupDeployment`
C) `New-AzDeployment`
D) `Deploy-AzTemplate`

<details>
<summary>Ver resposta</summary>

**Resposta: B) New-AzResourceGroupDeployment**

- `New-AzResourceGroupDeployment` → deploy no nivel de Resource Group
- `New-AzDeployment` → deploy no nivel de Subscription
- Os escopos de deploy CLI sao: `az deployment group|sub|mg|tenant create`

</details>

### Questao 3.3
**Qual a principal diferenca entre ARM Templates (JSON) e Bicep?**

A) Bicep e interpretada, ARM e compilada
B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON
C) ARM suporta mais tipos de recursos
D) Bicep requer runtime separada

<details>
<summary>Ver resposta</summary>

**Resposta: B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON**

Bicep e uma DSL que compila transparentemente para ARM JSON. Ambos suportam os mesmos recursos.

</details>

---


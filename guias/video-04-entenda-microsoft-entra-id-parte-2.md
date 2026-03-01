# Video 4: Entenda o Microsoft Entra ID (Parte 2) AZ-104

## Informacoes Gerais

| Propriedade             | Valor                                         |
| ----------------------- | --------------------------------------------- |
| **Titulo**              | Entenda o Microsoft Entra ID (Parte 2) AZ-104 |
| **Canal**               | Microsoft Learn                               |
| **Inscritos no Canal**  | 88,7 mil                                      |
| **Visualizacoes**       | 14.000+                                       |
| **Data de Publicacao**  | 4 de junho de 2025                            |
| **Posicao na Playlist** | Episodio 4 de 22                              |
| **Idioma**              | Ingles (com dublagem automatica disponivel)   |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=LcSRgoQLX0I                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Esta e a segunda parte do modulo sobre Microsoft Entra ID. O video continua explorando os aspectos praticos do gerenciamento de identidades, incluindo redefinicao de senha por autoatendimento (SSPR) e comparacao de diferentes tipos de identidades.

### O que voce aprendera

- Gerenciamento de usuarios e grupos no Entra ID
- Configuracao de Self-Service Password Reset (SSPR)
- Tipos de grupos e suas diferencas
- Atribuicao de licencas
- Identidades externas e convidados (B2B)

---

## Topicos Abordados

### 1. Gerenciamento de Usuarios

| Operacao              | Descricao                                  |
| --------------------- | ------------------------------------------ |
| **Criar usuario**     | Adicionar novos usuarios ao tenant         |
| **Editar usuario**    | Modificar propriedades e atributos         |
| **Deletar usuario**   | Remover usuarios (soft delete por 30 dias) |
| **Restaurar usuario** | Recuperar usuarios deletados               |

### 2. Gerenciamento de Grupos

| Tipo de Grupo     | Caracteristica                       |
| ----------------- | ------------------------------------ |
| **Security**      | Para gerenciar acesso a recursos     |
| **Microsoft 365** | Para colaboracao (email, SharePoint) |

| Tipo de Associacao | Descricao                               |
| ------------------ | --------------------------------------- |
| **Assigned**       | Membros adicionados manualmente         |
| **Dynamic User**   | Membros baseados em regras de atributos |
| **Dynamic Device** | Dispositivos baseados em regras         |

### 3. Self-Service Password Reset (SSPR)

| Configuracao                | Opcoes                                  |
| --------------------------- | --------------------------------------- |
| **Habilitacao**             | None, Selected, All                     |
| **Metodos de autenticacao** | Email, SMS, App, Perguntas de seguranca |
| **Numero de metodos**       | 1 ou 2 metodos requeridos               |
| **Registro**                | Forcar registro no proximo login        |

### 4. Identidades Externas (B2B)

- **Guest Users** - Usuarios de fora da organizacao
- **Convites** - Processo de convite por email
- **Restricoes** - Controle de dominios permitidos
- **Permissoes** - Acesso limitado por padrao

---

## Conceitos-Chave para o Exame

### 1. Bulk Operations

| Operacao           | Uso                              |
| ------------------ | -------------------------------- |
| **Bulk create**    | Criar multiplos usuarios via CSV |
| **Bulk invite**    | Convidar multiplos guests        |
| **Bulk delete**    | Remover multiplos usuarios       |
| **Download users** | Exportar lista de usuarios       |

### 2. Licenciamento

| Metodo               | Descricao                         |
| -------------------- | --------------------------------- |
| **Direto**           | Atribuir licenca ao usuario       |
| **Baseado em grupo** | Atribuir licenca ao grupo (P1/P2) |

### 3. Administrative Units

- Delegacao de administracao por unidade organizacional
- Escopo limitado para administradores
- Semelhante a OUs do AD on-premises

### 4. Device Management

| Tipo de Join               | Descricao                            |
| -------------------------- | ------------------------------------ |
| **Azure AD Registered**    | Dispositivos pessoais (BYOD)         |
| **Azure AD Joined**        | Dispositivos corporativos cloud-only |
| **Hybrid Azure AD Joined** | Dispositivos joined no AD e Azure AD |

---

## Peso no Exame AZ-104

| Dominio                                     | Peso   |
| ------------------------------------------- | ------ |
| Gerenciar identidades e governanca do Azure | 20-25% |

### Questoes Frequentes no Exame

1. Configuracao de SSPR
2. Tipos de grupos e membership
3. Bulk operations com CSV
4. Identidades externas B2B
5. Administrative Units

---

## Recursos Complementares

| Recurso                | Link                                                                                    |
| ---------------------- | --------------------------------------------------------------------------------------- |
| **SSPR Documentation** | https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sspr-howitworks |
| **Manage Groups**      | https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-groups               |
| **B2B Collaboration**  | https://learn.microsoft.com/en-us/entra/external-id/what-is-b2b                         |

---

## Proximo Video

**Video 5:** Administer Governance and Compliance (Parte 1)

- Azure Subscriptions e Management Groups
- Azure Policy
- Role-Based Access Control (RBAC)
- Resource locks

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

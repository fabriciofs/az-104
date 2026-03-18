Guia de Permissionamento Azure: Entra ID, RBAC e ABAC

1. Introdução: O Coração da Identidade vs. O Poder da Infraestrutura

Entender o ecossistema do Microsoft Azure pode parecer desafiador, mas o segredo para o sucesso no exame AZ-104 está em uma analogia simples: imagine um prédio comercial. O seu crachá de identificação diz quem você é e permite que você passe pela portaria (isso é o Diretório/Entra ID). Já a chave que abre a porta de uma sala específica determina o que você pode fazer lá dentro (isso é o RBAC).

A ansiedade com permissões geralmente surge ao confundir esses dois mundos. Para eliminar qualquer dúvida, grave este resumo fundamental:

Entra ID Roles: Quem pode fazer o quê no diretório (identidade). Azure RBAC: Quem pode fazer o quê nos recursos (infraestrutura). Azure ABAC: É o RBAC com "filtros inteligentes" (condições por atributos).

Agora que entendemos a premissa básica, vamos olhar para o cérebro da operação: o Entra ID.


--------------------------------------------------------------------------------


2. Microsoft Entra ID Roles: O Gerenciamento do Diretório (Quem somos)

Este sistema foca exclusivamente no nível de Tenant/Diretório. Ele é o guardião das identidades e das configurações globais da sua organização na nuvem.

O Entra ID Roles controla:

* Usuários e Grupos: Criação, exclusão e gerenciamento.
* Registros de Aplicativos: Identidades para softwares.
* Licenças: Atribuição de Microsoft 365 ou Azure AD Premium.
* Políticas: Acesso Condicional e SSPR (Redefinição de senha).

💡 Mentor Note: Pense nos App Registrations (Registros de Aplicativos) como "contas de usuário para softwares". Assim como uma pessoa precisa de um login, um sistema precisa de uma identidade para interagir com o Azure.

Exemplos Clássicos para a Prova:

* Global Admin: Acesso total ao diretório.
* User Admin: Gerencia usuários e grupos, mas não mexe em servidores.
* Guest Inviter: Permite convidar usuários externos (B2B).

Com a identidade criada no diretório, precisamos decidir em quais partes da nossa infraestrutura esse usuário pode atuar.


--------------------------------------------------------------------------------


3. Azure RBAC: O Controle sobre os Recursos (Onde atuamos)

O Azure RBAC (Role-Based Access Control) é o sistema que dita as regras dentro da infraestrutura. Ele segue uma hierarquia geográfica rigorosa que você deve memorizar:

Management Group → Subscription → Resource Group (RG) → Resource


🏗️ Pro Tip do Arquiteto: Management Groups (Grupos de Gerenciamento) são essenciais para governança em larga escala. Eles permitem aplicar políticas e permissões a várias Assinaturas (Subscriptions) ao mesmo tempo, garantindo que toda a empresa siga o mesmo padrão.

Abaixo, os papéis fundamentais que você encontrará no dia a dia e nos exames:

Papel (Role)	Função Principal	Diferencial Pedagógico
Owner	Acesso total a todos os recursos.	Pode delegar permissões a outros (gerencia o IAM).
Contributor	Cria e gerencia recursos.	Não pode delegar acesso a outros. Ideal para administradores operacionais.
Reader	Apenas visualização.	Impede qualquer alteração acidental; perfeito para auditoria.

Às vezes, apenas o cargo não é suficiente; precisamos de regras mais específicas, e é aqui que entra o ABAC.


--------------------------------------------------------------------------------


4. Azure ABAC: O Refinamento por Condições (O 'Se' da questão)

O Azure ABAC (Attribute-Based Access Control) é uma extensão inteligente do RBAC. Imagine que o RBAC diz "você pode ler arquivos", mas o ABAC adiciona um "...mas apenas se o arquivo for do projeto financeiro".

* Definição: É o RBAC acrescido de condições baseadas em atributos (como tags ou caminhos).
* Exemplo Prático: Atribuímos o papel de Storage Blob Data Reader, mas com a condição: acesso permitido apenas se o blob tiver a tag project=finance.

Dica Pedagógica: O ABAC é a ferramenta definitiva para o conceito de "Privilégio Mínimo". Embora seja menos frequente em provas de nível associado, lembre-se dele sempre que a questão mencionar "filtros por tags" ou "condições de acesso a dados".


--------------------------------------------------------------------------------


5. Comparativo Direto: Entra ID vs. RBAC vs. ABAC

Para consolidar, veja como os três sistemas coexistem em uma única visão:

Característica	Entra ID Roles	Azure RBAC	Azure ABAC
O que controla	O diretório (identidades)	Recursos (VMs, Storage, VNets)	Recursos com condições extras
Onde atribui	Entra ID > Roles	Resource / RG / Sub > IAM	Resource / RG / Sub > IAM + Condições
Escopo	Tenant (Diretório)	MG → Sub → RG → Recurso	Mesmo do RBAC
Exemplo Prático	"User1 pode resetar senhas"	"User1 pode gerenciar o RG-Prod"	"User1 lê blobs se tag=finance"


--------------------------------------------------------------------------------


6. Laboratório Mental: Cenários Práticos de Decisão

Teste sua compreensão antes de avançar:

Cenário 1: Você precisa permitir que um consultor externo seja convidado para colaborar no ambiente. Solução: Entra ID Role (Guest Inviter). Por quê? Convites são funções de diretório, não de infraestrutura.

Cenário 2: Um administrador precisa criar e deletar máquinas virtuais dentro de um Grupo de Recursos. Solução: Azure RBAC (Virtual Machine Contributor no escopo do RG). Por quê? Envolve a gestão de um recurso específico da Azure.

Cenário 3: Um analista precisa ler arquivos no Storage Account, mas apenas se estiverem marcados com a tag "project=finance". Solução: Azure ABAC (Storage Blob Data Reader + condição de atributo). Por quê? O uso de uma "tag" ou "atributo" como filtro de acesso caracteriza o ABAC.


--------------------------------------------------------------------------------


7. Dicas de Ouro para a Prova (Como Identificar)

Se a pergunta mencionar esses termos, use este checklist para matar a questão:

1. Entra ID Role:
  * [ ] Licenças ou MFA.
  * [ ] SSPR (Redefinição de Senha).
  * [ ] Convites de Usuários (Guest Inviter).
  * [ ] Gerenciamento de Grupos ou Domínios.
2. Azure RBAC:
  * [ ] Resource Groups, Assinaturas ou VNets.
  * [ ] "Privilégio Mínimo" aplicado a recursos.
  * [ ] Permissão para criar máquinas virtuais ou bancos de dados.
3. Azure ABAC:
  * [ ] Tags de recursos como critério de acesso.
  * [ ] "Filtro por Path" ou "Atributos do Blob".
  * [ ] Condições lógicas (IF/THEN) em permissões de armazenamento.

Dominar esses níveis de permissionamento é o primeiro passo para se tornar um mestre em Azure. Mantenha o foco nos escopos e lembre-se: Identidade no Entra ID, Recursos no RBAC. Você está no caminho certo para a aprovação!

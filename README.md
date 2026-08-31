# SGA-Checklist — Aplicação Web Responsiva

Protótipo funcional baseado na especificação do PDF fornecido.

## O que já está implementado
- Login demonstrativo.
- Painel geral com indicadores.
- Execução de checklist por ambiente.
- Situações: Conforme, Parcialmente conforme, Não conforme, Não se aplica e Não verificado.
- Obrigatoriedade de observação nas situações irregulares.
- Geração automática de ocorrências de manutenção ao finalizar checklist.
- Módulo de manutenção e fluxo de ocorrências.
- Cadastro de ambientes.
- Catálogo de itens de checklist.
- Usuários e perfis.
- Almoxarifado / estoque e alertas de estoque mínimo.
- Empréstimos e devoluções.
- Programação de checklists.
- Relatórios e indicadores.
- Configurações, notificações e auditoria.
- Layout responsivo para computador, tablet e celular.
- Persistência de algumas ações em localStorage.

## Como executar localmente
Na primeira execução, instale as dependências e mantenha o PostgreSQL do Docker ativo:

```powershell
npm.cmd install
docker compose up -d postgres
npm.cmd start
```

Abra `http://localhost:3000` no navegador. A rota `http://localhost:3000/api/health` confirma a conexão com o PostgreSQL.

O arquivo `index.html` ainda pode ser aberto diretamente para usar o protótipo sem servidor, mas o modo recomendado é iniciar o servidor local.

## Próxima etapa para produção
A especificação prevê uma arquitetura com Next.js, Supabase/PostgreSQL, Supabase Auth, armazenamento de fotos e hospedagem na Vercel. Este pacote possui uma instância Node local com API inicial de usuários e saúde do banco; para produção ainda é necessário migrar os demais módulos para a API, adicionar autenticação real, upload de evidências, permissões no backend, notificações e auditoria persistente.

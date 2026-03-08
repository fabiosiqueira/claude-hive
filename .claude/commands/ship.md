---
description: "Deploy final — versão, changelog, commit, push, PR."
---

# /ship — Deploy Final

Você está preparando o projeto para deploy.

## Processo

### 1. Verificação Pré-Deploy

Antes de qualquer coisa, confirme:
- [ ] Todos os testes passam (`npm test` ou equivalente)
- [ ] Build funciona sem erros (`npm run build` ou equivalente)
- [ ] TypeScript sem erros (`npx tsc --noEmit`)
- [ ] Nenhum arquivo sensível staged (.env, credentials, keys)

Se qualquer verificação falhar, pare e corrija antes de prosseguir.

### 2. Versão (Semver)

Determine a versão com base nas mudanças:
- **patch** (0.0.X): bug fixes, correções menores
- **minor** (0.X.0): novas features, melhorias
- **major** (X.0.0): breaking changes

Atualize a versão em `package.json` (se existir).

### 3. CHANGELOG

Adicione entrada no `CHANGELOG.md`:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- [features novas]

### Changed
- [mudanças em features existentes]

### Fixed
- [bug fixes]

### Security
- [fixes de segurança]
```

Se `CHANGELOG.md` não existir, crie-o.

### 4. README

Verifique se `README.md` precisa de atualização:
- Instalação mudou?
- Interface pública mudou?
- Novos comandos ou configurações?

Atualize se necessário.

### 5. CLAUDE.md / MEMORY.md

Verifique se há decisões ou padrões novos que devem ser registrados:
- Decisões arquiteturais
- Novos patterns estabelecidos
- Configurações importantes

Atualize se necessário.

### 6. Commit + Push

Execute o ritual de commit seguindo as convenções do projeto:
1. Stage dos arquivos relevantes (específicos, não `git add .`)
2. Commit com mensagem Conventional Commits
3. Push para remote

### 7. PR (se em branch)

Se estiver em branch separada (não main):
- Crie PR via `gh pr create`
- Título curto e descritivo
- Body com summary e test plan

### 8. Docker (se aplicável)

Se o projeto usa Docker:
```bash
docker compose build
docker compose up -d
```

Confirme que os containers estão rodando.

### 9. Gate Final

O deploy está completo quando:
- [ ] Versão atualizada
- [ ] CHANGELOG atualizado
- [ ] README atualizado (se necessário)
- [ ] Código committed e pushed
- [ ] PR criada (se em branch)
- [ ] Containers rodando (se Docker)

Apresente resumo ao usuário:
```
Ship completo:
- Versão: X.Y.Z
- Commits: N
- PR: [URL] (se aplicável)
- Status: deployed / pushed
```

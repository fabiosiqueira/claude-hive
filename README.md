# VoltAgent Circle v2

Soft house AI completa dentro do Claude Code. Construída sobre o framework [Superpowers](https://github.com/obra/superpowers) com extensões especializadas para design, validação UX, segurança e deploy.

## Arquitetura

```
Superpowers (base)
├── /brainstorm             → refinar requisitos
├── /write-plan             → plano granular (tasks de 2-5 min)
├── /execute-plan           → implementação com subagentes + review
├── TDD, code review, git worktrees, debugging (skills nativas)
│
└── Circle Extensions
    ├── /design-system      → design tokens, componentes, layouts
    ├── /validate-ux        → testes reais via Playwright MCP
    ├── /security-review    → audit OWASP Top 10
    └── /ship               → versão, changelog, commit, push, PR
```

## Pipeline completo

```bash
/circle   # executa todas as fases em ordem com quality gates
```

Fases:
1. **Brainstorm** — refinar requisitos com o usuário
2. **Planejar** — tasks granulares com paths exatos e código
3. **Design** — design system + componentes (se UI)
4. **Implementar** — subagentes com TDD + code review
5. **Validar UX** — testes reais com Playwright (se UI)
6. **Security Review** — audit OWASP + verificações automatizadas
7. **Ship** — versão semver, changelog, push, PR

Cada fase tem gate objetivo. Falha → volta à fase que falhou.

## Comandos disponíveis

| Comando | Descrição |
|---------|-----------|
| `/circle` | Pipeline completo |
| `/brainstorm` | Refinar requisitos (Superpowers) |
| `/write-plan` | Criar plano de implementação (Superpowers) |
| `/execute-plan` | Executar plano com subagentes (Superpowers) |
| `/design-system` | Gerar design system |
| `/validate-ux` | Validar UX com Playwright |
| `/security-review` | Audit de segurança |
| `/ship` | Deploy final |

## Pré-requisitos

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instalado
- Plugin [Superpowers](https://github.com/obra/superpowers) instalado (`claude plugins install superpowers`)
- Playwright MCP configurado (para `/validate-ux`)

## Estrutura

```
voltagent-circle/
├── CLAUDE.MD                          # regras e arquitetura do Circle v2
├── .claude/commands/
│   ├── circle.md                      # pipeline completo
│   ├── design-system.md               # extensão: design
│   ├── validate-ux.md                 # extensão: validação UX
│   ├── security-review.md             # extensão: segurança
│   └── ship.md                        # extensão: deploy
├── docs/
│   ├── plans/                         # planos gerados pelo /write-plan
│   ├── design-spec.md                 # spec de design (gerado pelo /design-system)
│   └── references/                    # referência histórica da v1
└── README.md
```

## Diferenças da v1

| Aspecto | v1 | v2 |
|---------|----|----|
| Modelo mental | "Equipe de 8 pessoas" | "Processo com quality gates" |
| Subagentes | Por papel (Designer, QA...) | Por task (1 subagente/task) |
| Contexto | Fragmentado (8 handoffs) | Preservado (orquestrador mantém contexto) |
| Skills | Links para repos GitHub | Arquivos `.md` executáveis |
| Quality gates | "Confiança < 85%" | Gates objetivos e verificáveis |
| Roteamento de modelos | Impossível no Claude Code | Tags de complexidade (metadata) |

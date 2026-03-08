# Hive — Multi-Model Orchestration Plugin for Claude Code

Plugin standalone que orquestra múltiplos terminais tmux, cada um rodando Claude Code com um modelo diferente. Roteia tasks para o modelo ideal por complexidade.

## Arquitetura

```
Hive Plugin
├── Orchestration Layer (tmux + model routing)
│   ├── lib/tmux-manager.sh        → criar/gerenciar sessões e workers
│   ├── lib/plan-parser.sh         → extrair tasks, modelos, dependências
│   ├── lib/result-collector.sh    → coletar resultados, detectar conflitos
│   └── lib/worktree-manager.sh    → criar/limpar worktrees por worker
│
├── Skills (~16 skills em skills/<name>/SKILL.md)
│   ├── Orchestration: using-hive, dispatching-workers, worker-communication,
│   │   model-routing, integrating-modules, collecting-results, cost-tracking
│   └── Process: brainstorming, writing-plans, TDD, debugging, verification,
│       code-review, git-worktrees, finishing-branch, writing-skills
│
├── Commands (8 em commands/)
│   ├── /hive, /hive-plan, /hive-dispatch, /hive-status
│   └── /design-system, /validate-ux, /security-review, /ship
│
├── Agents (agents/)
│   ├── worker.md, integrator.md, reviewer.md
│
└── Lib (lib/) — shell scripts de orquestração
```

## Pipeline (`/hive`)

```
1. /hive-plan       → lê CLAUDE.md + docs/roadmap.md, gera plano com model tags
2. /hive-dispatch   → cria tmux session, worktrees, lança workers em paralelo
3. Integração       → merge worktrees, dispatch integration worker se necessário
4. Review           → testes completos, code review
5. /ship            → versão, changelog, commit, push, PR
```

## Model Routing

| Tag | Modelo | Uso |
|-----|--------|-----|
| `[Haiku]` | claude-haiku-4-5 | Schema, CRUD, boilerplate |
| `[Sonnet]` | claude-sonnet-4-6 | Business logic, APIs, testes |
| `[Opus]` | claude-opus-4-6 | Arquitetura, segurança, algoritmos complexos |

## Worker Isolation

Cada worker recebe git worktree isolada em `.hive/worktrees/task-<N>/`.
Workers são lançados com `claude --model <model> --dangerously-skip-permissions`.
Comunicação via filesystem: `.hive/runs/<run-id>/tasks/task-<N>.result.md`.

## Regras

### Skills
- Invoque skills APENAS quando claramente aplicável
- Skill errado = contexto desperdiçado. Na dúvida, NÃO invoque

### Quality Gates
- **Plano**: tasks granulares com paths exatos, model tags, dependency graph
- **Implementação**: TDD obrigatório, cada task em worktree isolada
- **Integração**: integration worker conecta módulos + testes de integração
- **Segurança**: 0 issues CRITICAL/HIGH
- **Deploy**: changelog atualizado, README atualizado, versão semver

### Convenções
- Planos salvos em `docs/plans/YYYY-MM-DD-<feature>.md`
- Design specs em `docs/design-spec.md`
- Estado de execução em `.hive/runs/<run-id>/`
- Worktrees em `.hive/worktrees/`

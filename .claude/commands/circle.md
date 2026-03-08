---
description: "Pipeline completo do VoltAgent Circle — do brainstorm ao deploy."
---

# /circle — Pipeline Completo

Você está executando o pipeline completo do VoltAgent Circle.
Siga cada fase em ordem. Cada fase tem um quality gate — se falhar, volte à fase que falhou.

## Fase 1: Brainstorm

Invoque a skill `superpowers:brainstorming` para refinar os requisitos com o usuário.

**Gate:** Usuário aprovou o escopo e requisitos.

## Fase 2: Planejar

Invoque a skill `superpowers:writing-plans` para criar o plano de implementação.

**Gate:** Plano salvo em `docs/plans/YYYY-MM-DD-<feature>.md` com tasks granulares (2-5 min cada), paths exatos, e código.

## Fase 3: Design (se projeto tem UI)

Pergunte ao usuário: "Este projeto tem interface visual? Se sim, vou gerar o design system."

Se sim, execute `/design-system` usando a Skill tool.

**Gate:** `docs/design-spec.md` criado com paleta, tipografia, componentes, e layouts.

Se não tem UI, pule para Fase 4.

## Fase 4: Implementar

Invoque a skill `superpowers:executing-plans` para executar o plano com subagentes.

Alternativa: Use `superpowers:subagent-driven-development` para execução na mesma sessão.

**Gate:** Todos os tasks do plano completos, testes passando, commits feitos.

## Fase 5: Validar UX (se projeto tem UI)

Execute `/validate-ux` usando a Skill tool.

**Gate:** Todas interações testadas — navegação, cliques, formulários, acessibilidade básica.

Se não tem UI, pule para Fase 6.

## Fase 6: Security Review

Execute `/security-review` usando a Skill tool.

**Gate:** 0 issues CRITICAL ou HIGH. Issues MEDIUM documentadas para fix posterior.

## Fase 7: Ship

Execute `/ship` usando a Skill tool.

**Gate:** Versão atualizada, CHANGELOG atualizado, código pushed, PR criada (se aplicável).

## Controle de Fluxo

- Se qualquer gate falhar, comunique claramente qual gate falhou e por quê.
- Volte à fase que falhou e corrija antes de avançar.
- Entre fases, dê um resumo de 1-2 linhas do que foi concluído.
- Se o contexto estiver ficando grande (muitas fases), sugira iniciar nova sessão para as fases restantes.

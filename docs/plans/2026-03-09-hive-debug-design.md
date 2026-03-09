# Design: /hive-debug

**Data:** 2026-03-09
**Status:** Aprovado

---

## Objetivo

Adicionar o comando `/hive-debug` ao plugin Hive. O usuário informa um erro (texto, stack trace, imagem opcional) e o comando diagnostica a causa raiz, propõe um plano de fix, aguarda aprovação e executa a correção.

---

## Arquivos

```
skills/hive-debug/SKILL.md     ← lógica principal da skill
commands/hive-debug.md         ← ponto de entrada (invoca a skill)
```

---

## Fluxo

```
1. Input          → descrição do erro + stack trace + imagem (opcional)
2. Diagnóstico    → analisa causa raiz (lê arquivos relevantes, git log, testes)
3. Plano de fix   → lista de mudanças com justificativa + avaliação de complexidade
4. Aprovação      → aguarda confirmação do usuário antes de qualquer mudança
5. Execução       → aplica o fix (direto ou via hive-dispatch)
6. Verificação    → roda testes, confirma que o erro não reproduz
```

---

## Diagnóstico (STAR)

- **Situação** — o que o erro diz
- **Tarefa** — o que deveria acontecer
- **Ação** — causa raiz da divergência
- **Resultado** — o fix necessário

---

## Critério de complexidade

| Simples → fix direto | Complexo → workers (hive-dispatch) |
|---|---|
| ≤ 2 arquivos afetados | 3+ arquivos ou módulos |
| Causa raiz clara e isolada | Refactor ou mudança arquitetural |
| Sem dependências entre mudanças | Tasks independentes paralelizáveis |

---

## Integração com o plugin

- Segue o padrão dos demais comandos Hive (`commands/*.md` invoca `skills/*/SKILL.md`)
- Para execução complexa, delega ao fluxo de `dispatching-workers`
- TDD obrigatório: qualquer fix deve incluir teste que reproduz o bug antes da correção

# /hive-debug Implementation Plan

**Goal:** Adicionar o comando `/hive-debug` ao plugin Hive — diagnóstica, planeja e executa o fix de um bug com aprovação do usuário.
**Architecture:** Dois arquivos Markdown: `commands/hive-debug.md` (ponto de entrada) e `skills/hive-debug/SKILL.md` (lógica principal). A skill reutiliza o padrão STAR para diagnóstico, avalia complexidade do fix (direto vs workers) e delega execução à skill `dispatching-workers` quando necessário.
**Tech Stack:** Markdown (skill/command), Bash (install.sh para sincronizar)

---

## Batch 1 — Implementação (paralelo)

### Task 1 · [Haiku] — `skills/hive-debug/SKILL.md`

**Files:**
- Create: `skills/hive-debug/SKILL.md`

**Steps:**

1. Criar o arquivo com o conteúdo abaixo:

```markdown
---
name: hive-debug
description: "Diagnose a bug from error input, propose a fix plan, get approval, and execute"
---

# Hive Debug

Você recebeu um erro para diagnosticar e corrigir. Siga os passos abaixo em ordem.
Não escreva código antes de completar o diagnóstico e obter aprovação do usuário.

## Step 1: Coletar input

O usuário forneceu um ou mais dos seguintes:
- Descrição do erro em texto
- Stack trace / log de saída
- Imagem/screenshot (use `Read` para visualizar se fornecida como path)

Se a descrição for ambígua, faça **uma** pergunta objetiva antes de continuar.

## Step 2: Diagnóstico (STAR)

Leia os arquivos relevantes identificados no erro. Consulte `git log --oneline -10` e
`git log --oneline -10 -- <arquivo>` para identificar mudanças recentes.

Estruture o diagnóstico:

```
**Situação:** O que o erro diz / o que está acontecendo
**Tarefa:** O que deveria acontecer (comportamento esperado)
**Ação:** Causa raiz — qual código, linha ou lógica provoca a divergência
**Resultado:** O que precisa mudar para corrigir
```

**GATE:** Não avance sem identificar a causa raiz com um trecho de código específico.
"Algo neste módulo" não é suficiente.

## Step 3: Avaliar complexidade

Classifique o fix em uma das duas categorias:

| Critério | Direto | Workers (hive-dispatch) |
|---|---|---|
| Arquivos afetados | ≤ 2 | 3+ |
| Causa raiz | Clara e isolada | Múltiplos módulos ou refactor |
| Dependências entre mudanças | Nenhuma | Tasks paralelizáveis independentes |

## Step 4: Propor plano de fix

Apresente ao usuário:

```
## Plano de fix

**Causa raiz:** <uma frase>
**Abordagem:** direto pelo orquestrador | workers paralelos

### Mudanças

| Arquivo | Mudança |
|---------|---------|
| `path/to/file.ext` | <descrição> |

### Teste de regressão
`tests/path/to/test.ext` — deve falhar antes do fix, passar depois
```

**GATE:** Aguarde confirmação explícita do usuário ("ok", "pode seguir", "aprovado") antes de qualquer mudança.

## Step 5: Executar o fix

### Fix direto (≤ 2 arquivos, causa clara)

Siga TDD:
1. Escreva o teste de regressão → confirme que **falha** com o erro original
2. Aplique o fix mínimo
3. Confirme que o teste **passa**
4. Commit: `fix: <descrição concisa>`

### Fix via workers (3+ arquivos ou complexo)

1. Salve o plano em `docs/plans/YYYY-MM-DD-debug-<descricao>.md`
2. Invoque a skill `dispatching-workers` para executar o plano em paralelo
3. Monitore via TaskCreate/TaskUpdate até conclusão

## Step 6: Verificar

Após o fix (direto ou workers):

```bash
# Rode a suite de testes completa do projeto
# Se não houver suite definida, rode o que o projeto usar (bash tests/, npm test, cargo test, etc.)
```

Confirme:
- [ ] Teste de regressão passa
- [ ] Suite completa passa sem novas falhas
- [ ] O erro original não se reproduz mais

Reporte o resultado ao usuário: causa raiz, arquivo corrigido, teste adicionado.

## Princípios

- **Diagnóstico antes de código.** Nunca toque em um arquivo sem entender por quê.
- **Fix mínimo.** Corrija só o que causa o bug. Não refatore adjacências.
- **Teste de regressão obrigatório.** Todo fix tem um teste que teria pegado o bug.
- **Uma pergunta por vez.** Se precisar de mais contexto, pergunte um item por vez.
```

2. Verificar que o arquivo foi criado com as seções: Step 1–6, tabela de complexidade, GATE de aprovação, princípios.

**Acceptance criteria:**
- Arquivo existe em `skills/hive-debug/SKILL.md`
- Contém Step 1 (input), Step 2 (STAR), Step 3 (complexidade), Step 4 (plano + GATE), Step 5 (fix direto e workers), Step 6 (verificação)
- Sem hardcodes ou workarounds temporários

---

### Task 2 · [Haiku] — `commands/hive-debug.md`

**Files:**
- Create: `commands/hive-debug.md`

**Steps:**

1. Criar o arquivo com o conteúdo abaixo:

```markdown
---
description: "Diagnose a bug, plan the fix, get approval, and execute — with direct fix or parallel workers."
disable-model-invocation: true
---

# /hive-debug -- Debug and Fix

You are running the Hive debug pipeline. Invoke the `hive:hive-debug` skill to begin.

The skill will:
1. Collect the error input (text, stack trace, optional image path)
2. Diagnose the root cause using STAR reasoning
3. Evaluate fix complexity (direct vs workers)
4. Present a fix plan and wait for user approval
5. Execute the fix (TDD for direct; dispatching-workers for complex)
6. Verify all tests pass

Provide your error description, stack trace, or image path to start.
```

2. Verificar que o frontmatter tem `disable-model-invocation: true` e que o arquivo invoca `hive:hive-debug`.

**Acceptance criteria:**
- Arquivo existe em `commands/hive-debug.md`
- Frontmatter válido com `description` e `disable-model-invocation: true`
- Invoca a skill `hive:hive-debug`
- Instrução clara para o usuário sobre o input esperado

---

## Batch 2 — Sincronização

### Task 3 · [Haiku] — `install.sh`

**Files:**
- Run: `bash install.sh`

**Steps:**

1. Rodar `bash install.sh` e confirmar saída:
```
Hive 1.1.2
→ marketplace: ...
→ cache: ...
Done. Restart Claude Code to load the new version.
```

**Acceptance criteria:**
- `install.sh` roda sem erros
- Versão sincronizada no marketplace e cache

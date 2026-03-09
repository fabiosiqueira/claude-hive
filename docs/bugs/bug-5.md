# Bug #5 — Background Task fica "running" indefinidamente após SSH com `nohup &`

**Data:** 2026-03-09
**Projeto:** trading-agent-rl
**Contexto:** Hive dispatch — lançamento de treino remoto na avell
**Status: ✅ DOCUMENTADO** — Gotcha #8 adicionado em `skills/dispatching-workers/SKILL.md`: nunca usar `run_in_background: true` com `ssh ... nohup ... &`. As sugestões 2 e 3 dependem do Claude Code (produto externo).

---

## O que aconteceu

Claude lançou um background bash task via `Bash(run_in_background: true)` com o comando:

```bash
ssh avell "cd ~/dev/projetos/trading-agent-rl && CUDA_VISIBLE_DEVICES='' nohup venv/bin/python src/sniper_agent/runner.py train --model-name sniper_f14_sentiment > /tmp/train_f14.log 2>&1 & echo PID=\$!"
```

A task ficou com status `running` por ~6 horas no footer do Claude Code. Claude nunca recebeu notificação de conclusão e não conseguia finalizar a task sem o ID explícito.

**Output registrado:** `PID=$!` (literal — sem expansão do `$!`)

---

## Causa Raiz

O comando SSH usa `nohup ... &` — o processo remoto é colocado em background **antes** do SSH fechar. O SSH retorna imediatamente (exit 0) após o `echo PID=$!`.

O Claude Code monitora o processo SSH em si. Como o SSH encerrou com exit 0, **a task deveria ter sido marcada como `completed` automaticamente** — mas não foi. A task ficou presa em `running`.

**Agravante:** `\$!` foi passado dentro de aspas duplas no SSH, resultando em `PID=$!` literal na saída (sem expansão da variável shell remota). Claude não capturou o PID real e não tinha como rastrear o processo remoto.

---

## Por que Claude não conseguiu finalizar

Não há API pública para listar background tasks ativos no contexto da sessão. Claude só conhece o task ID se tiver salvo explicitamente antes.

Quando a sessão sofreu compactação de contexto, o ID `bh9uh3fp4` ficou apenas no histórico compactado. Na nova sessão (pós-compactação), Claude não tinha visibilidade da task pendente e não podia chamar `TaskStop` sem o ID.

A única resolução foi o usuário identificar visualmente a task no footer e informar Claude, que então chamou `TaskStop("bh9uh3fp4")`.

---

## Reprodução

1. Lançar `Bash(run_in_background: true)` com `ssh host "... nohup cmd & echo PID=\$!"`
2. Aguardar — a task nunca recebe notificação de conclusão
3. Iniciar nova sessão via compactação de contexto — Claude perde referência ao task ID
4. Task fica visível no footer como "running" indefinidamente

---

## Impacto

- Task aparece no footer do Claude Code como "running" indefinidamente
- Usuário fica preso sem conseguir fechar sem saber o task ID
- Claude não consegue fazer `TaskStop` sem o ID salvo explicitamente
- Agrava com compactação de contexto: Claude perde rastreio do ID

---

## Sugestões de Fix

### 1. No Hive skill (workaround imediato)
Após `ssh ... nohup ... &`, **não usar** `run_in_background: true`. O SSH já retorna imediatamente porque o processo remoto está em background. Usar `Bash` síncrono normal — a task completa em ~1s e não fica presa.

```bash
# ERRADO — task fica presa
Bash(run_in_background: true, command: "ssh host 'nohup cmd & echo $!'")

# CORRETO — SSH retorna imediatamente, task completa normalmente
Bash(command: "ssh host 'nohup cmd > /tmp/log 2>&1 & echo $!'")
```

### 2. No Claude Code (fix de produto)
Expor endpoint/tool para listar background tasks ativos na sessão atual, permitindo que Claude descubra e limpe tasks órfãs sem depender do usuário.

### 3. No Claude Code (fix de produto)
Se um processo SSH encerrar com exit 0 e o comando continha `&` (background), marcar a task como `completed` automaticamente.

---

## Resolução

Task `bh9uh3fp4` finalizada manualmente via `TaskStop("bh9uh3fp4")` após o usuário informar o ID.
O treino remoto (`sniper_f14_sentiment`) estava rodando normalmente na avell — o `nohup` funcionou; apenas o tracking da task no Claude Code ficou inconsistente.

# Bug Report — Hive Plugin v3.0.0

**Data:** 2026-03-08
**Reportado por:** trading-agent-rl session
**Severidade:** Alta — impede execução de workers no macOS (zsh)
**Status: ✅ CORRIGIDO** — fix em v1.0.1 via `hive_write_worker_script` + `hive_launch_worker_script`

---

## Problema

`hive_launch_worker` em `lib/tmux-manager.sh` falha quando o prompt contém aspas simples, parênteses ou outros caracteres especiais de shell.

### Causa raiz

```bash
# lib/tmux-manager.sh — linha atual:
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"

  tmux send-keys -t "$session_name:$worker_name" "$command" Enter
}
```

`tmux send-keys` envia o texto como sequência de teclas para o terminal. O shell (zsh) interpreta os caracteres em tempo real, exatamente como se o usuário os digitasse. Quando o `$command` contém:

- Aspas simples `'` → zsh entra em "quote mode" aguardando fechamento
- Parênteses `)` → zsh emite `zsh: parse error near ')'`
- Acentos, arrows, `→` → interpretados como escape sequences

### Reprodução

```bash
source lib/tmux-manager.sh
tmux new-session -d -s test-session
tmux new-window -t test-session -n worker1

# Este comando FALHA quando o prompt tem aspas simples:
PROMPT="claude -p 'You are a worker. Call feature_name_to_index(name, list) and return Optional[int]'"
hive_launch_worker "test-session" "worker1" "$PROMPT"

# Saída no pane:
# zsh: parse error near ')'
# quote>   (zsh trava aguardando fechamento de aspas)
```

### Comportamento observado (log real)

```
(base) fabiosiqueira@macbook task-1 % claude ... -p 'You are a Hive worker...
quote>
quote> TASK: F11.1 — Feature Ablation Script
quote> ...
zsh: parse error near `)'

STEP 3 - Implement src/scripts/feature_ablation.py with:
  - @dataclass AblationResult(feature_name, baseline_sharpe, ablated_sharpe)...
  [prompt vaza para o terminal como texto]
```

O prompt inteiro vaza no terminal como texto simples, sem ser passado para o `claude`. Worker não executa.

---

## Solução Recomendada

### Opção 1 — Prompt via arquivo temporário (recomendada)

Modificar `hive_launch_worker` para aceitar o prompt como arquivo, ou criar variante `hive_launch_worker_with_prompt`:

```bash
# lib/tmux-manager.sh

# Versão corrigida: escreve prompt em arquivo temp, passa via $(cat)
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"   # comando base: "claude --model X --dangerously-skip-permissions"
  local prompt="$4"    # prompt (pode conter qualquer caractere)

  if [[ -n "$prompt" ]]; then
    # Escreve prompt em arquivo temp seguro
    local prompt_file
    prompt_file=$(mktemp /tmp/hive-prompt-XXXXXX.txt)
    printf '%s' "$prompt" > "$prompt_file"

    # Monta comando que lê o prompt do arquivo
    local full_command="${command} -p \"\$(cat '${prompt_file}')\""
    tmux send-keys -t "$session_name:$worker_name" "$full_command" Enter
  else
    tmux send-keys -t "$session_name:$worker_name" "$command" Enter
  fi
}
```

### Opção 2 — Script wrapper por worker

Criar um script `.sh` para cada worker com o prompt embutido em heredoc, e enviar só o caminho do script via send-keys:

```bash
# Gerado pelo orquestrador antes de hive_launch_worker:
hive_write_worker_script() {
  local script_path="$1"
  local worktree_path="$2"
  local model="$3"
  local budget="$4"
  local prompt="$5"

  cat > "$script_path" << SCRIPT
#!/usr/bin/env bash
cd "$worktree_path"
PROMPT_FILE=\$(mktemp)
cat > "\$PROMPT_FILE" << 'ENDPROMPT'
${prompt}
ENDPROMPT
claude --model "$model" --dangerously-skip-permissions --max-budget-usd "$budget" -p "\$(cat "\$PROMPT_FILE")"
rm -f "\$PROMPT_FILE"
SCRIPT
  chmod +x "$script_path"
}

# Uso:
hive_write_worker_script "/tmp/worker-task-1.sh" "$worktree" "claude-sonnet-4-6" "5.00" "$PROMPT"
hive_launch_worker "$SESSION" "task-1" "bash /tmp/worker-task-1.sh"
```

### Opção 3 — `tmux send-keys` com arquivo de pipe (alternativa Unix)

```bash
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"
  local prompt_file="$4"   # caminho para arquivo já escrito com o prompt

  if [[ -n "$prompt_file" && -f "$prompt_file" ]]; then
    local full_cmd="${command} -p \"\$(cat ${prompt_file})\""
    tmux send-keys -t "$session_name:$worker_name" "$full_cmd" Enter
  else
    tmux send-keys -t "$session_name:$worker_name" "$command" Enter
  fi
}
```

---

## Workaround usado nesta sessão

```bash
# 1. Escrevemos o prompt em arquivo:
cat > ".hive/runs/$RUN_ID/task-N-prompt.txt" << 'ENDPROMPT'
<prompt aqui, qualquer caractere funciona>
ENDPROMPT

# 2. Criamos script wrapper:
cat > ".hive/runs/$RUN_ID/run-task-N.sh" << EOF
#!/bin/bash
cd "$WORKTREE"
claude --model $MODEL --dangerously-skip-permissions --max-budget-usd $BUDGET \
  -p "\$(cat '$RUN_DIR/task-N-prompt.txt')"
EOF
chmod +x ".hive/runs/$RUN_ID/run-task-N.sh"

# 3. Send-keys só com o path do script (sem aspas problemáticas):
tmux send-keys -t "$SESSION:task-N" "bash $RUN_DIR/run-task-N.sh" Enter
```

---

## Arquivos afetados no plugin

| Arquivo | Mudança necessária |
|---------|-------------------|
| `lib/tmux-manager.sh` | Corrigir `hive_launch_worker` (principal) |
| `skills/dispatching-workers/SKILL.md` | Documentar que prompts devem ser passados via arquivo |

---

## Bug 2 — `hive_create_worker` / `hive_launch_worker`: nome de pane truncado

**Severidade:** Alta — worker lançado no pane errado ou não lançado

### Causa raiz

`hive_create_worker` cria a janela tmux com `-n "$worker_name"`, mas o tmux **trunca nomes de janela** que contêm `-` seguido de caracteres quando o terminal está estreito. O `hive_launch_worker` então usa `"$session_name:$worker_name"` como target, e o tmux falha com:

```
can't find pane: hive-20260308-162032ask-6
```

O problema: tmux concatena `session:window` como `hive-20260308-162032` + `task-6` → interpreta como `hive-20260308-162032ask-6` (o `t` do `task` é consumido como separador).

### Reprodução

```bash
SESSION="hive-20260308-162032"
tmux new-window -t "$SESSION" -n "task-6"
tmux send-keys -t "$SESSION:task-6" "echo hello" Enter
# Erro: can't find pane: hive-20260308-162032ask-6
```

### Fix recomendado

Usar **índice numérico** do window em vez do nome, ou usar `:=worker_name` (match exato por nome):

```bash
# Opção 1: target por índice (mais confiável)
hive_launch_worker() {
  local session_name="$1"
  local worker_name="$2"
  local command="$3"

  # Busca o índice numérico do window pelo nome
  local window_index
  window_index=$(tmux list-windows -t "$session_name" -F "#{window_index} #{window_name}" \
    | awk -v name="$worker_name" '$2 == name {print $1}' | head -1)

  if [[ -z "$window_index" ]]; then
    echo "ERROR: window '$worker_name' not found in session '$session_name'" >&2
    return 1
  fi

  tmux send-keys -t "${session_name}:${window_index}" "$command" Enter
}

# Opção 2: usar =name para match exato (tmux >= 3.x)
tmux send-keys -t "${session_name}:=${worker_name}" "$command" Enter
```

### Workaround usado nesta sessão

Após identificar o índice das janelas com `tmux list-windows`, usar índice numérico diretamente:

```bash
tmux send-keys -t "$SESSION:6" "bash $RUN_DIR/run-task-6.sh" Enter  # task-6 = window 6
tmux send-keys -t "$SESSION:7" "bash $RUN_DIR/run-task-7.sh" Enter
tmux send-keys -t "$SESSION:8" "bash $RUN_DIR/run-task-8.sh" Enter
```

---

## Ambiente onde ocorreu

- **OS:** macOS Darwin 25.3.0
- **Shell:** zsh
- **tmux:** 3.6a
- **claude CLI:** `~/.local/bin/claude`
- **Hive version:** 3.0.0

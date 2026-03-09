#!/usr/bin/env bash
# demo-visual.sh — Simulação visual do polling de tasks com hive_print_status
# Cria 5 workers fake com timeouts diferentes e todos os estados possíveis

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/tmux-manager.sh" 2>/dev/null || true

RUN_DIR=$(mktemp -d)
mkdir -p "$RUN_DIR/tasks"

cleanup() { rm -rf "$RUN_DIR"; }
trap cleanup EXIT

# --- Workers fake com comportamentos diferentes ---

# Task 1 · Haiku · sucesso rápido (4s)
echo '{"model":"claude-haiku-4-5"}' > "$RUN_DIR/tasks/task-1.assigned.json"
(
  sleep 1; echo "[$(date +%H:%M:%S)] Reading CLAUDE.md" >> "$RUN_DIR/tasks/task-1.progress.txt"
  sleep 1; echo "[$(date +%H:%M:%S)] Writing migration SQL" >> "$RUN_DIR/tasks/task-1.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Committing" >> "$RUN_DIR/tasks/task-1.progress.txt"
  printf "## Result\nSchema migration complete.\nHIVE_TASK_COMPLETE\n" > "$RUN_DIR/tasks/task-1.result.md"
) &

# Task 2 · Sonnet · sucesso médio (9s)
echo '{"model":"claude-sonnet-4-6"}' > "$RUN_DIR/tasks/task-2.assigned.json"
(
  sleep 1; echo "[$(date +%H:%M:%S)] Reading domain files" >> "$RUN_DIR/tasks/task-2.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Writing failing tests" >> "$RUN_DIR/tasks/task-2.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] 3/5 tests passing" >> "$RUN_DIR/tasks/task-2.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Implementing service layer" >> "$RUN_DIR/tasks/task-2.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] All tests passing — committing" >> "$RUN_DIR/tasks/task-2.progress.txt"
  printf "## Result\nAuth service implemented.\nHIVE_TASK_COMPLETE\n" > "$RUN_DIR/tasks/task-2.result.md"
) &

# Task 3 · Opus · sucesso lento (16s)
echo '{"model":"claude-opus-4-6"}' > "$RUN_DIR/tasks/task-3.assigned.json"
(
  sleep 1; echo "[$(date +%H:%M:%S)] Analyzing architecture" >> "$RUN_DIR/tasks/task-3.progress.txt"
  sleep 3; echo "[$(date +%H:%M:%S)] Designing caching strategy" >> "$RUN_DIR/tasks/task-3.progress.txt"
  sleep 3; echo "[$(date +%H:%M:%S)] Writing integration tests" >> "$RUN_DIR/tasks/task-3.progress.txt"
  sleep 3; echo "[$(date +%H:%M:%S)] Implementing Redis adapter" >> "$RUN_DIR/tasks/task-3.progress.txt"
  sleep 3; echo "[$(date +%H:%M:%S)] Performance validated — committing" >> "$RUN_DIR/tasks/task-3.progress.txt"
  sleep 3; printf "## Result\nCaching layer implemented.\nHIVE_TASK_COMPLETE\n" > "$RUN_DIR/tasks/task-3.result.md"
) &

# Task 4 · Haiku · erro (6s)
echo '{"model":"claude-haiku-4-5"}' > "$RUN_DIR/tasks/task-4.assigned.json"
(
  sleep 1; echo "[$(date +%H:%M:%S)] Reading API docs" >> "$RUN_DIR/tasks/task-4.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Attempting webhook setup" >> "$RUN_DIR/tasks/task-4.progress.txt"
  sleep 3; echo "[$(date +%H:%M:%S)] External API unreachable — aborting" >> "$RUN_DIR/tasks/task-4.progress.txt"
  printf "## Error\nCould not reach external webhook API.\nHIVE_TASK_ERROR\n" > "$RUN_DIR/tasks/task-4.result.md"
) &

# Task 5 · Sonnet · context overload (11s)
echo '{"model":"claude-sonnet-4-6"}' > "$RUN_DIR/tasks/task-5.assigned.json"
(
  sleep 1; echo "[$(date +%H:%M:%S)] Reading module A" >> "$RUN_DIR/tasks/task-5.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Reading module B" >> "$RUN_DIR/tasks/task-5.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Reading module C" >> "$RUN_DIR/tasks/task-5.progress.txt"
  sleep 2; echo "[$(date +%H:%M:%S)] Reading module D (context limit approaching)" >> "$RUN_DIR/tasks/task-5.progress.txt"
  sleep 4; echo "[$(date +%H:%M:%S)] Context overload — signaling orchestrator" >> "$RUN_DIR/tasks/task-5.progress.txt"
  printf "## Context Overload\nRead 4 interdependent modules. Recommend split.\nHIVE_TASK_CONTEXT_HEAVY\n" > "$RUN_DIR/tasks/task-5.result.md"
) &

# --- Loop de polling ---
TASK_NUMBERS="1 2 3 4 5"
INTERVAL=2

echo ""
echo "Simulando batch com 5 workers — polling a cada ${INTERVAL}s"
echo "(Ctrl+C para interromper)"
echo ""

while true; do
  clear
  hive_print_status "" "$RUN_DIR" "$TASK_NUMBERS"

  # Verifica se todos têm status terminal
  all_done=true
  for N in $TASK_NUMBERS; do
    status=$(hive_get_task_status "$RUN_DIR/tasks/task-$N.result.md")
    if [[ "$status" == "running" ]]; then
      all_done=false
      break
    fi
  done

  if [[ "$all_done" == "true" ]]; then
    echo ""
    echo "✓ Todos os tasks concluídos. Avançando para merge."
    break
  fi

  sleep "$INTERVAL"
done

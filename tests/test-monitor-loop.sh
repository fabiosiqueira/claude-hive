#!/usr/bin/env bash
# test-monitor-loop.sh — Testa o loop de monitoramento (Step 5 do skill dispatching-workers)
# Mocka TaskCreate/TaskUpdate como funções bash que gravam chamadas em arquivo de log.
# Verifica que o loop faz as chamadas corretas para cada transição de estado.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/tmux-manager.sh" 2>/dev/null || true

PASS=0
FAIL=0

# --- Infraestrutura de assert ---

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc"
    echo "    esperado conter: $needle"
    echo "    conteúdo:        $haystack"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  FAIL: $desc (encontrado inesperadamente: $needle)"
    ((FAIL++))
  else
    echo "  PASS: $desc"
    ((PASS++))
  fi
}

# --- Mocks de TaskCreate / TaskUpdate ---
# Gravam cada chamada em CALLS_LOG no formato:
#   TaskCreate <subject> | <activeForm>
#   TaskUpdate <taskId> <status> [subject=...] [activeForm=...]

CALLS_LOG=""

mock_task_id_counter=0

TaskCreate() {
  local subject="${1:-}" active_form="${2:-}"
  ((mock_task_id_counter++))
  echo "TaskCreate|$subject|$active_form" >> "$CALLS_LOG"
  echo "$mock_task_id_counter"
}

TaskUpdate() {
  local task_id="${1:-}" status="${2:-}" subject="${3:-}" active_form="${4:-}"
  echo "TaskUpdate|$task_id|$status|$subject|$active_form" >> "$CALLS_LOG"
}

# --- Implementação do loop de monitoramento (extrato do Step 5) ---
# Args: run_dir, task_numbers (espaço-separados), task_ids (espaço-separados),
#       task_descriptions (array via nameref), interval (segundos)
run_monitor_loop() {
  local run_dir="$1"
  local task_numbers="$2"
  local -n _task_ids="$3"    # array: índice = N, valor = taskId do Claude Code
  local -n _task_descs="$4"  # array: índice = N, valor = "Task N · [Model] desc"
  local interval="${5:-0}"   # 0 para testes (sem sleep real)

  local -A terminal_states=()

  while true; do
    local all_done=true

    for N in $task_numbers; do
      # Já terminal — não re-checar
      [[ -n "${terminal_states[$N]:-}" ]] && continue

      local result_file="$run_dir/tasks/task-$N.result.md"
      local status
      status=$(hive_get_task_status "$result_file")

      case "$status" in
        complete)
          TaskUpdate "${_task_ids[$N]}" "completed" "${_task_descs[$N]} — DONE" ""
          terminal_states[$N]="complete"
          ;;
        error)
          TaskUpdate "${_task_ids[$N]}" "completed" "${_task_descs[$N]} — FAILED" ""
          terminal_states[$N]="error"
          ;;
        context_heavy)
          TaskUpdate "${_task_ids[$N]}" "completed" "${_task_descs[$N]} — CONTEXT_OVERLOAD" ""
          terminal_states[$N]="context_heavy"
          ;;
        running)
          local progress
          progress=$(hive_get_task_progress "$run_dir" "$N")
          TaskUpdate "${_task_ids[$N]}" "in_progress" "" "$progress"
          all_done=false
          ;;
      esac
    done

    if [[ "$all_done" == "true" ]]; then
      break
    fi

    [[ $interval -gt 0 ]] && sleep "$interval"
  done
}

# =============================================================================
echo "=== test-monitor-loop.sh ==="
echo ""

# --- Teste 1: task completa → TaskUpdate completed com DONE ---
echo "--- Teste 1: complete → TaskUpdate completed DONE ---"

TMP1=$(mktemp -d)
mkdir -p "$TMP1/tasks"
CALLS_LOG=$(mktemp)
mock_task_id_counter=0

echo "HIVE_TASK_COMPLETE" > "$TMP1/tasks/task-1.result.md"

declare -A ids1=([1]="101")
declare -A descs1=([1]="Task 1 · [Haiku] Schema migration")

run_monitor_loop "$TMP1" "1" ids1 descs1 0

calls1=$(cat "$CALLS_LOG")
assert_contains "chamou TaskUpdate com completed" "TaskUpdate|101|completed" "$calls1"
assert_contains "subject contém DONE" "Task 1 · [Haiku] Schema migration — DONE" "$calls1"
assert_not_contains "não chamou FAILED" "FAILED" "$calls1"

rm -rf "$TMP1" "$CALLS_LOG"
unset ids1 descs1

echo ""
# --- Teste 2: task error → TaskUpdate completed com FAILED ---
echo "--- Teste 2: error → TaskUpdate completed FAILED ---"

TMP2=$(mktemp -d)
mkdir -p "$TMP2/tasks"
CALLS_LOG=$(mktemp)
mock_task_id_counter=0

echo "HIVE_TASK_ERROR" > "$TMP2/tasks/task-2.result.md"

declare -A ids2=([2]="202")
declare -A descs2=([2]="Task 2 · [Sonnet] Auth service")

run_monitor_loop "$TMP2" "2" ids2 descs2 0

calls2=$(cat "$CALLS_LOG")
assert_contains "chamou TaskUpdate com completed" "TaskUpdate|202|completed" "$calls2"
assert_contains "subject contém FAILED" "Task 2 · [Sonnet] Auth service — FAILED" "$calls2"
assert_not_contains "não chamou DONE" "DONE" "$calls2"

rm -rf "$TMP2" "$CALLS_LOG"
unset ids2 descs2

echo ""
# --- Teste 3: context_heavy → TaskUpdate completed com CONTEXT_OVERLOAD ---
echo "--- Teste 3: context_heavy → TaskUpdate completed CONTEXT_OVERLOAD ---"

TMP3=$(mktemp -d)
mkdir -p "$TMP3/tasks"
CALLS_LOG=$(mktemp)
mock_task_id_counter=0

echo "HIVE_TASK_CONTEXT_HEAVY" > "$TMP3/tasks/task-3.result.md"

declare -A ids3=([3]="303")
declare -A descs3=([3]="Task 3 · [Sonnet] Module integration")

run_monitor_loop "$TMP3" "3" ids3 descs3 0

calls3=$(cat "$CALLS_LOG")
assert_contains "chamou TaskUpdate com completed" "TaskUpdate|303|completed" "$calls3"
assert_contains "subject contém CONTEXT_OVERLOAD" "Task 3 · [Sonnet] Module integration — CONTEXT_OVERLOAD" "$calls3"

rm -rf "$TMP3" "$CALLS_LOG"
unset ids3 descs3

echo ""
# --- Teste 4: running com progress file → TaskUpdate in_progress com activeForm ---
echo "--- Teste 4: running → TaskUpdate in_progress com progress ---"

TMP4=$(mktemp -d)
mkdir -p "$TMP4/tasks"
CALLS_LOG=$(mktemp)
mock_task_id_counter=0

echo '{"model":"claude-sonnet-4-6"}' > "$TMP4/tasks/task-4.assigned.json"
echo "[10:00:00] Writing failing tests" > "$TMP4/tasks/task-4.progress.txt"
# result ainda não existe → "running"
# Após 1ª iteração marca como complete para o loop terminar
(sleep 0.1; echo "HIVE_TASK_COMPLETE" > "$TMP4/tasks/task-4.result.md") &

declare -A ids4=([4]="404")
declare -A descs4=([4]="Task 4 · [Sonnet] Auth service")

run_monitor_loop "$TMP4" "4" ids4 descs4 0

wait

calls4=$(cat "$CALLS_LOG")
assert_contains "chamou TaskUpdate in_progress com progress" "TaskUpdate|404|in_progress||Writing failing tests" "$calls4"
assert_contains "depois chamou TaskUpdate completed" "TaskUpdate|404|completed" "$calls4"

rm -rf "$TMP4" "$CALLS_LOG"
unset ids4 descs4

echo ""
# --- Teste 5: batch misto (3 tasks, estados diferentes) ---
echo "--- Teste 5: batch misto — complete + error + context_heavy ---"

TMP5=$(mktemp -d)
mkdir -p "$TMP5/tasks"
CALLS_LOG=$(mktemp)
mock_task_id_counter=0

echo "HIVE_TASK_COMPLETE"       > "$TMP5/tasks/task-1.result.md"
echo "HIVE_TASK_ERROR"          > "$TMP5/tasks/task-2.result.md"
echo "HIVE_TASK_CONTEXT_HEAVY"  > "$TMP5/tasks/task-3.result.md"

declare -A ids5=([1]="101" [2]="202" [3]="303")
declare -A descs5=([1]="Task 1 · [Haiku] Migration" [2]="Task 2 · [Sonnet] Auth" [3]="Task 3 · [Opus] Cache")

run_monitor_loop "$TMP5" "1 2 3" ids5 descs5 0

calls5=$(cat "$CALLS_LOG")
assert_contains "task-1 → DONE"             "Task 1 · [Haiku] Migration — DONE" "$calls5"
assert_contains "task-2 → FAILED"           "Task 2 · [Sonnet] Auth — FAILED" "$calls5"
assert_contains "task-3 → CONTEXT_OVERLOAD" "Task 3 · [Opus] Cache — CONTEXT_OVERLOAD" "$calls5"

# Verifica que não houve re-chamadas após terminal (cada task aparece exatamente 1x no log)
count_t1=$(echo "$calls5" | grep -c "TaskUpdate|101" || true)
count_t2=$(echo "$calls5" | grep -c "TaskUpdate|202" || true)
count_t3=$(echo "$calls5" | grep -c "TaskUpdate|303" || true)
assert_eq "task-1 atualizada exatamente 1x" "1" "$count_t1"
assert_eq "task-2 atualizada exatamente 1x" "1" "$count_t2"
assert_eq "task-3 atualizada exatamente 1x" "1" "$count_t3"

rm -rf "$TMP5" "$CALLS_LOG"
unset ids5 descs5

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

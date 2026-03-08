#!/usr/bin/env bash
# Tests for lib/tmux-manager.sh
# Note: set -e is NOT used here because we need to test failure cases
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
PASS=0
FAIL=0
TEST_SESSION="hive-test-$$"

# Source without inheriting set -e
(
  set +e
  source "$LIB_DIR/tmux-manager.sh" 2>/dev/null
)
source "$LIB_DIR/tmux-manager.sh" 2>/dev/null || true

assert_eq() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_success() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    ((PASS++))
  else
    echo "  FAIL: $description (command failed: $*)"
    ((FAIL++))
  fi
}

assert_fail() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL: $description (expected failure but succeeded)"
    ((FAIL++))
  else
    echo "  PASS: $description"
    ((PASS++))
  fi
}

cleanup() {
  tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
}
trap cleanup EXIT

# --- Tests ---

echo "=== tmux-manager.sh tests ==="
echo ""

echo "--- hive_check_tmux ---"
assert_success "tmux is available" hive_check_tmux

echo ""
echo "--- hive_create_session ---"
assert_success "creates tmux session" hive_create_session "$TEST_SESSION"

has_session=0
tmux has-session -t "$TEST_SESSION" 2>/dev/null && has_session=1
assert_eq "session exists" "1" "$has_session"

assert_fail "fails on duplicate session" hive_create_session "$TEST_SESSION"

echo ""
echo "--- hive_create_worker ---"
assert_success "creates worker window" hive_create_worker "$TEST_SESSION" "worker-1" "/tmp"
local_windows=$(tmux list-windows -t "$TEST_SESSION" -F "#{window_name}" | grep -c "worker-1" || echo "0")
assert_eq "worker window exists" "1" "$local_windows"

echo ""
echo "--- hive_capture_output ---"
tmux send-keys -t "$TEST_SESSION:worker-1" "echo HIVE_TEST_MARKER" Enter
sleep 1
captured=$(hive_capture_output "$TEST_SESSION" "worker-1" 10)
if echo "$captured" | grep -q "HIVE_TEST_MARKER"; then
  echo "  PASS: captures output containing marker"
  ((PASS++))
else
  echo "  FAIL: marker not found in captured output"
  ((FAIL++))
fi

echo ""
echo "--- hive_check_worker_alive ---"
alive=$(hive_check_worker_alive "$TEST_SESSION" "worker-1")
assert_eq "worker is alive" "true" "$alive"

echo ""
echo "--- hive_kill_worker ---"
assert_success "kills worker window" hive_kill_worker "$TEST_SESSION" "worker-1"
local_windows_after=$(tmux list-windows -t "$TEST_SESSION" -F "#{window_name}" 2>/dev/null | grep -c "worker-1" 2>/dev/null || true)
assert_eq "worker window removed" "0" "$local_windows_after"

echo ""
echo "--- hive_kill_session ---"
assert_success "kills session" hive_kill_session "$TEST_SESSION"
has_session_after=0
tmux has-session -t "$TEST_SESSION" 2>/dev/null && has_session_after=1
assert_eq "session gone" "0" "$has_session_after"

echo ""
echo "--- hive_launch_worker ---"
hive_create_session "$TEST_SESSION"
hive_create_worker "$TEST_SESSION" "worker-launch" "/tmp"
assert_success "launches worker with command" hive_launch_worker "$TEST_SESSION" "worker-launch" "echo LAUNCHED"
sleep 1
launched_output=$(hive_capture_output "$TEST_SESSION" "worker-launch" 5)
if echo "$launched_output" | grep -q "LAUNCHED"; then
  echo "  PASS: launch command executed"
  ((PASS++))
else
  echo "  FAIL: launch command not executed"
  ((FAIL++))
fi

echo ""
echo "--- hive_build_claude_command ---"
cmd=$(hive_build_claude_command "haiku" "" "" "")
if echo "$cmd" | grep -q "\-\-model 'haiku'"; then
  echo "  PASS: command includes model flag"
  ((PASS++))
else
  echo "  FAIL: command missing model flag"
  ((FAIL++))
fi

if echo "$cmd" | grep -q "\-\-dangerously-skip-permissions"; then
  echo "  PASS: command includes skip-permissions"
  ((PASS++))
else
  echo "  FAIL: command missing skip-permissions"
  ((FAIL++))
fi

cmd_with_budget=$(hive_build_claude_command "sonnet" "" "5.00" "do stuff")
if echo "$cmd_with_budget" | grep -q "\-\-max-budget-usd '5.00'"; then
  echo "  PASS: command includes budget flag"
  ((PASS++))
else
  echo "  FAIL: command missing budget flag"
  ((FAIL++))
fi

echo ""
echo "--- hive_build_claude_command with signal ---"
cmd_with_signal=$(hive_build_claude_command "sonnet" "" "" "do stuff" "hive-abc-task-1-done")
if echo "$cmd_with_signal" | grep -q "tmux wait-for -S 'hive-abc-task-1-done'"; then
  echo "  PASS: command includes wait-for signal"
  ((PASS++))
else
  echo "  FAIL: command missing wait-for signal"
  ((FAIL++))
fi

cmd_no_signal=$(hive_build_claude_command "haiku" "" "" "do stuff" "")
if echo "$cmd_no_signal" | grep -q "wait-for"; then
  echo "  FAIL: command should not include wait-for without signal"
  ((FAIL++))
else
  echo "  PASS: command without signal has no wait-for"
  ((PASS++))
fi

echo ""
echo "--- hive_signal_channel ---"
channel=$(hive_signal_channel "run123" "5")
assert_eq "signal channel format" "hive-run123-task-5-done" "$channel"

echo ""
echo "--- hive_wait_for_worker (background signal test) ---"
# Signal in background, then wait — should return immediately
tmux wait-for -S "hive-test-signal-$$" &
sleep 0.1
hive_wait_for_worker "hive-test-signal-$$"
echo "  PASS: wait-for returned after signal"
((PASS++))

echo ""
echo "--- hive_write_worker_script — básico ---"
TMPSCRIPT=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT" "/tmp" "claude-sonnet-4-6" "2.00" "hello world" "" ""

if [[ -x "$TMPSCRIPT" ]]; then
  echo "  PASS: script é executável"
  ((PASS++))
else
  echo "  FAIL: script não é executável"
  ((FAIL++))
fi

first_line=$(head -1 "$TMPSCRIPT")
assert_eq "primeira linha é shebang" "#!/usr/bin/env bash" "$first_line"

if grep -q "set -uo pipefail" "$TMPSCRIPT"; then
  echo "  PASS: script contém set -uo pipefail (sem -e para não abortar antes do trap)"
  ((PASS++))
else
  echo "  FAIL: script não contém set -uo pipefail"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT"

echo ""
echo "--- hive_write_worker_script — path absoluto (regressão Bug 2.2) ---"
TMPSCRIPT_REL=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_REL" ".hive/worktrees/task-1" "claude-sonnet-4-6" "2.00" "hello" "" ""
cd_line_rel=$(grep "^cd " "$TMPSCRIPT_REL")
if [[ "$cd_line_rel" == "cd /"* ]]; then
  echo "  PASS: path relativo → cd com path absoluto"
  ((PASS++))
else
  echo "  FAIL: path relativo não foi resolvido para absoluto"
  echo "    actual: $cd_line_rel"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT_REL"

TMPSCRIPT_ABS=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_ABS" "/tmp/worktree-test" "claude-sonnet-4-6" "2.00" "hello" "" ""
cd_line_abs=$(grep "^cd " "$TMPSCRIPT_ABS")
if echo "$cd_line_abs" | grep -q "/tmp/worktree-test"; then
  echo "  PASS: path absoluto preservado intacto"
  ((PASS++))
else
  echo "  FAIL: path absoluto alterado inesperadamente"
  echo "    actual: $cd_line_abs"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT_ABS"

echo ""
echo "--- hive_write_worker_script — prompts ---"
TMPSCRIPT_PROMPT=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_PROMPT" "/tmp" "claude-sonnet-4-6" "2.00" "my task prompt" "my system prompt" ""
TASK_PROMPT_FILE="${TMPSCRIPT_PROMPT%.sh}.task-prompt.txt"
SYS_PROMPT_FILE="${TMPSCRIPT_PROMPT%.sh}.system-prompt.txt"

if [[ -f "$TASK_PROMPT_FILE" ]]; then
  task_content=$(cat "$TASK_PROMPT_FILE")
  assert_eq "task-prompt.txt contém o prompt correto" "my task prompt" "$task_content"
else
  echo "  FAIL: task-prompt.txt não foi criado"
  ((FAIL++))
fi

if [[ -f "$SYS_PROMPT_FILE" ]]; then
  sys_content=$(cat "$SYS_PROMPT_FILE")
  assert_eq "system-prompt.txt contém o prompt correto" "my system prompt" "$sys_content"
else
  echo "  FAIL: system-prompt.txt não foi criado"
  ((FAIL++))
fi

if grep -q 'cat ' "$TMPSCRIPT_PROMPT"; then
  echo "  PASS: script referencia arquivos de prompt com cat"
  ((PASS++))
else
  echo "  FAIL: script não usa cat para ler arquivos de prompt"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT_PROMPT" "$TASK_PROMPT_FILE" "$SYS_PROMPT_FILE"

echo ""
echo "--- hive_write_worker_script — flags do claude (regressão Bug 2.1) ---"
TMPSCRIPT_FLAGS=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_FLAGS" "/tmp" "claude-sonnet-4-6" "3.00" "do stuff" "" ""

if grep -q "\-\-model" "$TMPSCRIPT_FLAGS"; then
  echo "  PASS: script contém --model"
  ((PASS++))
else
  echo "  FAIL: script não contém --model"
  ((FAIL++))
fi

if grep -q "\-\-dangerously-skip-permissions" "$TMPSCRIPT_FLAGS"; then
  echo "  PASS: script contém --dangerously-skip-permissions"
  ((PASS++))
else
  echo "  FAIL: script não contém --dangerously-skip-permissions"
  ((FAIL++))
fi

if grep -q "\-\-max-budget-usd" "$TMPSCRIPT_FLAGS"; then
  echo "  PASS: script contém --max-budget-usd"
  ((PASS++))
else
  echo "  FAIL: script não contém --max-budget-usd"
  ((FAIL++))
fi

if grep -q "\-\-budget-tokens" "$TMPSCRIPT_FLAGS"; then
  echo "  FAIL: script contém --budget-tokens (flag inválida!)"
  ((FAIL++))
else
  echo "  PASS: script NÃO contém --budget-tokens"
  ((PASS++))
fi
rm -f "$TMPSCRIPT_FLAGS"

echo ""
echo "--- hive_write_worker_script — signal channel ---"
TMPSCRIPT_SIG=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_SIG" "/tmp" "claude-haiku-4-5" "" "task" "" "hive-abc-task-1-done"
if grep -q "trap" "$TMPSCRIPT_SIG" && grep -q "wait-for" "$TMPSCRIPT_SIG" && grep -q "hive-abc-task-1-done" "$TMPSCRIPT_SIG"; then
  echo "  PASS: script com signal contém trap com wait-for <channel>"
  ((PASS++))
else
  echo "  FAIL: script com signal não contém trap wait-for correto"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT_SIG"

TMPSCRIPT_NOSIG=$(mktemp /tmp/hive-test-XXXXX.sh)
hive_write_worker_script "$TMPSCRIPT_NOSIG" "/tmp" "claude-haiku-4-5" "" "task" "" ""
if grep -q "wait-for" "$TMPSCRIPT_NOSIG"; then
  echo "  FAIL: script sem signal contém wait-for inesperadamente"
  ((FAIL++))
else
  echo "  PASS: script sem signal não contém wait-for"
  ((PASS++))
fi
rm -f "$TMPSCRIPT_NOSIG"

echo ""
echo "--- hive_launch_worker_script — execução ---"
hive_kill_session "$TEST_SESSION"
hive_create_session "$TEST_SESSION"
hive_create_worker "$TEST_SESSION" "script-worker" "/tmp"
TMPSCRIPT_LAUNCH=$(mktemp /tmp/hive-test-XXXXX.sh)
printf '#!/usr/bin/env bash\necho SCRIPT_LAUNCHED\n' > "$TMPSCRIPT_LAUNCH"
chmod +x "$TMPSCRIPT_LAUNCH"
hive_launch_worker_script "$TEST_SESSION" "script-worker" "$TMPSCRIPT_LAUNCH"
sleep 1
launched_script_output=$(hive_capture_output "$TEST_SESSION" "script-worker" 10)
if echo "$launched_script_output" | grep -q "bash "; then
  echo "  PASS: hive_capture_output captura bash /path/to/script no histórico"
  ((PASS++))
else
  echo "  FAIL: bash script path não encontrado na saída capturada"
  ((FAIL++))
fi
rm -f "$TMPSCRIPT_LAUNCH"
hive_kill_session "$TEST_SESSION"

echo ""
echo "--- :=name exact match (regressão Bug #2) — worker com hífens ---"
SESSION_HIFENADO="hive-20260308-test-$$"
hive_create_session "$SESSION_HIFENADO"
hive_create_worker "$SESSION_HIFENADO" "task-worker-1" "/tmp"

captured_hif=$(hive_capture_output "$SESSION_HIFENADO" "task-worker-1" 5 2>&1)
cap_exit=$?
if [[ $cap_exit -eq 0 ]]; then
  echo "  PASS: hive_capture_output funciona com worker hifenado"
  ((PASS++))
else
  echo "  FAIL: hive_capture_output falhou com worker hifenado (exit $cap_exit)"
  ((FAIL++))
fi

alive_hif=$(hive_check_worker_alive "$SESSION_HIFENADO" "task-worker-1")
assert_eq "hive_check_worker_alive retorna true para worker hifenado" "true" "$alive_hif"

hive_kill_session "$SESSION_HIFENADO"

echo ""
echo "--- hive_print_status — task pendente (sem assigned.json) ---"
TMP_RUN=$(mktemp -d)
mkdir -p "$TMP_RUN/tasks"

status_output=$(hive_print_status "" "$TMP_RUN" "9")
if echo "$status_output" | grep -q "pending"; then
  echo "  PASS: task sem assigned.json exibe 'pending'"
  ((PASS++))
else
  echo "  FAIL: task sem assigned.json deveria exibir 'pending'"
  ((FAIL++))
fi

if echo "$status_output" | grep -q -- "--"; then
  echo "  PASS: task sem assigned.json exibe '--' em elapsed"
  ((PASS++))
else
  echo "  FAIL: task sem assigned.json deveria exibir '--' em elapsed"
  ((FAIL++))
fi

echo ""
echo "--- hive_print_status — task running (com assigned.json, sem result) ---"
echo '{"model":"claude-sonnet-4-6"}' > "$TMP_RUN/tasks/task-5.assigned.json"
status_running=$(hive_print_status "" "$TMP_RUN" "5")

if echo "$status_running" | grep -q "claude-sonnet-4-6"; then
  echo "  PASS: exibe model name do assigned.json"
  ((PASS++))
else
  echo "  FAIL: deveria exibir model name"
  ((FAIL++))
fi

if echo "$status_running" | grep -q "running"; then
  echo "  PASS: task com assigned.json sem result exibe 'running'"
  ((PASS++))
else
  echo "  FAIL: deveria exibir 'running'"
  ((FAIL++))
fi

if echo "$status_running" | grep -qE "[0-9]+m[0-9]+s"; then
  echo "  PASS: elapsed no formato NmNs"
  ((PASS++))
else
  echo "  FAIL: elapsed deveria estar no formato NmNs"
  ((FAIL++))
fi

echo ""
echo "--- hive_print_status — task completa (HIVE_TASK_COMPLETE) ---"
echo '{"model":"claude-haiku-4-5"}' > "$TMP_RUN/tasks/task-6.assigned.json"
echo "## Summary" > "$TMP_RUN/tasks/task-6.result.md"
echo "HIVE_TASK_COMPLETE" >> "$TMP_RUN/tasks/task-6.result.md"
status_done=$(hive_print_status "" "$TMP_RUN" "6")

if echo "$status_done" | grep -q "✓ done"; then
  echo "  PASS: task com HIVE_TASK_COMPLETE exibe '✓ done'"
  ((PASS++))
else
  echo "  FAIL: deveria exibir '✓ done'"
  ((FAIL++))
fi

echo ""
echo "--- hive_print_status — task com erro (HIVE_TASK_ERROR) ---"
echo '{"model":"claude-opus-4-6"}' > "$TMP_RUN/tasks/task-7.assigned.json"
echo "## Error" > "$TMP_RUN/tasks/task-7.result.md"
echo "HIVE_TASK_ERROR" >> "$TMP_RUN/tasks/task-7.result.md"
status_err=$(hive_print_status "" "$TMP_RUN" "7")

if echo "$status_err" | grep -q "✗ error"; then
  echo "  PASS: task com HIVE_TASK_ERROR exibe '✗ error'"
  ((PASS++))
else
  echo "  FAIL: deveria exibir '✗ error'"
  ((FAIL++))
fi

echo ""
echo "--- hive_print_status — progress file ---"
echo '{"model":"claude-sonnet-4-6"}' > "$TMP_RUN/tasks/task-8.assigned.json"
echo "[10:00:00] Reading CLAUDE.md" > "$TMP_RUN/tasks/task-8.progress.txt"
echo "[10:01:00] Writing failing tests" >> "$TMP_RUN/tasks/task-8.progress.txt"
status_prog=$(hive_print_status "" "$TMP_RUN" "8")

if echo "$status_prog" | grep -q "Writing failing tests"; then
  echo "  PASS: exibe última linha do progress.txt"
  ((PASS++))
else
  echo "  FAIL: deveria exibir última linha do progress.txt"
  ((FAIL++))
fi

# Task sem progress.txt não deve quebrar
echo '{"model":"claude-haiku-4-5"}' > "$TMP_RUN/tasks/task-10.assigned.json"
status_noprog=$(hive_print_status "" "$TMP_RUN" "10" 2>&1)
if [[ $? -eq 0 ]]; then
  echo "  PASS: sem progress.txt não quebra a função"
  ((PASS++))
else
  echo "  FAIL: sem progress.txt causou erro"
  ((FAIL++))
fi

rm -rf "$TMP_RUN"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
# lib/plan-parser.sh — Parses Hive plan markdown files into structured task data
# This file is meant to be sourced, NOT executed directly.
# Do NOT use set -euo pipefail here.

readonly HIVE_PLAN_DELIMITER="|"

# Model tier ranking for comparison (higher = more capable)
_hive_model_tier() {
  local model="$1"
  case "$model" in
    haiku)  echo 1 ;;
    sonnet) echo 2 ;;
    opus)   echo 3 ;;
    *)      echo 0 ;;
  esac
}

_hive_tier_to_model() {
  local tier="$1"
  case "$tier" in
    1) echo "haiku" ;;
    2) echo "sonnet" ;;
    3) echo "opus" ;;
    *) echo "" ;;
  esac
}

# Parse a plan file and output task info as structured lines
# Args: plan_file_path
# Output: One line per task in format:
#   TASK_NUM|BATCH|MODEL|COMPLEXITY|DESCRIPTION|DEPENDS|INTEGRATION_REQUIRED|INTEGRATION_PROMPT
hive_parse_plan() {
  local plan_file="${1:-}"

  if [[ -z "$plan_file" ]] || [[ ! -f "$plan_file" ]]; then
    return 0
  fi

  local current_batch=0
  local in_task=false
  local task_num=""
  local task_model=""
  local task_complexity=""
  local task_description=""
  local task_depends=""
  local task_files=""
  local task_integration="false"
  local task_integration_prompt=""
  local output=""

  _flush_task() {
    if [[ "$in_task" == true ]] && [[ -n "$task_num" ]]; then
      local line="${task_num}${HIVE_PLAN_DELIMITER}${current_batch}${HIVE_PLAN_DELIMITER}${task_model}${HIVE_PLAN_DELIMITER}${task_complexity}${HIVE_PLAN_DELIMITER}${task_description}${HIVE_PLAN_DELIMITER}${task_depends}${HIVE_PLAN_DELIMITER}${task_integration}${HIVE_PLAN_DELIMITER}${task_integration_prompt}"
      if [[ -n "$output" ]]; then
        output="${output}"$'\n'"${line}"
      else
        output="${line}"
      fi
    fi
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Match batch header: ## Batch N
    if echo "$line" | grep -qE '^## Batch [0-9]+'; then
      _flush_task
      in_task=false
      current_batch=$(echo "$line" | sed -E 's/^## Batch ([0-9]+).*/\1/')
      continue
    fi

    # Match task header: ### Task N: [Model] [complexity] Description
    if echo "$line" | grep -qE '^### Task [0-9]+:'; then
      _flush_task

      in_task=true
      task_num=$(echo "$line" | sed -E 's/^### Task ([0-9]+):.*/\1/')
      task_model=$(echo "$line" | sed -E 's/.*\[([A-Za-z]+)\] \[[a-z]+\].*/\1/' | tr '[:upper:]' '[:lower:]')
      task_complexity=$(echo "$line" | sed -E 's/.*\[[A-Za-z]+\] \[([a-z]+)\].*/\1/')
      task_description=$(echo "$line" | sed -E 's/^### Task [0-9]+: \[[A-Za-z]+\] \[[a-z]+\] //')

      # Reset per-task fields
      task_depends=""
      task_files=""
      task_integration="false"
      task_integration_prompt=""
      continue
    fi

    # Parse task metadata lines (only when inside a task)
    if [[ "$in_task" == true ]]; then
      # Depends on
      if echo "$line" | grep -qE '^\- \*\*Depends on:\*\*'; then
        task_depends=$(echo "$line" | sed -E 's/^- \*\*Depends on:\*\* //')
      fi

      # Files
      if echo "$line" | grep -qE '^\- \*\*Files:\*\*'; then
        task_files=$(echo "$line" | sed -E 's/^- \*\*Files:\*\* //')
      fi

      # Integration required
      if echo "$line" | grep -qE '^\- \*\*Integration required:\*\*'; then
        task_integration=$(echo "$line" | sed -E 's/^- \*\*Integration required:\*\* //')
      fi

      # Integration prompt
      if echo "$line" | grep -qE '^\- \*\*Integration prompt:\*\*'; then
        task_integration_prompt=$(echo "$line" | sed -E 's/^- \*\*Integration prompt:\*\* //' | sed -E 's/^"//;s/"$//')
      fi
    fi
  done < "$plan_file"

  # Flush last task
  _flush_task

  if [[ -n "$output" ]]; then
    echo "$output"
  fi
}

# Get all tasks for a specific batch
# Args: plan_file_path, batch_number
# Output: Same format as hive_parse_plan but filtered to one batch
hive_get_batch_tasks() {
  local plan_file="${1:-}"
  local batch_num="${2:-}"

  if [[ -z "$plan_file" ]] || [[ -z "$batch_num" ]]; then
    return 0
  fi

  local all_tasks
  all_tasks=$(hive_parse_plan "$plan_file")

  if [[ -z "$all_tasks" ]]; then
    return 0
  fi

  local filtered
  filtered=$(echo "$all_tasks" | awk -F'|' -v batch="$batch_num" '$2 == batch')

  if [[ -n "$filtered" ]]; then
    echo "$filtered"
  fi
}

# Get the total number of batches
# Args: plan_file_path
# Output: number
hive_get_batch_count() {
  local plan_file="${1:-}"

  if [[ -z "$plan_file" ]] || [[ ! -f "$plan_file" ]]; then
    echo "0"
    return 0
  fi

  local count
  count=$(grep -cE '^## Batch [0-9]+' "$plan_file" 2>/dev/null)
  echo "${count:-0}"
}

# Get the model for a specific task
# Args: plan_file_path, task_number
# Output: haiku, sonnet, or opus
hive_get_task_model() {
  local plan_file="${1:-}"
  local task_num="${2:-}"

  if [[ -z "$plan_file" ]] || [[ -z "$task_num" ]]; then
    return 0
  fi

  local all_tasks
  all_tasks=$(hive_parse_plan "$plan_file")

  if [[ -z "$all_tasks" ]]; then
    return 0
  fi

  local model
  model=$(echo "$all_tasks" | awk -F'|' -v task="$task_num" '$1 == task { print $3 }')

  if [[ -n "$model" ]]; then
    echo "$model"
  fi
}

# Get tasks that require integration in a batch
# Args: plan_file_path, batch_number
# Output: Same format, filtered to integration_required=true
hive_get_integration_tasks() {
  local plan_file="${1:-}"
  local batch_num="${2:-}"

  if [[ -z "$plan_file" ]] || [[ -z "$batch_num" ]]; then
    return 0
  fi

  local batch_tasks
  batch_tasks=$(hive_get_batch_tasks "$plan_file" "$batch_num")

  if [[ -z "$batch_tasks" ]]; then
    return 0
  fi

  local filtered
  filtered=$(echo "$batch_tasks" | awk -F'|' '$7 == "true"')

  if [[ -n "$filtered" ]]; then
    echo "$filtered"
  fi
}

# Get the highest-tier model used in a batch (for integration worker)
# Args: plan_file_path, batch_number
# Output: haiku, sonnet, or opus (the most capable one)
hive_get_batch_max_model() {
  local plan_file="${1:-}"
  local batch_num="${2:-}"

  if [[ -z "$plan_file" ]] || [[ -z "$batch_num" ]]; then
    return 0
  fi

  local batch_tasks
  batch_tasks=$(hive_get_batch_tasks "$plan_file" "$batch_num")

  if [[ -z "$batch_tasks" ]]; then
    return 0
  fi

  local max_tier=0
  while IFS= read -r task_line; do
    local model
    model=$(echo "$task_line" | cut -d'|' -f3)
    local tier
    tier=$(_hive_model_tier "$model")
    if [[ "$tier" -gt "$max_tier" ]]; then
      max_tier="$tier"
    fi
  done <<< "$batch_tasks"

  local result
  result=$(_hive_tier_to_model "$max_tier")
  if [[ -n "$result" ]]; then
    echo "$result"
  fi
}

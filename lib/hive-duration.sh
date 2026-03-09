#!/bin/bash

# hive_format_duration SECONDS
# Convert seconds to HH:MM:SS format
# Usage: hive_format_duration 5445 → 01:30:45

hive_format_duration() {
  local seconds="${1:?seconds required}"

  local hours=$((seconds / 3600))
  local remainder=$((seconds % 3600))
  local minutes=$((remainder / 60))
  local secs=$((remainder % 60))

  printf "%02d:%02d:%02d\n" "$hours" "$minutes" "$secs"
}

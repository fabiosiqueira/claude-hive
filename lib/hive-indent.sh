#!/usr/bin/env bash
# Text indentation utility for Hive CLI output

# hive_indent TEXT PREFIX
# Adds PREFIX to the beginning of each line in TEXT
# Useful for indenting multi-line output for better readability
hive_indent() {
  local text="$1"
  local prefix="$2"

  # Handle empty text
  if [[ -z "$text" ]]; then
    return 0
  fi

  # Use sed to add prefix to each line
  echo "$text" | sed "s/^/${prefix}/"
}

#!/usr/bin/env bash
# Logging utilities for Hive CLI

# hive_log LEVEL MSG
# Outputs '[LEVEL] MSG' to stderr
# LEVEL: INFO, WARN, ERROR
hive_log() {
  local level="$1"
  local message="$2"

  case "$level" in
    INFO|WARN|ERROR)
      echo "[$level] $message" >&2
      ;;
    *)
      echo "[ERROR] Invalid log level: $level" >&2
      return 1
      ;;
  esac
}

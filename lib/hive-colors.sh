#!/usr/bin/env bash
# ANSI color utilities for Hive CLI output

# ANSI color codes as readonly constants
readonly HIVE_COLOR_RED='\033[31m'
readonly HIVE_COLOR_GREEN='\033[32m'
readonly HIVE_COLOR_YELLOW='\033[33m'
readonly HIVE_COLOR_BLUE='\033[34m'
readonly HIVE_COLOR_RESET='\033[0m'

# hive_colorize COLOR TEXT
# Outputs TEXT with the specified ANSI color code applied, followed by reset
hive_colorize() {
  local color="$1"
  local text="$2"
  echo -ne "${color}${text}${HIVE_COLOR_RESET}"
}

# hive_print_status STATUS MESSAGE
# Prints MESSAGE with color appropriate to STATUS
# STATUS can be: ok, error, warn, info
hive_print_status() {
  local status="$1"
  local message="$2"

  case "$status" in
    ok)
      echo -ne "${HIVE_COLOR_GREEN}[ok]${HIVE_COLOR_RESET} ${message}\n"
      ;;
    error)
      echo -ne "${HIVE_COLOR_RED}[error]${HIVE_COLOR_RESET} ${message}\n"
      ;;
    warn)
      echo -ne "${HIVE_COLOR_YELLOW}[warn]${HIVE_COLOR_RESET} ${message}\n"
      ;;
    info)
      echo -ne "${HIVE_COLOR_BLUE}[info]${HIVE_COLOR_RESET} ${message}\n"
      ;;
    *)
      echo -ne "[${status}] ${message}\n"
      ;;
  esac
}

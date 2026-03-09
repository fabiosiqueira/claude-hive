#!/bin/bash

# hive_assert — assertion function for Hive shell scripts
# Usage: hive_assert CONDITION MESSAGE
# Returns 0 if CONDITION is non-empty/non-zero; prints MESSAGE to stderr and returns 1 otherwise

hive_assert() {
    local condition="$1"
    local message="$2"

    # Check if condition is truthy (non-empty and non-zero)
    if [[ -n "$condition" ]] && [[ "$condition" != "0" ]]; then
        return 0
    else
        echo "$message" >&2
        return 1
    fi
}

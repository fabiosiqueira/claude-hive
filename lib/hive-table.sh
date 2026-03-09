#!/bin/bash
# Utility for printing formatted tables in Hive output

# hive_print_table HEADER ROWS
# Prints a formatted ASCII table
#
# HEADER: pipe-separated column names (e.g., "Task|Model|Status")
# ROWS: pipe-separated row data, with rows separated by \n
#
# Example:
#   hive_print_table "Task|Model|Status" "1|haiku|DONE\n2|sonnet|RUNNING"
#
hive_print_table() {
  local header="$1"
  local rows="$2"

  # Use awk to handle all formatting
  echo -e "$header\n$rows" | awk -F'|' '
    NR == 1 {
      # Store header and calculate column widths
      for (i = 1; i <= NF; i++) {
        widths[i] = length($i)
        header[i] = $i
      }
      ncols = NF
      next
    }
    {
      # Update column widths based on data
      for (i = 1; i <= NF; i++) {
        if (length($i) > widths[i]) {
          widths[i] = length($i)
        }
      }
      rows[NR - 1] = $0
    }
    END {
      # Print header
      for (i = 1; i <= ncols; i++) {
        printf "%-" widths[i] "s", header[i]
        if (i < ncols) printf " | "
      }
      print ""

      # Print separator
      for (i = 1; i <= ncols; i++) {
        for (j = 1; j <= widths[i]; j++) printf "-"
        if (i < ncols) printf "-+-"
      }
      print ""

      # Print rows
      for (r = 1; r < NR; r++) {
        split(rows[r], cols, "|")
        for (i = 1; i <= ncols; i++) {
          printf "%-" widths[i] "s", cols[i]
          if (i < ncols) printf " | "
        }
        print ""
      }
    }
  '
}

export -f hive_print_table

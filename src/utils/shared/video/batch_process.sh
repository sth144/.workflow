#!/bin/bash
set -euo pipefail
shopt -s nullglob

# -------------------------
# Argument parsing
# -------------------------

SKIP_EXISTING=0

if [[ "${1:-}" == "--skip-existing" ]]; then
  SKIP_EXISTING=1
  shift
fi

if [ $# -ne 3 ]; then
  echo "Usage: batch_process.sh [--skip-existing] <input_dir> <output_dir> <command>"
  exit 1
fi

input_directory=$1
output_directory=$2
command_template=$3

# -------------------------
# Validation
# -------------------------

if [ ! -d "$input_directory" ]; then
  echo "ERROR: Input directory does not exist: $input_directory"
  exit 1
fi

mkdir -p "$output_directory"

# -------------------------
# Recursive processor
# -------------------------

process_files() {
  local input_dir=$1
  local output_dir=$2

  for file in "$input_dir"/*; do
    if [ -f "$file" ]; then
      dir_path=$(dirname "$file")
      sub_dir="${dir_path/$input_directory/$output_directory}"

      mkdir -p "$sub_dir"

      outfile_name=$(basename "$file")
      outfile="$sub_dir/$outfile_name"

      # Idempotency
      if [[ $SKIP_EXISTING -eq 1 && -e "$outfile" ]]; then
        echo "SKIP (exists): $outfile"
        continue
      fi

      cmd="$command_template"
      cmd="${cmd//__INPUT__/$file}"
      cmd="${cmd//__OUTPUT__/$outfile}"

      echo "RUN: $cmd"
      eval "$cmd"

    elif [ -d "$file" ]; then
      process_files "$file" "$output_directory"
    fi
  done
}

# -------------------------
# Start
# -------------------------

process_files "$input_directory" "$output_directory"


#!/bin/bash

# Source environment files from ~ and ~/.config
# Handles two formats:
#   1. Raw value files: .env.VAR_NAME contains just the value → exports VAR_NAME=<value>
#   2. Key-value files: Contains KEY=value rows → exports each pair
#
# Usage: source /usr/local/bin/os/source_env_files.sh

_source_env_files() {
		local dirs=("$HOME" "$HOME/.config")

		for dir in "${dirs[@]}"; do
				[[ -d "$dir" ]] || continue

				# Find all .env* files (not directories, not in subdirs)
				for envfile in "$dir"/.env*; do
						[[ -f "$envfile" ]] || continue

						local filename
						filename=$(basename "$envfile")

						# Get content, stripping comments and empty lines
						local content
						content=$(grep -v '^\s*#' "$envfile" 2>/dev/null | grep -v '^\s*$')

						[[ -z "$content" ]] && continue

						# Count non-empty, non-comment lines
						local line_count
						line_count=$(echo "$content" | wc -l | tr -d ' ')

						# Check if ANY line contains an = sign (key-value format)
						local has_equals=false
						if echo "$content" | grep -q '='; then
								has_equals=true
						fi

						# Determine format:
						# - If filename is .env.SOMETHING and content is single line without '=',
						#   it's a raw value where SOMETHING is the var name
						# - Otherwise, treat as key-value pairs

						if [[ "$filename" =~ ^\.env\.(.+)$ ]] && [[ "$line_count" -eq 1 ]] && [[ "$has_equals" == "false" ]]; then
								# Raw value format: .env.VAR_NAME contains just the value
								local var_name="${BASH_REMATCH[1]}"
								# Trim whitespace from value
								local value
								value=$(echo "$content" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
								export "$var_name"="$value"
						else
								# Key-value format: parse each line as KEY=value
								while IFS= read -r line; do
										# Skip empty lines and comments
										[[ -z "$line" ]] && continue
										[[ "$line" =~ ^[[:space:]]*# ]] && continue

										# Check if line has KEY=value format
										if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
												local key="${BASH_REMATCH[1]}"
												local val="${BASH_REMATCH[2]}"
												# Remove surrounding quotes if present
												val="${val#\"}"
												val="${val%\"}"
												val="${val#\'}"
												val="${val%\'}"
												export "$key"="$val"
										fi
								done <<< "$content"
						fi
				done
		done
}

# Run the function
_source_env_files

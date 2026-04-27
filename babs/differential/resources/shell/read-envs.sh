## source any .env files between this directory and the project-level
if [[ -n "$env_file_name" ]]; then
    curdir="$(realpath .)"
    env_files=()
    while [[ "$curdir" != "/" ]]; do
        [[ -f "$curdir/${env_file_name}.local.${USER}" ]] && env_files+=("$curdir/${env_file_name}.local.${USER}")
        [[ -f "$curdir/${env_file_name}.${USER}" ]] && env_files+=("$curdir/${env_file_name}.${USER}")
        [[ -f "$curdir/${env_file_name}.local" ]] && env_files+=("$curdir/${env_file_name}.local")
        [[ -f "$curdir/$env_file_name" ]] && env_files+=("$curdir/$env_file_name")
        [[ "$curdir" == "$pdir" ]] && break
        curdir="$(dirname "$curdir")"
    done
    # Source from top-most to bottom-most
    for file in $(printf "%s\n" "${env_files[@]}" | tac); do
        source "$file"
    done
fi

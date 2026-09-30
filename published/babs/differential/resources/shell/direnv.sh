#!/usr/bin/env bash
#
# direnv.sh — pure bash envrc evaluator for Make
#

# function to dump all variables (exported + unexported) as KEY=VALUE
dump_env() {
    # iterate all variables
    compgen -v | while read -r var; do
        # skip variables that can't be printed
        declare -p "$var" &>/dev/null || continue
        # get value literally
        val=${!var-}
        # check exported
        if declare -p "$var" 2>/dev/null | grep -q -- '-x'; then
            echo "export $var=$val"
        else
            echo "$var=$val"
        fi
    done | sort
}

before=$(mktemp)
after=$(mktemp)
#So references to HOME won't get truly expanded until the arrive in a recipe shell:
export HOME='${HOME}'
dump_env >"$before"

# run a subshell with .envrc and snapshot after
(
    for file in "$@"; do
        source "$file";
    done
    dump_env >"$after"
)

# compute diff
diff -u "$before" "$after" \
    | grep '^[+-][^+-]' \
    | while read -r line; do
    case "$line" in
        +*) echo "${line#+}" ;;          # added/changed
        -*) var=${line#-}; echo "${var%%=*}=" ;;  # removed → blank
    esac
done

rm -f "$before" "$after"

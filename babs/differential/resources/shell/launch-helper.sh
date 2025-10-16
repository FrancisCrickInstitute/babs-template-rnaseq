if [[ "$(basename $0)" == "launcher" && -z "$BABS_CMD" ]]; then
    [[ -n "$docker_image" ]] && echo "About to use $docker_image" || echo "No image specificed - possible problem with ${BABS_DOTENV}"
    if [[ -z "$BABS_rerunning" ]]; then 
	echo "Please enter values (brackets contain example values - leave blank for the [default] value)"
    else
	echo "Restarting options, as a change in environment files can change remaining defaults"
    fi
    read -p "Path of environment file ([$BABS_DOTENV], '../.env', /dev/null/): " input_DOTENV
    if [[ -n "$input_DOTENV" ]]; then
      BABS_DOTENV=${input_DOTENV:-$BABS_DOTENV}
      export BABS_PROJECT_ROOT BABS_CMD BABS_DEV BABS_DOTENV BABS_INTERACTIVE BABS_LOG BABS_rerunning=true
      exec "$0" "$@"
    fi
    [[ "$BABS_DOTENV" == ".env" ]] && out="" || out="BABS_DOTENV=$BABS_DOTENV "
    read -p "Project root, for binding purposes ([$BABS_PROJECT_ROOT], ., ): " input_PROJECT_ROOT
    BABS_PROJECT_ROOT=$(realpath ${input_PROJECT_ROOT:-$BABS_PROJECT_ROOT})
    [[ -z "$input_PROJECT_ROOT"  ]] || out="${out}BABS_PROJECT_ROOT=$BABS_PROJECT_ROOT "
    read -p "What command to call in the container. ([rstudio], shiny, jupyter, http, shell; R, python3, ./run.sh or any other command/path to script): " input_CMD
    BABS_CMD=${input_CMD:-rstudio}
    out="${out}BABS_CMD=${BABS_CMD} "
    read -p "Redirect stdin/err to: ([${BABS_DEV:-terminal}], /dev/null, .launcher.log, ...): " input_DEV
    BABS_DEV=${input_DEV:-$BABS_DEV}
    [[ -z "$input_DEV"  ]] || out="${out}BABS_DEV=$BABS_DEV "
    read -p "For docker, do you want non-server commands to be interactive ([true], anything else is false): " input_INTERACTIVE
    BABS_INTERACTIVE=${input_INTERACTIVE:-true}
    [[ "$BABS_INTERACTIVE" == "true" ]] || out="${out}BABS_INTERACTIVE=false "
    echo "$out$0 $@"
fi

rstudio() {
    export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
    export SINGULARITYENV_USER=$(id -un)
    export SINGULARITYENV_PASSWORD=$PASSWORD
    export SINGULARITY_BIND="${SINGULARITY_BIND},\
${launcher_dir}/${USER}/rsession.conf:/etc/rstudio/rsession.conf,\
${launcher_dir}/${USER}/R:$HOME/.config/R,\
${launcher_dir}/${USER}/rstudio:$HOME/.config/rstudio"
    mkdir -p  ${launcher_dir}/${USER}/rstudio ${launcher_dir}/${USER}/R

    [[ ",${SINGULARITY_BIND}," == *",/etc/ssl/certs/ca-bundle.crt,"* ]] || SINGULARITY_BIND=${SINGULARITY_BIND},/etc/ssl/certs/ca-bundle.crt
    [[ ",${SINGULARITY_BIND}," == *",$HOME/.ssh,"* ]] || SINGULARITY_BIND=${SINGULARITY_BIND},$HOME/.ssh
    [[ ",${SINGULARITY_BIND}," == *",/sys/fs/cgroup,"* ]] || SINGULARITY_BIND=${SINGULARITY_BIND},/sys/fs/cgroup

    if [ "$container" = singularity ]; then
        echo "session-default-working-dir=$pdir" > ${launcher_dir}/${USER}/rsession.conf
    else
        echo "session-default-working-dir=/home/rstudio/project" > ${launcher_dir}/${USER}/rsession.conf
    fi

    printf '{\n"knit_working_dir": "current"\n}\n' > ${launcher_dir}/${USER}/rstudio/rstudio-prefs.json

    rstudio_cmd='env > ~/.Renviron;\
    echo "✅ Starting RStudio...";\
    exec /usr/lib/rstudio-server/bin/rserver \
    --server-daemonize=0 \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0 \
    --www-port '$PORT

    if [ "$container" = singularity ]; then
        rstudio_cmd+="\
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user $(whoami)"
    fi

    my_caller bash -c "$rstudio_cmd" &
    PID=$!
    server_info rstudio 8787
    wait $PID
}

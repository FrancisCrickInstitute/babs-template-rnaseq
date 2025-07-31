#!/usr/bin/env bash


export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$PASSWORD
export SINGULARITY_BIND="${SINGULARITY_BIND:+$SINGULARITY_BIND,}\
$ldir/rsession.conf:/etc/rstudio/rsession.conf,\
$ldir/R:$HOME/.config/R,\
$ldir/rstudio:$HOME/.config/rstudio,\
/etc/ssl/certs/ca-bundle.crt,\
$HOME/.ssh,/sys/fs/cgroup"

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
mkdir -p -m 700 $ldir/rstudio $ldir/R


if [ "$container" = singularity ]; then
    echo "session-default-working-dir=$pdir" > $ldir/rsession.conf
else
    echo "session-default-working-dir=/home/rstudio/project" > $ldir/rsession.conf
fi


cat > $ldir/rstudio/rstudio-prefs.json <<EOF
{
    "knit_working_dir": "current"
}
EOF

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
    --server-user "$(whoami)
fi


my_caller bash -c "$rstudio_cmd" &
PID=$!

server_info rstudio 8787

wait $PID

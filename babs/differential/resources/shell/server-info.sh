server_info() {
    # $1 = word describing server
    # $2 = usual port
    # $3 = option url suffix
    # Trap SIGINT/SIGTERM and kill *this specific singularity exec*
    if [ -z "$run_tmux" ]; then 
	trap "echo '⚠️ Stopping $1 (PID=$PID)...'; kill $PID; wait $PID 2>/dev/null; exit 0" SIGINT SIGTERM
    fi
    echo "✅ Starting $1 server..."
    # Wait until the port responds
    for i in {1..120}; do
        if nc -z localhost $PORT 2>/dev/null; then
            break
        fi
        sleep 1
    done
    if ! nc -z localhost $PORT 2>/dev/null; then
        echo "⚠️ Warning: $1 did not start within two minutes"
    fi
    ## Produce the informative message
    echo "✅ Point your web browser to http://$(hostname).$(dnsdomainname):$PORT$3"
    command -v doitclient >/dev/null 2>&1 && timeout 10s doitclient www "http://$(hostname).$(dnsdomainname):$PORT$3" || true

    if [ -n "${SLURM_JOB_ID}" ]; then
        cat 1>&2 <<END
$(echo -e "\033[44;97m i \033[0m") If that doesn't work, create an SSH tunnel from your workstation (ie _not_ something at $(dnsdomainname))
using the following command:

ssh -A -N -L $2:$(hostname).$(dnsdomainname):$PORT $(id -un)@${login_node}.$(dnsdomainname)

(or another login node on $(dnsdomainname) instead of ${login_node})
and point your web browser to http://localhost:$2$3
END
    fi

    if [ -z "${SLURM_JOB_ID}" ]; then
        [ -z "$run_tmux" ] && echo "⚠️ When done using using the server, quit (Ctrl+C) this process" || echo "⚠️ When done using using the server, close the tmux window (Ctrl+C in it)"
    else
        cat 1>&2 <<END
⚠️ When done using using the app, issue the following command on the ${login_node} node:
  scancel -f ${SLURM_JOB_ID}
END
    fi

    if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
        curl -s -H "Title: $1 server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
             -d "Access server on http://$(hostname).$(dnsdomainname):$PORT$3 - see slurm-$1.out for details. To cancel the slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
    fi
}



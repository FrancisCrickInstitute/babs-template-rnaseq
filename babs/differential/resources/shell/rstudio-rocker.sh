#!/usr/bin/env bash
#SBATCH --output=rstudio-server.log
#SBATCH --job-name=rstudio
#SBATCH --ntasks=1

ml Singularity/${2:-3.11.3}

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
workdir=$(mktemp -u)

mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server ${workdir}/rstudio ${workdir}/R
cat > ${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.

if [ -z ${SLURM_JOB_ID+x} ]; then
    OMP_NUM_THREADS_VAL=16
else
    OMP_NUM_THREADS_VAL=${SLURM_JOB_CPUS_PER_NODE}
fi
cat > ${workdir}/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${OMP_NUM_THREADS_VAL}
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

cat > ${workdir}/rsession.conf <<END
session-default-working-dir=${PWD}
END

cat > ${workdir}/rstudio/rstudio-prefs.json <<EOF
{
    "knit_working_dir": "current"
}
EOF

chmod +x ${workdir}/rsession.sh
set -a
. ./Renviron.site
set +a

export SINGULARITY_BIND="${workdir}/run:/run, ${workdir}/tmp:/tmp, ${workdir}/database.conf:/etc/rstudio/database.conf, \
                         ${workdir}/rsession.sh:/etc/rstudio/rsession.sh, ${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server, \
			 ${workdir}/rsession.conf:/etc/rstudio/rsession.conf, ${workdir}/R:$HOME/.config/R, ${workdir}/rstudio:$HOME/.config/rstudio, \
                         ${PWD}/Renviron.site:/usr/local/lib/R/etc/Renviron.site, /etc/ssl/certs/ca-bundle.crt, ${workdir}/rserver.sh, \
                         $HOME/.ssh,/sys/fs/cgroup,${PWD},${RENV_PATHS_ROOT}"

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

## Produce the informative message

if [ -z "$3" ]; then
    echo "1. Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}"
else
cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:
   ssh -A -N -L 8787:$(hostname).$(dnsdomainname):${PORT} ${SINGULARITYENV_USER}@$3.$(dnsdomainname)
   and point your web browser to http://localhost:8787
END
fi
cat 1>&2 <<END
2. Log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
END
if [ -z "$3" ]; then
echo "2. Quit (Ctrl+C) this process"
else
cat 1>&2 <<END
2. Issue the following command on the login node:
      scancel -f ${SLURM_JOB_ID}
END
fi

## Generate the script that will run RStudio

echo "#!/bin/sh" > ${workdir}/rserver.sh

if [ ! -z "$3" ] && [ ! -z "${NTFY}"]; then
cat >> ${workdir}/rserver.sh <<END
curl -s -H "Title: RStudio server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see rstudio-server.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
END
fi

cat >> ${workdir}/rserver.sh <<END
/usr/lib/rstudio-server/bin/rserver --www-port ${PORT} \
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user $(whoami) \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0 \
    --rsession-path=/etc/rstudio/rsession.sh  
END

## Run the above generated script within singularity
singularity exec --cleanenv --containall $1 sh ${workdir}/rserver.sh >/dev/null 2>&1

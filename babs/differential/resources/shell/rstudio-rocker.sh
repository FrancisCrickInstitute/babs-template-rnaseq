#!/usr/bin/env bash
#SBATCH --output=rstudio-server.job.log
#SBATCH --job-name=rstudio
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --partition=cpu
#SBATCH --time='8:00:00'
#SBATCH --mem=64G

ml Singularity/3.6.4 

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
IMAGE=${IMAGE:-/flask/apps/containers/all-singularity-images/verse-boost_4.2.2.sif}
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


export SINGULARITY_BIND="${workdir}/run:/run, ${workdir}/tmp:/tmp, ${workdir}/database.conf:/etc/rstudio/database.conf, \
                         ${workdir}/rsession.sh:/etc/rstudio/rsession.sh, ${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server, \
			 ${workdir}/rsession.conf:/etc/rstudio/rsession.conf, ${workdir}/R:$HOME/.config/R, ${workdir}/rstudio:$HOME/.config/rstudio, \
                         ${PWD}/rocker.Renviron:/usr/local/lib/R/etc/Renviron.site, /etc/ssl/certs/ca-bundle.crt, ${workdir}/rserver.sh, \
                         $HOME/.ssh,/sys/fs/cgroup, \
                         /nemo/project/apps,/nemo/svc,/nemo/stp,/camp/stp/,/nemo/lab"

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
cat 1>&2 <<END
1. Point your web browser to http://$(hostname).camp.thecrick.org:${PORT}

2. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:$(hostname).camp.thecrick.org:${PORT} ${SINGULARITYENV_USER}@LOGIN-HOST

   and point your web browser to http://localhost:8787

3. log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

# We will write Rserver script in a file to send notifications
cat > ${workdir}/rserver.sh <<END
#!/bin/sh

# Notification:
[ "${NTFY}" == "" ] || \
curl -s -H "Title: RStudio server ready" \
     -H "Tag:information_source" \
     -d "Access server at:
            http://$(hostname).camp.thecrick.org:${PORT}

        To cancel job, if on SLURM queue:
          scancel -f ${SLURM_JOB_ID}" \
        https://ntfy.sh/${NTFY} &> /dev/null

# Start server
/usr/lib/rstudio-server/bin/rserver --www-port ${PORT} \
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user $(whoami) \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0 \
    --rsession-path=/etc/rstudio/rsession.sh

printf 'rserver exited' 1>&2
END

singularity exec --cleanenv --containall ${IMAGE} sh ${workdir}/rserver.sh

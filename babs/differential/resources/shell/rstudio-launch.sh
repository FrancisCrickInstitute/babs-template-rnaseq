#!/usr/bin/env bash
#SBATCH --output=server.log
#SBATCH --job-name=rstudio
#SBATCH --ntasks=1


# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
mkdir -p -m 700 tmp var/lib/rstudio-server rstudio R run

cat > database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.

if [ -z "${SLURM_JOB_ID}" ]; then
    OMP_NUM_THREADS_VAL=16
else
    OMP_NUM_THREADS_VAL=${SLURM_JOB_CPUS_PER_NODE}
fi
cat > rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${OMP_NUM_THREADS_VAL}
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

cat > rsession.conf <<END
session-default-working-dir=${PWD}/..
END

cat > rstudio/rstudio-prefs.json <<EOF
{
    "knit_working_dir": "current"
}
EOF

chmod +x ./rsession.sh

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126

while
  PORT=$(shuf -n 1 -i 49152-65535)
  netstat -atun | grep -q "$PORT"
do
  continue
done


## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
    echo "1. Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}"
else
cat 1>&2 <<END
1. SSH tunnel from your workstation (ie not ${hname}) using the following command:
   ssh -A -N -L 8787:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
   and point your web browser to http://localhost:8787
END
fi

cat 1>&2 <<END
2. Log in to RStudio Server using the following credentials:

   user: ${me}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
END
if [ -z "${SLURM_JOB_ID}" ]; then
echo "2. Quit (Ctrl+C) this process"
else
cat 1>&2 <<END
2. Issue the following command on the login node:
      scancel -f ${SLURM_JOB_ID}
END
fi


if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
curl -s -H "Title: RStudio server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see rstudio-server.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
fi

eval ${caller} /usr/lib/rstudio-server/bin/rserver --www-port ${PORT} \
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user $(whoami) \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0 \
    --rsession-path=/etc/rstudio/rsession.sh  

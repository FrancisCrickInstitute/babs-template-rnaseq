#!/usr/bin/env bash
#SBATCH --output=jupyter-server.log
#SBATCH --job-name=jupyter
#SBATCH --ntasks=1


# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.

if [ -z "${SLURM_JOB_ID}" ]; then
    OMP_NUM_THREADS_VAL=16
else
    OMP_NUM_THREADS_VAL=${SLURM_JOB_CPUS_PER_NODE}
fi


while
  PORT=$(shuf -n 1 -i 49152-65535)
  netstat -atun | grep -q "$PORT"
do
  continue
done


## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
    echo "1. Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}/lab"
else
cat 1>&2 <<END
1. SSH tunnel from your workstation (ie not ${hname}) using the following command:
   ssh -A -N -L 8888:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
   and point your web browser to http://localhost:8888/lab
END
fi

cat 1>&2 <<END
1. Exit the Jupyter lab Session (From within Jupyter lab interface: File > Shut Down)
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
curl -s -H "Title: Jupyter server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see jupyter-server.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
fi

eval ${caller} uv run --no-cache  --with jupyter jupyter lab \
     --ip 0.0.0.0 \
     --no-browser \
     --port ${PORT} \
     --NotebookApp.token='' \
     --NotebookApp.password=''

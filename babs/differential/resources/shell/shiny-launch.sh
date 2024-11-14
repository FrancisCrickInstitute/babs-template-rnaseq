#!/usr/bin/env bash
#SBATCH --output=shiny.log
#SBATCH --job-name=shiny
#SBATCH --ntasks=1

while
  PORT=$(shuf -n 1 -i 49152-65535)
  netstat -atun | grep -q "$PORT"
do
  continue
done

## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
  echo "Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}"
else
cat 1>&2 <<END
SSH tunnel from your workstation (ie not ${hname}) using the following command:
ssh -A -N -L 3838:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
and point your web browser to http://localhost:3838
END
fi

cat 1>&2 <<END
When done using using the app, terminate the job:
END
if [ -z "${SLURM_JOB_ID}" ]; then
echo "Quit (Ctrl+C) this process"
else
cat 1>&2 <<END
Issue the following command on the login node:
      scancel -f ${SLURM_JOB_ID}
END
fi


if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
curl -s -H "Title: Shiny server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see shiny.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
END
fi

eval ${caller} "R  -e \"shiny::runApp(host='0.0.0.0',port=${PORT})\""

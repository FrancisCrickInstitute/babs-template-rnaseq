#!/usr/bin/env bash

## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
    echo "Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}/lab"
else
cat 1>&2 <<END
Create an SSH tunnel from your workstation (ie _not_ something at $(dnsdomainname)) using the following command:
ssh -A -N -L 8888:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
(or another login node on $(dnsdomainname) instead of ${hname})
and point your web browser to http://localhost:8888
END
fi

cat 1>&2 <<END
When done, exit the Jupyter lab Session (From within Jupyter lab interface: File > Shut Down), then
END

if [ -z "${SLURM_JOB_ID}" ]; then
echo "quit (Ctrl+C) this process"
else
cat 1>&2 <<END
issue the following command on the login node:
   scancel -f ${SLURM_JOB_ID}
END
fi


if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
curl -s -H "Title: Jupyter server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see jupyter-server.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
fi

my_caller uv run --no-cache  --with jupyter jupyter lab \
     --ip 0.0.0.0 \
     --no-browser \
     --port ${PORT} \
     --NotebookApp.token='' \
     --NotebookApp.password=''

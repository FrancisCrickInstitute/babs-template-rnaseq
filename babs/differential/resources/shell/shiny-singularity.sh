#!/usr/bin/env bash

## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
  echo "Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}"
else
cat 1>&2 <<END
Create an SSH tunnel from your workstation (ie _not_ something at $(dnsdomainname)) using the following command:
ssh -A -N -L 3838:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
(or another login node on $(dnsdomainname) instead of ${hname})
and point your web browser to http://localhost:3838
END
fi

if [ -z "${SLURM_JOB_ID}" ]; then
echo "When done using using the app, quit (Ctrl+C) this process"
else
cat 1>&2 <<END
When done using using the app, issue the following command on the login node:
  scancel -f ${SLURM_JOB_ID}
END
fi


if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
curl -s -H "Title: Shiny server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see shiny.log for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
END
fi

if [ -z "$@" ]; then 
    my_caller R -e "shiny::runApp(host='0.0.0.0',port=${PORT})"
else
    my_caller R -e "shiny::runApp(appDir='$1', host='0.0.0.0',port=${PORT})"
fi

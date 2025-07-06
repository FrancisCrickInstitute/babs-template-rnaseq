#!/usr/bin/env bash

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
mkdir -p -m 700 tmp var/lib/rstudio-server rstudio R run

cat > database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END


cat > rsession.conf <<END
session-default-working-dir=$(realpath ..)
END

cat > rstudio/rstudio-prefs.json <<EOF
{
    "knit_working_dir": "current"
}
EOF


## Produce the informative message
me=$(id -un)
if [ -z "${SLURM_JOB_ID}" ]; then
    echo "Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}"
else
cat 1>&2 <<END
Create an SSH tunnel from your workstation (ie _not_ something at $(dnsdomainname)) using the following command:
ssh -A -N -L 8787:$(hostname).$(dnsdomainname):${PORT} ${me}@${hname}.$(dnsdomainname)
(or another login node on $(dnsdomainname) instead of ${hname})
and point your web browser to http://localhost:8787
END
fi

cat 1>&2 <<END
then log in to RStudio Server using the following credentials:

   user: ${me}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job:
  Exit the RStudio Session ("power" button in the top right corner of the RStudio window) then 
END
if [ -z "${SLURM_JOB_ID}" ]; then
echo "  quit (Ctrl+C) this process"
else
cat 1>&2 <<END
  Issue the following command on the login node:
    scancel -f ${SLURM_JOB_ID}
END
fi


if [ ! -z "${SLURM_JOB_ID}" ] && [ ! -z "${NTFY}" ]; then
curl -s -H "Title: RStudio server ready" -H "Tag:information_source"  https://ntfy.sh/${NTFY} \
 -d "Access server on port ${PORT} - see log file for details. To cancel any slurm job, scancel -f ${SLURM_JOB_ID}"  >/dev/null 2>&1
fi


my_caller bash -c 'env > ~/.Renviron ; exec /usr/lib/rstudio-server/bin/rserver --www-port '$PORT' \
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user '$(whoami)' \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0'

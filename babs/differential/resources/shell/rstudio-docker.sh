#!/usr/bin/env bash

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
mkdir -p -m 700 tmp var/lib/rstudio-server rstudio R run

cat > database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

cat > rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${NUM_THREADS}
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

cat > rsession.conf <<END
session-default-working-dir=$(realpath ..)
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


## Produce the informative message
me=$(id -un)
cat 1>&2 <<END
Point your web browser to http://$(hostname).$(dnsdomainname):${PORT}
then log in to RStudio Server using the following credentials:

   user: ${me}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job:
  Exit the RStudio Session ("power" button in the top right corner of the RStudio window) then quit (Ctrl+C) this process
END

eval ${caller} /usr/lib/rstudio-server/bin/rserver --www-port ${PORT} \
    --auth-none=1 \
    --auth-pam-helper-path=pam-helper \
    --server-user $(whoami) \
    --auth-stay-signed-in-days=30 \
    --auth-timeout-minutes=0 \
    --rsession-path=/etc/rstudio/rsession.sh  

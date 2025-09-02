FROM bioconductor/bioconductor_docker:3.21-r-4.5.1

LABEL name="babs/bioconductor_docker"
LABEL version=3.21-r-4.5.1-v1.2.0
LABEL org.opencontainers.image.source="https://github.com/franciscrickinstitute/babs-wg-environments"
LABEL url="https://github.com/FrancisCrickInstitute/babs-wg-environments"
LABEL vendor="BABS at Francis Crick Institute"
LABEL maintainer="bioinformatics@crick.ac.uk"
LABEL description="Semi-official BABS singularity container"
LABEL license="Artistic-2.0"

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl

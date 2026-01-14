FROM ghcr.io/prefix-dev/pixi:latest AS pixi

FROM bioconductor/bioconductor_docker:3.22-r-4.5.2

LABEL name="babs/bioconductor_docker"
LABEL version=3.22-r-4.5.2-v1.10.0
LABEL org.opencontainers.image.source="https://github.com/franciscrickinstitute/babs-wg-environments"
LABEL url="https://github.com/FrancisCrickInstitute/babs-wg-environments"
LABEL vendor="BABS at Francis Crick Institute"
LABEL maintainer="bioinformatics@crick.ac.uk"
LABEL description="Semi-official BABS singularity container"
LABEL license="Artistic-2.0"

COPY --from=pixi /usr/local/bin/pixi /usr/local/bin/pixi

FROM rocker/verse:4.2.2
RUN R -q -e 'install.packages("renv"); install.packages("pak"); pak::pak("boost"); pak::pak("BiocParallel")'
# docker build -t verse-boost .
# docker tag verse-boost:latest gavinpaulkelly/verse-boost:4.2.2
# docker push gavinpaulkelly/verseboost:4.2.2

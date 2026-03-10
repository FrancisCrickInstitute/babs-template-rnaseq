## Outline

We use a Docker image for all script runtimes (R, Python, etc). This
is based upon the official Bioconductor images (which in turn are
based upon Rocker). We build and publish these images on
[github](https://github.com/franciscrickinstitute/babs-environments/pkgs/container/babs-environments%2Fbioconductor_docker)
but all the resources we used to construct this are at
`./resources/docker` if that URL becomes unavailable.

### Docker Build

We use 'devcontainers' to build our images, using a Dockerfile very
minimally changed from the Bioconductor one, and 'devcontainer features'
to install extra features:

 - R packages that bring with them extra system dependencies that mean
   they can't be purely installed at runtime via renv
   
 - uv package manager for Python
 
 - A specific version of the Quarto renderer
 
In the docker folder we coordinate all this with the `build.sh` script
which invokes the `devcontainer build` command to combine the
Dockerfile and the devcontainer features. If you want to use your own
copy of the image, you just need to run that push the image

### Singularity Build

Once the docker image is pushed to a registry, our scripts will
generate a corresponding singularity `.sif` file when needed (the
criterion for it being needed being if it the `docker` command isn't
available on your system, and also it can't already find the
corresponding `.sif` file on your local system.

Once the `.sif` file is in place, that will be used to contain the
analysis when docker isn't available.

## Package management

For R analyses, we supply a `renv.lock` file, and for Python we supply
the necessary `uv` files to rebuild the environment. These are
compatible with the containers run from our image. They are likely to
work on systems where you have root access to install system
dependencies for the packages and version of R we used, if you install
`uv` as well.

## Localisation

We use `.env` and `.env.local` files. The former is expected to be
analysis-, but not location-, specific: it prescribes the image that
is to be used to run the analysis, so we provide it in the analysis
repo. If you find that the docker image is unavailable and have had to
recreate it yourself, then you will need to change the provided `.env`
file to point to the location of the image.

But `.env.local` is for site-specific settings (where you store
your renv cache, how you call Singularity, ...) so you'll need to
create that yourself. The final lines of the distributed `.env` list
all the environment variable names we use in our analysis: many will
have sensible defaults if unset, but you probably want to copy and
uncomment those lines into your own `.env.local`


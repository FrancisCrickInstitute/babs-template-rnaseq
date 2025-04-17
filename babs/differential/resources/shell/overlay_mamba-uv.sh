#Install UV for python package/project management
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/singularity-bin sh
#Install micromamba for conda-like behaviour
curl -L micro.mamba.pm/install.sh | env BIN_DIR=/singularity-bin sh

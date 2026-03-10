jupyter() {
    sentinel=${launcher_dir}/jupyter-kernel.sentinel
    mkdir -p ${SINGULARITY_UV_CACHE_DIR} ${SINGULARITYENV_PIP_CACHE_DIR} ${SINGULARITYENV_JUPYTER_DATA_DIR}

    if [ ! -f "./pyproject.toml" ]; then
        echo "✅ Initializing uv project..."
        my_caller uv init 
    fi

    if [ ! -d ".venv" ]; then
        echo "✅ Creating uv virtual environment..."
        my_caller uv venv .venv
    fi

    if [ ! -f "${sentinel}" ]; then 
        echo "✅ Installing Jupyter, ipykernel and custom kernel"
        my_caller bash -c "\
       uv add --dev ipykernel jupyterlab &&\
       uv run ipython kernel install --user --env VIRTUAL_ENV /.venv --name='Singularity-UV' &&\
       touch ${sentinel}"
    fi

    my_caller uv run --with jupyter jupyter lab \
              --ip 0.0.0.0 \
              --no-browser \
              --port ${PORT} \
              --NotebookApp.allow_origin='*' \
              --NotebookApp.token="${PASSWORD}" &
    PID=$!
    server_info jupyter 8888 "/lab?token=${PASSWORD}"
    [ -n "$run_tmux" ] || wait $PID
}

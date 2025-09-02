#!/usr/bin/env bash
set -e
devcontainer build --workspace-folder . --push true --image-name ghcr.io//bioconductor_docker:3.21-r-4.5.1-v1.2.0

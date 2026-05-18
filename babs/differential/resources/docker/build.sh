#!/usr/bin/env bash
set -e
devcontainer build --workspace-folder . --push true --image-name ghcr.io/franciscrickinstitute/babs-environments/bioconductor_docker:3.23-R-4.6.0-v1.14.0

#!/usr/bin/env bash
set -e
devcontainer build --workspace-folder . --push true --image-name ghcr.io/franciscrickinstitute/babs-wg-environments/bioconductor_docker:3.22-r-4.5.2-v1.10.0

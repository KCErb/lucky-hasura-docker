# Purpose

This directory contains scripts for starting and stopping local dev environment (up and down) and for deploying / rolling back production.

The `docker` dir contains scripts which should be run in a docker container, other scripts will call these via `docker exec` for example. They are built into the image.

The `functions` dir is for functions to include in main scripts.